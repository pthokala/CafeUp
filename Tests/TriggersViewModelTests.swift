import XCTest
@testable import CafeUp

@MainActor
final class TriggersViewModelTests: XCTestCase {

    func test_triggers_passesEngineList() {
        let trigger = Trigger(name: "FCP", conditions: [.appRunning(bundleIdentifier: "x")])
        let sut = makeSUT(persisted: [trigger])

        XCTAssertEqual(sut.viewModel.triggers, [trigger])
    }

    func test_activeTriggerIds_passesEngineSet() {
        let trigger = Trigger(name: "FCP", conditions: [.appRunning(bundleIdentifier: "x")])
        let sut = makeSUT(persisted: [trigger], initialSnapshot: ["x"])
        sut.engine.start()

        XCTAssertEqual(sut.viewModel.activeTriggerIds, [trigger.id])
    }

    func test_save_addsNewTriggerViaEngine() {
        let sut = makeSUT(persisted: [])
        let newTrigger = Trigger(name: "FCP", conditions: [.appRunning(bundleIdentifier: "x")])

        sut.viewModel.save(newTrigger)

        XCTAssertEqual(sut.viewModel.triggers, [newTrigger])
        XCTAssertEqual(sut.store.saveCount, 1)
    }

    func test_save_updatesExistingTrigger() {
        let original = Trigger(name: "FCP", conditions: [.appRunning(bundleIdentifier: "x")])
        let sut = makeSUT(persisted: [original])
        var updated = original
        updated.name = "Updated"

        sut.viewModel.save(updated)

        XCTAssertEqual(sut.viewModel.triggers.count, 1)
        XCTAssertEqual(sut.viewModel.triggers.first?.name, "Updated")
    }

    func test_remove_deletesTriggerViaEngine() {
        let trigger = Trigger(name: "FCP", conditions: [.appRunning(bundleIdentifier: "x")])
        let sut = makeSUT(persisted: [trigger])

        sut.viewModel.remove(triggerId: trigger.id)

        XCTAssertTrue(sut.viewModel.triggers.isEmpty)
    }

    func test_toggle_setsEnabledViaEngine() {
        let trigger = Trigger(
            name: "FCP",
            isEnabled: true,
            conditions: [.appRunning(bundleIdentifier: "x")]
        )
        let sut = makeSUT(persisted: [trigger])

        sut.viewModel.toggle(triggerId: trigger.id, isEnabled: false)

        XCTAssertEqual(sut.viewModel.triggers.first?.isEnabled, false)
    }

    func test_pickApplication_delegatesToPicker() {
        let sut = makeSUT(persisted: [])
        let picked = PickedApplication(displayName: "Final Cut", bundleIdentifier: "com.apple.FinalCut")
        sut.picker.nextResult = picked

        let result = sut.viewModel.pickApplication()

        XCTAssertEqual(result, picked)
        XCTAssertEqual(sut.picker.callCount, 1)
    }

    func test_pickApplication_returnsNilWhenCancelled() {
        let sut = makeSUT(persisted: [])
        sut.picker.nextResult = nil

        XCTAssertNil(sut.viewModel.pickApplication())
        XCTAssertEqual(sut.picker.callCount, 1)
    }

    private struct SUT {
        let viewModel: TriggersViewModel
        let engine: TriggerEngine
        let store: InMemoryTriggerStore
        let picker: FakeAppPicker
    }

    private func makeSUT(persisted: [Trigger], initialSnapshot: Set<String> = []) -> SUT {
        let store = InMemoryTriggerStore(initial: persisted)
        let engine = TriggerEngine(
            assertions: FakePowerAssertionService(),
            appObserver: FakeAppActivityObserver(initialSnapshot: initialSnapshot),
            scheduleObserver: FakeScheduleObserver(),
            powerObserver: FakePowerObserver(),
            store: store,
            logger: SilentLogger()
        )
        let picker = FakeAppPicker()
        let viewModel = TriggersViewModel(engine: engine, appPicker: picker)
        return SUT(viewModel: viewModel, engine: engine, store: store, picker: picker)
    }
}
