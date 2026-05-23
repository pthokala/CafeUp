import Foundation
@testable import CafeUp

@MainActor
final class FakeAppLifetimeWatcher: AppLifetimeWatcher {
    private(set) var watchedBundleIdentifier: String?
    private(set) var watchCount = 0
    private(set) var stopCount = 0
    private var onTermination: (@MainActor () -> Void)?

    func watch(bundleIdentifier: String, onTermination: @escaping @MainActor () -> Void) {
        watchCount += 1
        watchedBundleIdentifier = bundleIdentifier
        self.onTermination = onTermination
    }

    func stop() {
        stopCount += 1
        watchedBundleIdentifier = nil
        onTermination = nil
    }

    /// Simulate the watched app terminating.
    func simulateTermination() {
        let callback = onTermination
        callback?()
    }
}
