// Draws the app icon and writes an .iconset folder that `iconutil` turns into AppIcon.icns.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

/// Renders the icon at `pixels`×`pixels` and returns PNG data.
func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    // Apple's icon grid: the rounded square sits inside a 1024 canvas with ~100pt margins.
    let inset = size * 0.1
    let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)

    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.24, green: 0.56, blue: 1.00, alpha: 1),
        ending: NSColor(calibratedRed: 0.55, green: 0.27, blue: 0.95, alpha: 1)
    )!
    gradient.draw(in: shape, angle: -90)

    // The same SF Symbol the menu bar uses, drawn white in the middle of the tile.
    let config = NSImage.SymbolConfiguration(pointSize: tile.width * 0.5, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let origin = NSPoint(x: tile.midX - symbolSize.width / 2, y: tile.midY - symbolSize.height / 2)
        symbol.draw(in: NSRect(origin: origin, size: symbolSize))
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

// macOS wants each size at 1x and 2x, named exactly like this.
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        let file = outputDirectory.appending(path: "icon_\(points)x\(points)\(suffix).png")
        try renderIcon(pixels: points * scale).write(to: file)
    }
}
print("Wrote iconset to \(outputDirectory.path)")
