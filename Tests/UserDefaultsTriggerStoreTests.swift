import XCTest
@testable import CafeUp

final class UserDefaultsTriggerStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.pardhu.CafeUp.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_load_whenEmpty_returnsEmptyArray() {
        let store = UserDefaultsTriggerStore(defaults: defaults)
        XCTAssertEqual(store.load(), [])
    }

    func test_saveAndLoad_roundtripsTriggers() {
        let store = UserDefaultsTriggerStore(defaults: defaults)
        let triggers = [
            Trigger(name: "A", conditions: [.appRunning(bundleIdentifier: "a")]),
            Trigger(name: "B", isEnabled: false, conditions: [.appRunning(bundleIdentifier: "b")], policy: .systemOnly)
        ]

        store.save(triggers)

        XCTAssertEqual(store.load(), triggers)
    }

    func test_persistence_acrossInstances() {
        let triggers = [Trigger(name: "X", conditions: [.appRunning(bundleIdentifier: "x")])]
        let writer = UserDefaultsTriggerStore(defaults: defaults)
        writer.save(triggers)

        let reader = UserDefaultsTriggerStore(defaults: defaults)
        XCTAssertEqual(reader.load(), triggers)
    }

    func test_save_overwritesPreviousData() {
        let store = UserDefaultsTriggerStore(defaults: defaults)
        store.save([Trigger(name: "Old", conditions: [.appRunning(bundleIdentifier: "o")])])

        let newTriggers = [Trigger(name: "New", conditions: [.appRunning(bundleIdentifier: "n")])]
        store.save(newTriggers)

        XCTAssertEqual(store.load(), newTriggers)
    }

    func test_load_withCorruptData_returnsEmpty() {
        defaults.set(Data("garbage".utf8), forKey: "com.pardhu.CafeUp.triggers.v1")
        let store = UserDefaultsTriggerStore(defaults: defaults)

        XCTAssertEqual(store.load(), [])
    }

    func test_save_emptyArray_persistsEmpty() {
        let store = UserDefaultsTriggerStore(defaults: defaults)
        store.save([Trigger(name: "X", conditions: [.appRunning(bundleIdentifier: "x")])])
        store.save([])

        XCTAssertEqual(store.load(), [])
    }
}
