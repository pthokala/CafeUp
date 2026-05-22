import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: MenuBarViewModel
    let presets: [SessionPreset]
    let openTriggers: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            Divider()
            actionsSection
            Divider()
            settingsSection
            Divider()
            footerSection
        }
        .padding(.vertical, 6)
        .frame(width: 280)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SessionStatusView(
                session: viewModel.session,
                isTriggerActive: viewModel.isTriggerActive,
                activeTriggerCount: viewModel.activeTriggerCount
            )
            .font(.callout)

            if viewModel.isManualSessionActive {
                Button {
                    viewModel.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MenuRowButton(label: "Keep awake indefinitely", systemImage: "infinity") {
                viewModel.startIndefinite()
            }

            Text("Or for…")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                spacing: 6
            ) {
                ForEach(presets) { preset in
                    Button {
                        viewModel.start(duration: preset.duration)
                    } label: {
                        Text(preset.label)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var settingsSection: some View {
        Toggle("Prevent display sleep", isOn: Binding(
            get: { viewModel.policy == .systemAndDisplay },
            set: { viewModel.policy = $0 ? .systemAndDisplay : .systemOnly }
        ))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRowButton(label: "Triggers…", systemImage: "bolt", action: openTriggers)
            MenuRowButton(label: "Quit CafeUp", systemImage: "power") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

private struct MenuRowButton: View {
    let label: String
    let systemImage: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(label)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}
