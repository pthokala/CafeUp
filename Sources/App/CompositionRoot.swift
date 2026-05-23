import Foundation

@MainActor
enum CompositionRoot {
    struct AppDependencies {
        let menuBarViewModel: MenuBarViewModel
        let triggersViewModel: TriggersViewModel
        let appearanceViewModel: AppearanceViewModel
        let updatesViewModel: UpdatesSectionViewModel
        let updaterService: UpdaterService
        let appPicker: AppPicker
    }

    static func makeAppDependencies() -> AppDependencies {
        let clock = SystemClock()
        let assertions = IOKitPowerAssertionService()

        let sessionEngine = SessionEngine(
            assertions: assertions,
            clock: clock,
            scheduler: TaskScheduler(),
            logger: OSAppLogger(category: "session")
        )

        let triggerEngine = TriggerEngine(
            assertions: assertions,
            appObserver: NSWorkspaceAppActivityObserver(),
            scheduleObserver: TimerScheduleObserver(),
            powerObserver: IOPSPowerObserver(),
            store: UserDefaultsTriggerStore(),
            logger: OSAppLogger(category: "triggers")
        )
        triggerEngine.start()
        AppIntentBridge.shared.register(sessionEngine: sessionEngine)

        let appPicker = OpenPanelAppPicker()
        let updaterService = SparkleUpdaterService()

        return AppDependencies(
            menuBarViewModel: MenuBarViewModel(
                engine: sessionEngine,
                triggerEngine: triggerEngine,
                appLifetimeWatcher: NSWorkspaceAppLifetimeWatcher(),
                downloadsMonitor: FileSystemDownloadsMonitor(),
                idleObserver: CGEventSourceIdleObserver()
            ),
            triggersViewModel: TriggersViewModel(
                engine: triggerEngine,
                appPicker: appPicker
            ),
            appearanceViewModel: AppearanceViewModel(
                store: UserDefaultsIconStylePreferenceStore()
            ),
            updatesViewModel: UpdatesSectionViewModel(updater: updaterService),
            updaterService: updaterService,
            appPicker: appPicker
        )
    }
}
