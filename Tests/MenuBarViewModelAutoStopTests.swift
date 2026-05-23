import XCTest
@testable import CafeUp

@MainActor
final class MenuBarViewModelAutoStopTests: XCTestCase {

    func test_startWhileAppRunning_setsBundleAndArmsWatcher() {
        let sut = makeSUT()

        sut.viewModel.startWhileAppRunning(bundleIdentifier: "com.example.Foo")

        XCTAssertTrue(sut.viewModel.isManualSessionActive)
        XCTAssertEqual(sut.viewModel.session?.mode, .indefinite)
        XCTAssertEqual(sut.viewModel.whileAppRunningBundleId, "com.example.Foo")
        XCTAssertEqual(sut.watcher.watchCount, 1)
        XCTAssertEqual(sut.watcher.watchedBundleIdentifier, "com.example.Foo")
    }

    func test_appTermination_stopsSession() {
        let sut = makeSUT()
        sut.viewModel.startWhileAppRunning(bundleIdentifier: "com.example.Foo")

        sut.watcher.simulateTermination()

        XCTAssertFalse(sut.viewModel.isManualSessionActive)
        XCTAssertNil(sut.viewModel.whileAppRunningBundleId)
    }

    func test_startWhileDownloading_armsMonitor() {
        let sut = makeSUT()

        sut.viewModel.startWhileDownloading()

        XCTAssertTrue(sut.viewModel.isManualSessionActive)
        XCTAssertTrue(sut.viewModel.isWhileDownloadingActive)
        XCTAssertEqual(sut.monitor.startCount, 1)
    }

    func test_downloadsIdle_stopsSession() {
        let sut = makeSUT()
        sut.viewModel.startWhileDownloading()

        sut.monitor.simulateIdle()

        XCTAssertFalse(sut.viewModel.isManualSessionActive)
        XCTAssertFalse(sut.viewModel.isWhileDownloadingActive)
    }

    func test_startingNewSession_cancelsPriorAutoStopper() {
        let sut = makeSUT()
        sut.viewModel.startWhileAppRunning(bundleIdentifier: "com.example.Foo")
        let stopsAfterArm = sut.watcher.stopCount

        sut.viewModel.startIndefinite()

        XCTAssertEqual(sut.watcher.stopCount, stopsAfterArm + 1)
        XCTAssertNil(sut.viewModel.whileAppRunningBundleId)
    }

    func test_startUntil_inFuture_setsTimedDuration() {
        let sut = makeSUT()
        let now = Date()
        let endsIn30Min = now.addingTimeInterval(30 * 60)

        sut.viewModel.startUntil(endsIn30Min, now: now)

        guard case .timed(let duration) = sut.viewModel.session?.mode else {
            XCTFail("expected timed session"); return
        }
        XCTAssertEqual(duration.components.seconds, 30 * 60)
    }

    func test_startUntil_inPast_isNoOp() {
        let sut = makeSUT()
        let now = Date()

        sut.viewModel.startUntil(now.addingTimeInterval(-60), now: now)

        XCTAssertFalse(sut.viewModel.isManualSessionActive)
    }

    func test_startWhileAppRunning_failedAssertion_doesNotArmWatcher() {
        let sut = makeSUT()
        sut.sessionAssertions.failure = .assertionFailed(code: -7)

        sut.viewModel.startWhileAppRunning(bundleIdentifier: "com.example.Foo")

        XCTAssertNil(sut.viewModel.whileAppRunningBundleId)
        XCTAssertEqual(sut.watcher.watchCount, 0)
        XCTAssertNotNil(sut.viewModel.lastError)
    }

    func test_startWhileDownloading_failedAssertion_doesNotArmMonitor() {
        let sut = makeSUT()
        sut.sessionAssertions.failure = .assertionFailed(code: -7)

        sut.viewModel.startWhileDownloading()

        XCTAssertFalse(sut.viewModel.isWhileDownloadingActive)
        XCTAssertEqual(sut.monitor.startCount, 0)
    }

    private struct SUT {
        let viewModel: MenuBarViewModel
        let sessionAssertions: FakePowerAssertionService
        let watcher: FakeAppLifetimeWatcher
        let monitor: FakeDownloadsMonitor
        let tickScheduler: FakeScheduler
    }

    private func makeSUT() -> SUT {
        let sessionAssertions = FakePowerAssertionService()
        let sessionEngine = SessionEngine(
            assertions: sessionAssertions,
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
        let watcher = FakeAppLifetimeWatcher()
        let monitor = FakeDownloadsMonitor()
        let tickScheduler = FakeScheduler()
        let viewModel = MenuBarViewModel(
            engine: sessionEngine,
            triggerEngine: triggerEngine,
            appLifetimeWatcher: watcher,
            downloadsMonitor: monitor,
            tickScheduler: tickScheduler
        )
        return SUT(
            viewModel: viewModel,
            sessionAssertions: sessionAssertions,
            watcher: watcher,
            monitor: monitor,
            tickScheduler: tickScheduler
        )
    }
}
