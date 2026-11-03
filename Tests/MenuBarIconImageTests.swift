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

    // MARK: - Bolt Disc pixels

    func test_activeBoltDisc_hasWarmGradientBoltOnALabelColouredDisc() {
        let image = MenuBarIconImage.statusItemImage(for: .boltDisc, isActive: true)
        let (top, bottom) = boltSamplePoints()

        let onDark = render(image, appearance: .darkAqua)
        let darkDisc = onDark.colorAt(x: discOnlyPoint.x, y: discOnlyPoint.y)!
        XCTAssertGreaterThan(darkDisc.redComponent, 0.85, "disc should be light on a dark bar")
        XCTAssertEqual(darkDisc.alphaComponent, BoltDisc.discOpacity, accuracy: 0.03)

        let onLight = render(image, appearance: .aqua)
        let lightDisc = onLight.colorAt(x: discOnlyPoint.x, y: discOnlyPoint.y)!
        XCTAssertLessThan(lightDisc.redComponent, 0.15, "disc should be dark on a light bar")
        XCTAssertEqual(lightDisc.alphaComponent, BoltDisc.discOpacity, accuracy: 0.03)

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

        XCTAssertEqual(disc.alphaComponent, BoltDisc.discOpacity, accuracy: 0.03)
        XCTAssertEqual(bolt.alphaComponent, BoltDisc.discOpacity * BoltDisc.idleBoltKeep, accuracy: 0.03)
        XCTAssertLessThan(bolt.alphaComponent, disc.alphaComponent, "bolt should read as a quieter cut into the disc")
        XCTAssertLessThan(disc.redComponent, 0.05, "template image: black + alpha only")
    }

    // MARK: - Helpers

    /// A pixel on the disc, well clear of the bolt.
    private var discOnlyPoint: (x: Int, y: Int) { (Int(Double(side) * 0.12), side / 2) }

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
