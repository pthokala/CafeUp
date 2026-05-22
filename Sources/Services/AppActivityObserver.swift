import AppKit
import Foundation

@MainActor
protocol AppActivityObserver: AnyObject {
    func start(onChange: @escaping @MainActor (Set<String>) -> Void)
    func stop()
    func currentSnapshot() -> Set<String>
}

@MainActor
final class NSWorkspaceAppActivityObserver: AppActivityObserver {
    private var tokens: [NSObjectProtocol] = []
    private var onChange: ((Set<String>) -> Void)?

    func start(onChange: @escaping @MainActor (Set<String>) -> Void) {
        stop()
        self.onChange = onChange
        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        tokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.fireChange() }
            }
        }
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for token in tokens { center.removeObserver(token) }
        tokens = []
        onChange = nil
    }

    func currentSnapshot() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    private func fireChange() {
        onChange?(currentSnapshot())
    }
}
