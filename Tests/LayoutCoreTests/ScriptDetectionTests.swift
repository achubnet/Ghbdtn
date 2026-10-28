import Testing
@testable import LayoutCore

@Suite struct ScriptDetectionTests {
    @Test func latinTextIsLatin() {
        #expect(dominantScript(of: "ghbdtn rfr ltkf") == .latin)
    }

    @Test func cyrillicTextIsCyrillic() {
        #expect(dominantScript(of: "привет как дела") == .cyrillic)
    }

    @Test func majorityWinsInMixedText() {
        #expect(dominantScript(of: "привет hi") == .cyrillic)
        #expect(dominantScript(of: "hello мир") == .latin)
    }

    @Test func textWithoutLettersHasNoScript() {
        #expect(dominantScript(of: "123 ;'[] !?") == nil)
        #expect(dominantScript(of: "") == nil)
    }

    @Test func cyrillicExtrasCount() {
        // ё and Ё live outside the basic а-я range but are still Cyrillic.
        #expect(dominantScript(of: "ёЁ") == .cyrillic)
    }
}
