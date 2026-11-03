import Foundation

protocol WakePolicyStore: Sendable {
    func load() -> WakePolicy
    func save(_ policy: WakePolicy)
}

final class UserDefaultsWakePolicyStore: WakePolicyStore, @unchecked Sendable {
    private static let key = "com.pardhu.CafeUp.wakePolicy.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> WakePolicy {
        guard
            let data = defaults.data(forKey: Self.key),
            let policy = try? decoder.decode(WakePolicy.self, from: data)
        else { return .default }
        return policy
    }

    func save(_ policy: WakePolicy) {
        guard let data = try? encoder.encode(policy) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
