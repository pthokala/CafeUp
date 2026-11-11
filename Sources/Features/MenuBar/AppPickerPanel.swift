import SwiftUI

/// Contents of the "While App is Running" submenu: a searchable list of running apps.
/// The session ends when the selected app quits.
struct AppPickerPanel: View {
    let onSelect: @MainActor (_ bundleIdentifier: String) -> Void
    let onChooseOther: @MainActor () -> Void
    let onCancel: @MainActor () -> Void

    @State private var query = ""
    @State private var hideHelpers = true
    @State private var apps: [RunningApplicationsSnapshot.Entry]
    @State private var selection: String?

    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private static let rowHeight: CGFloat = 36
    private static let visibleRows = 8

    init(
        onSelect: @escaping @MainActor (_ bundleIdentifier: String) -> Void,
        onChooseOther: @escaping @MainActor () -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.onSelect = onSelect
        self.onChooseOther = onChooseOther
        self.onCancel = onCancel
        let apps = RunningApplicationsSnapshot.runningApps()
        _apps = State(initialValue: apps)
        _selection = State(initialValue: apps.first?.id)   // so Select starts out enabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                searchField
                Button(action: reload) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh the list of running apps")
            }

            list

            Toggle("Don't show helper apps or processes", isOn: $hideHelpers)
                .toggleStyle(MenuCheckboxStyle(labelSize: 13, boxSize: 14))
                .onChange(of: hideHelpers) { _, _ in reload() }

            HStack(spacing: 8) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(MenuPushButtonStyle(font: .system(size: 13), height: 22))
                    .frame(width: 80)
                Spacer()
                Button("Other App…", action: onChooseOther)
                    .buttonStyle(MenuPushButtonStyle(font: .system(size: 13), height: 22))
                    .frame(width: 96)
                    .help("Pick an app that isn't running yet")
                Button("Select") {
                    if let selection { onSelect(selection) }
                }
                .buttonStyle(MenuPushButtonStyle(prominent: true, font: .system(size: 13), height: 22))
                .frame(width: 80)
                .disabled(selection == nil)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var searchField: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit {
                    // Return picks the selected app, or the top match.
                    if let id = selection ?? filteredApps.first?.id { onSelect(id) }
                }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(shape.fill(colorScheme == .dark ? Color.black.opacity(0.25) : Color.white))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
        .overlay(shape.inset(by: -1.5).stroke(Color.accentColor.opacity(searchFocused ? 0.8 : 0), lineWidth: 3))
    }

    private var list: some View {
        let rows = filteredApps
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, app in
                    row(app, striped: index.isMultiple(of: 2))
                }
                // Keep the stripes going below the last app, down to the list's bottom.
                ForEach(rows.count..<max(rows.count, Self.visibleRows), id: \.self) { index in
                    stripe(index.isMultiple(of: 2) ? Color.primary.opacity(0.06) : Color.clear)
                }
            }
        }
        .frame(height: Self.rowHeight * CGFloat(Self.visibleRows))
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
        .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
        .overlay {
            if rows.isEmpty {
                Text(query.isEmpty ? "No other apps running" : "No matching apps")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ app: RunningApplicationsSnapshot.Entry, striped: Bool) -> some View {
        let selected = app.id == selection
        return HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Color.clear.frame(width: 24, height: 24)
            }
            Text(app.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.rowHeight)
        .background(
            selected ? Color.accentColor
                : (striped ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onSelect(app.id) }
        .onTapGesture { selection = app.id }
    }

    private func stripe(_ color: Color) -> some View {
        color.frame(height: Self.rowHeight)
    }

    private var filteredApps: [RunningApplicationsSnapshot.Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private func reload() {
        apps = RunningApplicationsSnapshot.runningApps(includeHelpers: !hideHelpers)
        if !apps.contains(where: { $0.id == selection }) {
            selection = apps.first?.id
        }
    }
}
