import XCTest
@testable import CafeUp

@MainActor
final class UpdatesSectionViewModelTests: XCTestCase {

    // MARK: - Plumbing

    func test_currentVersionDisplay_passesThroughFromService() {
        let updater = FakeUpdaterService(currentVersionDisplay: "0.2.0 (2)")
        let vm = UpdatesSectionViewModel(updater: updater)
        XCTAssertEqual(vm.currentVersionDisplay, "0.2.0 (2)")
    }

    func test_canCheckForUpdates_passesThroughFromService() {
        let updater = FakeUpdaterService(canCheckForUpdates: false)
        let vm = UpdatesSectionViewModel(updater: updater)
        XCTAssertFalse(vm.canCheckForUpdates)
    }

    func test_checkForUpdates_delegatesToService() {
        let updater = FakeUpdaterService()
        let vm = UpdatesSectionViewModel(updater: updater)

        vm.checkForUpdates()
        vm.checkForUpdates()

        XCTAssertEqual(updater.checkForUpdatesCount, 2)
    }

    // MARK: - Last-checked formatting

    func test_lastChecked_isNever_whenServiceHasNoDate() {
        let updater = FakeUpdaterService(lastUpdateCheckDate: nil)
        let vm = UpdatesSectionViewModel(updater: updater, clock: FakeClock())
        XCTAssertEqual(vm.lastCheckedDescription, "Never")
    }

    func test_lastChecked_showsTodayWithTime_whenDateIsSameDay() {
        let now = makeDate(year: 2026, month: 5, day: 23, hour: 15, minute: 30)
        let checked = makeDate(year: 2026, month: 5, day: 23, hour: 9, minute: 5)
        let updater = FakeUpdaterService(lastUpdateCheckDate: checked)
        let vm = UpdatesSectionViewModel(updater: updater, clock: FakeClock(now))

        let description = vm.lastCheckedDescription

        XCTAssertTrue(description.hasPrefix("Today at "), "Expected 'Today at …', got \(description)")
    }

    func test_lastChecked_showsYesterday_whenDateIsPreviousCalendarDay() {
        let now = makeDate(year: 2026, month: 5, day: 23, hour: 8, minute: 0)
        let checked = makeDate(year: 2026, month: 5, day: 22, hour: 23, minute: 45)
        let updater = FakeUpdaterService(lastUpdateCheckDate: checked)
        let vm = UpdatesSectionViewModel(updater: updater, clock: FakeClock(now))

        let description = vm.lastCheckedDescription

        XCTAssertTrue(description.hasPrefix("Yesterday at "), "Expected 'Yesterday at …', got \(description)")
    }

    func test_lastChecked_showsNDaysAgo_forOlderDates() {
        let now = makeDate(year: 2026, month: 5, day: 23, hour: 12, minute: 0)
        let checked = makeDate(year: 2026, month: 5, day: 18, hour: 12, minute: 0)
        let updater = FakeUpdaterService(lastUpdateCheckDate: checked)
        let vm = UpdatesSectionViewModel(updater: updater, clock: FakeClock(now))

        XCTAssertEqual(vm.lastCheckedDescription, "5 days ago")
    }

    func test_lastChecked_handlesFutureDateGracefully() {
        // Clock skew or a test fake — render the absolute timestamp rather than a negative-days string.
        let now = makeDate(year: 2026, month: 5, day: 23, hour: 12, minute: 0)
        let checked = makeDate(year: 2027, month: 1, day: 1, hour: 12, minute: 0)
        let updater = FakeUpdaterService(lastUpdateCheckDate: checked)
        let vm = UpdatesSectionViewModel(updater: updater, clock: FakeClock(now))

        let description = vm.lastCheckedDescription

        XCTAssertFalse(description.isEmpty)
        XCTAssertFalse(description.contains("Today"))
        XCTAssertFalse(description.contains("Yesterday"))
        XCTAssertFalse(description.contains("days ago"))
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.calendar = Calendar.current
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)!
    }
}
