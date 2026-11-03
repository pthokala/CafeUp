import AppKit
import SwiftUI

/// Geometry and tones for the Wave Ring icon: a ring with a liquid wave filling its
/// lower half.
///
/// The picker preview (`WaveRingGlyph`) and the status-item image
/// (`MenuBarIconImage`) both draw from here, so the two can't drift apart. Shapes
/// are built with path booleans rather than blend modes, so they don't depend on
/// what the destination already contains.
///
/// - Idle: the ring and the wave in one tone. Drawn as a template image, so macOS
///   tints it for light/dark bars and the click highlight.
/// - Active: the ring in the menu bar's label colour, the wave an electric-blue
///   gradient. That colour can't live in a template image, so this state is not one.
enum WaveRing {
    /// Ring thickness, as a fraction of the icon's diameter.
    static let ringThicknessRatio: CGFloat = 0.06

    /// Gap between the ring and the wave, as a fraction of the diameter.
    private static let liquidGapRatio: CGFloat = 0.03

    /// The wave's surface: resting level below the centre, wave height and wavelength,
    /// as fractions of the diameter.
    private static let liquidLevelRatio: CGFloat = 0.07
    private static let waveAmplitudeRatio: CGFloat = 0.045
    private static let wavelengthRatio: CGFloat = 0.5

    /// Idle opacity. Bright enough to read as the standard menu-bar white. (An earlier
    /// 0.5 for a similar icon read as a washed-out grey.)
    static let idleOpacity: CGFloat = 0.85

    /// Active wave gradient, top to bottom of the icon (the wave sits in its lower half).
    static var blueTop: NSColor { NSColor(srgbRed: 10.0 / 255, green: 200.0 / 255, blue: 1, alpha: 1) }
    static var blueBottom: NSColor { NSColor(srgbRed: 30.0 / 255, green: 90.0 / 255, blue: 1, alpha: 1) }

    // MARK: - Geometry

    /// The ring: an annulus filling `disc`, in a y-down space (SwiftUI, or a flipped `NSImage`).
    static func ringPath(in disc: CGRect) -> CGPath {
        CGPath(ellipseIn: disc, transform: nil).subtracting(CGPath(ellipseIn: innerRect(of: disc), transform: nil))
    }

    /// The wave: everything below a sine-wave surface, kept clear of the ring.
    static func liquidPath(in disc: CGRect) -> CGPath {
        let side = min(disc.width, disc.height)
        let center = CGPoint(x: disc.midX, y: disc.midY)
        let radius = side / 2

        let level = center.y + side * liquidLevelRatio
        let amplitude = side * waveAmplitudeRatio
        let wavelength = side * wavelengthRatio
        func surfaceY(at x: CGFloat) -> CGFloat {
            level + amplitude * sin(2 * .pi * (x - center.x) / wavelength)
        }

        let wave = CGMutablePath()
        let step = side / 240
        var x = center.x - radius
        wave.move(to: CGPoint(x: x, y: surfaceY(at: x)))
        while x < center.x + radius {
            x += step
            wave.addLine(to: CGPoint(x: x, y: surfaceY(at: x)))
        }
        wave.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius))
        wave.addLine(to: CGPoint(x: center.x - radius, y: center.y + radius))
        wave.closeSubpath()

        let gap = side * liquidGapRatio
        let room = CGPath(ellipseIn: innerRect(of: disc).insetBy(dx: gap, dy: gap), transform: nil)
        return wave.intersection(room)
    }

    private static func innerRect(of disc: CGRect) -> CGRect {
        let thickness = min(disc.width, disc.height) * ringThicknessRatio
        return disc.insetBy(dx: thickness, dy: thickness)
    }

    // MARK: - Drawing

    /// Draws the icon filling `rect` of a flipped (y-down) context. Resolves
    /// `NSColor.labelColor` at draw time, so the active ring follows the current appearance.
    static func draw(isActive: Bool, in rect: CGRect, context cg: CGContext) {
        let side = min(rect.width, rect.height)
        let disc = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        let ring = ringPath(in: disc)
        let liquid = liquidPath(in: disc)

        if isActive {
            NSColor.labelColor.setFill()
            cg.addPath(ring)
            cg.fillPath()

            let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: [blueTop.cgColor, blueBottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.saveGState()
            cg.addPath(liquid)
            cg.clip()
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: disc.midX, y: disc.minY),
                end: CGPoint(x: disc.midX, y: disc.maxY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            cg.restoreGState()
        } else {
            cg.setFillColor(gray: 0, alpha: idleOpacity)
            cg.addPath(ring)
            cg.fillPath()
            cg.addPath(liquid)
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

/// Picker-preview rendering of the Wave Ring icon. The status item itself uses
/// `MenuBarIconImage`, which draws the same geometry through `WaveRing.draw`.
struct WaveRingGlyph: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                if isActive {
                    PathShape { WaveRing.ringPath(in: $0) }
                        .fill(Color.primary)
                    PathShape { WaveRing.liquidPath(in: $0) }
                        .fill(LinearGradient(
                            colors: [Color(nsColor: WaveRing.blueTop), Color(nsColor: WaveRing.blueBottom)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                } else {
                    PathShape { WaveRing.ringPath(in: $0) }
                        .fill(Color.primary.opacity(WaveRing.idleOpacity))
                    PathShape { WaveRing.liquidPath(in: $0) }
                        .fill(Color.primary.opacity(WaveRing.idleOpacity))
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
