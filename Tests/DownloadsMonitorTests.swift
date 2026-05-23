import XCTest
@testable import CafeUp

@MainActor
final class DownloadsMonitorTests: XCTestCase {

    func test_partials_detectsSafariDownload() throws {
        let dir = try makeTempDir()
        try makeFile(in: dir, named: "movie.mp4.download")
        try makeFile(in: dir, named: "notes.txt")

        let result = FileSystemDownloadsMonitor.partials(in: dir)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.lastPathComponent, "movie.mp4.download")
    }

    func test_partials_detectsChromeAndFirefoxAndGenericPartial() throws {
        let dir = try makeTempDir()
        try makeFile(in: dir, named: "a.crdownload")
        try makeFile(in: dir, named: "b.part")
        try makeFile(in: dir, named: "c.partial")
        try makeFile(in: dir, named: "done.zip")

        let result = FileSystemDownloadsMonitor.partials(in: dir)

        XCTAssertEqual(Set(result.map(\.lastPathComponent)), ["a.crdownload", "b.part", "c.partial"])
    }

    func test_partials_isCaseInsensitive() throws {
        let dir = try makeTempDir()
        try makeFile(in: dir, named: "FOO.DOWNLOAD")

        XCTAssertEqual(FileSystemDownloadsMonitor.partials(in: dir).count, 1)
    }

    func test_partials_returnsEmptyForMissingDirectory() {
        let url = URL(fileURLWithPath: "/tmp/cafeup-nonexistent-\(UUID().uuidString)")
        XCTAssertEqual(FileSystemDownloadsMonitor.partials(in: url), [])
    }

    private func makeTempDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cafeup-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeFile(in dir: URL, named name: String) throws {
        let url = dir.appendingPathComponent(name)
        try Data().write(to: url)
    }
}
