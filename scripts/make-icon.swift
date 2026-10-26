// Renders the Docky app icon into Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift   (re-run after changing the drawing)
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

/// Draws the icon on a 1024×1024 canvas: a screen with docks on the left, bottom and right.
func drawIcon() {
    // Squircle body following the macOS icon grid (824pt body, 100pt margin).
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = roundedRect(body, 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x3A3FD9).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [color(0x6A5CFF), color(0x3E7BFA), color(0x22C1E8)])!
        .draw(in: bodyPath, angle: -55)

    // Soft highlight on the top half for depth.
    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // The "screen".
    let screen = NSRect(x: 190, y: 190, width: 644, height: 644)
    let screenPath = roundedRect(screen, 70)
    color(0x0B1033, 0.28).setFill()
    screenPath.fill()
    NSColor.white.withAlphaComponent(0.35).setStroke()
    screenPath.lineWidth = 6
    screenPath.stroke()

    let tileColors: [UInt32] = [0xFF6B6B, 0xFFC93C, 0x4ADE80, 0xA78BFA, 0x38BDF8, 0xF472B6]
    let tile: CGFloat = 58
    let gap: CGFloat = 20
    let barThickness: CGFloat = 96

    func drawBar(_ rect: NSRect, tiles: Int, vertical: Bool, colorOffset: Int) {
        let bar = roundedRect(rect, 34)
        NSGraphicsContext.saveGraphicsState()
        let barShadow = NSShadow()
        barShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        barShadow.shadowBlurRadius = 14
        barShadow.shadowOffset = NSSize(width: 0, height: -5)
        barShadow.set()
        NSColor.white.withAlphaComponent(0.92).setFill()
        bar.fill()
        NSGraphicsContext.restoreGraphicsState()

        let length = CGFloat(tiles) * tile + CGFloat(tiles - 1) * gap
        for index in 0..<tiles {
            let offset = CGFloat(index) * (tile + gap)
            let origin = vertical
                ? NSPoint(x: rect.midX - tile / 2, y: rect.midY + length / 2 - tile - offset)
                : NSPoint(x: rect.midX - length / 2 + offset, y: rect.midY - tile / 2)
            let hex = tileColors[(index + colorOffset) % tileColors.count]
            let tilePath = roundedRect(NSRect(origin: origin, size: NSSize(width: tile, height: tile)), 16)
            NSGradient(colors: [color(hex), color(hex).blended(withFraction: 0.25, of: .black)!])!
                .draw(in: tilePath, angle: -90)
        }
    }

    let inset: CGFloat = 34
    // Bottom dock.
    drawBar(NSRect(x: screen.midX - 210, y: screen.minY + inset, width: 420, height: barThickness),
            tiles: 4, vertical: false, colorOffset: 0)
    // Left and right docks, raised so they clear the bottom dock.
    let sideHeight: CGFloat = 330
    let sideY = screen.midY - sideHeight / 2 + 50
    drawBar(NSRect(x: screen.minX + inset, y: sideY, width: barThickness, height: sideHeight),
            tiles: 3, vertical: true, colorOffset: 3)
    drawBar(NSRect(x: screen.maxX - inset - barThickness, y: sideY, width: barThickness, height: sideHeight),
            tiles: 3, vertical: true, colorOffset: 1)
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let scale = CGFloat(pixels) / canvas
    context.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(pixels: 1024).write(to: root.appendingPathComponent("Resources/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
