import Foundation
@testable import CafeUp

@MainActor
final class FakeUserIdleObserver: UserIdleObserver {
    private(set) var idleSeconds: TimeInterval = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var lastInterval: Duration?
    private var onTick: (@MainActor (TimeInterval) -> Void)?

    func start(interval: Duration, onTick: @escaping @MainActor (TimeInterval) -> Void) {
        startCount += 1
        lastInterval = interval
        self.onTick = onTick
        onTick(idleSeconds)
    }

    func stop() {
        stopCount += 1
        onTick = nil
    }

    /// Simulate the polling loop firing with a new idle reading.
    func emit(idleSeconds: TimeInterval) {
        self.idleSeconds = idleSeconds
        onTick?(idleSeconds)
    }
}
