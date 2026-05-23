import SwiftUI

/// Rich, Amphetamine-styled active-session panel. Used as the `view` of a single
/// NSMenuItem at the top of the status-item menu so we get full styling control
/// (square checkboxes, prominent pill button) that vanilla NSMenu items don't allow.
struct ActiveSessionPanel: View {
    @Bindable var viewModel: MenuBarViewModel
    let onEnd: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 2)
            statusLines
                .padding(.bottom, 8)

            subtleSeparator
                .padding(.bottom, 6)

            togglesGroup
                .padding(.bottom, 6)

            // Pill button gets its own section bounded by matching hairlines
            // top + bottom, with identical vertical padding so the button sits
            // dead-center between them. Horizontal padding narrows the button
            // away from the panel edges (matches Amphetamine's inset look).
            subtleSeparator
            endButton
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            subtleSeparator
        }
        .padding(.horizontal, 16)   // matches NSMenu item inset
        .padding(.top, 8)
        .padding(.bottom, 0)        // bottom hairline marks the panel edge
        .frame(width: 330, alignment: .leading)
    }

    private var header: some View {
        Text("Current Session Details:")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.primary)
    }

    private var statusLines: some View {
        VStack(alignment: .leading, spacing: 2) {
            LiveStatusText(viewModel: viewModel)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Text(activationLabel)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var activationLabel: String {
        viewModel.isTriggerActive ? "Manual + Triggered Activation" : "Manual Activation"
    }

    private var togglesGroup: some View {
        VStack(alignment: .leading, spacing: 3) {
            CheckboxRow(
                title: "Allow display sleep",
                isOn: Binding(
                    get: { viewModel.policy.allowDisplaySleep },
                    set: { viewModel.policy.allowDisplaySleep = $0 }
                )
            )
            CheckboxRow(
                title: "Allow system sleep when display is closed",
                isOn: Binding(
                    get: { viewModel.policy.allowSystemSleepWhenLidClosed },
                    set: { viewModel.policy.allowSystemSleepWhenLidClosed = $0 }
                )
            )
            CheckboxRow(
                title: "Allow screen saver after 45m of inactivity",
                isOn: Binding(
                    get: { viewModel.policy.allowScreenSaverAfter45Min },
                    set: { viewModel.policy.allowScreenSaverAfter45Min = $0 }
                )
            )
        }
    }

    /// Hairline horizontal separator (more subtle than SwiftUI's default `Divider()`,
    /// matches Amphetamine's faint section breaks).
    private var subtleSeparator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    private var endButton: some View {
        Button(action: onEnd) {
            ZStack {
                // Geometric-center group: icon + label sit on the pill's true midline.
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 14))
                    Text("End Current Session")
                        .font(.system(size: 13, weight: .semibold))
                }
                // ⌘X stays right-aligned independently of the centered group.
                HStack {
                    Spacer()
                    Text("⌘X")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Pieces

/// Subview isolates `viewModel.tick` so only this text refreshes each second.
private struct LiveStatusText: View {
    let viewModel: MenuBarViewModel
    var body: some View {
        Text(viewModel.sessionStatusLine() ?? "")
    }
}

private struct CheckboxRow: View {
    let title: String
    @Binding var isOn: Bool
    @State private var hovering = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                checkbox
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(hovering ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .strokeBorder(Color.primary.opacity(isOn ? 0 : 0.35), lineWidth: 1)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 14, height: 14)
    }
}
