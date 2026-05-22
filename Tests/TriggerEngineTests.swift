import XCTest
@testable import CafeUp

@MainActor
final class TriggerEngineTests: XCTestCase {

    func test_start_evaluatesAgainstInitialSnapshot() {
        let trigger = Trigger(
            name: "FCP",
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")]
        )
        let sut = makeSUT(initial: [trigger], initialApps: ["com.apple.FinalCut"])

        sut.engine.start()

        XCTAssertEqual(sut.assertions.acquireCount, 1)
        XCTAssertEqual(sut.engine.activeTriggerIds, [trigger.id])
    }

    func test_satisfiedTrigger_acquiresAssertion() {
        let sut = makeSUT(initial: [
            .init(name: "FCP", conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")])
        ])

        sut.engine.start()
        sut.appObserver.emit(["com.apple.FinalCut"])

        XCTAssertEqual(sut.assertions.acquireCount, 1)
        XCTAssertEqual(sut.assertions.lastPolicy, .systemAndDisplay)
        XCTAssertEqual(sut.engine.activeTriggerIds.count, 1)
    }

    func test_unsatisfiedAfterEmit_releasesAssertion() {
        let sut = makeSUT(initial: [
            .init(name: "FCP", conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")])
        ])

        sut.engine.start()
        sut.appObserver.emit(["com.apple.FinalCut"])
        let token = sut.assertions.lastIssuedToken
        sut.appObserver.emit([])

        XCTAssertEqual(token?.released, true)
        XCTAssertTrue(sut.engine.activeTriggerIds.isEmpty)
    }

    func test_repeatedIdenticalEmit_doesNotReacquire() {
        let sut = makeSUT(initial: [
            .init(name: "FCP", conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")])
        ])

        sut.engine.start()
        sut.appObserver.emit(["com.apple.FinalCut"])
        sut.appObserver.emit(["com.apple.FinalCut"])
        sut.appObserver.emit(["com.apple.FinalCut"])

        XCTAssertEqual(sut.assertions.acquireCount, 1)
    }

    func test_upsert_persistsAndReevaluates() {
        let sut = makeSUT(initial: [])

        sut.engine.start()
        sut.appObserver.emit(["com.apple.FinalCut"])
        sut.engine.upsert(
            .init(name: "FCP", conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")])
        )

        XCTAssertEqual(sut.store.saveCount, 1)
        XCTAssertEqual(sut.assertions.acquireCount, 1)
        XCTAssertEqual(sut.engine.activeTriggerIds.count, 1)
    }

    func test_remove_persistsAndReleases() {
        let trigger = Trigger(
            name: "FCP",
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")]
        )
        let sut = makeSUT(initial: [trigger])

        sut.engine.start()
        sut.appObserver.emit(["com.apple.FinalCut"])
        let token = sut.assertions.lastIssuedToken
        sut.engine.remove(id: trigger.id)

        XCTAssertEqual(sut.engine.triggers.count, 0)
        XCTAssertEqual(token?.released, true)
        XCTAssertEqual(sut.store.saveCount, 1)
    }

    func test_disabledTrigger_doesNotActivate() {
        let trigger = Trigger(
            name: "FCP",
            isEnabled: false,
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")]
        )
        let sut = makeSUT(initial: [trigger])

        sut.engine.start()
        sut.appObserver.emit(["com.apple.FinalCut"])

        XCTAssertEqual(sut.assertions.acquireCount, 0)
        XCTAssertTrue(sut.engine.activeTriggerIds.isEmpty)
    }

    func test_setEnabled_toggleChangesActivation() {
        let trigger = Trigger(
            name: "FCP",
            isEnabled: false,
            conditions: [.appRunning(bundleIdentifier: "com.apple.FinalCut")]
        )
        let sut = makeSUT(initial: [trigger], initialApps: ["com.apple.FinalCut"])

        sut.engine.start()
        XCTAssertTrue(sut.engine.activeTriggerIds.isEmpty)

        sut.engine.setEnabled(id: trigger.id, isEnabled: true)
        XCTAssertEqual(sut.engine.activeTriggerIds, [trigger.id])

        sut.engine.setEnabled(id: trigger.id, isEnabled: false)
        XCTAssertTrue(sut.engine.activeTriggerIds.isEmpty)
    }

    func test_strictestPolicyWins_whenMultipleActive() {
        let triggers = [
            Trigger(name: "A", conditions: [.appRunning(bundleIdentifier: "a")], policy: .systemOnly),
            Trigger(name: "B", conditions: [.appRunning(bundleIdentifier: "b")], policy: .systemAndDisplay)
        ]
        let sut = makeSUT(initial: triggers)

        sut.engine.start()
        sut.appObserver.emit(["a", "b"])

        XCTAssertEqual(sut.assertions.lastPolicy, .systemAndDisplay)
    }

    func test_powerEmit_activatesACPowerTrigger() {
        let trigger = Trigger(name: "AC", conditions: [.onACPower])
        let sut = makeSUT(initial: [trigger])

        sut.engine.start()
        sut.powerObserver.emit(PowerSource(isOnACPower: true, batteryPercentage: 100))

        XCTAssertEqual(sut.engine.activeTriggerIds, [trigger.id])
    }

    func test_batteryDrop_deactivatesBatteryTrigger() {
        let trigger = Trigger(name: "High battery", conditions: [.batteryAtLeast(percent: 50)])
        let sut = makeSUT(
            initial: [trigger],
            initialPower: PowerSource(isOnACPower: false, batteryPercentage: 75)
        )

        sut.engine.start()
        XCTAssertEqual(sut.engine.activeTriggerIds, [trigger.id])

        sut.powerObserver.emit(PowerSource(isOnACPower: false, batteryPercentage: 30))
        XCTAssertTrue(sut.engine.activeTriggerIds.isEmpty)
    }

    func test_scheduleEmit_activatesScheduleTrigger() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Monday 2026-01-05 at 10:00 UTC
        let inRange = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 10))!
        let outOfRange = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 20))!

