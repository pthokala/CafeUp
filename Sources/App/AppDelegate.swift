import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let deps: CompositionRoot.AppDependencies
    var statusController: StatusBarController?

    /// Set by `CafeUpApp` so the AppDelegate can open SwiftUI windows by id.
    var openWindow: ((String) -> Void)?

    override init() {
        self.deps = CompositionRoot.makeAppDependencies()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusBarController(
            viewModel: deps.menuBarViewModel,
            appearanceViewModel: deps.appearanceViewModel,
            updaterService: deps.updaterService,
            pickApplication: { [deps] in deps.appPicker.pickApplication() },
            openSettings: { [weak self] in self?.openAndActivate(WindowID.settings) },
            openCustomDuration: { [weak self] in self?.openAndActivate(WindowID.customDuration) },
            openEndAtTime: { [weak self] in self?.openAndActivate(WindowID.endAtTime) }
        )
    }

    /// Gracefully end any active session before the process exits so that
    /// session-end callbacks (sounds, observers) fire and watchers shut down
    /// cleanly. IOKit assertions would be released by the kernel either way.
    func applicationWillTerminate(_ notification: Notification) {
        deps.menuBarViewModel.stop()
    }

    private func openAndActivate(_ id: String) {
        openWindow?(id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
