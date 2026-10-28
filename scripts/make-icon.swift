// Renders the app icon (a keycap with "W" and "Ц") as an .icns and as an .appiconset for actool.
// Usage: swift scripts/make-icon.swift Resources
import AppKit

let canvas: CGFloat = 1024

func drawIcon(in rect: NSRect) -> Bool {
    let radius: CGFloat = 185
    let capFrame = NSRect(x: 100, y: 118, width: 824, height: 806)

    // Key side: a darker slab peeking out below the cap.
    let side = NSBezierPath(roundedRect: NSRect(x: 100, y: 84, width: 824, height: 806), xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.66, alpha: 1).setFill()
    side.fill()

    // Cap with a light vertical gradient.
    let cap = NSBezierPath(roundedRect: capFrame, xRadius: radius, yRadius: radius)
    NSGradient(
        starting: NSColor(calibratedWhite: 1.0, alpha: 1),
        ending: NSColor(calibratedRed: 0.86, green: 0.86, blue: 0.89, alpha: 1)
    )!.draw(in: cap, angle: -90)

    // Letters: fit "W" + gap + "Ц" into ~80% of the cap width.
    var fontSize: CGFloat = 460
    var font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let gap: CGFloat = 24
    func attributed(_ string: String, _ color: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }
    let dark = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
    let blue = NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)
    var w = attributed("W", dark)
    var c = attributed("Ц", blue)
    while w.size().width + gap + c.size().width > capFrame.width * 0.8 {
        fontSize -= 10
        font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        w = attributed("W", dark)
        c = attributed("Ц", blue)
    }

    let total = w.size().width + gap + c.size().width
    let x = capFrame.midX - total / 2
    let baseline = capFrame.midY - font.capHeight / 2
    let origin = baseline + font.descender
    w.draw(at: NSPoint(x: x, y: origin))
    c.draw(at: NSPoint(x: x + w.size().width + gap, y: origin))
    return true
}

let master = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false, drawingHandler: drawIcon)

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <Resources dir>\n".data(using: .utf8)!)
    exit(1)
}
let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let appiconset = resources.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(getpid()).iconset")
try FileManager.default.createDirectory(at: appiconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let data = png(size: points * scale)
        try data.write(to: iconset.appendingPathComponent(name))
        try data.write(to: appiconset.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: appiconset.appendingPathComponent("Contents.json"))
try "{\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n"
    .write(to: resources.appendingPathComponent("Assets.xcassets/Contents.json"), atomically: true, encoding: .utf8)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
