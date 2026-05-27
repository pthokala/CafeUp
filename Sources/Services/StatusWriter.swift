import Foundation

/// Sink for `StatusSnapshot` values. A protocol so the publisher can be
/// tested without touching the filesystem.
@MainActor
protocol StatusWriter: AnyObject {
    func write(_ snapshot: StatusSnapshot)
}

/// Writes JSON snapshots to a file on disk, atomically and only when the
/// encoded payload actually changes.
///
/// Why this is lightweight:
/// - Encoding is cheap (a few dozen bytes); `JSONEncoder` is reused.
/// - `Data.write(options: .atomic)` writes to a sibling temp file and
///   renames — never leaves a half-written file on disk.
/// - We compare the new encoded bytes against the last-written bytes and
///   skip the syscalls entirely when they match, so re-observation that
///   produces the same snapshot is essentially free.
/// - All I/O is on the main actor (CafeUp's snapshots are <1 KB, so the
///   write cost is dominated by APFS metadata, not blocking time).
@MainActor
final class FileSystemStatusWriter: StatusWriter {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let logger: AppLogger
    private var lastWritten: Data?

    init(
        fileURL: URL,
        fileManager: FileManager = .default,
        logger: AppLogger
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        self.logger = logger
    }

    func write(_ snapshot: StatusSnapshot) {
        let payload: Data
        do {
            payload = try encoder.encode(snapshot)
        } catch {
            logger.error("status: encode failed: \(error)")
            return
        }
        // Dedupe: skip the write when nothing actually changed.
        guard payload != lastWritten else { return }
        do {
            try ensureParentDirectoryExists()
            try payload.write(to: fileURL, options: .atomic)
            lastWritten = payload
        } catch {
            logger.error("status: write failed at \(fileURL.path): \(error)")
        }
    }

    /// Default install location: `~/Library/Application Support/CafeUp/status.json`.
    /// Sandbox is off for CafeUp, so this resolves to the real Application Support
    /// directory (not a container).
    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("CafeUp", isDirectory: true)
            .appendingPathComponent("status.json", isDirectory: false)
    }

    private func ensureParentDirectoryExists() throws {
        let dir = fileURL.deletingLastPathComponent()
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
            return
        }
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
