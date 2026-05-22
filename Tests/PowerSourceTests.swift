import XCTest
@testable import CafeUp

final class PowerSourceTests: XCTestCase {
    func test_unknown_assumesACWithNoBattery() {
        XCTAssertEqual(PowerSource.unknown.isOnACPower, true)
        XCTAssertNil(PowerSource.unknown.batteryPercentage)
    }

    func test_codableRoundtrip() throws {
        let original = PowerSource(isOnACPower: false, batteryPercentage: 73)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PowerSource.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_codableRoundtrip_withNilBattery() throws {
        let original = PowerSource(isOnACPower: true, batteryPercentage: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PowerSource.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
