import XCTest
import Observation
@testable import CafeUp

@MainActor
final class StatusFilePublisherTests: XCTestCase {

    func test_start_writesInitialSnapshotImmediately() {
        let source = ObservableSource()
        let writer = FakeStatusWriter()
        let publisher = StatusFilePublisher(
            snapshot: { source.currentSnapshot },
            writer: writer
        )

        publisher.start()

        XCTAssertEqual(writer.writes.count, 1)
        XCTAssertEqual(writer.writes.first?.active, false)
    }

    func test_observedChange_triggersWrite() async {
        let source = ObservableSource()
        let writer = FakeStatusWriter()
        let publisher = StatusFilePublisher(
            snapshot: { source.currentSnapshot },
            writer: writer
        )

        publisher.start()
        XCTAssertEqual(writer.writes.count, 1)

        source.activate(startedAt: .init(timeIntervalSince1970: 1_700_000_000))
        // onChange re-observes via Task { @MainActor in ... }; let it run.
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(writer.writes.count, 2)
        XCTAssertEqual(writer.writes.last?.active, true)
    }

    func test_multipleSynchronousChanges_coalesceToOneRewrite() async {
        let source = ObservableSource()
        let writer = FakeStatusWriter()
        let publisher = StatusFilePublisher(
            snapshot: { source.currentSnapshot },
            writer: writer
        )

        publisher.start()
        let baseline = writer.writes.count

        // Three mutations in one runloop tick — onChange fires once.
        source.activate(startedAt: .init(timeIntervalSince1970: 1_700_000_000))
        source.deactivate()
        source.activate(startedAt: .init(timeIntervalSince1970: 1_700_000_100))
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(writer.writes.count - baseline, 1,
                       "Synchronous bursts should coalesce; got \(writer.writes.count - baseline) extra writes")
    }

    func test_start_isIdempotent() {
        let source = ObservableSource()
        let writer = FakeStatusWriter()
        let publisher = StatusFilePublisher(
            snapshot: { source.currentSnapshot },
            writer: writer
        )

        publisher.start()
        publisher.start()
        publisher.start()

        XCTAssertEqual(writer.writes.count, 1)
    }

    func test_flushNow_writesCurrentSnapshotEvenWithoutChange() {
        let source = ObservableSource()
        let writer = FakeStatusWriter()
        let publisher = StatusFilePublisher(
            snapshot: { source.currentSnapshot },
            writer: writer
        )

        publisher.start()
        let baseline = writer.writes.count

        publisher.flushNow()

        XCTAssertEqual(writer.writes.count - baseline, 1)
    }

    func test_flushNow_canBeCalledBeforeStart() {
        // Useful as a safety net during shutdown if start() wasn't reached.
        let source = ObservableSource()
        let writer = FakeStatusWriter()
        let publisher = StatusFilePublisher(
            snapshot: { source.currentSnapshot },
            writer: writer
        )

        publisher.flushNow()

        XCTAssertEqual(writer.writes.count, 1)
    }
}

// MARK: - Test fixture

/// Minimal observable source mirroring the engine/view-model surface: one
/// optional Session and a saved policy. Mutating either triggers
/// `withObservationTracking`'s onChange when the publisher's snapshot closure
/// reads them.
@MainActor
@Observable
private final class ObservableSource {
    var session: Session?
    var policy: WakePolicy

    @ObservationIgnored private let clock = Date(timeIntervalSince1970: 1_700_000_000)

    init(policy: WakePolicy = .default) {
        self.session = nil
        self.policy = policy
    }

    var currentSnapshot: StatusSnapshot {
        StatusSnapshot.make(session: session, savedPolicy: policy, now: clock)
    }

    func activate(startedAt: Date) {
        session = Session(
            mode: .timed(.seconds(60)),
            policy: policy,
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(60)
        )
    }

    func deactivate() {
        session = nil
    }
}
