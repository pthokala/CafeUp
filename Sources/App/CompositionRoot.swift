import Foundation

@MainActor
enum CompositionRoot {
    struct AppDependencies {
        let menuBarViewModel: MenuBarViewModel
        let triggersViewModel: TriggersViewModel
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

        return AppDependencies(
            menuBarViewModel: MenuBarViewModel(
                engine: sessionEngine,
                triggerEngine: triggerEngine
            ),
            triggersViewModel: TriggersViewModel(
                engine: triggerEngine,
                appPicker: OpenPanelAppPicker()
            )
        )
    }
}
