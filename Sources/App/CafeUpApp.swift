import SwiftUI

@main
struct CafeUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Settings", id: WindowID.settings) {
            SettingsView(
                menuBarViewModel: appDelegate.deps.menuBarViewModel,
                appearanceViewModel: appDelegate.deps.appearanceViewModel,
                triggersViewModel: appDelegate.deps.triggersViewModel,
                updatesViewModel: appDelegate.deps.updatesViewModel
            )
            .onAppear { appDelegate.openWindow = { id in openWindow(id: id) } }
        }
        .windowResizability(.contentSize)

        Window("Custom Duration", id: WindowID.customDuration) {
            CustomDurationView { duration in
                appDelegate.deps.menuBarViewModel.start(duration: duration)
            }
        }
        .windowResizability(.contentSize)

        Window("End at Time", id: WindowID.endAtTime) {
            EndAtTimeView { endDate in
                appDelegate.deps.menuBarViewModel.startUntil(endDate)
            }
        }
        .windowResizability(.contentSize)
    }
}
