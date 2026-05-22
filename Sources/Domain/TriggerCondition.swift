import Foundation

enum TriggerCondition: Codable, Equatable, Sendable, Hashable {
    case appRunning(bundleIdentifier: String)
    case schedule(weekdays: Set<Weekday>, range: TimeRange)
    case onACPower
    case batteryAtLeast(percent: Int)

    func isSatisfied(by state: WorldState, calendar: Calendar = .current) -> Bool {
        switch self {
        case .appRunning(let bundleId):
            return state.runningAppBundleIds.contains(bundleId)

        case .schedule(let weekdays, let range):
            return scheduleIsSatisfied(by: state, weekdays: weekdays, range: range, calendar: calendar)

        case .onACPower:
            return state.powerSource.isOnACPower

        case .batteryAtLeast(let percent):
            guard let battery = state.powerSource.batteryPercentage else { return false }
            return battery >= percent
        }
    }

    private func scheduleIsSatisfied(
        by state: WorldState,
        weekdays: Set<Weekday>,
        range: TimeRange,
        calendar: Calendar
    ) -> Bool {
        guard !weekdays.isEmpty else { return false }
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: state.currentDate)
        guard
            let weekdayRaw = components.weekday,
            let weekday = Weekday(rawValue: weekdayRaw)
        else { return false }
        guard weekdays.contains(weekday) else { return false }
        let now = TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
        return range.contains(now)
    }
}
