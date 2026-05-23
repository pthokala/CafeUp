import XCTest
@testable import CafeUp

final class MenuBarIconStyleTests: XCTestCase {

    func test_allCases_haveDistinctActiveRendering() {
        let active = MenuBarIconStyle.allCases.map { $0.rendering(isActive: true) }
        XCTAssertEqual(Set(active).count, MenuBarIconStyle.allCases.count)
    }

    func test_allCases_haveDistinctIdleRendering() {
        let idle = MenuBarIconStyle.allCases.map { $0.rendering(isActive: false) }
        XCTAssertEqual(Set(idle).count, MenuBarIconStyle.allCases.count)
    }

    func test_activeAndIdle_differForEveryStyle() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertNotEqual(
                style.rendering(isActive: true),
                style.rendering(isActive: false),
                "\(style) should distinguish active from idle"
            )
        }
    }

    func test_displayName_isNonEmpty() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertFalse(style.displayName.isEmpty, "\(style) missing display name")
        }
    }

    func test_default_isCupAndSaucer() {
        XCTAssertEqual(MenuBarIconStyle.default, .cupAndSaucer)
    }

    func test_codableRoundtrip() throws {
        for style in MenuBarIconStyle.allCases {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(MenuBarIconStyle.self, from: data)
            XCTAssertEqual(style, decoded)
        }
    }

    func test_dividedCircle_activeUsesVerticalIdleUsesHorizontal() {
        XCTAssertEqual(
            MenuBarIconStyle.dividedCircle.rendering(isActive: true),
            .dividedCircle(orientation: .vertical)
        )
        XCTAssertEqual(
            MenuBarIconStyle.dividedCircle.rendering(isActive: false),
            .dividedCircle(orientation: .horizontal)
        )
    }

    func test_coffeeBean_activeFilledIdleOutlined() {
        XCTAssertEqual(
            MenuBarIconStyle.coffeeBean.rendering(isActive: true),
            .coffeeBean(isFilled: true)
        )
        XCTAssertEqual(
            MenuBarIconStyle.coffeeBean.rendering(isActive: false),
            .coffeeBean(isFilled: false)
        )
    }

    func test_dot_activeFilledIdleHollow() {
        XCTAssertEqual(
            MenuBarIconStyle.dot.rendering(isActive: true),
            .solidCircle(isFilled: true)
        )
        XCTAssertEqual(
            MenuBarIconStyle.dot.rendering(isActive: false),
            .solidCircle(isFilled: false)
        )
    }

    func test_dividedDisc_activeUsesVerticalIdleUsesHorizontal() {
        XCTAssertEqual(
            MenuBarIconStyle.dividedDisc.rendering(isActive: true),
            .dividedDisc(orientation: .vertical)
        )
        XCTAssertEqual(
            MenuBarIconStyle.dividedDisc.rendering(isActive: false),
            .dividedDisc(orientation: .horizontal)
        )
    }

    func test_sfSymbolStyles_returnSymbolRendering() {
        if case .symbol = MenuBarIconStyle.circle.rendering(isActive: true) {
            // expected
        } else {
            XCTFail("Circle style should use SF Symbol rendering")
        }
    }
}
