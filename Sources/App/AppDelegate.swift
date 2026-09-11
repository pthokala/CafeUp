import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let deps: CompositionRoot.AppDependencies
    var statusController: StatusBarController?

    private let windows = AuxiliaryWindows()

    /// Router for `cafeup://…` URLs. Created once launch has wired the status
    /// item and command handler.
    private var urlRouter: URLCommandRouter?

    /// URLs that arrived before `urlRouter` existed. On a cold launch
    /// (`cafeup start` while the app isn't running) AppKit delivers the
    /// GetURL event *before* `applicationDidFinishLaunching`, so these are
    /// replayed there instead of being dropped.
    private var pendingURLs: [URL] = []

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
            openSettings: { [weak self] in self?.showSettings() },
            openCustomDuration: { [weak self] in self?.showCustomDuration() },
            openEndAtTime: { [weak self] in self?.showEndAtTime() }
        )
        let router = URLCommandRouter(
            handler: AppIntentBridge.shared,
            logger: OSAppLogger(category: "url")
        )
        urlRouter = router
        let launchURLs = pendingURLs
        pendingURLs = []
        for url in launchURLs {
            router.handle(url)
        }
        // Begin emitting status.json after the bridge is wired and any URL
        // that arrived during launch has run, so the first write reflects it.
        deps.statusFilePublisher.start()
    }

    /// AppKit funnels `open cafeup://…` here. The array can contain multiple
    /// URLs in a single invocation (e.g. `open cafeup://stop cafeup://start`);
    /// we route each in order, on the main actor.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let urlRouter else {
            pendingURLs.append(contentsOf: urls)
            return
        }
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

    func showSettings() {
        windows.show(id: WindowID.settings, title: "Settings") { _ in
            SettingsView(
                menuBarViewModel: deps.menuBarViewModel,
                appearanceViewModel: deps.appearanceViewModel,
                triggersViewModel: deps.triggersViewModel,
                updatesViewModel: deps.updatesViewModel
            )
        }
    }

    private func showCustomDuration() {
        let viewModel = deps.menuBarViewModel
        windows.show(id: WindowID.customDuration, title: "Custom Duration") { close in
            CustomDurationView(onStart: { viewModel.start(duration: $0) }, onClose: close)
        }
    }

    private func showEndAtTime() {
        let viewModel = deps.menuBarViewModel
        windows.show(id: WindowID.endAtTime, title: "End at Time") { close in
            EndAtTimeView(onStart: { viewModel.startUntil($0) }, onClose: close)
        }
    }
}
