import AppKit
import Carbon
import LayoutCore
import os

/// Copies the current selection (or the word before the cursor), re-types it in the other
/// layout, pastes it back and switches the system keyboard layout to match.
///
/// Text is only ever replaced by pasting over a selection whose contents were just copied and
/// checked, so a wrong guess about the selection can at worst do nothing.
@MainActor
final class SelectionConverter {
    private let log = Logger(subsystem: "com.skriptoff.Ghbdtn", category: "convert")
    private let pasteboard = NSPasteboard.general

    private var latin: InputSources.Entry?
    private var cyrillic: InputSources.Entry?
    private var converter: LayoutConverter?
    private var busy = false

    init() {
        reloadLayouts()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(layoutsChanged),
            name: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String), object: nil
        )
    }

    /// True when both a Latin and a Cyrillic layout are enabled in the system.
    var isReady: Bool { converter != nil }

    @objc private func layoutsChanged() {
        reloadLayouts()
    }

    private func reloadLayouts() {
        let entries = InputSources.enabledLayouts()
        latin = entries.first { $0.layout.script == .latin }
        cyrillic = entries.first { $0.layout.script == .cyrillic }
        if let latin, let cyrillic {
            converter = LayoutConverter(latin: latin.layout, cyrillic: cyrillic.layout)
            log.info("layouts: \(latin.layout.id, privacy: .public) <-> \(cyrillic.layout.id, privacy: .public)")
        } else {
            converter = nil
            log.error("need one Latin and one Cyrillic keyboard layout enabled")
        }
    }

    // MARK: - Conversion flow

    /// - Parameter likelySelected: what the input history suggests about the focused field.
    func convertSelection(likelySelected: Bool?) {
        guard !busy, let converter else { return }
        busy = true
        var timeline = Timeline()
        let snapshot = PasteboardSnapshot(of: pasteboard)
        timeline.mark("snapshot")

        // Go straight for the word before the cursor only when the input history says there
        // is no selection and Accessibility does not contradict it. Any doubt means ⌘C first:
        // the word path moves the selection around, which would wreck an existing one.
        let noSelection = likelySelected == false && !FocusedSelection.reportsSelection()
        timeline.mark(noSelection ? "word" : "copy")

        let finish: @MainActor (CopyResult) -> Void = { [self] result in
            switch result {
            case .text(let text):
                replace(text, using: converter, snapshot: snapshot, timeline: timeline)
            case .unusable:
                snapshot.restore(to: pasteboard)
                busy = false
            case .nothing:
                busy = false
            }
        }

        if noSelection {
            copyWordBeforeCursor(using: converter, completion: finish)
            return
        }
        copySelection { [self] result in
            guard case .nothing = result else { return finish(result) }
            // ⌘C copied nothing: either there was no selection after all, or the app does not
            // support ⌘C at all (menu bar apps without an Edit menu).
            if replaceViaAccessibility(wholeSelection: true, using: converter) {
                busy = false
            } else {
                copyWordBeforeCursor(using: converter, completion: finish)
            }
        }
    }

    /// Reads and rewrites the focused field through Accessibility, with no clipboard or
    /// keystrokes. Converts the selection when `wholeSelection` is set and one exists,
    /// otherwise the token ending at the caret (or at the end of the selection we made).
    private func replaceViaAccessibility(wholeSelection: Bool, using converter: LayoutConverter) -> Bool {
        guard let field = AXTextField.focused() else { return false }
        let range: Range<Int>
        if wholeSelection && !field.selection.isEmpty {
            range = field.selection
        } else {
            let end = field.selection.upperBound
            let token = lastToken(in: field.text(in: 0..<end)).token
            guard !token.isEmpty else { return false }
            range = (end - token.utf16.count)..<end
        }
        let text = field.text(in: range)
        let current = currentScript()
        let converted = converter.flip(text, unknownScript: current ?? .latin)
        guard field.replace(range, with: converted) else { return false }
        switchLayout(after: converted, current: current)
        log.info("\(text.count) chars via accessibility")
        return true
    }

    /// Selects from the start of the line to the cursor (⇧⌘←), copies that, shrinks the
    /// selection with ⇧→ to the last whitespace-delimited token, then copies once more to check
    /// that exactly the token is selected. On any mismatch the selection is collapsed and
    /// nothing is changed.
    ///
    /// Word-wise ⌥⇧← would not do: macOS stops at symbols, so from "nj;е" it grabs just "е".
    private func copyWordBeforeCursor(using converter: LayoutConverter, completion: @escaping @MainActor (CopyResult) -> Void) {
        Keystroke.post(Keystroke.leftArrow, flags: [.maskCommand, .maskShift])
        copySelection { [self] result in
            guard case .text(let line) = result else {
                if case .nothing = result, replaceViaAccessibility(wholeSelection: false, using: converter) {
                    return completion(.nothing)
                }
                collapseSelection()
                return completion(result)
            }
            let (prefixLength, token) = lastToken(in: line)
            guard !token.isEmpty else {
                collapseSelection()
                return completion(.unusable)
            }
            // The whole line is the token: it is already selected and copied.
            guard prefixLength > 0 else { return completion(.text(token)) }

            for _ in 0..<prefixLength {
                Keystroke.post(Keystroke.rightArrow, flags: .maskShift)
            }
            copySelection { [self] result in
                if case .text(let selected) = result, selected == token {
                    completion(.text(token))
                } else {
                    log.info("word selection did not verify; leaving the text alone")
                    collapseSelection()
                    completion(.unusable)
                }
            }
        }
    }

    /// Plain → collapses a selection to its end, which is where the cursor was.
    private func collapseSelection() {
        Keystroke.post(Keystroke.rightArrow, flags: [])
    }

    private func replace(_ text: String, using converter: LayoutConverter, snapshot: PasteboardSnapshot, timeline: Timeline) {
        var timeline = timeline
        timeline.mark("copied")
        let current = currentScript()
        let converted = converter.flip(text, unknownScript: current ?? .latin)

        pasteboard.clearContents()
        pasteboard.setString(converted, forType: .string)
        Keystroke.post(Keystroke.v, flags: .maskCommand)
        timeline.mark("pasted")

        // Switch only once the app has handled ⌘V: a key event is interpreted in the layout
        // current at delivery, and some apps would read it as ⌘М after a switch to Cyrillic.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
            switchLayout(after: converted, current: current)
        }
        log.info("\(text.count) chars: \(timeline.summary, privacy: .public)")

        // Give the target app time to read the pasteboard before putting the old contents back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            snapshot.restore(to: pasteboard)
            busy = false
        }
    }

    /// Millisecond marks since the hotkey fired, for the log.
    private struct Timeline {
        private let started = CFAbsoluteTimeGetCurrent()
        private var marks: [String] = []

        mutating func mark(_ label: String) {
            marks.append("\(label) \(Int((CFAbsoluteTimeGetCurrent() - started) * 1000))ms")
        }

        var summary: String { marks.joined(separator: ", ") }
    }

    private enum CopyResult {
        /// The pasteboard received this text.
        case text(String)
        /// The pasteboard changed but holds nothing to convert; it needs restoring.
        case unusable
        /// The pasteboard did not change: nothing was copied.
        case nothing
    }

    /// Posts ⌘C and reports what landed on the pasteboard within ~300 ms.
    private func copySelection(completion: @escaping @MainActor (CopyResult) -> Void) {
        let changeCountBefore = pasteboard.changeCount
        Keystroke.post(Keystroke.c, flags: .maskCommand)
        waitForPasteboardChange(since: changeCountBefore, attemptsLeft: 30) { [self] changed in
            guard changed else { return completion(.nothing) }
            if let text = pasteboard.string(forType: .string), !text.isEmpty {
                completion(.text(text))
            } else {
                completion(.unusable)
            }
        }
    }

    /// Polls `changeCount` every 10 ms (only while a conversion is in flight).
    private func waitForPasteboardChange(since count: Int, attemptsLeft: Int, completion: @escaping @MainActor (Bool) -> Void) {
        if pasteboard.changeCount != count { return completion(true) }
        if attemptsLeft == 0 { return completion(false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [self] in
            waitForPasteboardChange(since: count, attemptsLeft: attemptsLeft - 1, completion: completion)
        }
    }

    private func currentScript() -> Script? {
        guard let id = InputSources.currentLayoutID() else { return nil }
        if id == latin?.layout.id { return .latin }
        if id == cyrillic?.layout.id { return .cyrillic }
        return nil
    }

    /// Continue typing in the layout of the last letter, where the cursor now is.
    private func switchLayout(after converted: String, current: Script?) {
        if let target = lastScript(of: converted) ?? current?.opposite {
            switchLayout(to: target)
        }
    }

    private func switchLayout(to script: Script) {
        guard let entry = script == .latin ? latin : cyrillic else { return }
        InputSources.select(entry.source)
    }
}
