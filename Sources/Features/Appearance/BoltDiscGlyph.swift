import AppKit
import SwiftUI

/// Geometry and tones for the Bolt Disc icon: a disc with a flat-top lightning bolt.
///
/// The picker preview (`BoltDiscGlyph`) and the status-item image
/// (`MenuBarIconImage`) both draw from here, so the two can't drift apart.
///
/// - Idle: a dimmed disc with a quiet bolt. Drawn as a template image, so macOS
///   tints it for light/dark bars and the click highlight.
/// - Active: a disc in the menu bar's label colour with a warm gradient bolt. The
///   bolt colour can't live in a template image, so this state is not one.
enum BoltDisc {
    /// Bolt outline in unit coordinates (y up, height 1, centred on its bounding box).
    private static let outline: [CGPoint] = [
        CGPoint(x: -0.10, y: 0.50), CGPoint(x: 0.24, y: 0.50), CGPoint(x: 0.07, y: 0.10),
        CGPoint(x: 0.31, y: 0.10), CGPoint(x: -0.20, y: -0.50), CGPoint(x: -0.07, y: -0.02),
        CGPoint(x: -0.29, y: -0.02),
    ]

    /// Bolt height as a fraction of the disc diameter.
    static let boltHeightRatio: CGFloat = 0.69

    /// Width of the round-join stroke that softens the bolt's corners, as a fraction of its height.
    private static let cornerSoftening: CGFloat = 0.02

    /// Idle: opacity of the whole disc, and how much of the disc's tone the bolt keeps
    /// (0 = bolt fully cut out, 1 = bolt invisible). High enough that the bolt is visible
    /// but doesn't pull the eye.
    static let idleDiscOpacity: CGFloat = 0.5
    static let idleBoltKeep: CGFloat = 0.55

    /// Active bolt gradient, top to bottom.
    static var warmTop: NSColor { NSColor(srgbRed: 1, green: 176.0 / 255, blue: 0, alpha: 1) }
    static var warmBottom: NSColor { NSColor(srgbRed: 1, green: 94.0 / 255, blue: 0, alpha: 1) }

    /// The bolt's outline in a y-down space (SwiftUI, or a flipped `NSImage`), centred in `rect`.
    static func boltPath(in rect: CGRect) -> CGPath {
        let height = min(rect.width, rect.height) * boltHeightRatio
        let xs = outline.map(\.x), ys = outline.map(\.y)
        let midX = (xs.min()! + xs.max()!) / 2
        let midY = (ys.min()! + ys.max()!) / 2

        let polygon = CGMutablePath()
        polygon.addLines(between: outline.map {
            CGPoint(x: rect.midX + ($0.x - midX) * height, y: rect.midY - ($0.y - midY) * height)
        })
        polygon.closeSubpath()

        // Fill + stroke as one path, so partial-alpha fills are applied once.
        let rim = polygon.copy(
            strokingWithWidth: cornerSoftening * height,
            lineCap: .round, lineJoin: .round, miterLimit: 1
        )
        return polygon.union(rim, using: .winding)
    }

    /// Draws the icon filling `rect` of a flipped (y-down) context. Resolves
    /// `NSColor.labelColor` at draw time, so the disc follows the current appearance.
    static func draw(isActive: Bool, in rect: CGRect, context cg: CGContext) {
        let side = min(rect.width, rect.height)
        let disc = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        let bolt = boltPath(in: disc)

        if isActive {
            NSColor.labelColor.setFill()
            cg.fillEllipse(in: disc)

            let boltHeight = side * boltHeightRatio
            let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: [warmTop.cgColor, warmBottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.saveGState()
            cg.addPath(bolt)
            cg.clip()
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: disc.midX, y: disc.midY - boltHeight / 2),
                end: CGPoint(x: disc.midX, y: disc.midY + boltHeight / 2),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            cg.restoreGState()
        } else {
            cg.setFillColor(gray: 0, alpha: idleDiscOpacity)
            cg.fillEllipse(in: disc)

            // Cut the bolt partway out: what's left is disc × idleBoltKeep.
            cg.setBlendMode(.destinationOut)
            cg.setFillColor(gray: 0, alpha: 1 - idleBoltKeep)
            cg.addPath(bolt)
            cg.fillPath()
        }
    }
}

private struct BoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(BoltDisc.boltPath(in: rect))
    }
}

/// Picker-preview rendering of the Bolt Disc icon. The status item itself uses
/// `MenuBarIconImage`, which draws the same geometry through `BoltDisc.draw`.
struct BoltDiscGlyph: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let halfBolt = BoltDisc.boltHeightRatio / 2

            ZStack {
                Circle()
                    .fill(Color.primary)
                if isActive {
                    BoltShape()
                        .fill(LinearGradient(
                            colors: [Color(nsColor: BoltDisc.warmTop), Color(nsColor: BoltDisc.warmBottom)],
                            startPoint: UnitPoint(x: 0.5, y: 0.5 - halfBolt),
                            endPoint: UnitPoint(x: 0.5, y: 0.5 + halfBolt)
                        ))
                } else {
                    BoltShape()
                        .fill(Color.black.opacity(1 - BoltDisc.idleBoltKeep))
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
            .opacity(isActive ? 1 : BoltDisc.idleDiscOpacity)
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
