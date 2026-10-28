/// Tracks input events to guess whether the focused text field currently has a selection.
/// This is what decides between "convert the selection" and "convert the last word", so it
/// errs towards "there is a selection": that path never modifies text it has not copied.
public struct SelectionGuess: Sendable {
    /// `nil` until the user has done something that tells us either way.
    public private(set) var hasSelection: Bool?

    public init() {}

    /// Shift with a navigation key extends a selection (with or without ⌘: ⇧⌘← selects to the
    /// line start). Other ⌘ shortcuts say nothing. Anything else types or moves the caret,
    /// which collapses a selection.
    public mutating func keyDown(command: Bool, shift: Bool, navigation: Bool) {
        if shift && navigation {
            hasSelection = true
        } else if !command {
            hasSelection = false
        }
    }

    public mutating func selectAll() {
        hasSelection = true
    }

    /// A double or triple click selects a word or a line, a shift-click extends the selection;
    /// a plain single click just moves the caret.
    public mutating func mouseDown(clickCount: Int, shift: Bool) {
        hasSelection = clickCount > 1 || shift
    }

    public mutating func mouseDragged() {
        hasSelection = true
    }
}
