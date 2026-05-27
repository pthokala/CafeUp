import AppKit
import Foundation

@MainActor
protocol SessionAlertSounds {
    func playSessionStart()
    func playSessionEnd()
}

enum SessionSoundPreferences {
    static let isEnabledKey = "com.pardhu.CafeUp.sessionSounds.enabled.v1"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: isEnabledKey) as? Bool ?? true
    }
}

/// Plays brief system sounds when a session activates or ends. NSSound instances are
/// cached because `NSSound(named:)` reads from disk; calling `stop()` before `play()`
/// guarantees a rapid stop/start pair restarts the clip cleanly instead of being dropped.
@MainActor
final class SystemSessionAlertSounds: SessionAlertSounds {
    private let startSound: NSSound?
    private let endSound: NSSound?
    private let isEnabled: () -> Bool

    init(
        startSoundName: String = "Pop",
        endSoundName: String = "Glass",
        volume: Float = 0.5,
        isEnabled: @escaping () -> Bool = { SessionSoundPreferences.isEnabled() }
    ) {
        let start = NSSound(named: NSSound.Name(startSoundName))
        start?.volume = volume
        self.startSound = start

        let end = NSSound(named: NSSound.Name(endSoundName))
        end?.volume = volume
        self.endSound = end

        self.isEnabled = isEnabled
    }

    func playSessionStart() { play(startSound) }
    func playSessionEnd()   { play(endSound) }

    private func play(_ sound: NSSound?) {
        guard isEnabled(), let sound else { return }
        sound.stop()
        sound.play()
    }
}
