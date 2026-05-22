import Foundation

struct TimeOfDay: Codable, Equatable, Comparable, Sendable, Hashable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    var totalMinutes: Int { hour * 60 + minute }

    var formatted: String { String(format: "%02d:%02d", hour, minute) }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }
}
