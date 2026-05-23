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

    func load() -> MenuBarIconStyle {
        guard
            let raw = defaults.string(forKey: Self.key),
            let style = MenuBarIconStyle(rawValue: raw)
        else { return .default }
        return style
    }

    func save(_ style: MenuBarIconStyle) {
        defaults.set(style.rawValue, forKey: Self.key)
    }
}
