import XCTest
@testable import CafeUp

final class RemainingFormatterTests: XCTestCase {
    func test_underAnHour_showsMinutesAndSeconds() {
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 65), "1:05")
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 9), "0:09")
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 300), "5:00")
    }

    func test_overAnHour_showsHoursMinutesSeconds() {
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 3_725), "1:02:05")
    }

    func test_negativeOrZero_showsZero() {
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 0), "0:00")
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: -10), "0:00")
    }
}
