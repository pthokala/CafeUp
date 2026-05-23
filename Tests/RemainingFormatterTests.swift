import XCTest
@testable import CafeUp

final class RemainingFormatterTests: XCTestCase {

    // MARK: format

    func test_format_underAnHour_showsMinutesAndSeconds() {
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 65), "1:05")
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 9), "0:09")
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 300), "5:00")
    }

    func test_format_overAnHour_showsHoursMinutesSeconds() {
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 3_725), "1:02:05")
    }

    func test_format_negativeOrZero_showsZero() {
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: 0), "0:00")
        XCTAssertEqual(RemainingFormatter.format(secondsRemaining: -10), "0:00")
    }

    // MARK: amphetamineStyle

    func test_amphetamineStyle_underAnHour() {
        XCTAssertEqual(RemainingFormatter.amphetamineStyle(secondsRemaining: 593), "09m 53s remaining")
        XCTAssertEqual(RemainingFormatter.amphetamineStyle(secondsRemaining: 0), "00m 00s remaining")
    }

    func test_amphetamineStyle_overAnHour() {
        XCTAssertEqual(
            RemainingFormatter.amphetamineStyle(secondsRemaining: 3_725),
            "01h 02m 05s remaining"
        )
    }

    func test_amphetamineStyle_negativeClampsToZero() {
        XCTAssertEqual(RemainingFormatter.amphetamineStyle(secondsRemaining: -10), "00m 00s remaining")
    }

    // MARK: clockTime

    func test_clockTime_formatsAsShortTime() {
        let date = Date(timeIntervalSince1970: 0)
        let result = RemainingFormatter.clockTime(date)
        XCTAssertFalse(result.isEmpty)
    }
}
