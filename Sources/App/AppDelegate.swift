import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let deps: CompositionRoot.AppDependencies
    var statusController: StatusBarController?

    /// Set by `CafeUpApp` so the AppDelegate can open SwiftUI windows by id.
    var openWindow: ((String) -> Void)?

    /// Router for `cafeup://…` URLs. Created lazily after launch so the
    /// underlying command handler is fully wired.
    private var urlRouter: URLCommandRouter?

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
        urlRouter = URLCommandRouter(
            handler: AppIntentBridge.shared,
            logger: OSAppLogger(category: "url")
        )
        // Begin emitting status.json after the bridge is wired so any URL
        // that arrived during launch also reflects in the file.
        deps.statusFilePublisher.start()
    }

    /// AppKit funnels `open cafeup://…` here. The array can contain multiple
    /// URLs in a single invocation (e.g. `open cafeup://stop cafeup://start`);
    /// we route each in order, on the main actor.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let urlRouter else { return }
        for url in urls {
            urlRouter.handle(url)
        }
    }

    /// Gracefully end any active session before the process exits so that
    /// session-end callbacks (sounds, observers) fire and watchers shut down
    /// cleanly. IOKit assertions would be released by the kernel either way.
    /// We then `flushNow()` the status file so the on-disk state reflects
    /// shutdown even if pending main-actor Tasks don't get drained.
    func applicationWillTerminate(_ notification: Notification) {
        deps.menuBarViewModel.stop()
        deps.statusFilePublisher.flushNow()
    }

    private func openAndActivate(_ id: String) {
        openWindow?(id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
