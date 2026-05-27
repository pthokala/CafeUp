import Foundation

/// Operational surface exposed to agents via AppIntents, the `cafeup://` URL
/// scheme, and the `cafeup` CLI. All external commands converge here so we
/// have a single chokepoint for routing, validation, and (future) logging or
/// rate-limiting.
@MainActor
protocol AgentCommandHandler: AnyObject {
    var isActive: Bool { get }
    func startIndefinite() throws
    func startTimed(minutes: Int) throws
    func stop()
    /// Apply a partial policy update. Mutates the saved default policy via
    /// `PolicyMutator`; when a session is active, the mutation cascades to
    /// the live IOKit assertion via `MenuBarViewModel.policy.didSet`.
    func updatePolicy(_ update: PolicyUpdate) throws
}

/// Canonical start/stop API. Satisfied by `MenuBarViewModel`, whose
/// implementation manages auto-stopper cancellation, ticker scheduling, and
/// the idle observer — all of which the bridge needs to honor so an
/// agent-initiated session behaves identically to a menu-initiated one.
///
/// `startIndefinite`/`start(duration:)` don't throw because `MenuBarViewModel`
/// captures errors in `lastError`; the bridge inspects it post-call.
@MainActor
protocol SessionLifecycle: AnyObject {
    var isActive: Bool { get }
    var lastError: SessionError? { get }
    func startIndefinite()
    func start(duration: Duration)
    func stop()
}

/// Read/write access to the user's saved wake policy. Satisfied by
/// `MenuBarViewModel`, whose `policy.didSet` hook reapplies the policy to
/// the active session for us — so the bridge doesn't have to touch the
/// engine directly when changing policy mid-session.
@MainActor
protocol PolicyMutator: AnyObject {
    var policy: WakePolicy { get set }
}

@MainActor
final class AppIntentBridge: AgentCommandHandler {
    static let shared = AppIntentBridge()

    private var lifecycle: SessionLifecycle?
    private var policyMutator: PolicyMutator?

    /// Bounds on the `minutes` parameter for timed sessions. Mirrors the
    /// `inclusiveRange` on `StartCafeUpSessionIntent.minutes` so AppIntents
    /// and the URL scheme agree.
    static let minTimedMinutes = 1
    static let maxTimedMinutes = 24 * 60

    private init() {}

    /// Wire runtime dependencies. Called once from `CompositionRoot`. The
    /// bridge is a singleton because AppIntents are instantiated by the
    /// system and need a process-wide rendezvous point.
    func register(lifecycle: SessionLifecycle, policyMutator: PolicyMutator) {
        self.lifecycle = lifecycle
        self.policyMutator = policyMutator
    }

    var isActive: Bool { lifecycle?.isActive ?? false }

    func startIndefinite() throws {
        guard let lifecycle else { throw IntentError.notRegistered }
        lifecycle.startIndefinite()
        try throwIfRecorded(lifecycle.lastError)
    }

    func startTimed(minutes: Int) throws {
        guard let lifecycle else { throw IntentError.notRegistered }
        let clamped = max(Self.minTimedMinutes, min(minutes, Self.maxTimedMinutes))
        lifecycle.start(duration: .seconds(clamped * 60))
        try throwIfRecorded(lifecycle.lastError)
    }

    func stop() {
        lifecycle?.stop()
    }

    func updatePolicy(_ update: PolicyUpdate) throws {
        guard let policyMutator else { throw IntentError.notRegistered }
        guard !update.isEmpty else { throw IntentError.emptyPolicyUpdate }
        policyMutator.policy = update.apply(to: policyMutator.policy)
    }

    private func throwIfRecorded(_ error: SessionError?) throws {
        if let error { throw IntentError.sessionFailed(error.localizedDescription) }
    }
}

enum IntentError: LocalizedError, Equatable {
    case notRegistered
    case emptyPolicyUpdate
    case sessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notRegistered:          return "CafeUp engine is not available."
        case .emptyPolicyUpdate:      return "No policy fields were provided."
        case .sessionFailed(let msg): return "CafeUp session failed: \(msg)"
        }
    }
}
