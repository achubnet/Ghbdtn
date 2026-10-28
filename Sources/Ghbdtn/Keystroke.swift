import AppKit

/// Synthetic key presses, tagged so our own input monitor can ignore them.
enum Keystroke {
    static let c: CGKeyCode = 8
    static let v: CGKeyCode = 9
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124

    private static let marker: Int64 = 0x4C53 // "LS"

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
