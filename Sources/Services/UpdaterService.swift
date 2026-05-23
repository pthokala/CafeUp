import AppKit
import Foundation
import Observation
import Sparkle

@MainActor
protocol UpdaterService: AnyObject {
    /// Whether a new "Check for Updates" can be started right now. False only during a
    /// check that's already in progress.
    var canCheckForUpdates: Bool { get }

    /// "<short> (<build>)" — matches the format Apple's About panel uses, so the Settings
    /// row and the About panel read identically.
    var currentVersionDisplay: String { get }

    /// Last time Sparkle completed a check (initiated by the user). `nil` until the first
    /// check finishes.
    var lastUpdateCheckDate: Date? { get }

    /// Begin a user-initiated update check. Sparkle owns the resulting UI: an alert with
    /// release notes if an update is available, the standard "you're up-to-date" alert
    /// if not, or an error alert if the appcast couldn't be fetched.
    func checkForUpdates()
}

/// Production `UpdaterService` backed by Sparkle 2's `SPUStandardUpdaterController`.
///
/// Background auto-checks are disabled both in Info.plist (`SUEnableAutomaticChecks=false`)
/// and at runtime; every check originates from the user.
@MainActor
@Observable
final class SparkleUpdaterService: UpdaterService {
    private(set) var canCheckForUpdates: Bool
    private(set) var lastUpdateCheckDate: Date?
    let currentVersionDisplay: String

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private let delegate: SparkleDelegate
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private var lastCheckObservation: NSKeyValueObservation?

    init() {
        let delegate = SparkleDelegate()
        self.delegate = delegate
        self.currentVersionDisplay = Self.makeVersionDisplay()
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        // Defense in depth: even though Info.plist disables auto-checks, also enforce at
        // runtime so a stale UserDefaults value (e.g. set by a prior build) can't re-enable it.
        controller.updater.automaticallyChecksForUpdates = false

        self.canCheckForUpdates = controller.updater.canCheckForUpdates
        self.lastUpdateCheckDate = controller.updater.lastUpdateCheckDate

        // Mirror Sparkle's KVO-published state into our @Observable storage so SwiftUI views
        // automatically re-render. Sparkle's properties are main-thread-only, so the change
        // handlers fire on the main thread; the explicit @MainActor hop is belt-and-suspenders.
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheckForUpdates = value }
        }
        lastCheckObservation = controller.updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] updater, _ in
            let value = updater.lastUpdateCheckDate
            Task { @MainActor in self?.lastUpdateCheckDate = value }
        }
    }

    deinit {
        canCheckObservation?.invalidate()
        lastCheckObservation?.invalidate()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    private static func makeVersionDisplay() -> String {
        let bundle = Bundle.main
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// Empty delegate. Kept as a dedicated type so future channel selection or update-filtering
/// hooks can land here without changing `SparkleUpdaterService`'s init signature.
private final class SparkleDelegate: NSObject, SPUUpdaterDelegate {}
