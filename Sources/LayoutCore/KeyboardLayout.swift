/// What one physical key produces in a layout, without and with Shift.
public struct KeyCap: Sendable, Equatable {
    public let base: Character?
    public let shift: Character?

    public init(base: Character?, shift: Character?) {
        self.base = base
        self.shift = shift
    }
}

/// A snapshot of a keyboard layout: for each virtual keycode, the characters it types.
public struct KeyboardLayout: Sendable, Equatable {
    public let id: String
    public let keys: [Int: KeyCap]

    public init(id: String, keys: [Int: KeyCap]) {
        self.id = id
        self.keys = keys
    }

    /// The script most of this layout's letters belong to; `nil` for a layout with no letters.
    public var script: Script? {
        let letters = keys.values.flatMap { [$0.base, $0.shift] }.compactMap { $0 }
        return dominantScript(of: String(letters))
    }
}
