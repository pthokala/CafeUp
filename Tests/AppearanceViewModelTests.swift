import XCTest
@testable import CafeUp

@MainActor
final class AppearanceViewModelTests: XCTestCase {

    func test_init_loadsFromStore() {
        let store = InMemoryIconStyleStore(initial: .bolt)
        let vm = AppearanceViewModel(store: store)
        XCTAssertEqual(vm.iconStyle, .bolt)
    }

    func test_settingStyle_persistsToStore() {
        let store = InMemoryIconStyleStore()
        let vm = AppearanceViewModel(store: store)

        vm.iconStyle = .flame

        XCTAssertEqual(store.load(), .flame)
        XCTAssertEqual(store.saveCount, 1)
    }

    func test_settingSameStyle_isNoOp() {
        let store = InMemoryIconStyleStore(initial: .mug)
        let vm = AppearanceViewModel(store: store)

        vm.iconStyle = .mug

        XCTAssertEqual(store.saveCount, 0)
    }

    func test_multipleChanges_persistEachDistinctValue() {
        let store = InMemoryIconStyleStore()
        let vm = AppearanceViewModel(store: store)

        vm.iconStyle = .sun
        vm.iconStyle = .bolt
        vm.iconStyle = .sun

        XCTAssertEqual(store.load(), .sun)
        XCTAssertEqual(store.saveCount, 3)
    }
}
