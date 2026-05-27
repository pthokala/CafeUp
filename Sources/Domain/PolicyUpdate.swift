import Foundation

/// A partial mutation of `WakePolicy`. Each field is optional — `nil` means
/// "leave as-is". Used by the agent IPC surface (URL scheme, CLI, intents)
/// so callers can change just one knob without echoing the others.
struct PolicyUpdate: Sendable, Equatable {
    var allowDisplaySleep: Bool?
    var allowSystemSleepWhenLidClosed: Bool?
    var allowScreenSaverAfter45Min: Bool?

    init(
        allowDisplaySleep: Bool? = nil,
        allowSystemSleepWhenLidClosed: Bool? = nil,
        allowScreenSaverAfter45Min: Bool? = nil
    ) {
        self.allowDisplaySleep = allowDisplaySleep
        self.allowSystemSleepWhenLidClosed = allowSystemSleepWhenLidClosed
        self.allowScreenSaverAfter45Min = allowScreenSaverAfter45Min
    }

    /// `true` when every field is `nil`. Callers should treat this as a no-op
    /// (and typically reject it at the API boundary so accidental no-ops surface).
    var isEmpty: Bool {
        allowDisplaySleep == nil
        && allowSystemSleepWhenLidClosed == nil
        && allowScreenSaverAfter45Min == nil
    }

    /// Returns a new `WakePolicy` with each non-nil field overriding `base`.
    func apply(to base: WakePolicy) -> WakePolicy {
        var next = base
        if let allowDisplaySleep              { next.allowDisplaySleep = allowDisplaySleep }
        if let allowSystemSleepWhenLidClosed  { next.allowSystemSleepWhenLidClosed = allowSystemSleepWhenLidClosed }
        if let allowScreenSaverAfter45Min     { next.allowScreenSaverAfter45Min = allowScreenSaverAfter45Min }
        return next
    }
}
