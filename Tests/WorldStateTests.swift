import XCTest
@testable import CafeUp

final class WorldStateTests: XCTestCase {
    func test_empty_hasNoApps() {
        XCTAssertTrue(WorldState.empty.runningAppBundleIds.isEmpty)
    }

    func test_equality_dependsOnRunningApps() {
        XCTAssertEqual(
            WorldState(runningAppBundleIds: ["a", "b"]),
            WorldState(runningAppBundleIds: ["a", "b"])
        )
        XCTAssertNotEqual(
            WorldState(runningAppBundleIds: ["a"]),
            WorldState(runningAppBundleIds: ["a", "b"])
        )
    }
}
