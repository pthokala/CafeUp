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
        defaults.set(Data("garbage".utf8), forKey: storageKey)
        let store = makeStore()

        XCTAssertEqual(store.load(), [])
    }

    func test_load_withCorruptData_backsUpRawBytesBeforeAnySave() {
        let garbage = Data("garbage".utf8)
        defaults.set(garbage, forKey: storageKey)
        let store = makeStore()

        _ = store.load()
        store.save([Trigger(name: "New", conditions: [.onACPower])])

        XCTAssertEqual(defaults.data(forKey: UserDefaultsTriggerStore.unreadableBackupKey), garbage)
    }

    func test_load_withReadableData_writesNoBackup() {
        let store = makeStore()
        store.save([Trigger(name: "A", conditions: [.onACPower])])

        _ = store.load()

        XCTAssertNil(defaults.data(forKey: UserDefaultsTriggerStore.unreadableBackupKey))
    }

    func test_load_skipsUnreadableEntry_andKeepsTheRest() throws {
        let readable = Trigger(name: "Keep", conditions: [.onACPower])
        defaults.set(try payload([readable], appending: [Self.futureEntry]), forKey: storageKey)

        XCTAssertEqual(makeStore().load(), [readable])
    }

    func test_save_afterPartialLoad_writesUnreadableEntryBackUnchanged() throws {
        let readable = Trigger(name: "Keep", conditions: [.onACPower])
        defaults.set(try payload([readable], appending: [Self.futureEntry]), forKey: storageKey)
        let store = makeStore()
        _ = store.load()

        let added = Trigger(name: "New", conditions: [.appRunning(bundleIdentifier: "n")])
        store.save([readable, added])

        let stored = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: storageKey))) as? [Any]
        )
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(stored.last as? NSDictionary, Self.futureEntry as NSDictionary)
        XCTAssertEqual(makeStore().load(), [readable, added])
    }

    func test_save_emptyArray_persistsEmpty() {
        let store = UserDefaultsTriggerStore(defaults: defaults)
        store.save([Trigger(name: "X", conditions: [.appRunning(bundleIdentifier: "x")])])
        store.save([])

        XCTAssertEqual(store.load(), [])
    }

    // MARK: - Helpers

    private let storageKey = "com.pardhu.CafeUp.triggers.v1"

    /// A trigger as a newer build might write it: its condition case doesn't
    /// exist in this build, so it can't decode here.
    private static let futureEntry: [String: Any] = [
        "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
        "name": "Office Wi-Fi",
        "isEnabled": true,
        "conditions": [["wifiNetwork": ["ssid": "Office"]]],
        "policy": [
            "allowDisplaySleep": false,
            "allowSystemSleepWhenLidClosed": true,
            "allowScreenSaverAfter45Min": false
        ]
    ]

    private func makeStore() -> UserDefaultsTriggerStore {
        UserDefaultsTriggerStore(defaults: defaults, logger: SilentLogger())
    }

    private func payload(_ triggers: [Trigger], appending extra: [[String: Any]]) throws -> Data {
        let encoded = try JSONEncoder().encode(triggers)
        let array = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [Any])
        return try JSONSerialization.data(withJSONObject: array + extra)
    }
}
