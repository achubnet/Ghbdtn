import Testing
@testable import LayoutCore

/// A subset of the real macOS ABC and Russian layouts keyed by virtual keycode.
enum Fixtures {
    // keycode: (abcBase, abcShift, ruBase, ruShift)
    static let keys: [Int: (Character, Character, Character, Character)] = [
        0: ("a", "A", "ф", "Ф"), 1: ("s", "S", "ы", "Ы"), 2: ("d", "D", "в", "В"),
        3: ("f", "F", "а", "А"), 4: ("h", "H", "р", "Р"), 5: ("g", "G", "п", "П"),
        6: ("z", "Z", "я", "Я"), 7: ("x", "X", "ч", "Ч"), 8: ("c", "C", "с", "С"),
        9: ("v", "V", "м", "М"), 11: ("b", "B", "и", "И"), 12: ("q", "Q", "й", "Й"),
        13: ("w", "W", "ц", "Ц"), 14: ("e", "E", "у", "У"), 15: ("r", "R", "к", "К"),
        16: ("y", "Y", "н", "Н"), 17: ("t", "T", "е", "Е"), 22: ("6", "^", "6", ","),
        26: ("7", "&", "7", "."),
        30: ("]", "}", "ъ", "Ъ"), 31: ("o", "O", "щ", "Щ"), 32: ("u", "U", "г", "Г"),
        33: ("[", "{", "х", "Х"), 34: ("i", "I", "ш", "Ш"), 35: ("p", "P", "з", "З"),
        37: ("l", "L", "д", "Д"), 38: ("j", "J", "о", "О"), 39: ("'", "\"", "э", "Э"),
        40: ("k", "K", "л", "Л"), 41: (";", ":", "ж", "Ж"), 43: (",", "<", "б", "Б"),
        42: ("\\", "|", "ё", "Ё"), 44: ("/", "?", "/", "?"), 45: ("n", "N", "т", "Т"),
        46: ("m", "M", "ь", "Ь"), 47: (".", ">", "ю", "Ю"), 49: (" ", " ", " ", " "),
    ]

    static let abc = KeyboardLayout(
        id: "com.apple.keylayout.ABC",
        keys: keys.mapValues { KeyCap(base: $0.0, shift: $0.1) }
    )

    static let russian = KeyboardLayout(
        id: "com.apple.keylayout.Russian",
        keys: keys.mapValues { KeyCap(base: $0.2, shift: $0.3) }
    )

    static let converter = LayoutConverter(latin: abc, cyrillic: russian)
}

@Suite struct LayoutConverterTests {
    let converter = Fixtures.converter

    @Test func convertsLatinTypedTextToCyrillic() {
        #expect(converter.convert("ghbdtn rfr ltkf", to: .cyrillic) == "привет как дела")
    }

    @Test func convertsCyrillicTypedTextToLatin() {
        #expect(converter.convert("привет как дела", to: .latin) == "ghbdtn rfr ltkf")
    }

    @Test func preservesLetterCase() {
        #expect(converter.convert("Ghbdtn", to: .cyrillic) == "Привет")
        #expect(converter.convert("ПРИВЕТ", to: .latin) == "GHBDTN")
    }

    @Test func mapsPunctuationByKeyPosition() {
        #expect(converter.convert(";'[]\\", to: .cyrillic) == "жэхъё")
        #expect(converter.convert(",.&", to: .cyrillic) == "бю.")
        #expect(converter.convert("жэхъё", to: .latin) == ";'[]\\")
        #expect(converter.convert("бю.", to: .latin) == ",.&")
    }

    @Test func leavesUnmappedCharactersAlone() {
        #expect(converter.convert("123/?\n🙂", to: .cyrillic) == "123/?\n🙂")
        #expect(converter.convert("123/?\n🙂", to: .latin) == "123/?\n🙂")
    }

    @Test func prefersUnshiftedKeyWhenCharacterExistsOnSeveralKeys() {
        // Some layouts (e.g. Russian – PC) put the same character on two keys;
        // the unshifted position wins so the result is deterministic.
        let latin = KeyboardLayout(id: "l", keys: [26: KeyCap(base: "7", shift: "&"), 44: KeyCap(base: "/", shift: "?")])
        let cyrillic = KeyboardLayout(id: "c", keys: [26: KeyCap(base: "7", shift: "."), 44: KeyCap(base: ".", shift: ",")])
        let converter = LayoutConverter(latin: latin, cyrillic: cyrillic)
        #expect(converter.convert(".", to: .latin) == "/")
    }
}

@Suite struct KeyboardLayoutScriptTests {
    @Test func classifiesLayoutsByTheLettersTheyProduce() {
        #expect(Fixtures.abc.script == .latin)
        #expect(Fixtures.russian.script == .cyrillic)
    }

    @Test func layoutWithoutLettersHasNoScript() {
        let digits = KeyboardLayout(id: "x", keys: [18: KeyCap(base: "1", shift: "!")])
        #expect(digits.script == nil)
    }
}
