/// What a ⌘C put on the clipboard.
public enum CopyResult: Equatable, Sendable {
    /// The clipboard received this text.
    case text(String)
    /// The clipboard changed but holds nothing to convert (an image, an empty string).
    case unusable
    /// The clipboard did not change: nothing was copied.
    case nothing
}

/// Edits the focused text field the way a user would: with keystrokes and the clipboard.
@MainActor
public protocol ClipboardTextIO: AnyObject {
    /// Remembers the clipboard contents so `restoreClipboard` can put them back.
    func saveClipboard()
    /// Puts back what `saveClipboard` remembered, if the clipboard has changed since.
    func restoreClipboard()
    /// ⌘C, then reports what landed on the clipboard.
    func copy() async -> CopyResult
    /// Puts `text` on the clipboard and ⌘V's it over the selection.
    func paste(_ text: String)
    /// ⇧⌘←: selects from the caret back to the start of the line.
    func selectToLineStart()
    /// ⇧→ `count` times: moves the start of a backwards selection towards its end.
    func shrinkSelectionFromStart(by count: Int)
    /// →: collapses a selection to its end (or moves the caret right when there is none).
    func collapseSelection()
}

/// Reads and edits the focused text field directly through the Accessibility API.
@MainActor
public protocol AccessibilityTextIO: AnyObject {
    /// True only when the focused field positively reports a non-empty selection. A negative
    /// answer is not trustworthy: Chromium-based apps update their tree with a delay.
    func reportsSelection() -> Bool
    /// The focused field, if it exposes an editable text value and selection.
    func focusedField() -> TextFieldState?
    /// Replaces `range` (UTF-16 offsets) of the focused field with `text`.
    func replace(_ range: Range<Int>, with text: String) -> Bool
}

/// The system keyboard layouts Ghbdtn converts between.
@MainActor
public protocol LayoutSwitching: AnyObject {
    /// `nil` unless both a Latin and a Cyrillic layout are enabled.
    var converter: LayoutConverter? { get }
    /// The script of the current keyboard layout, if it is one of the pair.
    var currentScript: Script? { get }
    func select(_ script: Script)
}

/// Which part of a text field to convert.
public enum EditScope: Sendable {
    /// The selection, or the last word before the caret when nothing is selected.
    case selectionOrLastWord
    /// The last word ending at the end of the selection.
    case lastWord
}

/// A text field's value and selection as Accessibility reports them, in UTF-16 offsets.
public struct TextFieldState: Equatable, Sendable {
    public let value: String
    public let selection: Range<Int>

    public init?(value: String, selection: Range<Int>) {
        guard selection.lowerBound >= 0, selection.upperBound <= value.utf16.count else { return nil }
        self.value = value
        self.selection = selection
    }

    public func text(in range: Range<Int>) -> String {
        let utf16 = value.utf16
        let start = utf16.index(utf16.startIndex, offsetBy: range.lowerBound)
        let end = utf16.index(utf16.startIndex, offsetBy: range.upperBound)
        return String(utf16[start..<end]) ?? ""
    }

    /// The range to convert, or `nil` when there is nothing there.
    public func editRange(_ scope: EditScope) -> Range<Int>? {
        if scope == .selectionOrLastWord && !selection.isEmpty { return selection }
        let end = selection.upperBound
        let token = lastToken(in: text(in: 0..<end)).token
        guard !token.isEmpty else { return nil }
        return (end - token.utf16.count)..<end
    }
}
