import AppKit
import SwiftUI

/// SwiftUI view used **only** by the Appearance picker preview cells. The actual
/// menu-bar status item does NOT use this view — it goes through
/// `MenuBarIconImage.template(for:)` so macOS sees the icon as a real template
/// `NSImage` and can invert it correctly when the status item is highlighted.
struct MenuBarIcon: View {
    let style: MenuBarIconStyle
    let isActive: Bool

    var body: some View {
        Group {
            switch style.rendering(isActive: isActive) {
            case .symbol(let name):
                Image(systemName: name)
            case .solidCircle(let isFilled):
                SolidCircleGlyph(isFilled: isFilled)
            case .dividedDisc(let orientation):
                DividedDiscGlyph(orientation: orientation)
            }
        }
        .accessibilityLabel(isActive ? "CafeUp active" : "CafeUp idle")
    }
}

/// Produces template `NSImage`s for the menu-bar status item.
///
/// Why a template image (and not an `NSHostingView` subview, which was the prior
/// approach): macOS draws a selection highlight behind the status item when the
/// user clicks it. For a properly-marked template image (`isTemplate = true`),
/// AppKit inverts the icon's colors against the highlight so the symbol stays
/// readable. An `NSHostingView` subview is treated as opaque content — the
/// highlight draws *behind* it, leaving filled shapes (e.g. `moon.zzz.fill`,
/// `power.circle.fill`) sitting as solid dark blobs on the dark blue highlight.
///
/// SF Symbols go through `NSImage(systemSymbolName:)` directly so they remain
/// vectors at high-DPI. Custom shape glyphs are rasterized with SwiftUI's
/// `ImageRenderer` at the screen scale; the resulting bitmap is still a valid
/// template image because every pixel is either black or transparent.
@MainActor
enum MenuBarIconImage {
    /// Optical size of the icon inside the 22pt status-item button. Matches
    /// Apple's other menu-bar icons (battery, wifi, …).
    static let pointSize: CGFloat = 16

    static func template(for style: MenuBarIconStyle, isActive: Bool) -> NSImage {
        let label = isActive ? "CafeUp active" : "CafeUp idle"
        let image = nsImage(for: style.rendering(isActive: isActive)) ?? fallback()
        image.isTemplate = true
        image.accessibilityDescription = label
        return image
    }

    private static func nsImage(for rendering: IconRendering) -> NSImage? {
        switch rendering {
        case .symbol(let name):
            let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)

        case .solidCircle(let isFilled):
            return rasterize(SolidCircleGlyph(isFilled: isFilled))

        case .dividedDisc(let orientation):
            return rasterize(DividedDiscGlyph(orientation: orientation))
        }
    }

    private static func rasterize<Content: View>(_ glyph: Content) -> NSImage? {
        let renderer = ImageRenderer(
            content: glyph
                .frame(width: pointSize, height: pointSize)
                .foregroundStyle(Color.black)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }

    private static func fallback() -> NSImage {
        NSImage(systemSymbolName: "questionmark", accessibilityDescription: "CafeUp")
            ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
    }
}
