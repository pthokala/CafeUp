import XCTest
@testable import CafeUp

final class SessionPresetTests: XCTestCase {
    func test_standard_containsExpectedDurations() {
        let durations = SessionPreset.standard.map(\.duration)

        XCTAssertEqual(durations, [
            .seconds(5 * 60),
            .seconds(15 * 60),
            .seconds(30 * 60),
            .seconds(60 * 60),
            .seconds(2 * 60 * 60),
            .seconds(5 * 60 * 60)
        ])
    }

    func test_standard_labelsAreUnique() {
        let labels = SessionPreset.standard.map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count)
    }

    func test_standard_idsAreUnique() {
        let ids = SessionPreset.standard.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
