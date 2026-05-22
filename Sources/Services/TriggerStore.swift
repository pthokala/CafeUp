import Foundation

protocol TriggerStore: Sendable {
    func load() -> [Trigger]
    func save(_ triggers: [Trigger])
}

final class UserDefaultsTriggerStore: TriggerStore, @unchecked Sendable {
    private static let storageKey = "com.pardhu.CafeUp.triggers.v1"

    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [Trigger] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        return (try? decoder.decode([Trigger].self, from: data)) ?? []
    }

    func save(_ triggers: [Trigger]) {
        guard let data = try? encoder.encode(triggers) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
