import CoreGraphics
import Foundation

@MainActor
protocol UserIdleObserver: AnyObject {
    /// Seconds since the user last interacted with the Mac (keyboard, mouse, etc.).
    var idleSeconds: TimeInterval { get }
    /// Begin periodically polling and notifying on each tick.
    func start(interval: Duration, onTick: @escaping @MainActor (TimeInterval) -> Void)
    func stop()
}

@MainActor
final class CGEventSourceIdleObserver: UserIdleObserver {
    private let scheduler: Scheduler
    private var handle: ScheduledWork?
    private var onTick: (@MainActor (TimeInterval) -> Void)?
    private var pollInterval: Duration = .seconds(30)

    init(scheduler: Scheduler = TaskScheduler()) {
        self.scheduler = scheduler
    }

    var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .init(rawValue: ~0)!)
    }

    func start(interval: Duration, onTick: @escaping @MainActor (TimeInterval) -> Void) {
        stop()
        self.pollInterval = interval
        self.onTick = onTick
        // Fire once immediately so callers see the initial value.
        onTick(idleSeconds)
        scheduleNext()
    }

    func stop() {
        handle?.cancel()
        handle = nil
        onTick = nil
    }

    private func scheduleNext() {
        handle = scheduler.schedule(after: pollInterval) { [weak self] in
            Task { @MainActor in
                guard let self, let callback = self.onTick else { return }
                callback(self.idleSeconds)
                self.scheduleNext()
            }
        }
    }
}
