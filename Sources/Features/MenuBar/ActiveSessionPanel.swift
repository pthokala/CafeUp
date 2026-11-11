import SwiftUI

/// Active-session panel. Used as the `view` of a single NSMenuItem at the top of the
/// status-item menu so the details, toggles and End button can sit together in one
/// block. Styled to read like native menu content: bold header, smaller indented
/// detail rows, small checkboxes, and a key-equivalent hint aligned with the
/// menu's own shortcut column.
struct ActiveSessionPanel: View {
    @Bindable var viewModel: MenuBarViewModel
    let onEnd: @MainActor () -> Void

    /// Width shared with `StatusBarMenuBuilder`'s section headers so both line up.
    static let width: CGFloat = 330

    /// Matches NSMenu's leading/trailing text inset.
    private static let edgeInset: CGFloat = 16
    /// Detail rows sit indented under the header.
    private static let detailIndent: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 4)
            Group {
                statusLines
                    .padding(.bottom, 12)
                togglesGroup
                    .padding(.bottom, 18)
                if viewModel.isTimedSession {
                    ExtendRow(onExtend: viewModel.extendSession(by:))
                        .padding(.bottom, 10)
                }
                endRow
            }
            .padding(.leading, Self.detailIndent)
        }
        .padding(.horizontal, Self.edgeInset)
        .padding(.top, 4)
        .padding(.bottom, 4)        // native separator follows in the menu
        .frame(width: Self.width, alignment: .leading)
    }

    private var header: some View {
        Text("Current Session Details:")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
    }

    private var statusLines: some View {
        VStack(alignment: .leading, spacing: 5) {
            LiveStatusText(viewModel: viewModel)
            Text(activationLabel)
        }
        .font(.system(size: 11))
        .foregroundStyle(.primary)
    }

    private var activationLabel: String {
        viewModel.isTriggerActive ? "Manual + Triggered Activation" : "Manual Activation"
    }

    private var togglesGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Allow display sleep", isOn: Binding(
                get: { viewModel.policy.allowDisplaySleep },
                set: { viewModel.policy.allowDisplaySleep = $0 }
            ))
            Toggle("Allow system sleep when display is closed", isOn: Binding(
                get: { viewModel.policy.allowSystemSleepWhenLidClosed },
                set: { viewModel.policy.allowSystemSleepWhenLidClosed = $0 }
            ))
            .help(WakePolicy.lidClosedAwakeNote)
            Toggle("Allow screen saver after 45m of inactivity", isOn: Binding(
                get: { viewModel.policy.allowScreenSaverAfter45Min },
                set: { viewModel.policy.allowScreenSaverAfter45Min = $0 }
            ))
        }
        .toggleStyle(MenuCheckboxStyle())
    }

    /// End button on the left; "⌘X" on the right in the same column as the menu's
    /// other key equivalents. `StatusBarController` handles the real ⌘X.
    private var endRow: some View {
        HStack(spacing: 0) {
            Button("End Current Session", action: onEnd)
                .buttonStyle(MenuPushButtonStyle())
                .frame(width: 204)
            Spacer(minLength: 8)
            Text("⌘X")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Pieces

/// "Extend session by [15] [m|h] [+]", shown for sessions with a fixed end.
private struct ExtendRow: View {
    let onExtend: @MainActor (Duration) -> Void

    private enum Unit: Hashable { case minutes, hours }

    @State private var amount = "15"
    @State private var unit = Unit.minutes

    var body: some View {
        HStack(spacing: 8) {
            Text("Extend session by")
                .font(.system(size: 11))
            MenuNumberField(text: $amount, width: 30, fontSize: 11, maxDigits: 3)
                .onSubmit(extend)
            MenuSegmentedControl(
                segments: [(label: "m", value: Unit.minutes), (label: "h", value: Unit.hours)],
                selection: $unit
            )
            Button(action: extend) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(MenuPushButtonStyle(height: 18))
            .frame(width: 30)
            .disabled((Int(amount) ?? 0) == 0)
        }
    }

    private func extend() {
        guard let n = Int(amount), n > 0 else { return }
        onExtend(.seconds(n * (unit == .hours ? 3600 : 60)))
    }
}

/// Subview isolates `viewModel.tick` so only this text refreshes each second.
private struct LiveStatusText: View {
    let viewModel: MenuBarViewModel
    var body: some View {
        Text(viewModel.sessionStatusLine() ?? "")
    }
}
