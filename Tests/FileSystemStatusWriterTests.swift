import XCTest
@testable import CafeUp

@MainActor
final class FileSystemStatusWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("CafeUpStatusTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func test_write_createsParentDirectoryAndFile() throws {
        let url = tempDir.appendingPathComponent("nested/deep/status.json")
        let writer = FileSystemStatusWriter(fileURL: url, logger: SilentLogger())

        writer.write(makeSnapshot())

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let dir = url.deletingLastPathComponent().path
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func test_write_producesParseableJSON() throws {
        let url = tempDir.appendingPathComponent("status.json")
        let writer = FileSystemStatusWriter(fileURL: url, logger: SilentLogger())
        let snap = makeSnapshot(active: true)

        writer.write(snap)

        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(StatusSnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }

    func test_repeatedIdenticalWrites_skipDiskIO() throws {
        let url = tempDir.appendingPathComponent("status.json")
        let writer = FileSystemStatusWriter(fileURL: url, logger: SilentLogger())
        let snap = makeSnapshot()

        writer.write(snap)
        let firstAttrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let firstMTime = firstAttrs[.modificationDate] as? Date

        // Sleep just enough that any actual write would have a different mtime.
        Thread.sleep(forTimeInterval: 0.05)
        writer.write(snap)
        let secondAttrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let secondMTime = secondAttrs[.modificationDate] as? Date

        XCTAssertNotNil(firstMTime)
        XCTAssertEqual(firstMTime, secondMTime, "Identical snapshots should not re-touch the file")
    }

    func test_changedSnapshot_rewritesFile() throws {
        let url = tempDir.appendingPathComponent("status.json")
        let writer = FileSystemStatusWriter(fileURL: url, logger: SilentLogger())

        writer.write(makeSnapshot(active: false))
        let firstData = try Data(contentsOf: url)
        writer.write(makeSnapshot(active: true))
        let secondData = try Data(contentsOf: url)

        XCTAssertNotEqual(firstData, secondData)
    }

    func test_write_overwritesExistingFileAtomically() throws {
        // Pre-seed the file with garbage and ensure the writer replaces it.
        let url = tempDir.appendingPathComponent("status.json")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)

        let writer = FileSystemStatusWriter(fileURL: url, logger: SilentLogger())
        let snap = makeSnapshot()
        writer.write(snap)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(StatusSnapshot.self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded, snap)
    }

    func test_write_doesNotLeaveSiblingTempFiles() throws {
        let url = tempDir.appendingPathComponent("status.json")
        let writer = FileSystemStatusWriter(fileURL: url, logger: SilentLogger())
        writer.write(makeSnapshot())

        let siblings = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertEqual(siblings, ["status.json"],
                       "Atomic write should clean up its temp file: found \(siblings)")
    }

    func test_writeFailure_isSwallowed() throws {
        // Pointing at a path whose parent is an EXISTING FILE makes both
        // createDirectory and write fail. The writer must not crash.
        let blocking = tempDir.appendingPathComponent("blocker")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data().write(to: blocking)
        let url = blocking.appendingPathComponent("status.json") // parent is a file → invalid
        let writer = FileSystemStatusWriter(fileURL: url, logger: SilentLogger())

        writer.write(makeSnapshot()) // must not throw or crash
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func test_defaultFileURL_underApplicationSupportSlashCafeUp() {
        let url = FileSystemStatusWriter.defaultFileURL()
        XCTAssertEqual(url.lastPathComponent, "status.json")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "CafeUp")
        XCTAssertTrue(url.path.contains("Application Support"),
                      "Expected Application Support in path; got \(url.path)")
    }

    // MARK: - Helpers

    private func makeSnapshot(active: Bool = false) -> StatusSnapshot {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        if active {
            let session = Session(
                mode: .timed(.seconds(60)),
                policy: .default,
                startedAt: now,
                endsAt: now.addingTimeInterval(60)
            )
            return StatusSnapshot.make(session: session, savedPolicy: .default, now: now)
        } else {
            return StatusSnapshot.make(session: nil, savedPolicy: .default, now: now)
        }
    }
}
