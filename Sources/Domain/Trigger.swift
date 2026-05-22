import Foundation

struct Trigger: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var conditions: [TriggerCondition]
    var policy: WakePolicy

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        conditions: [TriggerCondition],
        policy: WakePolicy = .systemAndDisplay
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.conditions = conditions
        self.policy = policy
    }

    func isSatisfied(by state: WorldState, calendar: Calendar = .current) -> Bool {
        guard isEnabled, !conditions.isEmpty else { return false }
        return conditions.allSatisfy { $0.isSatisfied(by: state, calendar: calendar) }
    }
}
