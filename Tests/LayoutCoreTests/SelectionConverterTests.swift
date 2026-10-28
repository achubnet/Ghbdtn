import Testing
@testable import LayoutCore

/// A single-line text field driven the way Ghbdtn drives a real one: synthetic keystrokes and
/// the clipboard, or Accessibility. Offsets are characters; the fixtures are all BMP, so they
/// match the UTF-16 offsets Accessibility uses.
@MainActor
final class FakeTextField: ClipboardTextIO, AccessibilityTextIO {
    private(set) var text: [Character]
    private(set) var selection: Range<Int>
    var string: String { String(text) }

    /// False for apps without an Edit menu, where ⌘C/⌘V do nothing.
    var copyPasteWorks = true
    /// Whether the field exposes its text and selection through Accessibility.
    var accessible = false
    /// Simulates an app whose ⇧→ moves differently than expected.
    var shrinkOvershoot = 0

    private(set) var clipboard = "original clipboard"
    private var savedClipboard: String?
    private(set) var restoreCount = 0

    init(_ text: String, selection: Range<Int>? = nil) {
        self.text = Array(text)
        self.selection = selection ?? self.text.count..<self.text.count
    }

    // MARK: ClipboardTextIO

    func saveClipboard() { savedClipboard = clipboard }

    func restoreClipboard() {
        if let savedClipboard { clipboard = savedClipboard }
        restoreCount += 1
    }

    func copy() async -> CopyResult {
        guard copyPasteWorks, !selection.isEmpty else { return .nothing }
        clipboard = String(text[selection])
        return .text(clipboard)
    }

    func paste(_ string: String) {
        guard copyPasteWorks else { return }
        clipboard = string
        replaceSelection(with: string)
    }

    func selectToLineStart() {
        let caret = selection.upperBound
        let lineStart = text[..<caret].lastIndex(of: "\n").map { $0 + 1 } ?? 0
        selection = lineStart..<caret
    }

    func shrinkSelectionFromStart(by count: Int) {
        let start = min(selection.lowerBound + count + shrinkOvershoot, selection.upperBound)
        selection = start..<selection.upperBound
    }

    func collapseSelection() {
        // Like →: collapses a selection to its end, or moves the caret right without one.
        let caret = selection.isEmpty ? min(selection.upperBound + 1, text.count) : selection.upperBound
        selection = caret..<caret
    }

    // MARK: AccessibilityTextIO

    func reportsSelection() -> Bool { accessible && !selection.isEmpty }

    func focusedField() -> TextFieldState? {
        accessible ? TextFieldState(value: string, selection: selection) : nil
    }

    func replace(_ range: Range<Int>, with string: String) -> Bool {
        guard accessible else { return false }
        selection = range
        replaceSelection(with: string)
        return true
    }

    private func replaceSelection(with string: String) {
        text.replaceSubrange(selection, with: Array(string))
        let caret = selection.lowerBound + string.count
        selection = caret..<caret
    }
}

@MainActor
final class FakeLayouts: LayoutSwitching {
    var converter: LayoutConverter? = Fixtures.converter
    var currentScript: Script?
    private(set) var selected: [Script] = []

    init(current: Script?) { currentScript = current }

    func select(_ script: Script) {
        selected.append(script)
        currentScript = script
    }
}

@MainActor
@Suite struct SelectionConverterTests {
    func run(_ field: FakeTextField, likelySelected: Bool?, layout: Script? = .latin) async -> (ConversionOutcome, FakeLayouts) {
        let layouts = FakeLayouts(current: layout)
        let converter = SelectionConverter(layouts: layouts, clipboard: field, accessibility: field, sleep: { _ in })
        let outcome = await converter.convert(likelySelected: likelySelected)
        return (outcome, layouts)
    }

    @Test func convertsTheWholeSelection() async {
        let text = "lkz ghbdzprb b njulf jyj ghbdz;tn^ dfkblfwb"
        let field = FakeTextField(text, selection: 0..<text.count)
        let (outcome, layouts) = await run(field, likelySelected: true)
        #expect(field.string == "для привязки и тогда оно привяжет, валидаци")
        #expect(outcome == .converted(characters: text.count, method: .clipboard))
        #expect(layouts.selected == [.cyrillic])
    }

