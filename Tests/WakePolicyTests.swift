import XCTest
@testable import CafeUp

final class WakePolicyTests: XCTestCase {

    // MARK: - Defaults

    func test_default_matchesAmphetamine() {
        let policy = WakePolicy.default
        XCTAssertFalse(policy.allowDisplaySleep)
        XCTAssertTrue(policy.allowSystemSleepWhenLidClosed)
        XCTAssertFalse(policy.allowScreenSaverAfter45Min)
    }

    func test_legacySystemOnly_allowsDisplaySleep() {
        XCTAssertTrue(WakePolicy.systemOnly.allowDisplaySleep)
    }

    func test_legacySystemAndDisplay_keepsDisplayOn() {
        XCTAssertFalse(WakePolicy.systemAndDisplay.allowDisplaySleep)
    }

    // MARK: - effective(idleSeconds:)

    func test_effective_returnsSelf_whenScreenSaverDisabled() {
        let policy = WakePolicy(allowDisplaySleep: false, allowScreenSaverAfter45Min: false)
        let effective = policy.effective(idleSeconds: 60 * 60)
        XCTAssertEqual(effective, policy)
    }

    func test_effective_returnsSelf_whenBelowThreshold() {
        let policy = WakePolicy(allowDisplaySleep: false, allowScreenSaverAfter45Min: true)
        let effective = policy.effective(idleSeconds: 44 * 60)
        XCTAssertFalse(effective.allowDisplaySleep)
    }

    func test_effective_releasesDisplay_atThreshold() {
        let policy = WakePolicy(allowDisplaySleep: false, allowScreenSaverAfter45Min: true)
        let effective = policy.effective(idleSeconds: 45 * 60)
        XCTAssertTrue(effective.allowDisplaySleep)
    }

    func test_effective_releasesDisplay_pastThreshold() {
        let policy = WakePolicy(allowDisplaySleep: false, allowScreenSaverAfter45Min: true)
        let effective = policy.effective(idleSeconds: 3 * 60 * 60)
        XCTAssertTrue(effective.allowDisplaySleep)
    }

    // MARK: - Codable migration

    func test_decode_fromLegacyString_systemOnly() throws {
        let json = #""systemOnly""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WakePolicy.self, from: json)
        XCTAssertEqual(decoded, WakePolicy.systemOnly)
    }

    func test_decode_fromLegacyString_systemAndDisplay() throws {
        let json = #""systemAndDisplay""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WakePolicy.self, from: json)
        XCTAssertEqual(decoded, WakePolicy.systemAndDisplay)
    }

    func test_decode_fromLegacyUnknown_fallsBackToDefault() throws {
        let json = #""bogus""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WakePolicy.self, from: json)
        XCTAssertEqual(decoded, WakePolicy.default)
    }

    func test_roundTrip_newFormat() throws {
        let original = WakePolicy(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: false,
            allowScreenSaverAfter45Min: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WakePolicy.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_decode_missingKeys_usesDefaults() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WakePolicy.self, from: json)
        XCTAssertFalse(decoded.allowDisplaySleep)
        XCTAssertTrue(decoded.allowSystemSleepWhenLidClosed)
        XCTAssertFalse(decoded.allowScreenSaverAfter45Min)
    }
}
