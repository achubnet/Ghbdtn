import AppKit
import LayoutCore

/// `ClipboardTextIO` over the general pasteboard and synthetic key presses.
@MainActor
final class SystemClipboardTextIO: ClipboardTextIO {
    private let pasteboard = NSPasteboard.general
    private var saved: (snapshot: PasteboardSnapshot, changeCount: Int)?

    func saveClipboard() {
        saved = (PasteboardSnapshot(of: pasteboard), pasteboard.changeCount)
    }

    func restoreClipboard() {
        defer { saved = nil }
        guard let saved, pasteboard.changeCount != saved.changeCount else { return }
        saved.snapshot.restore(to: pasteboard)
    }

    func copy() async -> CopyResult {
        let before = pasteboard.changeCount
        Keystroke.post(Keystroke.c, flags: .maskCommand)
        // NSPasteboard has no change notification: poll for up to 300 ms, only while converting.
        for _ in 0..<30 where pasteboard.changeCount == before {
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard pasteboard.changeCount != before else { return .nothing }
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return .unusable }
        return .text(text)
    }

    func paste(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Keystroke.post(Keystroke.v, flags: .maskCommand)
    }

    func selectToLineStart() {
        Keystroke.post(Keystroke.leftArrow, flags: [.maskCommand, .maskShift])
    }

    func shrinkSelectionFromStart(by count: Int) {
        for _ in 0..<count {
            Keystroke.post(Keystroke.rightArrow, flags: .maskShift)
        }
    }

    func collapseSelection() {
        Keystroke.post(Keystroke.rightArrow, flags: [])
    }
}

/// A deep copy of the pasteboard contents that can be written back later.
@MainActor
private struct PasteboardSnapshot {
    private let items: [NSPasteboardItem]

    init(of pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
