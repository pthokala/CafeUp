import Foundation
import Observation

/// Drives the **Updates** section inside Settings → General. Holds a reference to the
/// `UpdaterService` and exposes pre-formatted strings for display + the user-initiated
/// action. The service is `@Observable`, so reads here re-render the SwiftUI view
/// automatically when Sparkle's `canCheckForUpdates` / `lastUpdateCheckDate` change.
@MainActor
@Observable
final class UpdatesSectionViewModel {
    @ObservationIgnored let updater: UpdaterService
    @ObservationIgnored private let clock: Clock

    init(updater: UpdaterService, clock: Clock = SystemClock()) {
        self.updater = updater
        self.clock = clock
    }

    /// "0.2.0 (2)" — same shape Apple's About panel uses, for visual consistency.
    var currentVersionDisplay: String { updater.currentVersionDisplay }

    /// True while no check is in flight; the "Check for Updates Now" button binds to this.
    var canCheckForUpdates: Bool { updater.canCheckForUpdates }

    /// Human-readable "Last checked" line, e.g. "Never", "Today at 3:42 PM",
    /// "Yesterday", "3 days ago".
    var lastCheckedDescription: String {
        guard let date = updater.lastUpdateCheckDate else { return "Never" }
        return Self.relativeDescription(of: date, now: clock.now)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    // MARK: - Date formatting (deterministic, testable)

    /// Plain, predictable formatting for the "Last checked" string. We render relative
    /// to today so the user can tell at a glance "did I check recently?" The exact
    /// timestamp is in Sparkle's alert anyway when they next click the button.
    static func relativeDescription(of date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today at \(timeFormatter.string(from: date))"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday at \(timeFormatter.string(from: date))"
        }
        let dayStart = calendar.startOfDay(for: date)
        let nowStart = calendar.startOfDay(for: now)
        if let days = calendar.dateComponents([.day], from: dayStart, to: nowStart).day, days > 0 {
            return "\(days) days ago"
        }
        // Future date (clock skew or test fakes) — fall back to the absolute timestamp.
        return absoluteFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
