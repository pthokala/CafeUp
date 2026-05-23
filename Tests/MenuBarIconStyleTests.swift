import XCTest
@testable import CafeUp

final class MenuBarIconStyleTests: XCTestCase {

    /// A style is uniquely identified by its (idle, active) pair — not by either state
    /// in isolation. Asymmetric styles like `battery` legitimately share visual elements
    /// with other styles while remaining distinct as a pair. What must NOT happen is two
    /// styles producing identical pairs, which would make them indistinguishable in the
    /// picker.
    func test_allCases_haveDistinctIdleActivePairs() {
        struct Pair: Hashable { let idle: IconRendering; let active: IconRendering }
        let pairs = MenuBarIconStyle.allCases.map {
            Pair(idle: $0.rendering(isActive: false), active: $0.rendering(isActive: true))
        }
        XCTAssertEqual(Set(pairs).count, MenuBarIconStyle.allCases.count)
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

    // MARK: - Custom shape glyphs

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

    // MARK: - SF Symbol pairs — outline → fill

    func test_sfSymbolStyles_returnSymbolRendering() {
        if case .symbol = MenuBarIconStyle.circle.rendering(isActive: true) {
            // expected
        } else {
            XCTFail("Circle style should use SF Symbol rendering")
        }
    }

    func test_espressoDrop_usesDropSymbolWithFillSwap() {
        XCTAssertEqual(MenuBarIconStyle.espressoDrop.rendering(isActive: false), .symbol("drop"))
        XCTAssertEqual(MenuBarIconStyle.espressoDrop.rendering(isActive: true),  .symbol("drop.fill"))
    }

    func test_powerToggle_usesPowerCircleSymbolWithFillSwap() {
        XCTAssertEqual(MenuBarIconStyle.powerToggle.rendering(isActive: false), .symbol("power.circle"))
        XCTAssertEqual(MenuBarIconStyle.powerToggle.rendering(isActive: true),  .symbol("power.circle.fill"))
    }

    func test_ledBulb_usesLightbulbLedSymbolWithFillSwap() {
        XCTAssertEqual(MenuBarIconStyle.ledBulb.rendering(isActive: false), .symbol("lightbulb.led"))
        XCTAssertEqual(MenuBarIconStyle.ledBulb.rendering(isActive: true),  .symbol("lightbulb.led.fill"))
    }

    // MARK: - Amphetamine-flavored additions

    func test_flame_usesFlameSymbolWithFillSwap() {
        XCTAssertEqual(MenuBarIconStyle.flame.rendering(isActive: false), .symbol("flame"))
        XCTAssertEqual(MenuBarIconStyle.flame.rendering(isActive: true),  .symbol("flame.fill"))
    }

    func test_hexagon_usesHexagonSymbolWithFillSwap() {
        XCTAssertEqual(MenuBarIconStyle.hexagon.rendering(isActive: false), .symbol("hexagon"))
        XCTAssertEqual(MenuBarIconStyle.hexagon.rendering(isActive: true),  .symbol("hexagon.fill"))
    }

    func test_deskLamp_usesLampDeskSymbolWithFillSwap() {
        XCTAssertEqual(MenuBarIconStyle.deskLamp.rendering(isActive: false), .symbol("lamp.desk"))
        XCTAssertEqual(MenuBarIconStyle.deskLamp.rendering(isActive: true),  .symbol("lamp.desk.fill"))
    }

    func test_moon_usesMoonSymbolWithFillSwap() {
        XCTAssertEqual(MenuBarIconStyle.moon.rendering(isActive: false), .symbol("moon"))
        XCTAssertEqual(MenuBarIconStyle.moon.rendering(isActive: true),  .symbol("moon.fill"))
    }

    func test_owl_usesBirdSymbolWithFillSwap() {
        // SF Symbols has no dedicated owl; `bird` is the closest perched-silhouette
        // stand-in for Amphetamine's classic owl icon.
        XCTAssertEqual(MenuBarIconStyle.owl.rendering(isActive: false), .symbol("bird"))
        XCTAssertEqual(MenuBarIconStyle.owl.rendering(isActive: true),  .symbol("bird.fill"))
    }

    func test_battery_idleIsEmptyActiveIsFull() {
        // Asymmetric pair: empty battery = idle/sleeping, full battery = active/awake.
        // Explicit assertion guards against accidental glyph swap.
        XCTAssertEqual(MenuBarIconStyle.battery.rendering(isActive: false), .symbol("battery.0percent"))
        XCTAssertEqual(MenuBarIconStyle.battery.rendering(isActive: true),  .symbol("battery.100percent"))
    }
}
