import Carbon
import LayoutCore

/// Bridges the Text Input Sources API to `KeyboardLayout` snapshots and layout switching.
@MainActor
final class InputSources {
    struct Entry {
        let source: TISInputSource
        let layout: KeyboardLayout
    }

    /// Enabled keyboard layouts the user can switch to, in system order.
    static func enabledLayouts() -> [Entry] {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceType: kTISTypeKeyboardLayout as Any,
            kTISPropertyInputSourceIsEnabled: true,
            kTISPropertyInputSourceIsSelectCapable: true,
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue(),
              let sources = list as? [TISInputSource] else { return [] }
        return sources.compactMap { source in
            snapshot(of: source).map { Entry(source: source, layout: $0) }
        }
    }

    static func currentLayoutID() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return stringProperty(kTISPropertyInputSourceID, of: source)
    }

    static func select(_ source: TISInputSource) {
        TISSelectInputSource(source)
    }

    // MARK: - Snapshots

    /// Keycodes for the alphanumeric block: letters, digits, punctuation, ISO section key, grave.
    private static let typingKeycodes = 0...50

    private static func snapshot(of source: TISInputSource) -> KeyboardLayout? {
        guard let id = stringProperty(kTISPropertyInputSourceID, of: source),
              let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue() as Data
        let keys = data.withUnsafeBytes { raw -> [Int: KeyCap] in
            guard let layoutPtr = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return [:] }
            var keys: [Int: KeyCap] = [:]
            for keycode in typingKeycodes {
                let base = translate(keycode: keycode, shift: false, layout: layoutPtr)
                let shift = translate(keycode: keycode, shift: true, layout: layoutPtr)
                if base != nil || shift != nil {
                    keys[keycode] = KeyCap(base: base, shift: shift)
                }
            }
            return keys
        }
        return KeyboardLayout(id: id, keys: keys)
    }

    private static func translate(keycode: Int, shift: Bool, layout: UnsafePointer<UCKeyboardLayout>) -> Character? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        let modifiers: UInt32 = shift ? UInt32(shiftKey >> 8) : 0
        let status = UCKeyTranslate(
            layout, UInt16(keycode), UInt16(kUCKeyActionDown), modifiers,
            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState, buffer.count, &length, &buffer
        )
        guard status == noErr, length > 0 else { return nil }
        let string = String(utf16CodeUnits: buffer, count: length)
        guard string.count == 1, let character = string.first else { return nil }
        return character
    }

    private static func stringProperty(_ key: CFString, of source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
