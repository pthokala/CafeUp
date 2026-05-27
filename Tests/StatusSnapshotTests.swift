import XCTest
@testable import CafeUp

final class StatusSnapshotTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let policy = WakePolicy(
        allowDisplaySleep: false,
        allowSystemSleepWhenLidClosed: true,
        allowScreenSaverAfter45Min: false
    )

    func test_inactiveSnapshot_hasNoSessionFields() {
        let snap = StatusSnapshot.make(session: nil, savedPolicy: policy, now: now)
        XCTAssertFalse(snap.active)
        XCTAssertNil(snap.mode)
        XCTAssertNil(snap.startedAt)
        XCTAssertNil(snap.endsAt)
        XCTAssertEqual(snap.policy, policy)
        XCTAssertEqual(snap.updatedAt, now)
    }

    func test_indefiniteSession_marksMode() {
        let session = Session(
            mode: .indefinite,
            policy: policy,
            startedAt: now.addingTimeInterval(-60),
            endsAt: nil
        )
        let snap = StatusSnapshot.make(session: session, savedPolicy: policy, now: now)
        XCTAssertTrue(snap.active)
        XCTAssertEqual(snap.mode, .indefinite)
        XCTAssertEqual(snap.startedAt, session.startedAt)
        XCTAssertNil(snap.endsAt)
    }

    func test_timedSession_carriesStartAndEnd() {
        let start = now.addingTimeInterval(-30)
        let end = now.addingTimeInterval(60)
        let session = Session(
            mode: .timed(.seconds(90)),
            policy: policy,
            startedAt: start,
            endsAt: end
        )
        let snap = StatusSnapshot.make(session: session, savedPolicy: policy, now: now)
        XCTAssertTrue(snap.active)
        XCTAssertEqual(snap.mode, .timed)
        XCTAssertEqual(snap.startedAt, start)
        XCTAssertEqual(snap.endsAt, end)
    }

    func test_snapshotRoundTripsThroughJSON() throws {
        let session = Session(
            mode: .timed(.seconds(90)),
            policy: policy,
            startedAt: now.addingTimeInterval(-30),
            endsAt: now.addingTimeInterval(60)
        )
        let snap = StatusSnapshot.make(session: session, savedPolicy: policy, now: now)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        let data = try enc.encode(snap)
        let decoded = try dec.decode(StatusSnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }

    func test_savedPolicyIsUsedRegardlessOfSessionPolicy() {
        // Idle override would normally make the runtime policy diverge from the
        // saved policy; the snapshot should always carry the saved one.
        let sessionPolicy = WakePolicy(allowDisplaySleep: true) // e.g. idle override
        let saved = WakePolicy(allowDisplaySleep: false, allowScreenSaverAfter45Min: true)
        let session = Session(
            mode: .indefinite,
            policy: sessionPolicy,
            startedAt: now,
            endsAt: nil
        )
        let snap = StatusSnapshot.make(session: session, savedPolicy: saved, now: now)
        XCTAssertEqual(snap.policy, saved)
    }
}
