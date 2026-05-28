import Foundation

/// User-facing wake options. Each bool maps directly to a checkbox in the active-session
/// menu and to the corresponding IOKit assertion that should be **released**.
struct WakePolicy: Sendable, Hashable, Codable {
    /// When `true`, the user wants the display to be allowed to sleep — we do NOT hold
    /// `kIOPMAssertionTypePreventUserIdleDisplaySleep`.
    var allowDisplaySleep: Bool

    /// When `true`, the system may sleep even while keep-awake is active if the lid is closed —
    /// we do NOT hold `kIOPMAssertionTypePreventSystemSleep`. (Display-on case still uses the
    /// `PreventUserIdleSystemSleep` assertion which honors clamshell.)
    var allowSystemSleepWhenLidClosed: Bool

    /// When `true`, after 45 minutes of user idle we'll temporarily release the display
    /// assertion so the screen saver can engage.
    var allowScreenSaverAfter45Min: Bool

    init(
        allowDisplaySleep: Bool = false,
        allowSystemSleepWhenLidClosed: Bool = true,
        allowScreenSaverAfter45Min: Bool = false
    ) {
        self.allowDisplaySleep = allowDisplaySleep
        self.allowSystemSleepWhenLidClosed = allowSystemSleepWhenLidClosed
        self.allowScreenSaverAfter45Min = allowScreenSaverAfter45Min
    }

    /// Number of seconds of user idleness after which we let the screen saver take over,
    /// when `allowScreenSaverAfter45Min` is enabled.
    static let screenSaverIdleThreshold: TimeInterval = 45 * 60

    /// Apply runtime-dependent overrides. Returns a copy of the policy with
    /// `allowDisplaySleep == true` if `allowScreenSaverAfter45Min` is set and the user
    /// has been idle past the 45-min threshold — letting the display assertion drop so
    /// the screen saver can engage.
    func effective(idleSeconds: TimeInterval) -> WakePolicy {
        guard allowScreenSaverAfter45Min,
              idleSeconds >= WakePolicy.screenSaverIdleThreshold else {
            return self
        }
        var copy = self
        copy.allowDisplaySleep = true
        return copy
    }

    /// Default: keep display on, allow lid-close sleep.
    static let `default` = WakePolicy()

    /// Equivalent of the legacy `.systemOnly` enum case — system stays awake but display
    /// may sleep.
    static let systemOnly = WakePolicy(
        allowDisplaySleep: true,
        allowSystemSleepWhenLidClosed: true,
        allowScreenSaverAfter45Min: false
    )

    /// Equivalent of the legacy `.systemAndDisplay` enum case — both stay awake.
    static let systemAndDisplay = WakePolicy(
        allowDisplaySleep: false,
        allowSystemSleepWhenLidClosed: true,
        allowScreenSaverAfter45Min: false
    )

    // MARK: - Codable with legacy-enum migration

    private enum CodingKeys: String, CodingKey {
        case allowDisplaySleep
        case allowSystemSleepWhenLidClosed
        case allowScreenSaverAfter45Min
    }

    init(from decoder: Decoder) throws {
        // Legacy: WakePolicy used to be a String-backed enum ("systemOnly" / "systemAndDisplay").
        if let singleValue = try? decoder.singleValueContainer(),
           let raw = try? singleValue.decode(String.self) {
            switch raw {
            case "systemOnly":       self = .systemOnly
            case "systemAndDisplay": self = .systemAndDisplay
            default:                 self = .default
            }
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.allowDisplaySleep = try container.decodeIfPresent(Bool.self, forKey: .allowDisplaySleep)
            ?? false
        self.allowSystemSleepWhenLidClosed = try container.decodeIfPresent(Bool.self, forKey: .allowSystemSleepWhenLidClosed)
            ?? true
        self.allowScreenSaverAfter45Min = try container.decodeIfPresent(Bool.self, forKey: .allowScreenSaverAfter45Min)
            ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(allowDisplaySleep, forKey: .allowDisplaySleep)
        try container.encode(allowSystemSleepWhenLidClosed, forKey: .allowSystemSleepWhenLidClosed)
        try container.encode(allowScreenSaverAfter45Min, forKey: .allowScreenSaverAfter45Min)
    }
}
