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
        let statusFilePublisher: StatusFilePublisher
    }

    static func makeAppDependencies() -> AppDependencies {
        let clock = SystemClock()
        let assertions = IOKitPowerAssertionService()

        let sessionEngine = SessionEngine(
            assertions: assertions,
            clock: clock,
            scheduler: TaskScheduler(),
            logger: OSAppLogger(category: "session"),
            alertSounds: SystemSessionAlertSounds()
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

        let appPicker = OpenPanelAppPicker()
        let updaterService = SparkleUpdaterService()

        let menuBarViewModel = MenuBarViewModel(
            engine: sessionEngine,
            triggerEngine: triggerEngine,
            appLifetimeWatcher: NSWorkspaceAppLifetimeWatcher(),
            downloadsMonitor: FileSystemDownloadsMonitor(),
            idleObserver: CGEventSourceIdleObserver()
        )

        // The bridge needs the view model (not just the engine) so agent commands
        // pick up auto-stopper cancellation, the ticker, and the idle observer.
        AppIntentBridge.shared.register(
            lifecycle: menuBarViewModel,
            policyMutator: menuBarViewModel
        )

        // Status JSON file: agents read this for state queries. The snapshot
        // closure reads `sessionEngine.current` and `menuBarViewModel.policy`
        // — both `@Observable`, so writes happen exactly when those change.
        let statusWriter = FileSystemStatusWriter(
            fileURL: FileSystemStatusWriter.defaultFileURL(),
            logger: OSAppLogger(category: "status")
        )
        let statusFilePublisher = StatusFilePublisher(
            snapshot: { [weak sessionEngine, weak menuBarViewModel] in
                StatusSnapshot.make(
                    session: sessionEngine?.current,
                    savedPolicy: menuBarViewModel?.policy ?? .default,
                    now: clock.now
                )
            },
            writer: statusWriter
        )

        return AppDependencies(
            menuBarViewModel: menuBarViewModel,
            triggersViewModel: TriggersViewModel(
                engine: triggerEngine,
                appPicker: appPicker
            ),
            appearanceViewModel: AppearanceViewModel(
                store: UserDefaultsIconStylePreferenceStore()
            ),
            updatesViewModel: UpdatesSectionViewModel(updater: updaterService),
            updaterService: updaterService,
            appPicker: appPicker,
            statusFilePublisher: statusFilePublisher
        )
    }
}
