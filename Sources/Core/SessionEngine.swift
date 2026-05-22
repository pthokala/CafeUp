import Foundation
import Observation

@MainActor
@Observable
final class SessionEngine {
    private(set) var current: Session?

    @ObservationIgnored private var token: PowerAssertionToken?
    @ObservationIgnored private var scheduled: ScheduledWork?

    @ObservationIgnored private let assertions: PowerAssertionService
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let scheduler: Scheduler
    @ObservationIgnored private let logger: AppLogger

    init(
        assertions: PowerAssertionService,
        clock: Clock,
        scheduler: Scheduler,
        logger: AppLogger
    ) {
        self.assertions = assertions
        self.clock = clock
        self.scheduler = scheduler
        self.logger = logger
    }

    var isActive: Bool { current != nil }

    func start(mode: SessionMode, policy: WakePolicy) throws {
        try replaceSession(mode: mode, policy: policy, preserving: nil)
    }

    func stop() {
        guard current != nil else { return }
        scheduled?.cancel()
        scheduled = nil
        token?.release()
        token = nil
        current = nil
        logger.info("Session stopped")
    }

    func updatePolicy(_ policy: WakePolicy) throws {
        guard let session = current else { return }
        try replaceSession(mode: session.mode, policy: policy, preserving: session)
    }

    private func replaceSession(
        mode: SessionMode,
        policy: WakePolicy,
        preserving previous: Session?
    ) throws {
        let newToken = try assertions.acquire(policy: policy, reason: "CafeUp keeping Mac awake")

        scheduled?.cancel()
        token?.release()

        let startedAt = previous?.startedAt ?? clock.now
        let endsAt: Date? = previous?.endsAt ?? endDate(for: mode, startingAt: startedAt)
        let session = Session(mode: mode, policy: policy, startedAt: startedAt, endsAt: endsAt)

        token = newToken
        scheduled = nil
        current = session

        if let endsAt, let remaining = remainingDuration(until: endsAt) {
            scheduled = scheduler.schedule(after: remaining) { [weak self] in
                Task { @MainActor in self?.stop() }
            }
        }

        logger.info(
            "Session started: mode=\(String(describing: mode)) policy=\(policy.rawValue) "
            + "startedAt=\(startedAt) endsAt=\(endsAt.map(String.init(describing:)) ?? "nil")"
        )
    }

    private func endDate(for mode: SessionMode, startingAt start: Date) -> Date? {
        guard case .timed(let duration) = mode else { return nil }
        return start.addingTimeInterval(TimeInterval(duration.components.seconds))
    }

    private func remainingDuration(until end: Date) -> Duration? {
        let seconds = end.timeIntervalSince(clock.now)
        guard seconds > 0 else { return nil }
        return .seconds(seconds)
    }
}
