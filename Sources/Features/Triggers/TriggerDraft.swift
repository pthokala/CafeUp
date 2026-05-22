import Foundation

struct TriggerDraft: Equatable {
    var id: UUID
    var name: String
    var conditions: [TriggerCondition]
    var policy: WakePolicy
    var isEnabled: Bool

    init(from trigger: Trigger? = nil) {
        if let trigger {
            self.id = trigger.id
            self.name = trigger.name
            self.conditions = trigger.conditions
            self.policy = trigger.policy
            self.isEnabled = trigger.isEnabled
        } else {
            self.id = UUID()
            self.name = ""
            self.conditions = []
            self.policy = .systemAndDisplay
            self.isEnabled = true
        }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !conditions.isEmpty
    }

    func toTrigger() -> Trigger {
        Trigger(
            id: id,
            name: name,
            isEnabled: isEnabled,
            conditions: conditions,
            policy: policy
        )
    }
}
