import Foundation

@MainActor
protocol SessionCommandHandler: Sendable {
    func startIndefinite() throws
    func startTimed(minutes: Int) throws
    func stop()
    var isActive: Bool { get }
}

@MainActor
final class AppIntentBridge: SessionCommandHandler {
    static let shared = AppIntentBridge()

    private var sessionEngine: SessionEngine?

    private init() {}

    func register(sessionEngine: SessionEngine) {
        self.sessionEngine = sessionEngine
    }

    var isActive: Bool { sessionEngine?.isActive ?? false }

    func startIndefinite() throws {
        guard let engine = sessionEngine else { throw IntentError.notRegistered }
        try engine.start(mode: .indefinite, policy: .systemAndDisplay)
    }

    func startTimed(minutes: Int) throws {
        guard let engine = sessionEngine else { throw IntentError.notRegistered }
        let clamped = max(1, min(minutes, 24 * 60))
        try engine.start(
            mode: .timed(.seconds(clamped * 60)),
            policy: .systemAndDisplay
        )
    }

    func stop() {
        sessionEngine?.stop()
    }
}

enum IntentError: LocalizedError {
    case notRegistered
    case sessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notRegistered:           return "CafeUp engine is not available."
        case .sessionFailed(let msg):  return "CafeUp session failed: \(msg)"
        }
    }
}
