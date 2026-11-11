import XCTest
@testable import CafeUp

final class SessionPresetTests: XCTestCase {

    func test_minutePresets_areEveryFiveMinutesUpTo55() {
        XCTAssertEqual(
            SessionPreset.minutePresets.map(\.duration),
            stride(from: 5, through: 55, by: 5).map { .seconds($0 * 60) }
        )
    }

    func test_minutePresetGroups_pairUpAfterTheFirst() {
        XCTAssertEqual(SessionPreset.minutePresetGroups.map(\.count), [1, 2, 2, 2, 2, 2])
    }

    func test_hourPresets_haveExpectedDurations() {
        XCTAssertEqual(
            SessionPreset.hourPresets.map(\.duration),
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 24].map { .seconds($0 * 60 * 60) }
        )
    }

    func test_hourPresetGroups_splitAfterNineHours() {
        XCTAssertEqual(SessionPreset.hourPresetGroups.map(\.count), [9, 3])
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
            XCTAssertTrue(preset.label.hasSuffix(" minutes"), "Expected plural \"minutes\" suffix for \(preset.label)")
        }
    }

    func test_hourPresets_labelsHaveCorrectGrammar() {
        XCTAssertEqual(SessionPreset.hourPresets.first?.label, "1 hour")
        XCTAssertEqual(SessionPreset.hourPresets.dropFirst().first?.label, "2 hours")
    }
}
