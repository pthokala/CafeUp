import Foundation
import Observation

@MainActor
@Observable
final class TriggersViewModel {
    @ObservationIgnored private let engine: TriggerEngine
    @ObservationIgnored private let appPicker: AppPicker

    init(engine: TriggerEngine, appPicker: AppPicker) {
        self.engine = engine
        self.appPicker = appPicker
    }

    var triggers: [Trigger] { engine.triggers }
    var activeTriggerIds: Set<UUID> { engine.activeTriggerIds }

    func toggle(triggerId: UUID, isEnabled: Bool) {
        engine.setEnabled(id: triggerId, isEnabled: isEnabled)
    }

    func remove(triggerId: UUID) {
        engine.remove(id: triggerId)
    }

    func save(_ trigger: Trigger) {
        engine.upsert(trigger)
    }

    func pickApplication() -> PickedApplication? {
        appPicker.pickApplication()
    }
}
