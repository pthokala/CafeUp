import AppKit
import Foundation

@MainActor
protocol AppLifetimeWatcher: AnyObject {
    func watch(bundleIdentifier: String, onTermination: @escaping @MainActor () -> Void)
    func stop()
    var watchedBundleIdentifier: String? { get }
}

@MainActor
final class NSWorkspaceAppLifetimeWatcher: AppLifetimeWatcher {
    private(set) var watchedBundleIdentifier: String?
    private var token: NSObjectProtocol?
    private var onTermination: (@MainActor () -> Void)?

    func watch(bundleIdentifier: String, onTermination: @escaping @MainActor () -> Void) {
        stop()
        watchedBundleIdentifier = bundleIdentifier
        self.onTermination = onTermination

        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let terminated = (note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.bundleIdentifier
            guard let terminated, terminated == bundleIdentifier else { return }
            MainActor.assumeIsolated {
                let callback = self?.onTermination
                self?.stop()
                callback?()
            }
        }
    }

    func stop() {
        if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        token = nil
        onTermination = nil
        watchedBundleIdentifier = nil
    }
}

@MainActor
enum RunningApplicationsSnapshot {
    struct Entry: Identifiable, Hashable {
        let id: String   // bundle identifier
        let name: String
        let icon: NSImage?
    }

    /// Running apps other than CafeUp, sorted by name. Regular (Dock) apps only unless
    /// `includeHelpers`, which adds menu-bar agents and background helpers.
    static func runningApps(includeHelpers: Bool = false) -> [Entry] {
        var seen = Set<String>()   // helpers can run several processes per bundle ID
        return NSWorkspace.shared.runningApplications
            .filter { includeHelpers || $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier,
                      bundleId != Bundle.main.bundleIdentifier,
                      seen.insert(bundleId).inserted else { return nil }
                let name = app.localizedName ?? bundleId
                return Entry(id: bundleId, name: name, icon: app.icon)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
