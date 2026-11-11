import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let duration: Duration

    /// Minutes submenu, one inner array per block between separators.
    static let minutePresetGroups: [[SessionPreset]] = [
        [minutes(5)],
        [minutes(10), minutes(15)],
        [minutes(20), minutes(25)],
        [minutes(30), minutes(35)],
        [minutes(40), minutes(45)],
        [minutes(50), minutes(55)],
    ]

    /// Hours submenu, one inner array per block between separators.
    static let hourPresetGroups: [[SessionPreset]] = [
        (1...9).map(hours),
        [hours(10), hours(12), hours(24)],
    ]

    static let minutePresets: [SessionPreset] = minutePresetGroups.flatMap { $0 }
    static let hourPresets: [SessionPreset] = hourPresetGroups.flatMap { $0 }

    private static func minutes(_ n: Int) -> SessionPreset {
        SessionPreset(label: "\(n) minutes", duration: .seconds(n * 60))
    }

    private static func hours(_ n: Int) -> SessionPreset {
        SessionPreset(label: n == 1 ? "1 hour" : "\(n) hours", duration: .seconds(n * 60 * 60))
    }
}
