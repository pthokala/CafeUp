import XCTest
@testable import CafeUp

final class WorldStateTests: XCTestCase {
    func test_empty_hasDefaults() {
        XCTAssertTrue(WorldState.empty.runningAppBundleIds.isEmpty)
        XCTAssertEqual(WorldState.empty.powerSource, .unknown)
        XCTAssertEqual(WorldState.empty.currentDate, .distantPast)
    }

    func test_equality_dependsOnAllFields() {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        let lhs = WorldState(
            runningAppBundleIds: ["a"],
            currentDate: baseDate,
            powerSource: PowerSource(isOnACPower: true, batteryPercentage: 90)
        )
        let rhs = WorldState(
            runningAppBundleIds: ["a"],
            currentDate: baseDate,
            powerSource: PowerSource(isOnACPower: true, batteryPercentage: 90)
        )
        XCTAssertEqual(lhs, rhs)

        var different = rhs
        different.powerSource.batteryPercentage = 89
        XCTAssertNotEqual(lhs, different)

        var differentDate = rhs
        differentDate.currentDate = baseDate.addingTimeInterval(1)
        XCTAssertNotEqual(lhs, differentDate)

        var differentApps = rhs
        differentApps.runningAppBundleIds = ["b"]
        XCTAssertNotEqual(lhs, differentApps)
    }
}
