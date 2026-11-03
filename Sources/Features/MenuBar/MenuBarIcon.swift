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
            case .boltDisc(let isActive):
                BoltDiscGlyph(isActive: isActive)
            }
        }
        .accessibilityLabel(isActive ? "CafeUp active" : "CafeUp idle")
    }
}

/// Produces the `NSImage`s for the menu-bar status item. Every style is a template
/// image except the active Bolt Disc, whose coloured bolt needs a regular image (see
/// `IconRendering.isTemplate`).
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
/// template image because every pixel is either black or transparent. The Bolt Disc
/// is the exception: it is drawn with a resolution-independent drawing handler, which
/// re-runs per appearance and screen scale, and its idle state uses partial alpha.
@MainActor
enum MenuBarIconImage {
    /// Optical size of the icon inside the 22pt status-item button. Matches
    /// Apple's other menu-bar icons (battery, wifi, …).
    static let pointSize: CGFloat = 16

    static func statusItemImage(for style: MenuBarIconStyle, isActive: Bool) -> NSImage {
        let label = isActive ? "CafeUp active" : "CafeUp idle"
        let rendering = style.rendering(isActive: isActive)
        let image = nsImage(for: rendering) ?? fallback()
        image.isTemplate = rendering.isTemplate
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

        case .boltDisc(let isActive):
            return NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                BoltDisc.draw(isActive: isActive, in: rect, context: context)
                return true
            }
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
