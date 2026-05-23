import Foundation

@MainActor
protocol DownloadsMonitor: AnyObject {
    func start(onIdle: @escaping @MainActor () -> Void)
    func stop()
    var hasActiveDownloads: Bool { get }
}

@MainActor
final class FileSystemDownloadsMonitor: DownloadsMonitor {
    static let partialExtensions: Set<String> = [
        "download",   // Safari
        "crdownload", // Chrome / Edge / Brave
        "part",       // Firefox
        "partial"     // Generic
    ]

    private let directory: URL
    private let pollInterval: Duration
    private let scheduler: Scheduler
    private var scheduled: ScheduledWork?
    private var onIdle: (@MainActor () -> Void)?
    private(set) var hasActiveDownloads: Bool = false

    init(
        directory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads"),
        pollInterval: Duration = .seconds(5),
        scheduler: Scheduler = TaskScheduler()
    ) {
        self.directory = directory
        self.pollInterval = pollInterval
        self.scheduler = scheduler
    }

    func start(onIdle: @escaping @MainActor () -> Void) {
        stop()
        self.onIdle = onIdle
        hasActiveDownloads = Self.partials(in: directory).count > 0
        scheduleNextPoll()
    }

    func stop() {
        scheduled?.cancel()
        scheduled = nil
        onIdle = nil
    }

    private func scheduleNextPoll() {
        scheduled = scheduler.schedule(after: pollInterval) { [weak self] in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        let partials = Self.partials(in: directory)
        hasActiveDownloads = !partials.isEmpty
        if partials.isEmpty {
            let callback = onIdle
            stop()
            callback?()
        } else {
            scheduleNextPoll()
        }
    }

    static func partials(in directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents.filter { partialExtensions.contains($0.pathExtension.lowercased()) }
    }
}
