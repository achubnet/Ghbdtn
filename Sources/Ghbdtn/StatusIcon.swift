import AppKit

/// The menu bar glyph: a keycap outline with "WЦ", drawn as a template so it follows the bar's tint.
enum StatusIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let cap = NSBezierPath(roundedRect: NSRect(x: 1, y: 2, width: 16, height: 14), xRadius: 3, yRadius: 3)
            cap.lineWidth = 1.5
            NSColor.black.setStroke()
            cap.stroke()

            let font = NSFont.systemFont(ofSize: 8.5, weight: .heavy)
            let text = NSAttributedString(string: "WЦ", attributes: [
                .font: font, .foregroundColor: NSColor.black, .kern: -0.3,
            ])
            let width = text.size().width
            text.draw(at: NSPoint(x: (18 - width) / 2, y: 9 - font.capHeight / 2 + font.descender))
            return true
        }
        image.isTemplate = true
        return image
    }
}
