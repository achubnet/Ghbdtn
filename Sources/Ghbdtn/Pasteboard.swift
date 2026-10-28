import AppKit

/// A deep copy of the pasteboard contents that can be written back later.
@MainActor
struct PasteboardSnapshot {
    private let items: [NSPasteboardItem]

    init(of pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

enum Keystroke {
    static let c: CGKeyCode = 8
    static let v: CGKeyCode = 9
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124

    /// Tag on the events we post, so our own monitor can tell them from the user's typing.
    static let marker: Int64 = 0x4C53 // "LS"

    /// Posts a key press with the given modifiers as if typed on the keyboard.
    static func post(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.post(tap: .cghidEventTap)
        }
    }

    static func isOurs(_ event: NSEvent) -> Bool {
        event.cgEvent?.getIntegerValueField(.eventSourceUserData) == marker
    }
}
