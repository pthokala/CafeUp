import XCTest
@testable import CafeUp

final class SessionTests: XCTestCase {

    func test_indefiniteMode_durationIsNil() {
        XCTAssertNil(SessionMode.indefinite.duration)
    }

    func test_timedMode_exposesDuration() {
        XCTAssertEqual(SessionMode.timed(.seconds(60)).duration, .seconds(60))
    }

    func test_session_storesAllFields() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = Session(
            mode: .timed(.seconds(120)),
            policy: .systemOnly,
            startedAt: now,
            endsAt: now.addingTimeInterval(120)
        )

        XCTAssertEqual(session.mode, .timed(.seconds(120)))
        XCTAssertEqual(session.policy, .systemOnly)
        XCTAssertEqual(session.startedAt, now)
        XCTAssertEqual(session.endsAt, now.addingTimeInterval(120))
    }

    func test_indefiniteSession_hasNoEndDate() {
        let session = Session(
            mode: .indefinite,
            policy: .systemAndDisplay,
            startedAt: .now,
            endsAt: nil
        )
        XCTAssertNil(session.endsAt)
    }
}