    @Test func convertsTheLastWordWithoutASelection() async {
        let field = FakeTextField("привет ghbdtn")
        let (outcome, layouts) = await run(field, likelySelected: false)
        #expect(field.string == "привет привет")
        #expect(outcome == .converted(characters: 6, method: .clipboard))
        #expect(layouts.selected == [.cyrillic])
    }

    @Test func symbolsInsideTheLastWordAreLetters() async {
        let field = FakeTextField("nj;t")
        _ = await run(field, likelySelected: false)
        #expect(field.string == "тоже")

        let other = FakeTextField("cegth^")
        _ = await run(other, likelySelected: false)
        #expect(other.string == "супер,")
    }

    @Test func lastWordOnTheSecondLine() async {
        let field = FakeTextField("first line\nok ghbdtn")
        _ = await run(field, likelySelected: false)
        #expect(field.string == "first line\nok привет")
    }

    @Test func accessibilityOverridesAGuessOfNoSelection() async {
        let field = FakeTextField("ghbdtn rfr", selection: 0..<6)
        field.accessible = true
        _ = await run(field, likelySelected: false)
        #expect(field.string == "привет rfr")
    }

    @Test func unknownSelectionFallsBackToTheLastWord() async {
        let field = FakeTextField("привет ghbdtn")
        _ = await run(field, likelySelected: nil)
        #expect(field.string == "привет привет")
    }

    @Test func unverifiedWordSelectionLeavesTheTextAlone() async {
        let field = FakeTextField("привет ghbdtn")
        field.shrinkOvershoot = 1
        let (outcome, layouts) = await run(field, likelySelected: false)
        #expect(outcome == .selectionNotVerified)
        #expect(field.string == "привет ghbdtn")
        #expect(field.selection.isEmpty)
        #expect(layouts.selected.isEmpty)
    }

    @Test func appsWithoutCopyPasteUseAccessibility() async {
        let field = FakeTextField("привет ghbdtn")
        field.copyPasteWorks = false
        field.accessible = true
        let (outcome, layouts) = await run(field, likelySelected: false)
        #expect(field.string == "привет привет")
        #expect(outcome == .converted(characters: 6, method: .accessibility))
        #expect(layouts.selected == [.cyrillic])
    }

    @Test func appsWithoutCopyPasteConvertTheSelectionThroughAccessibility() async {
        let field = FakeTextField("ghbdtn rfr", selection: 0..<6)
        field.copyPasteWorks = false
        field.accessible = true
        _ = await run(field, likelySelected: true)
        #expect(field.string == "привет rfr")
    }

    @Test func emptyLineHasNothingToConvert() async {
        let field = FakeTextField("")
        let (outcome, layouts) = await run(field, likelySelected: false)
        #expect(outcome == .nothingToConvert)
        #expect(field.string == "")
        #expect(layouts.selected.isEmpty)
    }

    @Test func layoutFollowsTheLastConvertedLetter() async {
        let field = FakeTextField("привет", selection: 0..<6)
        let (_, layouts) = await run(field, likelySelected: true, layout: .cyrillic)
        #expect(field.string == "ghbdtn")
        #expect(layouts.selected == [.latin])
    }

    @Test func clipboardIsRestoredAfterEveryRun() async {
        let converted = FakeTextField("ghbdtn", selection: 0..<6)
        _ = await run(converted, likelySelected: true)
        #expect(converted.clipboard == "original clipboard")
        #expect(converted.restoreCount == 1)

        let untouched = FakeTextField("")
        _ = await run(untouched, likelySelected: false)
        #expect(untouched.clipboard == "original clipboard")
        #expect(untouched.restoreCount == 1)
    }

    @Test func skipsWithoutBothLayouts() async {
        let field = FakeTextField("ghbdtn", selection: 0..<6)
        let layouts = FakeLayouts(current: .latin)
        layouts.converter = nil
        let converter = SelectionConverter(layouts: layouts, clipboard: field, accessibility: field, sleep: { _ in })
        #expect(await converter.convert(likelySelected: true) == .skipped)
        #expect(field.string == "ghbdtn")
    }
}
