import ApplicationServices

/// Direct access to the focused text field through Accessibility, for apps where ⌘C/⌘V do
/// nothing (menu bar apps without an Edit menu, such as LaunchOS). Offsets are UTF-16, as AX
/// counts them.
struct AXTextField {
    let element: AXUIElement
    let value: String
    let selection: Range<Int>

    static func focused() -> AXTextField? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.1)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement

        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &raw) == .success,
              let value = raw as? String,
              AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(raw as! AXValue, .cfRange, &range),
              range.location >= 0, range.location + range.length <= value.utf16.count else { return nil }

        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue else { return nil }

        return AXTextField(element: element, value: value, selection: range.location..<(range.location + range.length))
    }

    func text(in range: Range<Int>) -> String {
        let utf16 = value.utf16
        let start = utf16.index(utf16.startIndex, offsetBy: range.lowerBound)
        let end = utf16.index(utf16.startIndex, offsetBy: range.upperBound)
        return String(utf16[start..<end]) ?? ""
    }

    /// Selects `range` and replaces it with `text`.
    func replace(_ range: Range<Int>, with text: String) -> Bool {
        var cfRange = CFRange(location: range.lowerBound, length: range.count)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue) == .success,
              AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
        else { return false }
        return true
    }
}
