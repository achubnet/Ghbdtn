/// The writing system a piece of text (or a keyboard layout) belongs to.
public enum Script: Sendable, Equatable {
    case latin
    case cyrillic

    public var opposite: Script {
        switch self {
        case .latin: return .cyrillic
        case .cyrillic: return .latin
        }
    }
}

extension Character {
    var isCyrillicLetter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        // Cyrillic + Cyrillic Supplement blocks.
        return (0x0400...0x052F).contains(scalar.value)
    }

    var isLatinLetter: Bool {
        isASCII && isLetter
    }

    var script: Script? {
        if isCyrillicLetter { return .cyrillic }
        if isLatinLetter { return .latin }
        return nil
    }
}

/// The script of the last letter in the text; `nil` when it has no letters at all.
public func lastScript(of text: String) -> Script? {
    text.last { $0.script != nil }?.script
}

/// Which script the text is mostly written in; `nil` when it has no letters at all.
public func dominantScript(of text: String) -> Script? {
    var latin = 0
    var cyrillic = 0
    for character in text {
        switch character.script {
        case .latin: latin += 1
        case .cyrillic: cyrillic += 1
        case nil: continue
        }
    }
    if latin == 0 && cyrillic == 0 { return nil }
    return cyrillic > latin ? .cyrillic : .latin
}
