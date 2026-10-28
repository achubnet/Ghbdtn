// Renders the README demo: text typed in the wrong layout, ⌥⌘, the fixed text and the layout switch.
// Usage: swift scripts/make-demo.swift docs/demo.gif
import AppKit
import ImageIO
import UniformTypeIdentifiers

let size = NSSize(width: 720, height: 250)
let scale: CGFloat = 1

struct Frame {
    var text = ""
    var selected = false
    var caret = true
    var keysDown = false
    var layout = "EN"
    var delay = 0.1
}

let background = NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.97, alpha: 1)
let fieldBorder = NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.84, alpha: 1)
let selection = NSColor(calibratedRed: 0.70, green: 0.84, blue: 1.0, alpha: 1)
let accent = NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)
let ink = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
let secondary = NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.48, alpha: 1)

func draw(_ string: String, font: NSFont, color: NSColor, centeredIn rect: NSRect) {
    let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    let textSize = text.size()
    text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
}

func keycap(_ glyph: String, at origin: NSPoint, down: Bool) {
    let rect = NSRect(origin: NSPoint(x: origin.x, y: origin.y - (down ? 3 : 0)), size: NSSize(width: 72, height: 60))
    if !down {
        NSColor(calibratedWhite: 0.78, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect.offsetBy(dx: 0, dy: -4), xRadius: 12, yRadius: 12).fill()
    }
    (down ? accent : .white).setFill()
    let cap = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
    cap.fill()
    fieldBorder.setStroke()
    if !down { cap.stroke() }
    draw(glyph, font: .systemFont(ofSize: 30, weight: .medium), color: down ? .white : ink, centeredIn: rect)
}

func render(_ frame: Frame) -> CGImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    background.setFill()
    NSRect(origin: .zero, size: size).fill()

    // Layout indicator, like the input menu in the menu bar.
    let badge = NSRect(x: size.width - 40 - 64, y: size.height - 52, width: 64, height: 32)
    (frame.layout == "RU" ? accent : ink).setFill()
    NSBezierPath(roundedRect: badge, xRadius: 7, yRadius: 7).fill()
    draw(frame.layout, font: .systemFont(ofSize: 17, weight: .bold), color: .white, centeredIn: badge)
    let label = NSAttributedString(string: "Ghbdtn", attributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: secondary,
    ])
    label.draw(at: NSPoint(x: 40, y: badge.midY - label.size().height / 2))

    // Text field.
    let field = NSRect(x: 40, y: 104, width: size.width - 80, height: 72)
    NSColor.white.setFill()
    let fieldPath = NSBezierPath(roundedRect: field, xRadius: 12, yRadius: 12)
    fieldPath.fill()
    fieldBorder.setStroke()
    fieldPath.stroke()

    let font = NSFont.systemFont(ofSize: 32)
    let text = NSAttributedString(string: frame.text, attributes: [.font: font, .foregroundColor: ink])
    let textOrigin = NSPoint(x: field.minX + 22, y: field.midY - text.size().height / 2)
    if frame.selected && !frame.text.isEmpty {
        selection.setFill()
        NSRect(x: textOrigin.x - 2, y: field.midY - 22, width: text.size().width + 4, height: 44).fill()
    }
    text.draw(at: textOrigin)
    if frame.caret {
        ink.setFill()
        NSRect(x: textOrigin.x + text.size().width + 2, y: field.midY - 19, width: 2, height: 38).fill()
    }

    // ⌥ ⌘ keys.
    let keysWidth: CGFloat = 72 * 2 + 16
    keycap("⌥", at: NSPoint(x: size.width / 2 - keysWidth / 2, y: 22), down: frame.keysDown)
    keycap("⌘", at: NSPoint(x: size.width / 2 - keysWidth / 2 + 88, y: 22), down: frame.keysDown)

    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

func scene(typing source: String, fixed: String, from: String, to: String) -> [Frame] {
    var frames = [Frame(layout: from, delay: 0.5)]
    var typed = ""
    for character in source {
        typed.append(character)
        frames.append(Frame(text: typed, layout: from, delay: 0.09))
    }
    frames.append(Frame(text: typed, caret: false, layout: from, delay: 0.35))
    frames.append(Frame(text: typed, layout: from, delay: 0.35))
    frames.append(Frame(text: typed, selected: true, caret: false, layout: from, delay: 0.5))
    frames.append(Frame(text: typed, selected: true, caret: false, keysDown: true, layout: from, delay: 0.3))
    frames.append(Frame(text: fixed, layout: to, delay: 0.5))
    frames.append(Frame(text: fixed, caret: false, layout: to, delay: 0.5))
    frames.append(Frame(text: fixed, layout: to, delay: 0.5))
    frames.append(Frame(text: fixed, caret: false, layout: to, delay: 0.5))
    frames.append(Frame(text: fixed, layout: to, delay: 0.6))
    return frames
}

let frames = scene(typing: "ghbdtn rfr ltkf", fixed: "привет как дела", from: "EN", to: "RU")
    + scene(typing: "ыщккн", fixed: "sorry", from: "RU", to: "EN")

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-demo.swift <output.gif>\n".data(using: .utf8)!)
    exit(1)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let gif = CGImageDestinationCreateWithURL(url, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for frame in frames {
    let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frame.delay]] as CFDictionary
    CGImageDestinationAddImage(gif, render(frame), properties)
}
exit(CGImageDestinationFinalize(gif) ? 0 : 1)
