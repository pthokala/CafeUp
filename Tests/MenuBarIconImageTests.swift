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

    // MARK: - Wave Ring geometry

    func test_ringAndWave_dontOverlapAndStayInsideTheCircle() {
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let ring = WaveRing.ringPath(in: rect)
        let wave = WaveRing.liquidPath(in: rect)
        let center = CGFloat(side) / 2

        var overlaps = 0, outside = 0, ringPixels = 0, wavePixels = 0
        for x in 0..<side {
            for y in 0..<side {
                let p = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let inRing = ring.contains(p), inWave = wave.contains(p)
                if inRing { ringPixels += 1 }
                if inWave { wavePixels += 1 }
                if inRing && inWave { overlaps += 1 }
                if (inRing || inWave) && hypot(p.x - center, p.y - center) > center + 0.5 { outside += 1 }
            }
        }
        XCTAssertEqual(overlaps, 0, "the wave should keep clear of the ring")
        XCTAssertEqual(outside, 0)
        XCTAssertGreaterThan(ringPixels, 1_500)
        XCTAssertGreaterThan(wavePixels, 1_500)
    }

    func test_wave_fillsOnlyTheLowerHalf() {
        let box = WaveRing.liquidPath(in: CGRect(x: 0, y: 0, width: side, height: side)).boundingBox
        XCTAssertGreaterThan(box.minY, CGFloat(side) / 2, "the wave's surface should sit below the centre")
    }

    // MARK: - Wave Ring pixels

    func test_activeWaveRing_hasALabelColouredRingAndABlueWave() {
        let image = MenuBarIconImage.statusItemImage(for: .waveRing, isActive: true)
        XCTAssertTrue(WaveRing.liquidPath(in: CGRect(x: 0, y: 0, width: side, height: side))
            .contains(CGPoint(x: Double(wavePoint.x) + 0.5, y: Double(wavePoint.y) + 0.5)), "test point should be in the wave")

        let onDark = render(image, appearance: .darkAqua)
        let onLight = render(image, appearance: .aqua)

        // the ring uses the label colour: light on a dark bar, dark on a light bar
        let darkRing = onDark.colorAt(x: ringPoint.x, y: ringPoint.y)!
        XCTAssertGreaterThan(darkRing.redComponent, 0.85, "ring should be light on a dark bar")
        XCTAssertGreaterThan(darkRing.alphaComponent, 0.8)
        let lightRing = onLight.colorAt(x: ringPoint.x, y: ringPoint.y)!
        XCTAssertLessThan(lightRing.redComponent, 0.15, "ring should be dark on a light bar")
        XCTAssertGreaterThan(lightRing.alphaComponent, 0.8)

        // the wave keeps its own blue in both appearances; above it, inside the ring, is empty
        for rep in [onDark, onLight] {
            let wave = rep.colorAt(x: wavePoint.x, y: wavePoint.y)!
            XCTAssertGreaterThan(wave.blueComponent, 0.9)
            XCTAssertLessThan(wave.redComponent, 0.2)
            XCTAssertEqual(wave.alphaComponent, 1, accuracy: 0.02)

            let empty = rep.colorAt(x: emptyPoint.x, y: emptyPoint.y)!
            XCTAssertLessThan(empty.alphaComponent, 0.02, "space above the wave should be transparent")
        }
    }

    func test_idleWaveRing_isTheSameShapeInOneTone() {
        let image = MenuBarIconImage.statusItemImage(for: .waveRing, isActive: false)
        let rep = render(image, appearance: .aqua)

        let ring = rep.colorAt(x: ringPoint.x, y: ringPoint.y)!
        let wave = rep.colorAt(x: wavePoint.x, y: wavePoint.y)!
        let empty = rep.colorAt(x: emptyPoint.x, y: emptyPoint.y)!

        XCTAssertEqual(ring.alphaComponent, WaveRing.idleOpacity, accuracy: 0.03)
        XCTAssertEqual(wave.alphaComponent, WaveRing.idleOpacity, accuracy: 0.03)
        XCTAssertLessThan(empty.alphaComponent, 0.02)
        XCTAssertLessThan(ring.redComponent, 0.05, "template image: black + alpha only")
        XCTAssertLessThan(wave.redComponent, 0.05, "template image: black + alpha only")
    }

    // MARK: - Helpers

    /// A pixel on the ring, at the left edge.
    private var ringPoint: (x: Int, y: Int) { (2, side / 2) }

    /// A pixel in the wave, below the centre.
    private var wavePoint: (x: Int, y: Int) { (side / 2, Int(Double(side) * 0.8)) }

    /// A pixel inside the ring and above the wave.
    private var emptyPoint: (x: Int, y: Int) { (side / 2, side / 4) }

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
