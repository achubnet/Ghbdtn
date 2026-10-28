import ApplicationServices

/// Asks the focused text field, through the Accessibility API, whether it has a selection.
///
/// Only a positive answer is trusted. Chromium-based apps update their accessibility tree
/// asynchronously, so right after the user selects something they may still report an empty
/// selection; acting on that would mangle the selection.
enum FocusedSelection {
    static func reportsSelection() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        // Do not hang on an unresponsive app.
        AXUIElementSetMessagingTimeout(systemWide, 0.1)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let element = focused as! AXUIElement

        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
           let value, CFGetTypeID(value) == AXValueGetTypeID() {
            var range = CFRange()
            if AXValueGetValue(value as! AXValue, .cfRange, &range) {
                return range.length > 0
            }
        }
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
           let text = value as? String {
            return !text.isEmpty
        }
        return false
    }
}
