import XCTest
@testable import CafeUp

final class TriggerEvaluationTests: XCTestCase {

    // MARK: Trigger

    func test_disabledTrigger_isNeverSatisfied() {
        let trigger = Trigger(
            name: "FCP",
            isEnabled: false,
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")]
        )
        let state = WorldState(runningAppBundleIds: ["com.apple.FinalCut"])
        XCTAssertFalse(trigger.isSatisfied(by: state))
    }

    func test_emptyConditions_isNeverSatisfied() {
        let trigger = Trigger(name: "Empty", conditions: [])
        XCTAssertFalse(trigger.isSatisfied(by: .empty))
    }

    func test_singleCondition_matchesRunningApp() {
        let trigger = Trigger(
            name: "FCP",
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")]
        )
        let running = WorldState(runningAppBundleIds: ["com.apple.FinalCut", "com.apple.Safari"])
        let absent = WorldState(runningAppBundleIds: ["com.apple.Safari"])

        XCTAssertTrue(trigger.isSatisfied(by: running))
        XCTAssertFalse(trigger.isSatisfied(by: absent))
    }

    func test_multipleConditions_requireAll() {
        let trigger = Trigger(
            name: "FCP + Safari",
            conditions: [
                .appRunning(bundleIdentifier: "com.apple.FinalCut"),
                .appRunning(bundleIdentifier: "com.apple.Safari")
            ]
        )
        XCTAssertTrue(trigger.isSatisfied(
            by: WorldState(runningAppBundleIds: ["com.apple.FinalCut", "com.apple.Safari"])
        ))
        XCTAssertFalse(trigger.isSatisfied(
            by: WorldState(runningAppBundleIds: ["com.apple.FinalCut"])
        ))
        XCTAssertFalse(trigger.isSatisfied(
            by: WorldState(runningAppBundleIds: ["com.apple.Safari"])
        ))
        XCTAssertFalse(trigger.isSatisfied(by: .empty))
    }

    func test_trigger_isSatisfied_withDuplicateConditions_stillSatisfiedIfMet() {
        let trigger = Trigger(
            name: "FCP twice",
            conditions: [
                .appRunning(bundleIdentifier: "com.apple.FinalCut"),
                .appRunning(bundleIdentifier: "com.apple.FinalCut")
            ]
        )
        XCTAssertTrue(trigger.isSatisfied(
            by: WorldState(runningAppBundleIds: ["com.apple.FinalCut"])
        ))
    }

    // MARK: TriggerCondition

    func test_appRunningCondition_caseSensitiveMatching() {
        let condition = TriggerCondition.appRunning(bundleIdentifier: "com.apple.FinalCut")

        XCTAssertTrue(condition.isSatisfied(by: WorldState(runningAppBundleIds: ["com.apple.FinalCut"])))
        XCTAssertFalse(condition.isSatisfied(by: WorldState(runningAppBundleIds: ["com.apple.finalcut"])))
    }

    func test_appRunningCondition_emptyBundleId_neverMatches() {
        let condition = TriggerCondition.appRunning(bundleIdentifier: "")

        XCTAssertFalse(condition.isSatisfied(by: WorldState(runningAppBundleIds: ["x"])))
        XCTAssertFalse(condition.isSatisfied(by: .empty))
    }

    func test_appRunningCondition_codableRoundtrip() throws {
        let original = TriggerCondition.appRunning(bundleIdentifier: "com.apple.FinalCut")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TriggerCondition.self, from: data)

        XCTAssertEqual(original, decoded)
    }
}
