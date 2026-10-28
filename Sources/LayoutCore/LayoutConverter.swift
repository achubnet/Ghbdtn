/// Re-types text as if the same keys had been pressed in the other layout.
public struct LayoutConverter: Sendable {
    private let toCyrillic: [Character: Character]
    private let toLatin: [Character: Character]

    public init(latin: KeyboardLayout, cyrillic: KeyboardLayout) {
        toCyrillic = Self.buildMap(from: latin, to: cyrillic)
        toLatin = Self.buildMap(from: cyrillic, to: latin)
    }

    public func convert(_ text: String, to target: Script) -> String {
        let map = map(to: target)
        return String(text.map { map[$0] ?? $0 })
    }

    /// Flips every letter to the layout it was not typed in. Characters without a script
    /// (punctuation, digits) follow the letters of their word, then of the whole text, then
    /// `unknownScript`.
    public func flip(_ text: String, unknownScript: Script) -> String {
        let textScript = dominantScript(of: text) ?? unknownScript
        var result = ""
        var word = ""

        func flushWord() {
            guard !word.isEmpty else { return }
            let wordScript = dominantScript(of: word) ?? textScript
            for character in word {
                let source = character.script ?? wordScript
                result.append(map(to: source.opposite)[character] ?? character)
            }
            word = ""
        }

        for character in text {
            if character.isWhitespace {
                flushWord()
                result.append(character)
            } else {
                word.append(character)
            }
        }
        flushWord()
        return result
    }

    private func map(to target: Script) -> [Character: Character] {
        target == .cyrillic ? toCyrillic : toLatin
    }

    /// Pairs characters that share a key. Unshifted caps are visited first so that a
    /// character present on several keys resolves to its unshifted position.
    private static func buildMap(from source: KeyboardLayout, to target: KeyboardLayout) -> [Character: Character] {
        var map: [Character: Character] = [:]
        let keycodes = source.keys.keys.sorted()
        for pass in [\KeyCap.base, \KeyCap.shift] {
            for keycode in keycodes {
                guard let from = source.keys[keycode]?[keyPath: pass],
                      let to = target.keys[keycode]?[keyPath: pass],
                      map[from] == nil else { continue }
                map[from] = to
            }
        }
        return map
    }
}
