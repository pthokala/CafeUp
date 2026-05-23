import XCTest
@testable import CafeUp

final class IconStylePreferenceStoreTests: XCTestCase {
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
        let store = UserDefaultsIconStylePreferenceStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }

    func test_saveAndLoad_roundtrips() {
        let store = UserDefaultsIconStylePreferenceStore(defaults: defaults)
        store.save(.bolt)
        XCTAssertEqual(store.load(), .bolt)
    }

    func test_persistence_acrossInstances() {
        UserDefaultsIconStylePreferenceStore(defaults: defaults).save(.eye)
        XCTAssertEqual(UserDefaultsIconStylePreferenceStore(defaults: defaults).load(), .eye)
    }

    func test_load_withCorruptValue_returnsDefault() {
        defaults.set("not-a-real-style", forKey: "com.pardhu.CafeUp.iconStyle.v1")
        let store = UserDefaultsIconStylePreferenceStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }
}
