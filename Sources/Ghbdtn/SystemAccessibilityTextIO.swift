import ApplicationServices
import LayoutCore

/// `AccessibilityTextIO` over the system-wide focused element.
@MainActor
final class SystemAccessibilityTextIO: AccessibilityTextIO {
    func reportsSelection() -> Bool {
        guard let element = focusedElement() else { return false }
        if let range = selectedRange(of: element) { return !range.isEmpty }
        if let text = attribute(kAXSelectedTextAttribute, of: element) as? String { return !text.isEmpty }
        return false
    }

    func focusedField() -> TextFieldState? {
        guard let element = focusedElement(),
              let value = attribute(kAXValueAttribute, of: element) as? String,
              let range = selectedRange(of: element),
              isSettable(kAXSelectedTextAttribute, of: element) else { return nil }
        return TextFieldState(value: value, selection: range)
    }

    func replace(_ range: Range<Int>, with text: String) -> Bool {
        var cfRange = CFRange(location: range.lowerBound, length: range.count)
        guard let element = focusedElement(), let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue) == .success
            && AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }

    // MARK: - Helpers

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        // Applies to every element: do not hang on an unresponsive app.
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
        guard let value = attribute(kAXFocusedUIElementAttribute, of: systemWide),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func selectedRange(of element: AXUIElement) -> Range<Int>? {
        guard let value = attribute(kAXSelectedTextRangeAttribute, of: element),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range),
              range.location >= 0, range.length >= 0 else { return nil }
        return range.location..<(range.location + range.length)
    }

    private func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func isSettable(_ name: String, of element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success && settable.boolValue
    }
}
