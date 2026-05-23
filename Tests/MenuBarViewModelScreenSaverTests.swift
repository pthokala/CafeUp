import XCTest
@testable import CafeUp

@MainActor
final class MenuBarViewModelScreenSaverTests: XCTestCase {

    func test_idleObserver_doesNotStart_whenScreenSaverDisabled() {
        let sut = makeSUT()
        sut.viewModel.policy.allowScreenSaverAfter45Min = false

        sut.viewModel.startIndefinite()

        XCTAssertEqual(sut.idle.startCount, 0)
    }

    func test_idleObserver_starts_whenScreenSaverEnabled_andSessionActive() {
        let sut = makeSUT()
        sut.viewModel.policy.allowScreenSaverAfter45Min = true

        sut.viewModel.startIndefinite()

        XCTAssertEqual(sut.idle.startCount, 1)
    }

    func test_idleObserver_stops_whenSessionEnds() {
        let sut = makeSUT()
        sut.viewModel.policy.allowScreenSaverAfter45Min = true
        sut.viewModel.startIndefinite()

        sut.viewModel.stop()

        XCTAssertGreaterThanOrEqual(sut.idle.stopCount, 1)
    }

    func test_idleObserver_starts_whenScreenSaverToggledOn_midSession() {
        let sut = makeSUT()
        sut.viewModel.startIndefinite() // policy default has screensaver = false

        sut.viewModel.policy.allowScreenSaverAfter45Min = true

        XCTAssertEqual(sut.idle.startCount, 1)
    }

    func test_idleObserver_stops_whenScreenSaverToggledOff_midSession() {
        let sut = makeSUT()
        sut.viewModel.policy.allowScreenSaverAfter45Min = true
        sut.viewModel.startIndefinite()

        sut.viewModel.policy.allowScreenSaverAfter45Min = false

        XCTAssertGreaterThanOrEqual(sut.idle.stopCount, 1)
    }

    func test_idleTickPast45Min_swapsEffectivePolicyToAllowDisplaySleep() {
        let sut = makeSUT()
        sut.viewModel.policy.allowScreenSaverAfter45Min = true
        sut.viewModel.startIndefinite()
        let acquiresBefore = sut.assertions.acquireCount

        sut.idle.emit(idleSeconds: 46 * 60)

        XCTAssertEqual(sut.viewModel.effectivePolicy.allowDisplaySleep, true)
        XCTAssertGreaterThan(sut.assertions.acquireCount, acquiresBefore)
        XCTAssertEqual(sut.assertions.lastPolicy?.allowDisplaySleep, true)
    }

    func test_idleTickBelow45Min_doesNotSwapPolicy() {
        let sut = makeSUT()
        sut.viewModel.policy.allowScreenSaverAfter45Min = true
        sut.viewModel.startIndefinite()
        let acquiresBefore = sut.assertions.acquireCount

        sut.idle.emit(idleSeconds: 30 * 60)

        XCTAssertEqual(sut.viewModel.effectivePolicy.allowDisplaySleep, false)
        XCTAssertEqual(sut.assertions.acquireCount, acquiresBefore, "No reacquire if effective policy unchanged")
    }

    func test_returningFromIdle_reacquiresDisplayAssertion() {
        let sut = makeSUT()
        sut.viewModel.policy.allowScreenSaverAfter45Min = true
        sut.viewModel.startIndefinite()
        sut.idle.emit(idleSeconds: 50 * 60) // crosses threshold → display released
        let acquiresAfterIdle = sut.assertions.acquireCount

        sut.idle.emit(idleSeconds: 5) // user is back

        XCTAssertEqual(sut.viewModel.effectivePolicy.allowDisplaySleep, false)
        XCTAssertGreaterThan(sut.assertions.acquireCount, acquiresAfterIdle)
    }

    private struct SUT {
        let viewModel: MenuBarViewModel
        let assertions: FakePowerAssertionService
        let idle: FakeUserIdleObserver
    }

    private func makeSUT() -> SUT {
        let assertions = FakePowerAssertionService()
        let sessionEngine = SessionEngine(
            assertions: assertions,
            clock: FakeClock(),
            scheduler: FakeScheduler(),
            logger: SilentLogger()
        )
        let triggerEngine = TriggerEngine(
            assertions: FakePowerAssertionService(),
            appObserver: FakeAppActivityObserver(),
            scheduleObserver: FakeScheduleObserver(),
            powerObserver: FakePowerObserver(),
            store: InMemoryTriggerStore(initial: []),
            logger: SilentLogger()
        )
        let idle = FakeUserIdleObserver()
        let viewModel = MenuBarViewModel(
            engine: sessionEngine,
            triggerEngine: triggerEngine,
            idleObserver: idle,
            tickScheduler: FakeScheduler()
        )
        return SUT(viewModel: viewModel, assertions: assertions, idle: idle)
    }
}
