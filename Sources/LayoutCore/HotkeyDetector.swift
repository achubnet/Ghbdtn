/// Recognises a clean tap of ⌥⌘: both held together, nothing else pressed, then released.
///
/// Feed it modifier-flag changes and key presses; `flagsChanged` returns `true` once per
/// tap, at the moment the last modifier is let go.
public struct HotkeyDetector: Sendable {
    private var sawBothTogether = false
    private var tainted = false
    private var anyModifierDown = false

    public init() {}

    public mutating func flagsChanged(option: Bool, command: Bool, other: Bool) -> Bool {
        anyModifierDown = option || command || other
        if other { tainted = true }
        if option && command && !other { sawBothTogether = true }

        guard !anyModifierDown else { return false }

        let fire = sawBothTogether && !tainted
        sawBothTogether = false
        tainted = false
        return fire
    }

    public mutating func keyDown() {
        if anyModifierDown { tainted = true }
    }
}
