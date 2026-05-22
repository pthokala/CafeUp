import XCTest
@testable import CafeUp

final class TimeRangeTests: XCTestCase {
    func test_normalRange_includesBoundsAndInterior() {
        let range = TimeRange(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0)
        )
        XCTAssertTrue(range.contains(TimeOfDay(hour: 9, minute: 0)))
        XCTAssertTrue(range.contains(TimeOfDay(hour: 13, minute: 0)))
        XCTAssertTrue(range.contains(TimeOfDay(hour: 17, minute: 0)))
    }

    func test_normalRange_excludesOutside() {
        let range = TimeRange(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0)
        )
        XCTAssertFalse(range.contains(TimeOfDay(hour: 8, minute: 59)))
        XCTAssertFalse(range.contains(TimeOfDay(hour: 17, minute: 1)))
        XCTAssertFalse(range.contains(TimeOfDay(hour: 0, minute: 0)))
        XCTAssertFalse(range.contains(TimeOfDay(hour: 23, minute: 59)))
    }

    func test_overnightRange_includesEdgesAndInterior() {
        let range = TimeRange(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0)
        )
        XCTAssertTrue(range.contains(TimeOfDay(hour: 22, minute: 0)))
        XCTAssertTrue(range.contains(TimeOfDay(hour: 23, minute: 30)))
        XCTAssertTrue(range.contains(TimeOfDay(hour: 0, minute: 0)))
        XCTAssertTrue(range.contains(TimeOfDay(hour: 3, minute: 0)))
        XCTAssertTrue(range.contains(TimeOfDay(hour: 6, minute: 0)))
    }

    func test_overnightRange_excludesMiddleOfDay() {
        let range = TimeRange(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0)
        )
        XCTAssertFalse(range.contains(TimeOfDay(hour: 12, minute: 0)))
        XCTAssertFalse(range.contains(TimeOfDay(hour: 6, minute: 1)))
        XCTAssertFalse(range.contains(TimeOfDay(hour: 21, minute: 59)))
    }

    func test_isOvernight() {
        let normal = TimeRange(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0)
        )
        let overnight = TimeRange(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0)
        )
        XCTAssertFalse(normal.isOvernight)
        XCTAssertTrue(overnight.isOvernight)
    }

    func test_zeroWidthRange_includesOnlyThatInstant() {
        let range = TimeRange(
            start: TimeOfDay(hour: 12, minute: 0),
            end: TimeOfDay(hour: 12, minute: 0)
        )
        XCTAssertTrue(range.contains(TimeOfDay(hour: 12, minute: 0)))
        XCTAssertFalse(range.contains(TimeOfDay(hour: 11, minute: 59)))
        XCTAssertFalse(range.contains(TimeOfDay(hour: 12, minute: 1)))
    }
}
