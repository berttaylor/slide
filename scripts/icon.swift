// Draws the Slide app icon into an .iconset folder: swift scripts/icon.swift <output.iconset>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let unit = CGFloat(pixels) / 1024

    // Apple's grid: an 824pt tile centred on a 1024pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824).applying(.init(scaleX: unit, y: unit))
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * unit, yRadius: 185 * unit)
    NSGradient(starting: NSColor(red: 0.20, green: 0.21, blue: 0.25, alpha: 1), ending: NSColor(red: 0.07, green: 0.075, blue: 0.09, alpha: 1))!
        .draw(in: shape, angle: -90)

    // Three slots, the last one lit: the mark, large.
    let side = 170 * unit
    let gap = 52 * unit
    let originX = tile.midX - (3 * side + 2 * gap) / 2
    let fills = [NSColor.white.withAlphaComponent(0.3), NSColor.white.withAlphaComponent(0.6), NSColor(red: 1, green: 0.69, blue: 0, alpha: 1)]
    for (index, fill) in fills.enumerated() {
        fill.setFill()
        let slot = CGRect(x: originX + CGFloat(index) * (side + gap), y: tile.midY - side / 2, width: side, height: side)
        NSBezierPath(roundedRect: slot, xRadius: 38 * unit, yRadius: 38 * unit).fill()
    }
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(points * scale).write(to: output.appendingPathComponent(name))
    }
}
