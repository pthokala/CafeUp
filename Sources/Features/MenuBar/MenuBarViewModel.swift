import Foundation
import Observation

@MainActor
@Observable
final class MenuBarViewModel {
    private(set) var lastError: SessionError?

    var policy: WakePolicy {
        didSet {
            guard policy != oldValue, engine.isActive else { return }
            perform { try engine.updatePolicy(policy) }
        }
    }

    /// Increments every `tickInterval` while a session is active. Views that need to
    /// re-render the remaining-time string should read this so SwiftUI tracks it as
    /// a dependency.
    private(set) var tick: Int = 0

    /// True while a session was started by "While App is Running"; the session ends when that app quits.
    private(set) var whileAppRunningBundleId: String?
    /// True while a session was started by "While File is Downloading…"; the session ends when downloads idle.
    private(set) var isWhileDownloadingActive: Bool = false

    @ObservationIgnored private let engine: SessionEngine
    @ObservationIgnored private let triggerEngine: TriggerEngine
    @ObservationIgnored private let appLifetimeWatcher: AppLifetimeWatcher?
    @ObservationIgnored private let downloadsMonitor: DownloadsMonitor?
    @ObservationIgnored private let tickScheduler: Scheduler
    @ObservationIgnored private let tickInterval: Duration
    @ObservationIgnored private var tickHandle: ScheduledWork?

    init(
        engine: SessionEngine,
        triggerEngine: TriggerEngine,
        appLifetimeWatcher: AppLifetimeWatcher? = nil,
        downloadsMonitor: DownloadsMonitor? = nil,
        tickScheduler: Scheduler = TaskScheduler(),
        tickInterval: Duration = .seconds(1),
        initialPolicy: WakePolicy = .systemAndDisplay
    ) {
        self.engine = engine
        self.triggerEngine = triggerEngine
        self.appLifetimeWatcher = appLifetimeWatcher
        self.downloadsMonitor = downloadsMonitor
        self.tickScheduler = tickScheduler
        self.tickInterval = tickInterval
        self.policy = initialPolicy
    }

    var session: Session? { engine.current }
    var isManualSessionActive: Bool { engine.current != nil }
    var isTriggerActive: Bool { triggerEngine.isAnyTriggerActive }
    var isActive: Bool { isManualSessionActive || isTriggerActive }
    var activeTriggerCount: Int { triggerEngine.activeTriggerIds.count }

    /// Human-readable line shown under "Current Session Details:" — e.g. "05m 30s remaining (12:35 PM)".
    /// Returns `nil` when there is no active session. Reading this also registers `tick` as an observable
    /// dependency so SwiftUI re-renders the line each time the ticker fires.
    func sessionStatusLine(now: Date = Date()) -> String? {
        _ = tick
        guard let session = engine.current else { return nil }
        guard let endsAt = session.endsAt else { return "Indefinite session" }
        let remaining = max(0, Int(endsAt.timeIntervalSince(now)))
        let duration = RemainingFormatter.amphetamineStyle(secondsRemaining: remaining)
        let endsText = RemainingFormatter.clockTime(endsAt)
        return "\(duration) (\(endsText))"
    }

    func startIndefinite() {
        cancelAutoStoppers()
        perform { try engine.start(mode: .indefinite, policy: policy) }
        startTickerIfActive()
    }

    func start(duration: Duration) {
        cancelAutoStoppers()
        perform { try engine.start(mode: .timed(duration), policy: policy) }
        startTickerIfActive()
    }

    func startUntil(_ endDate: Date, now: Date = Date()) {
        let seconds = max(0, endDate.timeIntervalSince(now))
        guard seconds > 0 else { return }
        start(duration: .seconds(seconds))
    }

    func startWhileAppRunning(bundleIdentifier: String) {
        guard let watcher = appLifetimeWatcher else { return }
        cancelAutoStoppers()
        perform { try engine.start(mode: .indefinite, policy: policy) }
        guard lastError == nil else { return }
        whileAppRunningBundleId = bundleIdentifier
        watcher.watch(bundleIdentifier: bundleIdentifier) { [weak self] in
            self?.stop()
        }
        startTickerIfActive()
    }

    func startWhileDownloading() {
        guard let monitor = downloadsMonitor else { return }
        cancelAutoStoppers()
        perform { try engine.start(mode: .indefinite, policy: policy) }
        guard lastError == nil else { return }
        isWhileDownloadingActive = true
        monitor.start { [weak self] in
            self?.stop()
        }
        startTickerIfActive()
    }

    func stop() {
        cancelAutoStoppers()
        stopTicker()
        engine.stop()
    }

    private func cancelAutoStoppers() {
        appLifetimeWatcher?.stop()
        downloadsMonitor?.stop()
        whileAppRunningBundleId = nil
        isWhileDownloadingActive = false
    }

    private func startTickerIfActive() {
        guard engine.isActive else { return }
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        tickHandle?.cancel()
        tickHandle = tickScheduler.schedule(after: tickInterval) { [weak self] in
            Task { @MainActor in
                guard let self, self.engine.isActive else { return }
                self.tick &+= 1
                self.scheduleNextTick()
            }
        }
    }

    private func stopTicker() {
        tickHandle?.cancel()
        tickHandle = nil
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            lastError = nil
        } catch let error as SessionError {
            lastError = error
        } catch {
            lastError = .assertionFailed(code: -1)
        }
    }
}
