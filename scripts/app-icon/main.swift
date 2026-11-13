import AppKit

// Renders the layers of Sources/Resources/AppIcon.icon (an Icon Composer icon) from
// the Wave Ring geometry the menu-bar icon uses. Run through scripts/render-app-icon.sh.
// Arg: the .icon's Assets directory.

let assets = CommandLine.arguments[1]
let canvas: CGFloat = 1024
/// Ring diameter on the 1024pt icon canvas.
let glyph: CGFloat = 660
let disc = CGRect(x: (canvas - glyph) / 2, y: (canvas - glyph) / 2, width: glyph, height: glyph)

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Fills `path` with a top-to-bottom gradient across the ring's height and writes it
/// as a transparent 1024×1024 PNG.
func writeLayer(_ name: String, _ path: CGPath, top: CGColor, bottom: CGColor) {
    let ctx = CGContext(
        data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // WaveRing paths are y-down.
    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top, bottom] as CFArray, locations: nil
    )!
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: disc.midX, y: disc.minY), end: CGPoint(x: disc.midX, y: disc.maxY),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(assets)/\(name).png"))
    print("wrote \(name).png")
}

writeLayer("ring", WaveRing.ringPath(in: disc), top: srgb(255, 255, 255), bottom: srgb(235, 242, 255))
writeLayer("wave", WaveRing.liquidPath(in: disc), top: srgb(255, 255, 255), bottom: srgb(215, 232, 255))

// A fainter second wave behind the first: the same surface shifted half a wavelength
// and raised, kept inside the ring.
let backWave = WaveRing.liquidPath(in: disc.offsetBy(dx: glyph * 0.25, dy: -glyph * 0.07))
    .intersection(CGPath(ellipseIn: disc.insetBy(dx: glyph * 0.09, dy: glyph * 0.09), transform: nil))
writeLayer("back-wave", backWave, top: srgb(255, 255, 255, 0.35), bottom: srgb(255, 255, 255, 0.35))
