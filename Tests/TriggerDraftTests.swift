import XCTest
@testable import CafeUp

final class TriggerDraftTests: XCTestCase {

    func test_emptyInit_hasBlankFields() {
        let draft = TriggerDraft()

        XCTAssertEqual(draft.name, "")
        XCTAssertTrue(draft.conditions.isEmpty)
        XCTAssertEqual(draft.policy, .systemAndDisplay)
        XCTAssertTrue(draft.isEnabled)
    }

    func test_initFromTrigger_preservesAllFields() {
        let trigger = Trigger(
            name: "FCP",
            isEnabled: false,
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")],
            policy: .systemOnly
        )

        let draft = TriggerDraft(from: trigger)

        XCTAssertEqual(draft.id, trigger.id)
        XCTAssertEqual(draft.name, "FCP")
        XCTAssertEqual(draft.isEnabled, false)
        XCTAssertEqual(draft.policy, .systemOnly)
        XCTAssertEqual(draft.conditions, [.appRunning(bundleIdentifier: "com.apple.FinalCut")])
    }

    func test_isValid_falseWhenNameBlank() {
        var draft = TriggerDraft()
        draft.conditions = [.appRunning(bundleIdentifier: "x")]
        draft.name = ""

        XCTAssertFalse(draft.isValid)
    }

    func test_isValid_falseWhenNameOnlyWhitespace() {
        var draft = TriggerDraft()
        draft.conditions = [.appRunning(bundleIdentifier: "x")]
        draft.name = "   \n\t  "

        XCTAssertFalse(draft.isValid)
    }

    func test_isValid_falseWhenConditionsEmpty() {
        var draft = TriggerDraft()
        draft.name = "Anything"

        XCTAssertFalse(draft.isValid)
    }

    func test_isValid_trueWithNameAndConditions() {
        var draft = TriggerDraft()
        draft.name = "Anything"
        draft.conditions = [.appRunning(bundleIdentifier: "x")]

        XCTAssertTrue(draft.isValid)
    }

    func test_toTrigger_preservesAllFields() {
        var draft = TriggerDraft()
        draft.name = "Test"
        draft.isEnabled = false
        draft.conditions = [.appRunning(bundleIdentifier: "x")]
        draft.policy = .systemOnly

        let trigger = draft.toTrigger()

        XCTAssertEqual(trigger.id, draft.id)
        XCTAssertEqual(trigger.name, "Test")
        XCTAssertEqual(trigger.isEnabled, false)
        XCTAssertEqual(trigger.policy, .systemOnly)
        XCTAssertEqual(trigger.conditions, [.appRunning(bundleIdentifier: "x")])
    }

    func test_roundtrip_preservesIdentity() {
        let original = Trigger(
            name: "Original",
            conditions: [.appRunning(bundleIdentifier: "a")]
        )

        let recovered = TriggerDraft(from: original).toTrigger()

        XCTAssertEqual(original, recovered)
    }
}
