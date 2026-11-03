import Foundation

protocol IconStylePreferenceStore: Sendable {
    func load() -> MenuBarIconStyle
    func save(_ style: MenuBarIconStyle)
}

final class UserDefaultsIconStylePreferenceStore: IconStylePreferenceStore, @unchecked Sendable {
    private static let key = "com.pardhu.CafeUp.iconStyle.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Styles renamed after a release, so a choice saved under the old name survives.
    private static let renamedStyles: [String: MenuBarIconStyle] = [
        "boltDisc": .waveRing,
    ]

    func load() -> MenuBarIconStyle {
        guard let raw = defaults.string(forKey: Self.key) else { return .default }
        return MenuBarIconStyle(rawValue: raw) ?? Self.renamedStyles[raw] ?? .default
    }

    func save(_ style: MenuBarIconStyle) {
        defaults.set(style.rawValue, forKey: Self.key)
    }
}
