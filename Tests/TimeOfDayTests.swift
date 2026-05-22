import XCTest
@testable import CafeUp

final class TimeOfDayTests: XCTestCase {
    func test_init_clampsHour() {
        XCTAssertEqual(TimeOfDay(hour: 25, minute: 0).hour, 23)
        XCTAssertEqual(TimeOfDay(hour: -1, minute: 0).hour, 0)
    }

    func test_init_clampsMinute() {
        XCTAssertEqual(TimeOfDay(hour: 0, minute: 99).minute, 59)
        XCTAssertEqual(TimeOfDay(hour: 0, minute: -5).minute, 0)
    }

    func test_totalMinutes() {
        XCTAssertEqual(TimeOfDay(hour: 1, minute: 30).totalMinutes, 90)
        XCTAssertEqual(TimeOfDay(hour: 0, minute: 0).totalMinutes, 0)
        XCTAssertEqual(TimeOfDay(hour: 23, minute: 59).totalMinutes, 23 * 60 + 59)
    }

    func test_comparable() {
        XCTAssertLessThan(TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 17, minute: 0))
        XCTAssertLessThan(TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 9, minute: 1))
        XCTAssertEqual(TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 9, minute: 0))
    }

    func test_formatted() {
        XCTAssertEqual(TimeOfDay(hour: 9, minute: 5).formatted, "09:05")
        XCTAssertEqual(TimeOfDay(hour: 23, minute: 59).formatted, "23:59")
        XCTAssertEqual(TimeOfDay(hour: 0, minute: 0).formatted, "00:00")
    }

    func test_initFromDate_usesLocalComponents() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 14, minute: 30))!

        let tod = TimeOfDay(date: date, calendar: calendar)

        XCTAssertEqual(tod, TimeOfDay(hour: 14, minute: 30))
    }
}
