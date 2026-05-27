import Foundation

/// Serializable view of CafeUp's current state, written to
/// `~/Library/Application Support/CafeUp/status.json` whenever the session
/// or policy changes. Agents read this file to query state without any IPC.
///
/// Stored fields:
/// - `active` — whether a manual session is currently held by `SessionEngine`.
///   (Trigger-driven sessions are not surfaced here; agents that want trigger
///   info would need a separate channel.)
/// - `mode` / `startedAt` / `endsAt` — present only when `active == true`.
///   Agents compute live remaining time as `endsAt - now` themselves, so the
///   file doesn't need to be rewritten every second.
/// - `policy` — the user's saved wake-policy preference (not the effective
///   policy modulated by idle overrides; the override is an implementation
///   detail callers don't need to round-trip).
/// - `updatedAt` — wall-clock time the snapshot was produced.
struct StatusSnapshot: Sendable, Equatable, Codable {
    let active: Bool
    let mode: ModeRepr?
    let startedAt: Date?
    let endsAt: Date?
    let policy: WakePolicy
    let updatedAt: Date

    enum ModeRepr: String, Sendable, Equatable, Codable {
        case indefinite
        case timed
    }

    /// Build a snapshot from CafeUp's runtime values.
    static func make(
        session: Session?,
        savedPolicy: WakePolicy,
        now: Date
    ) -> StatusSnapshot {
        if let session {
            let mode: ModeRepr = (session.mode.duration == nil) ? .indefinite : .timed
            return StatusSnapshot(
                active: true,
                mode: mode,
                startedAt: session.startedAt,
                endsAt: session.endsAt,
                policy: savedPolicy,
                updatedAt: now
            )
        } else {
            return StatusSnapshot(
                active: false,
                mode: nil,
                startedAt: nil,
                endsAt: nil,
                policy: savedPolicy,
                updatedAt: now
            )
        }
    }
}