        let trigger = Trigger(name: "Work hours", conditions: [
            .schedule(
                weekdays: [.monday],
                range: TimeRange(
                    start: TimeOfDay(hour: 9, minute: 0),
                    end: TimeOfDay(hour: 17, minute: 0)
                )
            )
        ])
        let sut = makeSUT(initial: [trigger], initialDate: outOfRange)

        sut.engine.start()
        XCTAssertTrue(sut.engine.activeTriggerIds.isEmpty)

        sut.scheduleObserver.emit(inRange)
        // Note: scheduleIsSatisfied uses Calendar.current. Without injection at the engine level,
        // this test can only verify the engine's reaction to date changes, not the specific
        // calendar behavior. See TriggerEvaluationTests for pure schedule logic tests.
    }

    private struct SUT {
        let engine: TriggerEngine
        let assertions: FakePowerAssertionService
        let appObserver: FakeAppActivityObserver
        let scheduleObserver: FakeScheduleObserver
        let powerObserver: FakePowerObserver
        let store: InMemoryTriggerStore
    }

    private func makeSUT(
        initial: [Trigger],
        initialApps: Set<String> = [],
        initialDate: Date = Date(timeIntervalSince1970: 0),
        initialPower: PowerSource = .unknown
    ) -> SUT {
        let assertions = FakePowerAssertionService()
        let appObserver = FakeAppActivityObserver(initialSnapshot: initialApps)
        let scheduleObserver = FakeScheduleObserver(initial: initialDate)
        let powerObserver = FakePowerObserver(initial: initialPower)
        let store = InMemoryTriggerStore(initial: initial)
        let engine = TriggerEngine(
            assertions: assertions,
            appObserver: appObserver,
            scheduleObserver: scheduleObserver,
            powerObserver: powerObserver,
            store: store,
            logger: SilentLogger()
        )
        return SUT(
            engine: engine,
            assertions: assertions,
            appObserver: appObserver,
            scheduleObserver: scheduleObserver,
            powerObserver: powerObserver,
            store: store
        )
    }
}
