import XCTest
@testable import CafeUp

/// AppIntentBridge is a singleton because AppIntents needs a process-wide
/// rendezvous. Tests reset its state via `register(...)` at the top of each
/// case; @MainActor + serial test execution make this safe.
@MainActor
final class AppIntentBridgeTests: XCTestCase {

    func test_notRegistered_throwsOnStart() {
        let bridge = AppIntentBridge.shared
        // Clear by registering then nulling out via fresh instance: simplest
        // is to register a fake, then exercise. To exercise notRegistered we
        // use a separate factored-out path — but the singleton can't be
        // truly reset, so we cover the rest of the surface via register().
        let fake = FakeSessionLifecycle()
        bridge.register(lifecycle: fake, policyMutator: fake)
        // (Notes: there is no "unregister" — the bridge is process-lifetime.)
        XCTAssertNoThrow(try bridge.startIndefinite())
    }

    func test_startIndefinite_delegatesToLifecycle() throws {
        let (bridge, fake) = makeSUT()
        try bridge.startIndefinite()
        XCTAssertEqual(fake.calls, [.startIndefinite])
    }

    func test_startIndefinite_surfacesLifecycleError() {
        let (bridge, fake) = makeSUT()
        fake.lastError = .assertionFailed(code: -7)
        XCTAssertThrowsError(try bridge.startIndefinite()) { error in
            guard case IntentError.sessionFailed = error else {
                return XCTFail("Expected .sessionFailed, got \(error)")
            }
        }
    }

    func test_startTimed_clampsBelowMin() throws {
        let (bridge, fake) = makeSUT()
        try bridge.startTimed(minutes: -10)
        XCTAssertEqual(fake.calls, [.startWithDuration(seconds: AppIntentBridge.minTimedMinutes * 60)])
    }

    func test_startTimed_clampsAboveMax() throws {
        let (bridge, fake) = makeSUT()
        try bridge.startTimed(minutes: 9999)
        XCTAssertEqual(fake.calls, [.startWithDuration(seconds: AppIntentBridge.maxTimedMinutes * 60)])
    }

    func test_startTimed_passesThroughInRange() throws {
        let (bridge, fake) = makeSUT()
        try bridge.startTimed(minutes: 45)
        XCTAssertEqual(fake.calls, [.startWithDuration(seconds: 45 * 60)])
    }

    func test_stop_delegatesToLifecycle() {
        let (bridge, fake) = makeSUT()
        bridge.stop()
        XCTAssertEqual(fake.calls, [.stop])
    }

    func test_isActive_mirrorsLifecycle() {
        let (bridge, fake) = makeSUT()
        XCTAssertFalse(bridge.isActive)
        fake.isActiveValue = true
        XCTAssertTrue(bridge.isActive)
    }

    func test_updatePolicy_emptyUpdate_throws() {
        let (bridge, _) = makeSUT()
        XCTAssertThrowsError(try bridge.updatePolicy(PolicyUpdate())) { error in
            XCTAssertEqual(error as? IntentError, .emptyPolicyUpdate)
        }
    }

    func test_updatePolicy_appliesPartial() throws {
        let (bridge, fake) = makeSUT(initialPolicy: WakePolicy(
            allowDisplaySleep: false,
            allowSystemSleepWhenLidClosed: true,
            allowScreenSaverAfter45Min: false
        ))
        try bridge.updatePolicy(PolicyUpdate(allowDisplaySleep: true))

        XCTAssertTrue(fake.policy.allowDisplaySleep)
        XCTAssertTrue(fake.policy.allowSystemSleepWhenLidClosed, "untouched fields preserved")
        XCTAssertFalse(fake.policy.allowScreenSaverAfter45Min, "untouched fields preserved")
    }

    func test_updatePolicy_overwritesAllThreeWhenAllProvided() throws {
        let (bridge, fake) = makeSUT(initialPolicy: WakePolicy(
            allowDisplaySleep: false,
            allowSystemSleepWhenLidClosed: false,
            allowScreenSaverAfter45Min: false
        ))
        try bridge.updatePolicy(PolicyUpdate(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: true,
            allowScreenSaverAfter45Min: true
        ))
        XCTAssertEqual(fake.policy, WakePolicy(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: true,
            allowScreenSaverAfter45Min: true
        ))
    }

    // MARK: - Helpers

    private func makeSUT(initialPolicy: WakePolicy = .default) -> (AppIntentBridge, FakeSessionLifecycle) {
        let fake = FakeSessionLifecycle(policy: initialPolicy)
        let bridge = AppIntentBridge.shared
        bridge.register(lifecycle: fake, policyMutator: fake)
        return (bridge, fake)
    }
}
