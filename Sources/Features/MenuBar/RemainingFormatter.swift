import Foundation

enum RemainingFormatter {
    /// Compact format used in tests and tooltips: `M:SS` / `H:MM:SS`.
    static func format(secondsRemaining: Int) -> String {
        let seconds = max(0, secondsRemaining)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Verbose format used in the active-session menu: `MMm SSs remaining`,
    /// or `HHh MMm SSs remaining` when hours > 0.
    static func verboseStyle(secondsRemaining: Int) -> String {
        let seconds = max(0, secondsRemaining)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02dh %02dm %02ds remaining", hours, minutes, secs)
        }
        return String(format: "%02dm %02ds remaining", minutes, secs)
    }

    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
