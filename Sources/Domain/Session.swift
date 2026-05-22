import Foundation

struct Session: Sendable, Equatable, Identifiable {
    let id: UUID
    let mode: SessionMode
    let policy: WakePolicy
    let startedAt: Date
    let endsAt: Date?

    init(
        id: UUID = UUID(),
        mode: SessionMode,
        policy: WakePolicy,
        startedAt: Date,
        endsAt: Date?
    ) {
        self.id = id
        self.mode = mode
        self.policy = policy
        self.startedAt = startedAt
        self.endsAt = endsAt
    }
}
