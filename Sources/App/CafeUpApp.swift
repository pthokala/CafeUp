import SwiftUI

@main
struct CafeUpApp: App {
    @State private var deps = CompositionRoot.makeAppDependencies()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                viewModel: deps.menuBarViewModel,
                openSettings: { openWindowAndActivate(id: WindowID.settings) },
                openCustomDuration: { openWindowAndActivate(id: WindowID.customDuration) },
                openEndAtTime: { openWindowAndActivate(id: WindowID.endAtTime) },
                pickApplication: { deps.appPicker.pickApplication() }
            )
        } label: {
            MenuBarIcon(
                style: deps.appearanceViewModel.iconStyle,
                isActive: deps.menuBarViewModel.isActive
            )
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: WindowID.settings) {
            SettingsView(
                menuBarViewModel: deps.menuBarViewModel,
                appearanceViewModel: deps.appearanceViewModel,
                triggersViewModel: deps.triggersViewModel
            )
        }
        .windowResizability(.contentSize)

        Window("Custom Duration", id: WindowID.customDuration) {
            CustomDurationView { duration in
                deps.menuBarViewModel.start(duration: duration)
            }
        }
        .windowResizability(.contentSize)

        Window("End at Time", id: WindowID.endAtTime) {
            EndAtTimeView { endDate in
                deps.menuBarViewModel.startUntil(endDate)
            }
        }
        .windowResizability(.contentSize)
    }

    private func openWindowAndActivate(id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
