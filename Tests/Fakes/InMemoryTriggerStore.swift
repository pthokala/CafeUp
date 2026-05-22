import Foundation
@testable import CafeUp

final class InMemoryTriggerStore: TriggerStore, @unchecked Sendable {
    private var storage: [Trigger]
    private(set) var saveCount = 0

    init(initial: [Trigger] = []) { self.storage = initial }

    func load() -> [Trigger] { storage }
    func save(_ triggers: [Trigger]) {
        storage = triggers
        saveCount += 1
    }
}
