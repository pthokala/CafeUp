import Foundation
import Observation

@MainActor
@Observable
final class MenuBarViewModel {
    private(set) var lastError: SessionError?

    var policy: WakePolicy {
        didSet {
            guard policy != oldValue, engine.isActive else { return }
            perform { try engine.updatePolicy(policy) }
        }
    }

    @ObservationIgnored private let engine: SessionEngine
    @ObservationIgnored private let triggerEngine: TriggerEngine

    init(
        engine: SessionEngine,
        triggerEngine: TriggerEngine,
        initialPolicy: WakePolicy = .systemAndDisplay
    ) {
        self.engine = engine
        self.triggerEngine = triggerEngine
        self.policy = initialPolicy
    }

    var session: Session? { engine.current }
    var isManualSessionActive: Bool { engine.current != nil }
    var isTriggerActive: Bool { triggerEngine.isAnyTriggerActive }
    var isActive: Bool { isManualSessionActive || isTriggerActive }
    var activeTriggerCount: Int { triggerEngine.activeTriggerIds.count }

    func startIndefinite() {
        perform { try engine.start(mode: .indefinite, policy: policy) }
    }

    func start(duration: Duration) {
        perform { try engine.start(mode: .timed(duration), policy: policy) }
    }

    func stop() {
        engine.stop()
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            lastError = nil
        } catch let error as SessionError {
            lastError = error
        } catch {
            lastError = .assertionFailed(code: -1)
        }
    }
}
