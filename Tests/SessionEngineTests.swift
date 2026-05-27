import XCTest
@testable import CafeUp

@MainActor
final class SessionEngineTests: XCTestCase {

    func test_startIndefinite_acquiresAssertionAndExposesSession() throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .indefinite, policy: .systemAndDisplay)

        XCTAssertEqual(fakes.assertions.acquireCount, 1)
        XCTAssertEqual(fakes.assertions.lastPolicy, .systemAndDisplay)
        XCTAssertEqual(engine.current?.mode, .indefinite)
        XCTAssertNil(engine.current?.endsAt)
    }

    func test_startTimed_setsEndDateAndSchedulesAutoStop() async throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .timed(.seconds(60)), policy: .systemOnly)

        XCTAssertEqual(engine.current?.endsAt, fakes.clock.now.addingTimeInterval(60))
        XCTAssertEqual(fakes.scheduler.pending.count, 1)
        XCTAssertEqual(fakes.scheduler.pending.first?.duration, .seconds(60))

        fakes.scheduler.fireAll()
        await Task.yield()

        XCTAssertNil(engine.current)
    }

    func test_stop_releasesAssertionAndCancelsSchedule() throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .timed(.seconds(60)), policy: .systemAndDisplay)
        let scheduledHandle = fakes.scheduler.pending.first?.handle
        engine.stop()

        XCTAssertNil(engine.current)
        XCTAssertEqual(scheduledHandle?.cancelled, true)
        XCTAssertEqual(fakes.assertions.lastIssuedToken?.released, true)
    }

    func test_updatePolicy_replacesAssertionPreservingEndDate() throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .timed(.seconds(60)), policy: .systemOnly)
        let originalEnd = engine.current?.endsAt
        try engine.updatePolicy(.systemAndDisplay)

        XCTAssertEqual(fakes.assertions.acquireCount, 2)
        XCTAssertEqual(engine.current?.policy, .systemAndDisplay)
        XCTAssertEqual(engine.current?.endsAt, originalEnd)
    }

    func test_updatePolicy_withoutSession_isNoOp() throws {
        let (engine, fakes) = makeSUT()

        try engine.updatePolicy(.systemAndDisplay)

        XCTAssertNil(engine.current)
        XCTAssertEqual(fakes.assertions.acquireCount, 0)
    }

    func test_initialStartFailure_leavesNoSession() {
        let (engine, fakes) = makeSUT()
        fakes.assertions.failure = .assertionFailed(code: -42)

        XCTAssertThrowsError(try engine.start(mode: .indefinite, policy: .systemOnly)) { error in
            XCTAssertEqual(error as? SessionError, .assertionFailed(code: -42))
        }
        XCTAssertNil(engine.current)
    }

    func test_start_playsStartSoundOnce() throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .indefinite, policy: .systemOnly)

        XCTAssertEqual(fakes.alertSounds.startPlayCount, 1)
        XCTAssertEqual(fakes.alertSounds.endPlayCount, 0)
    }

    func test_stop_playsEndSoundOnce() throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .indefinite, policy: .systemOnly)
        engine.stop()

        XCTAssertEqual(fakes.alertSounds.endPlayCount, 1)
    }

    func test_stopWithoutSession_doesNotPlay() {
        let (engine, fakes) = makeSUT()

        engine.stop()

        XCTAssertEqual(fakes.alertSounds.endPlayCount, 0)
    }

    func test_updatePolicy_doesNotReplayStartSound() throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .timed(.seconds(60)), policy: .systemOnly)
        try engine.updatePolicy(.systemAndDisplay)

        XCTAssertEqual(fakes.alertSounds.startPlayCount, 1)
        XCTAssertEqual(fakes.alertSounds.endPlayCount, 0)
    }

    func test_startFailure_doesNotPlayStartSound() {
        let (engine, fakes) = makeSUT()
        fakes.assertions.failure = .assertionFailed(code: -1)

        XCTAssertThrowsError(try engine.start(mode: .indefinite, policy: .systemOnly))

        XCTAssertEqual(fakes.alertSounds.startPlayCount, 0)
    }

    func test_timedAutoStop_playsEndSound() async throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .timed(.seconds(60)), policy: .systemOnly)
        fakes.scheduler.fireAll()
        await Task.yield()

        XCTAssertEqual(fakes.alertSounds.endPlayCount, 1)
    }

    func test_reacquireFailure_preservesExistingSession() throws {
        let (engine, fakes) = makeSUT()

        try engine.start(mode: .indefinite, policy: .systemAndDisplay)
        let originalSession = engine.current
        let originalToken = fakes.assertions.lastIssuedToken
        fakes.assertions.failure = .assertionFailed(code: -42)

        XCTAssertThrowsError(try engine.updatePolicy(.systemOnly))

        XCTAssertEqual(engine.current, originalSession)
        XCTAssertEqual(originalToken?.released, false, "Old assertion must remain alive when reacquisition fails")
    }

    private struct Fakes {
        let assertions: FakePowerAssertionService
        let clock: FakeClock
        let scheduler: FakeScheduler
        let alertSounds: FakeSessionAlertSounds
    }

    private func makeSUT() -> (SessionEngine, Fakes) {
        let fakes = Fakes(
            assertions: FakePowerAssertionService(),
            clock: FakeClock(),
            scheduler: FakeScheduler(),
            alertSounds: FakeSessionAlertSounds()
        )
        let engine = SessionEngine(
            assertions: fakes.assertions,
            clock: fakes.clock,
            scheduler: fakes.scheduler,
            logger: SilentLogger(),
            alertSounds: fakes.alertSounds
        )
        return (engine, fakes)
    }
}
