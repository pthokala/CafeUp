import XCTest
@testable import CafeUp

@MainActor
final class MenuBarViewModelTests: XCTestCase {

    func test_initialState_isIdle() {
        let sut = makeSUT()
        XCTAssertNil(sut.viewModel.session)
        XCTAssertFalse(sut.viewModel.isActive)
        XCTAssertFalse(sut.viewModel.isManualSessionActive)
        XCTAssertFalse(sut.viewModel.isTriggerActive)
        XCTAssertEqual(sut.viewModel.activeTriggerCount, 0)
        XCTAssertNil(sut.viewModel.lastError)
    }

    func test_startIndefinite_acquiresAssertionAndExposesSession() {
        let sut = makeSUT()

        sut.viewModel.startIndefinite()

        XCTAssertTrue(sut.viewModel.isManualSessionActive)
        XCTAssertTrue(sut.viewModel.isActive)
        XCTAssertEqual(sut.viewModel.session?.mode, .indefinite)
        XCTAssertEqual(sut.sessionAssertions.acquireCount, 1)
    }

    func test_startTimed_setsEndDate() {
        let sut = makeSUT()

        sut.viewModel.start(duration: .seconds(60))

        XCTAssertEqual(sut.viewModel.session?.mode, .timed(.seconds(60)))
        XCTAssertNotNil(sut.viewModel.session?.endsAt)
    }

    func test_stop_clearsSession() {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()

        sut.viewModel.stop()

        XCTAssertNil(sut.viewModel.session)
        XCTAssertFalse(sut.viewModel.isManualSessionActive)
    }

    func test_policyChange_whileInactive_doesNotCallEngine() {
        let sut = makeSUT()
        let beforeAcquireCount = sut.sessionAssertions.acquireCount

        sut.viewModel.policy = .systemOnly

        XCTAssertEqual(sut.sessionAssertions.acquireCount, beforeAcquireCount)
    }

    func test_policyChange_whileActive_updatesEngine() {
        let sut = makeSUT(initialPolicy: .systemAndDisplay)
        sut.viewModel.startIndefinite()

        sut.viewModel.policy = .systemOnly

        XCTAssertEqual(sut.viewModel.session?.policy, .systemOnly)
        XCTAssertEqual(sut.sessionAssertions.lastPolicy, .systemOnly)
    }

    func test_policyChange_toSameValue_isNoOp() {
        let sut = makeSUT(initialPolicy: .systemAndDisplay)
        sut.viewModel.startIndefinite()
        let countBefore = sut.sessionAssertions.acquireCount

        sut.viewModel.policy = .systemAndDisplay

        XCTAssertEqual(sut.sessionAssertions.acquireCount, countBefore)
    }

    func test_startFailure_capturesError() {
        let sut = makeSUT()
        sut.sessionAssertions.failure = .assertionFailed(code: -99)

        sut.viewModel.startIndefinite()

        XCTAssertEqual(sut.viewModel.lastError, .assertionFailed(code: -99))
        XCTAssertNil(sut.viewModel.session)
    }

    func test_successfulStartAfterFailure_clearsError() {
        let sut = makeSUT()
        sut.sessionAssertions.failure = .assertionFailed(code: -99)
        sut.viewModel.startIndefinite()
        sut.sessionAssertions.failure = nil

        sut.viewModel.startIndefinite()

        XCTAssertNil(sut.viewModel.lastError)
    }

    func test_triggerActivation_propagatesToViewModel() {
        let sut = makeSUT(
            persistedTriggers: [
                .init(name: "FCP", conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")])
            ]
        )
        sut.triggerEngine.start()
        sut.appObserver.emit(["com.apple.FinalCut"])

        XCTAssertTrue(sut.viewModel.isTriggerActive)
        XCTAssertEqual(sut.viewModel.activeTriggerCount, 1)
        XCTAssertTrue(sut.viewModel.isActive)
    }

    func test_isActive_trueWhenEitherManualOrTrigger() {
        let sut = makeSUT(
            persistedTriggers: [
                .init(name: "FCP", conditions: [.appRunning(bundleIdentifier: "x")])
            ]
        )

        // Just trigger
        sut.triggerEngine.start()
        sut.appObserver.emit(["x"])
        XCTAssertTrue(sut.viewModel.isActive)
        XCTAssertFalse(sut.viewModel.isManualSessionActive)

        // Plus manual
        sut.viewModel.startIndefinite()
        XCTAssertTrue(sut.viewModel.isActive)
        XCTAssertTrue(sut.viewModel.isManualSessionActive)

        // Trigger off, manual still on
        sut.appObserver.emit([])
        XCTAssertTrue(sut.viewModel.isActive)
        XCTAssertTrue(sut.viewModel.isManualSessionActive)

        // Manual off too
        sut.viewModel.stop()
        XCTAssertFalse(sut.viewModel.isActive)
    }

    private struct SUT {
        let viewModel: MenuBarViewModel
        let sessionAssertions: FakePowerAssertionService
        let triggerAssertions: FakePowerAssertionService
        let triggerEngine: TriggerEngine
        let appObserver: FakeAppActivityObserver
    }

    private func makeSUT(
        initialPolicy: WakePolicy = .systemAndDisplay,
        persistedTriggers: [Trigger] = []
    ) -> SUT {
        let sessionAssertions = FakePowerAssertionService()
        let triggerAssertions = FakePowerAssertionService()
        let appObserver = FakeAppActivityObserver()
        let sessionEngine = SessionEngine(
            assertions: sessionAssertions,
            clock: FakeClock(),
            scheduler: FakeScheduler(),
            logger: SilentLogger(),
            alertSounds: FakeSessionAlertSounds()
        )
        let triggerEngine = TriggerEngine(
            assertions: triggerAssertions,
            appObserver: appObserver,
            scheduleObserver: FakeScheduleObserver(),
            powerObserver: FakePowerObserver(),
            store: InMemoryTriggerStore(initial: persistedTriggers),
            logger: SilentLogger()
        )
        let viewModel = MenuBarViewModel(
            engine: sessionEngine,
            triggerEngine: triggerEngine,
            initialPolicy: initialPolicy
        )
        return SUT(
            viewModel: viewModel,
            sessionAssertions: sessionAssertions,
            triggerAssertions: triggerAssertions,
            triggerEngine: triggerEngine,
            appObserver: appObserver
        )
    }
}
