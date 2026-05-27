import Foundation
@testable import CafeUp

/// Records every command and exposes a settable `lastError` so we can
/// exercise the bridge's "translate lastError to a throw" path.
@MainActor
final class FakeSessionLifecycle: SessionLifecycle, PolicyMutator {
    enum Call: Equatable {
        case startIndefinite
        case startWithDuration(seconds: Int)
        case stop
    }

    private(set) var calls: [Call] = []
    var isActiveValue: Bool = false
    var lastError: SessionError?
    var policy: WakePolicy

    init(policy: WakePolicy = .default) {
        self.policy = policy
    }

    var isActive: Bool { isActiveValue }

    func startIndefinite() {
        calls.append(.startIndefinite)
    }

    func start(duration: Duration) {
        // Capture as integer seconds for convenient assertion.
        let seconds = Int(duration.components.seconds)
        calls.append(.startWithDuration(seconds: seconds))
    }

    func stop() {
        calls.append(.stop)
    }
}
