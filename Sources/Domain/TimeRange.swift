struct TimeRange: Codable, Equatable, Sendable, Hashable {
    let start: TimeOfDay
    let end: TimeOfDay

    func contains(_ time: TimeOfDay) -> Bool {
        if start <= end {
            return time >= start && time <= end
        }
        return time >= start || time <= end
    }

    var isOvernight: Bool { start > end }
}
