import XCTest
@testable import CafeUp

final class TriggerEvaluationTests: XCTestCase {

    // MARK: General

    func test_disabledTrigger_isNeverSatisfied() {
        let trigger = Trigger(
            name: "FCP",
            isEnabled: false,
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")]
        )
        let state = WorldState(
            runningAppBundleIds: ["com.apple.FinalCut"],
            currentDate: .now,
            powerSource: .unknown
        )
        XCTAssertFalse(trigger.isSatisfied(by: state))
    }

    func test_emptyConditions_isNeverSatisfied() {
        let trigger = Trigger(name: "Empty", conditions: [])
        XCTAssertFalse(trigger.isSatisfied(by: .empty))
    }

    func test_multipleConditions_requireAll() {
        let trigger = Trigger(
            name: "Mixed",
            conditions: [
                .appRunning(bundleIdentifier: "x"),
                .onACPower
            ]
        )
        XCTAssertTrue(trigger.isSatisfied(by: stateWith(
            apps: ["x"],
            power: PowerSource(isOnACPower: true, batteryPercentage: 80)
        )))
        XCTAssertFalse(trigger.isSatisfied(by: stateWith(
            apps: ["x"],
            power: PowerSource(isOnACPower: false, batteryPercentage: 80)
        )))
        XCTAssertFalse(trigger.isSatisfied(by: stateWith(
            apps: [],
            power: PowerSource(isOnACPower: true, batteryPercentage: 80)
        )))
    }

    // MARK: appRunning

    func test_appRunning_caseSensitive() {
        let condition = TriggerCondition.appRunning(bundleIdentifier: "com.apple.FinalCut")
        XCTAssertTrue(condition.isSatisfied(by: stateWith(apps: ["com.apple.FinalCut"])))
        XCTAssertFalse(condition.isSatisfied(by: stateWith(apps: ["com.apple.finalcut"])))
    }

    func test_appRunning_codable() throws {
        let condition = TriggerCondition.appRunning(bundleIdentifier: "x")
        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(TriggerCondition.self, from: data)
        XCTAssertEqual(condition, decoded)
    }

    // MARK: onACPower

    func test_onACPower_trueWhenPluggedIn() {
        let condition = TriggerCondition.onACPower
        XCTAssertTrue(condition.isSatisfied(by: stateWith(
            power: PowerSource(isOnACPower: true, batteryPercentage: 100)
        )))
    }

    func test_onACPower_falseOnBattery() {
        let condition = TriggerCondition.onACPower
        XCTAssertFalse(condition.isSatisfied(by: stateWith(
            power: PowerSource(isOnACPower: false, batteryPercentage: 75)
        )))
    }

    func test_onACPower_codable() throws {
        let condition = TriggerCondition.onACPower
        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(TriggerCondition.self, from: data)
        XCTAssertEqual(condition, decoded)
    }

    // MARK: batteryAtLeast

    func test_batteryAtLeast_trueAtOrAboveThreshold() {
        let condition = TriggerCondition.batteryAtLeast(percent: 50)
        XCTAssertTrue(condition.isSatisfied(by: stateWith(
            power: PowerSource(isOnACPower: false, batteryPercentage: 50)
        )))
        XCTAssertTrue(condition.isSatisfied(by: stateWith(
            power: PowerSource(isOnACPower: false, batteryPercentage: 99)
        )))
    }

    func test_batteryAtLeast_falseBelowThreshold() {
        let condition = TriggerCondition.batteryAtLeast(percent: 50)
        XCTAssertFalse(condition.isSatisfied(by: stateWith(
            power: PowerSource(isOnACPower: false, batteryPercentage: 49)
        )))
        XCTAssertFalse(condition.isSatisfied(by: stateWith(
            power: PowerSource(isOnACPower: false, batteryPercentage: 0)
        )))
    }

    func test_batteryAtLeast_falseWhenNoBattery() {
        let condition = TriggerCondition.batteryAtLeast(percent: 0)
        XCTAssertFalse(condition.isSatisfied(by: stateWith(
            power: PowerSource(isOnACPower: true, batteryPercentage: nil)
        )))
    }

    // MARK: schedule

    func test_schedule_satisfiedOnMatchingWeekdayAndTime() {
        let calendar = utcCalendar()
        // 2026-01-05 is a Monday, 10:30 UTC
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 10, minute: 30))!
        let condition = TriggerCondition.schedule(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            range: TimeRange(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 17, minute: 0))
        )

        XCTAssertTrue(condition.isSatisfied(by: stateWith(date: date), calendar: calendar))
    }

    func test_schedule_unsatisfiedOnNonMatchingWeekday() {
        let calendar = utcCalendar()
        // 2026-01-04 is a Sunday
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4, hour: 10, minute: 30))!
        let condition = TriggerCondition.schedule(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            range: TimeRange(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 17, minute: 0))
        )

        XCTAssertFalse(condition.isSatisfied(by: stateWith(date: date), calendar: calendar))
    }

    func test_schedule_unsatisfiedOutsideTimeRange() {
        let calendar = utcCalendar()
        // 2026-01-05 is a Monday, 18:00 UTC (outside 9-17 range)
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 18, minute: 0))!
        let condition = TriggerCondition.schedule(
            weekdays: [.monday],
            range: TimeRange(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 17, minute: 0))
        )

        XCTAssertFalse(condition.isSatisfied(by: stateWith(date: date), calendar: calendar))
    }

    func test_schedule_emptyWeekdays_neverSatisfied() {
        let calendar = utcCalendar()
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 10))!
        let condition = TriggerCondition.schedule(
            weekdays: [],
            range: TimeRange(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 17, minute: 0))
        )

        XCTAssertFalse(condition.isSatisfied(by: stateWith(date: date), calendar: calendar))
    }

    func test_schedule_overnightRangeSpansMidnight() {
        let calendar = utcCalendar()
        let lateNight = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 23))!
        let earlyMorning = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 5))!
        let condition = TriggerCondition.schedule(
            weekdays: [.monday],
            range: TimeRange(start: TimeOfDay(hour: 22, minute: 0), end: TimeOfDay(hour: 6, minute: 0))
        )

        XCTAssertTrue(condition.isSatisfied(by: stateWith(date: lateNight), calendar: calendar))
        XCTAssertTrue(condition.isSatisfied(by: stateWith(date: earlyMorning), calendar: calendar))
    }

    func test_schedule_codableRoundtrip() throws {
        let condition = TriggerCondition.schedule(
            weekdays: [.monday, .friday],
            range: TimeRange(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 17, minute: 0))
        )
        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(TriggerCondition.self, from: data)
        XCTAssertEqual(condition, decoded)
    }

    // MARK: Helpers

    private func stateWith(
        apps: Set<String> = [],
        date: Date = .now,
        power: PowerSource = .unknown
    ) -> WorldState {
        WorldState(runningAppBundleIds: apps, currentDate: date, powerSource: power)
    }

    private func utcCalendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
}
