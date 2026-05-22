import Foundation

struct WorldState: Equatable, Sendable {
    var runningAppBundleIds: Set<String>
    var currentDate: Date
    var powerSource: PowerSource

    static let empty = WorldState(
        runningAppBundleIds: [],
        currentDate: .distantPast,
        powerSource: .unknown
    )
}
