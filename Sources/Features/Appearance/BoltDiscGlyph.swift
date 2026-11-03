import AppKit
import SwiftUI

/// Geometry and tones for the Bolt Disc icon: a circle with a flat-top lightning bolt.
///
/// The picker preview (`BoltDiscGlyph`) and the status-item image
/// (`MenuBarIconImage`) both draw from here, so the two can't drift apart. Shapes
/// are built with path booleans rather than blend modes, so they don't depend on
/// what the destination already contains.
///
/// - Idle: a bright disc with the bolt cut almost all the way out. Drawn as a
///   template image, so macOS tints it for light/dark bars and the click highlight.
/// - Active: a ring in the menu bar's label colour, transparent inside, around a warm
///   gradient bolt. The bolt colour can't live in a template image, so this state
///   is not one.
enum BoltDisc {
    /// Bolt outline in unit coordinates (y up, height 1, centred on its bounding box).
    private static let outline: [CGPoint] = [
        CGPoint(x: -0.10, y: 0.50), CGPoint(x: 0.24, y: 0.50), CGPoint(x: 0.07, y: 0.10),
        CGPoint(x: 0.31, y: 0.10), CGPoint(x: -0.20, y: -0.50), CGPoint(x: -0.07, y: -0.02),
        CGPoint(x: -0.29, y: -0.02),
    ]

    /// Bolt height as a fraction of the disc diameter. Its farthest corners reach about
    /// 0.91 of the radius.
    static let boltHeightRatio: CGFloat = 0.828

    /// Width of the round-join stroke that softens the bolt's corners, as a fraction of its height.
    private static let cornerSoftening: CGFloat = 0.02

    /// Active: ring thickness as a fraction of the disc diameter.
    static let ringThicknessRatio: CGFloat = 0.05

    /// Active: clearance carved out of the ring around the bolt, on every side, as a
    /// fraction of the disc diameter. The bolt is big enough to cross the ring at its
    /// corners; this makes it read as passing in front instead of colliding.
    static let ringGapRatio: CGFloat = 0.022

    /// Idle: opacity of the whole disc, and how much of the disc's tone the bolt keeps
    /// (0 = bolt fully cut out, 1 = bolt invisible). A bright disc with the bolt cut almost
    /// all the way out, so the bolt stays crisp at 16pt. (An earlier 0.5 / 0.55 read as a
    /// washed-out grey disc with a bolt you couldn't make out.)
    static let idleDiscOpacity: CGFloat = 0.85
    static let idleBoltKeep: CGFloat = 0.10

    /// Active bolt gradient, top to bottom.
    static var warmTop: NSColor { NSColor(srgbRed: 1, green: 176.0 / 255, blue: 0, alpha: 1) }
    static var warmBottom: NSColor { NSColor(srgbRed: 1, green: 94.0 / 255, blue: 0, alpha: 1) }

    // MARK: - Geometry

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
        return grown(polygon, by: cornerSoftening * height / 2)
    }

    /// The active ring: an annulus filling `disc`, minus clearance around the bolt.
    static func ringPath(in disc: CGRect) -> CGPath {
        let thickness = min(disc.width, disc.height) * ringThicknessRatio
        let outer = CGPath(ellipseIn: disc, transform: nil)
        let inner = CGPath(ellipseIn: disc.insetBy(dx: thickness, dy: thickness), transform: nil)
        let clearance = grown(boltPath(in: disc), by: min(disc.width, disc.height) * ringGapRatio)
        return outer.subtracting(inner).subtracting(clearance)
    }

    /// The idle disc: a full circle with the bolt removed.
    static func idleDiscPath(in disc: CGRect) -> CGPath {
        CGPath(ellipseIn: disc, transform: nil).subtracting(boltPath(in: disc))
    }

    /// `path` expanded by `distance` on every side, with round corners.
    private static func grown(_ path: CGPath, by distance: CGFloat) -> CGPath {
        let rim = path.copy(strokingWithWidth: distance * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return path.union(rim, using: .winding)
    }

    // MARK: - Drawing

    /// Draws the icon filling `rect` of a flipped (y-down) context. Resolves
    /// `NSColor.labelColor` at draw time, so the ring follows the current appearance.
    static func draw(isActive: Bool, in rect: CGRect, context cg: CGContext) {
        let side = min(rect.width, rect.height)
        let disc = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        let bolt = boltPath(in: disc)

        if isActive {
            NSColor.labelColor.setFill()
            cg.addPath(ringPath(in: disc))
            cg.fillPath()

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
            cg.addPath(idleDiscPath(in: disc))
            cg.fillPath()

            // What's left of the bolt: the disc's tone × idleBoltKeep.
            cg.setFillColor(gray: 0, alpha: idleDiscOpacity * idleBoltKeep)
            cg.addPath(bolt)
            cg.fillPath()
        }
    }
}

private struct PathShape: Shape {
    let build: @Sendable (CGRect) -> CGPath

    func path(in rect: CGRect) -> Path {
        Path(build(rect))
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
                if isActive {
                    PathShape(build: BoltDisc.ringPath(in:))
                        .fill(Color.primary)
                    PathShape(build: BoltDisc.boltPath(in:))
                        .fill(LinearGradient(
                            colors: [Color(nsColor: BoltDisc.warmTop), Color(nsColor: BoltDisc.warmBottom)],
                            startPoint: UnitPoint(x: 0.5, y: 0.5 - halfBolt),
                            endPoint: UnitPoint(x: 0.5, y: 0.5 + halfBolt)
                        ))
                } else {
                    PathShape(build: BoltDisc.idleDiscPath(in:))
                        .fill(Color.primary.opacity(BoltDisc.idleDiscOpacity))
                    PathShape(build: BoltDisc.boltPath(in:))
                        .fill(Color.primary.opacity(BoltDisc.idleDiscOpacity * BoltDisc.idleBoltKeep))
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
