struct PowerSource: Codable, Equatable, Sendable {
    var isOnACPower: Bool
    var batteryPercentage: Int?

    static let unknown = PowerSource(isOnACPower: true, batteryPercentage: nil)
}
