/// How a conversion ended.
public enum ConversionOutcome: Equatable, Sendable {
    public enum Method: Sendable { case clipboard, accessibility }

    case converted(characters: Int, method: Method)
    case nothingToConvert
    /// The word selection did not match what was copied, so the text was left alone.
    case selectionNotVerified
    /// A conversion is already running, or the layout pair is not available.
    case skipped
}

/// Converts the selection (or the word before the cursor) to the other layout and switches the
/// keyboard layout to match.
///
/// Text is only ever replaced over a selection whose contents were just copied and checked, or
/// through Accessibility at a range read a moment before, so a wrong guess about the selection
/// can at worst do nothing.
@MainActor
public final class SelectionConverter {
    private let layouts: LayoutSwitching
    private let clipboard: ClipboardTextIO
    private let accessibility: AccessibilityTextIO
    private let sleep: (Duration) async -> Void
    private var busy = false

    public init(layouts: LayoutSwitching, clipboard: ClipboardTextIO, accessibility: AccessibilityTextIO,
                sleep: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.layouts = layouts
        self.clipboard = clipboard
        self.accessibility = accessibility
        self.sleep = sleep
    }

    /// - Parameter likelySelected: what the user's recent input suggests about the selection.
    public func convert(likelySelected: Bool?) async -> ConversionOutcome {
        guard !busy, let converter = layouts.converter else { return .skipped }
        busy = true
        defer { busy = false }

        clipboard.saveClipboard()
        defer { clipboard.restoreClipboard() }

        // Go straight for the word before the cursor only when the input says there is no
        // selection and Accessibility does not contradict it. Any doubt means ⌘C first: the
        // word path moves the selection around, which would wreck an existing one.
        if likelySelected == false && !accessibility.reportsSelection() {
            return await convertLastWord(using: converter)
        }
        switch await clipboard.copy() {
        case .text(let text):
            return await replaceSelection(text, using: converter)
        case .unusable:
            return .nothingToConvert
        case .nothing:
            // Either nothing was selected after all, or the app has no ⌘C (menu bar apps
            // without an Edit menu).
            if let outcome = replaceDirectly(.selectionOrLastWord, using: converter) { return outcome }
            return await convertLastWord(using: converter)
        }
    }

    /// Selects from the start of the line to the cursor, copies that, narrows the selection to
    /// the last whitespace-delimited token and copies again to check exactly that is selected.
    ///
    /// Word-wise ⌥⇧← would not do: macOS stops at symbols, so from "nj;t" it grabs just "t".
    private func convertLastWord(using converter: LayoutConverter) async -> ConversionOutcome {
        clipboard.selectToLineStart()
        let line: String
        switch await clipboard.copy() {
        case .text(let text):
            line = text
        case .nothing:
            if let outcome = replaceDirectly(.lastWord, using: converter) { return outcome }
            // Collapse anyway: if the selection did happen, typing on would replace the line,
            // which is worse than the caret moving one character right.
            clipboard.collapseSelection()
            return .nothingToConvert
        case .unusable:
            clipboard.collapseSelection()
            return .nothingToConvert
        }

        let (prefixLength, token) = lastToken(in: line)
        guard !token.isEmpty else {
            clipboard.collapseSelection()
            return .nothingToConvert
        }
        if prefixLength > 0 {
            clipboard.shrinkSelectionFromStart(by: prefixLength)
            guard await clipboard.copy() == .text(token) else {
                clipboard.collapseSelection()
                return .selectionNotVerified
            }
        }
        return await replaceSelection(token, using: converter)
    }

    private func replaceSelection(_ text: String, using converter: LayoutConverter) async -> ConversionOutcome {
        let (converted, target) = flip(text, using: converter)
        clipboard.paste(converted)
        // Switch only once the app has handled ⌘V: a key event is interpreted in the layout
        // current at delivery, and some apps would read it as ⌘М after a switch to Cyrillic.
        await sleep(.milliseconds(120))
        if let target { layouts.select(target) }
        // Give the app time to read the clipboard before the old contents are put back.
        await sleep(.milliseconds(380))
        return .converted(characters: text.count, method: .clipboard)
    }

    private func replaceDirectly(_ scope: EditScope, using converter: LayoutConverter) -> ConversionOutcome? {
        guard let field = accessibility.focusedField(), let range = field.editRange(scope) else { return nil }
        let text = field.text(in: range)
        let (converted, target) = flip(text, using: converter)
        guard accessibility.replace(range, with: converted) else { return nil }
        if let target { layouts.select(target) }
        return .converted(characters: text.count, method: .accessibility)
    }

    /// The converted text and the layout to continue in: that of the last converted letter,
    /// where the cursor ends up.
    private func flip(_ text: String, using converter: LayoutConverter) -> (String, Script?) {
        let current = layouts.currentScript
        let converted = converter.flip(text, unknownScript: current ?? .latin)
        return (converted, lastScript(of: converted) ?? current?.opposite)
    }
}
