import XCTest
@testable import CafeUp

final class WakePolicyStoreTests: XCTestCase {
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

    func test_load_whenEmpty_returnsDefault() {
        let store = UserDefaultsWakePolicyStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }

    func test_saveAndLoad_roundtrips() {
        let store = UserDefaultsWakePolicyStore(defaults: defaults)
        let policy = WakePolicy(
            allowDisplaySleep: true,
            allowSystemSleepWhenLidClosed: false,
            allowScreenSaverAfter45Min: true
        )

        store.save(policy)

        XCTAssertEqual(store.load(), policy)
    }

    func test_persistence_acrossInstances() {
        let policy = WakePolicy(allowSystemSleepWhenLidClosed: false)
        UserDefaultsWakePolicyStore(defaults: defaults).save(policy)
        XCTAssertEqual(UserDefaultsWakePolicyStore(defaults: defaults).load(), policy)
    }

    func test_save_overwritesPreviousValue() {
        let store = UserDefaultsWakePolicyStore(defaults: defaults)
        store.save(WakePolicy(allowSystemSleepWhenLidClosed: false))
        store.save(.default)
        XCTAssertEqual(store.load(), .default)
    }

    func test_load_withCorruptData_returnsDefault() {
        defaults.set(Data("not json".utf8), forKey: "com.pardhu.CafeUp.wakePolicy.v1")
        let store = UserDefaultsWakePolicyStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }
}
