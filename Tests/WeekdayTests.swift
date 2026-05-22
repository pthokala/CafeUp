import XCTest
@testable import CafeUp

final class WeekdayTests: XCTestCase {
    func test_rawValuesMatchCalendarConvention() {
        // Calendar.weekday: Sunday = 1 through Saturday = 7
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.monday.rawValue, 2)
        XCTAssertEqual(Weekday.saturday.rawValue, 7)
    }

    func test_allCases_haveSevenDays() {
        XCTAssertEqual(Weekday.allCases.count, 7)
    }

    func test_shortNames() {
        XCTAssertEqual(Weekday.monday.shortName, "Mon")
        XCTAssertEqual(Weekday.sunday.shortName, "Sun")
        XCTAssertEqual(Weekday.friday.shortName, "Fri")
    }

    func test_codableRoundtrip() throws {
        let original: [Weekday] = [.monday, .wednesday, .friday]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([Weekday].self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
