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
        UserDefaultsIconStylePreferenceStore(defaults: defaults).save(.flame)
        XCTAssertEqual(UserDefaultsIconStylePreferenceStore(defaults: defaults).load(), .flame)
    }

    func test_load_withRenamedStyle_mapsToTheNewOne() {
        // "boltDisc" shipped in 0.4.0, then became the Wave Ring.
        defaults.set("boltDisc", forKey: "com.pardhu.CafeUp.iconStyle.v1")
        let store = UserDefaultsIconStylePreferenceStore(defaults: defaults)
        XCTAssertEqual(store.load(), .waveRing)
    }

    /// Styles that were removed after release have no mapping: a saved one loads as the default.
    func test_load_withRemovedStyle_returnsDefault() {
        for removed in ["cupAndSaucer", "mug", "powerToggle", "owl", "hexagon", "pill", "dot", "dividedDisc"] {
            defaults.set(removed, forKey: "com.pardhu.CafeUp.iconStyle.v1")
            let store = UserDefaultsIconStylePreferenceStore(defaults: defaults)
            XCTAssertEqual(store.load(), .default, "\(removed)")
        }
    }

    func test_load_withCorruptValue_returnsDefault() {
        defaults.set("not-a-real-style", forKey: "com.pardhu.CafeUp.iconStyle.v1")
        let store = UserDefaultsIconStylePreferenceStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }
}
