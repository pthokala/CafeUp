import AppKit
import XCTest
@testable import CafeUp

@MainActor
final class MenuBarIconImageTests: XCTestCase {

    private let side = 128

    func test_isTemplate_followsRendering() {
        for style in MenuBarIconStyle.allCases {
            for isActive in [true, false] {
                let image = MenuBarIconImage.statusItemImage(for: style, isActive: isActive)
                XCTAssertEqual(
                    image.isTemplate, style.rendering(isActive: isActive).isTemplate,
                    "\(style) isActive=\(isActive)"
                )
            }
        }
    }

    // MARK: - Bolt Disc geometry

    func test_boltPath_isCentredAndSizedToTheDisc() {
        let box = BoltDisc.boltPath(in: CGRect(x: 0, y: 0, width: side, height: side)).boundingBox
        let expectedHeight = CGFloat(side) * BoltDisc.boltHeightRatio

        XCTAssertEqual(box.midX, CGFloat(side) / 2, accuracy: 1)
        XCTAssertEqual(box.midY, CGFloat(side) / 2, accuracy: 1)
        // the corner-softening stroke adds a hair to the outline
        XCTAssertEqual(box.height, expectedHeight, accuracy: expectedHeight * 0.04)
    }

    /// The bolt is big enough to reach the ring's inner edge; the ring must give way
    /// rather than overlap it.
    func test_ring_neverOverlapsTheBolt() {
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let bolt = BoltDisc.boltPath(in: rect)
        let ring = BoltDisc.ringPath(in: rect)

        var overlaps = 0, ringPixels = 0
        for x in 0..<side {
            for y in 0..<side {
                let p = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                if ring.contains(p) { ringPixels += 1 }
                if ring.contains(p) && bolt.contains(p) { overlaps += 1 }
            }
        }
        XCTAssertEqual(overlaps, 0)
        XCTAssertGreaterThan(ringPixels, 1_000, "ring should still be there")
    }

    // MARK: - Bolt Disc pixels

    func test_activeBoltDisc_hasWarmGradientBoltInsideALabelColouredRing() {
        let image = MenuBarIconImage.statusItemImage(for: .boltDisc, isActive: true)
        let (top, bottom) = boltSamplePoints()

        let onDark = render(image, appearance: .darkAqua)
        let darkRing = onDark.colorAt(x: ringPoint.x, y: ringPoint.y)!
        XCTAssertGreaterThan(darkRing.redComponent, 0.85, "ring should be light on a dark bar")
        XCTAssertGreaterThan(darkRing.alphaComponent, 0.8)

        let onLight = render(image, appearance: .aqua)
        let lightRing = onLight.colorAt(x: ringPoint.x, y: ringPoint.y)!
        XCTAssertLessThan(lightRing.redComponent, 0.15, "ring should be dark on a light bar")

        // the inside of the ring is transparent, not filled
        for rep in [onDark, onLight] {
            let inside = rep.colorAt(x: discOnlyPoint.x, y: discOnlyPoint.y)!
            XCTAssertLessThan(inside.alphaComponent, 0.02, "inside the ring should be empty")
        }

        // the bolt keeps its own colour in both appearances, warmer (more green) at the top
        for rep in [onDark, onLight] {
            let boltTop = rep.colorAt(x: top.x, y: top.y)!
            let boltBottom = rep.colorAt(x: bottom.x, y: bottom.y)!
            XCTAssertGreaterThan(boltTop.redComponent, 0.95)
            XCTAssertLessThan(boltTop.blueComponent, 0.1)
            XCTAssertGreaterThan(boltTop.greenComponent, boltBottom.greenComponent + 0.1)
            XCTAssertEqual(boltTop.alphaComponent, 1, accuracy: 0.02)
        }
    }

    func test_idleBoltDisc_isADimmedDiscWithAQuietBolt() {
        let image = MenuBarIconImage.statusItemImage(for: .boltDisc, isActive: false)
        let rep = render(image, appearance: .aqua)
        let (top, _) = boltSamplePoints()

        let disc = rep.colorAt(x: discOnlyPoint.x, y: discOnlyPoint.y)!
        let bolt = rep.colorAt(x: top.x, y: top.y)!

        XCTAssertEqual(disc.alphaComponent, BoltDisc.idleDiscOpacity, accuracy: 0.03)
        XCTAssertEqual(bolt.alphaComponent, BoltDisc.idleDiscOpacity * BoltDisc.idleBoltKeep, accuracy: 0.03)
        XCTAssertLessThan(bolt.alphaComponent, disc.alphaComponent, "bolt should read as a quieter cut into the disc")
        XCTAssertLessThan(disc.redComponent, 0.05, "template image: black + alpha only")
    }

    // MARK: - Helpers

    /// A pixel inside the circle, well clear of both the bolt and the ring.
    private var discOnlyPoint: (x: Int, y: Int) { (Int(Double(side) * 0.12), side / 2) }

    /// A pixel on the active state's ring, at the left edge.
    private var ringPoint: (x: Int, y: Int) { (2, side / 2) }

    /// Points inside the bolt, one in its upper bar and one in its lower tail.
    private func boltSamplePoints() -> (top: (x: Int, y: Int), bottom: (x: Int, y: Int)) {
        let path = BoltDisc.boltPath(in: CGRect(x: 0, y: 0, width: side, height: side))
        let box = path.boundingBox

        func interior(atFraction f: CGFloat) -> (x: Int, y: Int) {
            let y = box.minY + box.height * f
            let xs = stride(from: box.minX, through: box.maxX, by: 1).filter { path.contains(CGPoint(x: $0, y: y)) }
            XCTAssertFalse(xs.isEmpty, "no bolt pixels at fraction \(f)")
            return (Int(xs.reduce(0, +) / CGFloat(max(xs.count, 1))), Int(y))
        }
        return (interior(atFraction: 0.2), interior(atFraction: 0.8))
    }

    /// Draws `image` into a `side`×`side` bitmap with `appearance` as the drawing appearance.
    private func render(_ image: NSImage, appearance: NSAppearance.Name) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
            NSGraphicsContext.restoreGraphicsState()
        }
        return rep
    }
}
