import XCTest
@testable import CafeUp

final class PolicyUpdateTests: XCTestCase {

    func test_emptyUpdate_isEmptyTrue() {
        XCTAssertTrue(PolicyUpdate().isEmpty)
    }

    func test_anyFieldSet_isEmptyFalse() {
        XCTAssertFalse(PolicyUpdate(allowDisplaySleep: false).isEmpty)
        XCTAssertFalse(PolicyUpdate(allowSystemSleepWhenLidClosed: true).isEmpty)
        XCTAssertFalse(PolicyUpdate(allowScreenSaverAfter45Min: false).isEmpty)
    }

    func test_apply_emptyUpdateReturnsBaseUnchanged() {
        let base = WakePolicy(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: false,
            allowScreenSaverAfter45Min: true
        )
        XCTAssertEqual(PolicyUpdate().apply(to: base), base)
    }

    func test_apply_overridesOnlyNonNilFields() {
        let base = WakePolicy(
            allowDisplaySleep: false,
            allowSystemSleepWhenLidClosed: true,
            allowScreenSaverAfter45Min: false
        )
        let update = PolicyUpdate(allowDisplaySleep: true)
        let next = update.apply(to: base)
        XCTAssertTrue(next.allowDisplaySleep)
        XCTAssertEqual(next.allowSystemSleepWhenLidClosed, base.allowSystemSleepWhenLidClosed)
        XCTAssertEqual(next.allowScreenSaverAfter45Min, base.allowScreenSaverAfter45Min)
    }

    func test_apply_canSetEachFieldToFalse() {
        // Ensure that an explicit `false` override isn't confused with `nil`.
        let base = WakePolicy(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: true,
            allowScreenSaverAfter45Min: true
        )
        let update = PolicyUpdate(
            allowDisplaySleep: false,
            allowSystemSleepWhenLidClosed: false,
            allowScreenSaverAfter45Min: false
        )
        let next = update.apply(to: base)
        XCTAssertFalse(next.allowDisplaySleep)
        XCTAssertFalse(next.allowSystemSleepWhenLidClosed)
        XCTAssertFalse(next.allowScreenSaverAfter45Min)
    }
}
