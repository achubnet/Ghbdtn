import Testing
@testable import LayoutCore

@Suite struct FlipTests {
    let converter = Fixtures.converter

    @Test func flipsEachLetterToTheOppositeLayout() {
        #expect(converter.flip("ghbdtn как дела", unknownScript: .latin) == "привет rfr ltkf")
        #expect(converter.flip("привет rfr ltkf", unknownScript: .latin) == "ghbdtn как дела")
    }

    @Test func preservesCaseWhileFlipping() {
        #expect(converter.flip("Ghbdtn Мир", unknownScript: .latin) == "Привет Vbh")
    }

    @Test func punctuationFollowsTheLettersOfItsWord() {
        // "^" sits in a Latin word, so it is read as a Latin keystroke → Cyrillic ",".
        #expect(converter.flip("ghbdtn^ rfr", unknownScript: .cyrillic) == "привет, как")
        // "б" is Cyrillic, "." belongs to that word → Latin "&" (Shift+7 in the fixture).
        #expect(converter.flip("б.", unknownScript: .latin) == ",&")
    }

    @Test func punctuationInWordWithoutLettersUsesTheTextsDominantScript() {
        #expect(converter.flip("ghbdtn ;", unknownScript: .cyrillic) == "привет ж")
    }

    @Test func textWithoutLettersUsesTheGivenScript() {
        #expect(converter.flip(";", unknownScript: .latin) == "ж")
        #expect(converter.flip("ж", unknownScript: .cyrillic) == ";")
        #expect(converter.flip("&", unknownScript: .cyrillic) == "&")
    }

    @Test func leavesUnmappedCharactersAlone() {
        #expect(converter.flip("123\n🙂", unknownScript: .latin) == "123\n🙂")
    }
}

@Suite struct LastScriptTests {
    @Test func returnsScriptOfTheLastLetter() {
        #expect(lastScript(of: "привет rfr") == .latin)
        #expect(lastScript(of: "hello мир!") == .cyrillic)
    }

    @Test func nilWhenThereAreNoLetters() {
        #expect(lastScript(of: "123 ;") == nil)
    }
}
