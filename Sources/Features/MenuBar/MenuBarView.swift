import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: MenuBarViewModel
    let openSettings: @MainActor () -> Void
    let openCustomDuration: @MainActor () -> Void
    let openEndAtTime: @MainActor () -> Void
    let pickApplication: @MainActor () -> PickedApplication?

    var body: some View {
        Group {
            if viewModel.isManualSessionActive, let session = viewModel.session {
                currentSessionSection(session: session)
                Divider()
            } else if viewModel.isTriggerActive {
                triggerOnlySection
                Divider()
            }

            startNewSessionSection

            Divider()

            quickSettingsMenu
            Button("Settings…") { openSettings() }
                .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("About CafeUp") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            feedbackMenu

            Divider()

            Button("Quit CafeUp") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }

    @ViewBuilder
    private func currentSessionSection(session: Session) -> some View {
        Section("Current Session Details:") {
            LiveSessionStatusLine(viewModel: viewModel)
            Text(activationLabel)
            allowDisplaySleepToggle
            Button("End Current Session") { viewModel.stop() }
                .keyboardShortcut("x", modifiers: .command)
        }
    }

    private var triggerOnlySection: some View {
        Section("Current Session Details:") {
            let count = viewModel.activeTriggerCount
            let suffix = count == 1 ? "trigger" : "triggers"
            Text("Awake — \(count) \(suffix) active")
            Text("Triggered Activation")
        }
    }

    private var startNewSessionSection: some View {
        Section("Start New Session:") {
            Button("Indefinitely") { viewModel.startIndefinite() }
                .keyboardShortcut("i", modifiers: .command)

            Menu("Minutes") {
                ForEach(SessionPreset.minutePresets) { preset in
                    Button(preset.label) { viewModel.start(duration: preset.duration) }
                }
            }

            Menu("Hours") {
                ForEach(SessionPreset.hourPresets) { preset in
                    Button(preset.label) { viewModel.start(duration: preset.duration) }
                }
            }

            Menu("Other Time/Until") {
                Button("Custom Duration…") { openCustomDuration() }
                Button("End at Time…") { openEndAtTime() }
            }

            Menu("While App is Running") {
                let apps = RunningApplicationsSnapshot.currentRegularApps()
                if apps.isEmpty {
                    Text("No other apps running")
                } else {
                    ForEach(apps.prefix(15), id: \.id) { entry in
                        Button(entry.name) {
                            viewModel.startWhileAppRunning(bundleIdentifier: entry.id)
                        }
                    }
                }
                Divider()
                Button("Choose Application…") {
                    if let picked = pickApplication() {
                        viewModel.startWhileAppRunning(bundleIdentifier: picked.bundleIdentifier)
                    }
                }
            }

            Button("While File is Downloading…") { viewModel.startWhileDownloading() }
                .keyboardShortcut("f", modifiers: .command)
        }
    }

    private var quickSettingsMenu: some View {
        Menu("Quick Settings") {
            allowDisplaySleepToggle
        }
    }

    private var feedbackMenu: some View {
        Menu("Feedback & Support") {
            Button("Report an Issue") {
                openURL("https://github.com/pthokala/CafeUp/issues/new")
            }
            Button("Project Page") {
                openURL("https://github.com/pthokala/CafeUp")
            }
        }
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private var allowDisplaySleepToggle: some View {
        Toggle("Allow display sleep", isOn: Binding(
            get: { viewModel.policy == .systemOnly },
            set: { viewModel.policy = $0 ? .systemOnly : .systemAndDisplay }
        ))
    }

    private var activationLabel: String {
        viewModel.isTriggerActive ? "Manual + Triggered Activation" : "Manual Activation"
    }

}

/// Isolated subview so the per-second `tick` only re-renders this row, not the whole menu —
/// otherwise NSMenu hover tracking gets reset every second.
private struct LiveSessionStatusLine: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        if let line = viewModel.sessionStatusLine() {
            Text(line)
        }
    }
}
