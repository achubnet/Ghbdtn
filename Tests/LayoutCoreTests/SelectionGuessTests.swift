import Testing
@testable import LayoutCore

@Suite struct SelectionGuessTests {
    @Test func startsUndecided() {
        #expect(SelectionGuess().hasSelection == nil)
    }

    @Test func plainTypingMeansNoSelection() {
        var guess = SelectionGuess()
        guess.keyDown(command: false, shift: false, navigation: false)
        #expect(guess.hasSelection == false)
    }

    @Test func shiftNavigationMeansSelection() {
        var guess = SelectionGuess()
        guess.keyDown(command: false, shift: false, navigation: false)
        guess.keyDown(command: false, shift: true, navigation: true)
        #expect(guess.hasSelection == true)
    }

    @Test func shiftedLetterIsStillTyping() {
        var guess = SelectionGuess()
        guess.keyDown(command: false, shift: true, navigation: false)
        #expect(guess.hasSelection == false)
    }

    @Test func selectAllMeansSelection() {
        var guess = SelectionGuess()
        guess.keyDown(command: false, shift: false, navigation: false)
        guess.selectAll()
        #expect(guess.hasSelection == true)
    }

    @Test func mouseDragAndMultiClickMeanSelection() {
        var guess = SelectionGuess()
        guess.keyDown(command: false, shift: false, navigation: false)
        guess.mouseDragged()
        #expect(guess.hasSelection == true)

        guess.keyDown(command: false, shift: false, navigation: false)
        guess.mouseDown(clickCount: 2, shift: false)
        #expect(guess.hasSelection == true)
    }

    @Test func singleClickAndPlainArrowsMeanNoSelection() {
        var guess = SelectionGuess()
        guess.mouseDragged()
        guess.mouseDown(clickCount: 1, shift: false)
        #expect(guess.hasSelection == false)

        guess.mouseDragged()
        guess.keyDown(command: false, shift: false, navigation: true)
        #expect(guess.hasSelection == false)
    }

    @Test func shiftClickExtendsSelection() {
        var guess = SelectionGuess()
        guess.keyDown(command: false, shift: false, navigation: false)
        guess.mouseDown(clickCount: 1, shift: true)
        #expect(guess.hasSelection == true)
    }

    @Test func shiftCommandNavigationSelectsToo() {
        var guess = SelectionGuess()
        guess.keyDown(command: false, shift: false, navigation: false)
        guess.keyDown(command: true, shift: true, navigation: true)
        #expect(guess.hasSelection == true)
    }

    @Test func commandShortcutsLeaveTheGuessAlone() {
        var guess = SelectionGuess()
        guess.mouseDragged()
        guess.keyDown(command: true, shift: false, navigation: false)
        #expect(guess.hasSelection == true)
    }

    @Test func typingAfterSelectionReplacesIt() {
        var guess = SelectionGuess()
        guess.mouseDragged()
        guess.keyDown(command: false, shift: false, navigation: false)
        #expect(guess.hasSelection == false)
    }
}
