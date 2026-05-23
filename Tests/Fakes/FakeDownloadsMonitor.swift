import Foundation
@testable import CafeUp

@MainActor
final class FakeDownloadsMonitor: DownloadsMonitor {
    private(set) var hasActiveDownloads: Bool = true
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var onIdle: (@MainActor () -> Void)?

    func start(onIdle: @escaping @MainActor () -> Void) {
        startCount += 1
        self.onIdle = onIdle
    }

    func stop() {
        stopCount += 1
        onIdle = nil
    }

    /// Simulate downloads finishing.
    func simulateIdle() {
        hasActiveDownloads = false
        let callback = onIdle
        callback?()
    }
}
