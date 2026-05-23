import XCTest
@testable import CafeUp

final class SessionPresetTests: XCTestCase {

    func test_minutePresets_haveExpectedDurations() {
        XCTAssertEqual(
            SessionPreset.minutePresets.map(\.duration),
            [
                .seconds(5 * 60),
                .seconds(10 * 60),
                .seconds(15 * 60),
                .seconds(20 * 60),
                .seconds(30 * 60),
                .seconds(45 * 60)
            ]
        )
    }

    func test_hourPresets_haveExpectedDurations() {
        XCTAssertEqual(
            SessionPreset.hourPresets.map(\.duration),
            [
                .seconds(60 * 60),
                .seconds(2 * 60 * 60),
                .seconds(3 * 60 * 60),
                .seconds(4 * 60 * 60),
                .seconds(5 * 60 * 60),
                .seconds(6 * 60 * 60),
                .seconds(8 * 60 * 60),
                .seconds(12 * 60 * 60)
            ]
        )
    }

    func test_minutePresets_labelsAreUnique() {
        let labels = SessionPreset.minutePresets.map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count)
    }

    func test_hourPresets_labelsAreUnique() {
        let labels = SessionPreset.hourPresets.map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count)
    }

    func test_allPresets_haveUniqueIds() {
        let allIds = (SessionPreset.minutePresets + SessionPreset.hourPresets).map(\.id)
        XCTAssertEqual(Set(allIds).count, allIds.count)
    }

    func test_minutePresets_labelsHaveCorrectGrammar() {
        for preset in SessionPreset.minutePresets {
            XCTAssertTrue(preset.label.hasSuffix("Minutes"), "Expected plural \"Minutes\" suffix for \(preset.label)")
        }
    }

    func test_hourPresets_labelsHaveCorrectGrammar() {
        XCTAssertEqual(SessionPreset.hourPresets.first?.label, "1 Hour")
        XCTAssertEqual(SessionPreset.hourPresets.dropFirst().first?.label, "2 Hours")
    }
}
