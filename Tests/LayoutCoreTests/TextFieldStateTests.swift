import Testing
@testable import LayoutCore

@Suite struct TextFieldStateTests {
    @Test func rejectsSelectionOutsideTheValue() {
        #expect(TextFieldState(value: "abc", selection: 2..<4) == nil)
        #expect(TextFieldState(value: "abc", selection: 3..<3) != nil)
    }

    @Test func editsTheSelectionWhenThereIsOne() throws {
        let field = try #require(TextFieldState(value: "hello ghbdtn", selection: 0..<5))
        #expect(field.editRange(.selectionOrLastWord) == 0..<5)
    }

    @Test func editsTheTokenBeforeTheCaretWithoutASelection() throws {
        let field = try #require(TextFieldState(value: "hello nj;t", selection: 10..<10))
        let range = try #require(field.editRange(.selectionOrLastWord))
        #expect(range == 6..<10)
        #expect(field.text(in: range) == "nj;t")
    }

    @Test func lastWordEndsAtTheEndOfTheSelection() throws {
        // After ⇧⌘← the selection runs from the line start to the caret.
        let field = try #require(TextFieldState(value: "a cegth^", selection: 0..<8))
        #expect(field.editRange(.lastWord) == 2..<8)
    }

    @Test func noTokenMeansNothingToEdit() throws {
        let field = try #require(TextFieldState(value: "a   ", selection: 4..<4))
        #expect(field.editRange(.lastWord) == 0..<4) // trailing spaces stay with the token
        let blank = try #require(TextFieldState(value: "   ", selection: 3..<3))
        #expect(blank.editRange(.lastWord) == nil)
    }

    @Test func offsetsAreUTF16() throws {
        let field = try #require(TextFieldState(value: "🙂 ghbdtn", selection: 9..<9))
        let range = try #require(field.editRange(.lastWord))
        #expect(range == 3..<9)
        #expect(field.text(in: range) == "ghbdtn")
    }
}
