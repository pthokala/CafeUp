import Foundation
@testable import CafeUp

final class InMemoryWakePolicyStore: WakePolicyStore, @unchecked Sendable {
    private var stored: WakePolicy
    private(set) var saveCount = 0

    init(initial: WakePolicy = .default) {
        self.stored = initial
    }

    func load() -> WakePolicy { stored }

    func save(_ policy: WakePolicy) {
        stored = policy
        saveCount += 1
    }
}
