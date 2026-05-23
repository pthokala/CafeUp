import XCTest
@testable import CafeUp

@MainActor
final class MenuBarViewModelTickerTests: XCTestCase {

    func test_tick_doesNotAdvanceBeforeSessionStarts() {
        let sut = makeSUT()
        XCTAssertEqual(sut.viewModel.tick, 0)
        XCTAssertEqual(sut.scheduler.pending.count, 0)
    }

    func test_startIndefinite_armsTick() {
        let sut = makeSUT()

        sut.viewModel.startIndefinite()

        XCTAssertEqual(sut.scheduler.pending.count, 1, "Ticker must schedule first tick on session start")
        XCTAssertEqual(sut.scheduler.pending.first?.duration, .seconds(1))
    }

    func test_tick_incrementsAndReschedules() async {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()

        sut.scheduler.fireAll()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(sut.viewModel.tick, 1)
        XCTAssertEqual(sut.scheduler.pending.count, 1, "Ticker must reschedule the next tick after firing")
    }

    func test_tick_continues_overManyFires() async {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()

        for _ in 0..<5 {
            sut.scheduler.fireAll()
            await Task.yield()
            await Task.yield()
        }

        XCTAssertEqual(sut.viewModel.tick, 5)
    }

    func test_stop_cancelsTicker() async {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()
        let armedHandle = sut.scheduler.pending.first?.handle

        sut.viewModel.stop()

        XCTAssertEqual(armedHandle?.cancelled, true)
    }

    func test_tick_doesNotAdvance_afterStop() async {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()
        sut.viewModel.stop()
        let tickBefore = sut.viewModel.tick

        // Any work scheduled before stop should be cancelled, so firing should not advance the tick.
        sut.scheduler.fireAll()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(sut.viewModel.tick, tickBefore)
    }

    func test_sessionStatusLine_nilWhenNoSession() {
        let sut = makeSUT()
        XCTAssertNil(sut.viewModel.sessionStatusLine())
    }

    func test_sessionStatusLine_indefiniteSession() {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()
        XCTAssertEqual(sut.viewModel.sessionStatusLine(), "Indefinite session")
    }

    func test_sessionStatusLine_timedSession_advancesWithSimulatedTime() {
        let sut = makeSUT()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        sut.viewModel.start(duration: .seconds(5 * 60))
        let endsAt = sut.viewModel.session?.endsAt ?? start

        let initial = sut.viewModel.sessionStatusLine(now: endsAt.addingTimeInterval(-5 * 60))
        let later = sut.viewModel.sessionStatusLine(now: endsAt.addingTimeInterval(-4 * 60))

        XCTAssertTrue(initial?.contains("05m 00s remaining") ?? false, "initial: \(initial ?? "nil")")
        XCTAssertTrue(later?.contains("04m 00s remaining") ?? false, "later: \(later ?? "nil")")
        XCTAssertNotEqual(initial, later, "Status line must advance as time passes")
    }

    func test_sessionStatusLine_clamps_atZero() {
        let sut = makeSUT()
        sut.viewModel.start(duration: .seconds(60))
        let endsAt = sut.viewModel.session?.endsAt ?? Date()

        let result = sut.viewModel.sessionStatusLine(now: endsAt.addingTimeInterval(120))

        XCTAssertTrue(result?.contains("00m 00s remaining") ?? false, "got: \(result ?? "nil")")
    }

    func test_restartingSession_resumesTicker() async {
        let sut = makeSUT()
        sut.viewModel.startIndefinite()
        sut.viewModel.stop()

        sut.viewModel.startIndefinite()
        sut.scheduler.fireAll()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(sut.viewModel.tick, 1)
    }

    private struct SUT {
        let viewModel: MenuBarViewModel
        let scheduler: FakeScheduler
    }

    private func makeSUT() -> SUT {
        let scheduler = FakeScheduler()
        let sessionEngine = SessionEngine(
            assertions: FakePowerAssertionService(),
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
        let viewModel = MenuBarViewModel(
            engine: sessionEngine,
            triggerEngine: triggerEngine,
            tickScheduler: scheduler
        )
        return SUT(viewModel: viewModel, scheduler: scheduler)
    }
}
