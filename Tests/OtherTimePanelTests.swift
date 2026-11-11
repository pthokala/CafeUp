import XCTest
@testable import CafeUp

final class OtherTimePanelTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(hour: Int, minute: Int, dayOffset: Int = 0, from base: Date) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: base)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    func test_nextOccurrence_laterToday_staysToday() {
        let now = date(hour: 10, minute: 0, from: Date())
        let picked = date(hour: 14, minute: 30, from: now)

        XCTAssertEqual(OtherTimePanel.nextOccurrence(of: picked, now: now), picked)
    }

    func test_nextOccurrence_alreadyPassed_wrapsToTomorrow() {
        let now = date(hour: 22, minute: 0, from: Date())
        let picked = date(hour: 7, minute: 15, from: now)

        XCTAssertEqual(
            OtherTimePanel.nextOccurrence(of: picked, now: now),
            date(hour: 7, minute: 15, dayOffset: 1, from: now)
        )
    }

    func test_nextOccurrence_ignoresPickerDatePart() {
        // The picker's date can carry yesterday's or tomorrow's day; only the clock
        // time counts.
        let now = date(hour: 9, minute: 0, from: Date())
        let pickedTomorrow = date(hour: 11, minute: 0, dayOffset: 1, from: now)

        XCTAssertEqual(
            OtherTimePanel.nextOccurrence(of: pickedTomorrow, now: now),
            date(hour: 11, minute: 0, from: now)
        )
    }
}
