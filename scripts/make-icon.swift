// Draws NoteMark's app icon and writes an .icns file, or a 1024-pixel PNG
// preview when the output ends in .png.
// Usage: swift scripts/make-icon.swift Packaging/Resources/AppIcon.icns
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns")
let canvas: CGFloat = 1024

/// Draws the icon on a 1024-point canvas with a bottom-left origin: a note
/// page with a yellow header and lines of text, and a large yellow plus for
/// "Notes, enhanced". Original artwork, not Apple's Notes icon.
func drawIcon(in context: CGContext) {
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: sRGB, components: [red, green, blue, alpha])!
    }
    func gradient(_ top: CGColor, _ bottom: CGColor) -> CGGradient {
        CGGradient(colorsSpace: sRGB, colors: [top, bottom] as CFArray, locations: [0, 1])!
    }
    func roundedBar(_ rect: CGRect, _ fill: CGColor) {
        context.addPath(CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil))
        context.setFillColor(fill)
        context.fillPath()
    }

    // macOS icon grid: an 824-point rounded square centered on the canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.28))
    context.addPath(tilePath)
    context.setFillColor(color(1, 1, 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    // The page.
    context.drawLinearGradient(gradient(color(1, 1, 1), color(0.95, 0.95, 0.94)),
                               start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // The yellow header, with a soft edge where it meets the page.
    let headerBottom: CGFloat = 742
    context.saveGState()
    context.clip(to: CGRect(x: tile.minX, y: headerBottom, width: tile.width, height: tile.maxY - headerBottom))
    context.drawLinearGradient(gradient(color(1.0, 0.86, 0.33), color(0.98, 0.76, 0.16)),
                               start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: headerBottom), options: [])
    context.restoreGState()
    context.setFillColor(color(0.85, 0.62, 0.05, 0.35))
    context.fill(CGRect(x: tile.minX, y: headerBottom - 5, width: tile.width, height: 5))

    // Lines of text: a darker heading over body lines, as Markdown becomes formatting.
    roundedBar(CGRect(x: 196, y: 600, width: 300, height: 52), color(0.33, 0.33, 0.36))
    for (y, width) in [(500, 600), (408, 540), (316, 600), (224, 380)] as [(CGFloat, CGFloat)] {
        roundedBar(CGRect(x: 196, y: y, width: width, height: 34), color(0.78, 0.78, 0.80))
    }
    context.restoreGState()

    // The plus badge, top right: a white disc carrying a large yellow plus.
    let center = CGPoint(x: 728, y: 728)
    let radius: CGFloat = 168
    let disc = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: color(0, 0, 0, 0.30))
    context.setFillColor(color(1, 1, 1))
    context.fillEllipse(in: disc)
    context.restoreGState()

    let arm: CGFloat = 124, thickness: CGFloat = 82
    let plus = CGMutablePath()
    plus.addPath(CGPath(roundedRect: CGRect(x: center.x - arm, y: center.y - thickness / 2, width: arm * 2, height: thickness),
                        cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
    plus.addPath(CGPath(roundedRect: CGRect(x: center.x - thickness / 2, y: center.y - arm, width: thickness, height: arm * 2),
                        cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
    context.saveGState()
    context.addPath(plus)
    context.clip()
    context.drawLinearGradient(gradient(color(1.0, 0.82, 0.18), color(0.98, 0.64, 0.0)),
                               start: CGPoint(x: 0, y: center.y + arm), end: CGPoint(x: 0, y: center.y - arm), options: [])
    context.restoreGState()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    context.interpolationQuality = .high
    drawIcon(in: context)
    graphics.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

if output.pathExtension == "png" {
    try png(pixels: 1024).write(to: output)
    print("Wrote \(output.path)")
    exit(0)
}
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("NoteMark-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
