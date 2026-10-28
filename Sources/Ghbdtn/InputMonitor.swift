import AppKit
import ApplicationServices
import LayoutCore
import os

/// Watches the keyboard and mouse globally: recognises the ⌥⌘ tap and keeps a guess of whether
/// the focused field has a selection.
@MainActor
final class InputMonitor {
    /// Called on a ⌥⌘ tap with the current guess about the selection.
    var onHotkey: @MainActor (_ likelySelected: Bool?) -> Void = { _ in }

    private let log = Logger(category: "input")
    private var detector = HotkeyDetector()
    private var selectionGuess = SelectionGuess()
    private var monitor: Any?
    private var trustPoll: Timer?

    /// Arrows, Home/End, Page Up/Down: keys that move the caret (and extend a selection with ⇧).
    private static let navigationKeyCodes: Set<UInt16> = [123, 124, 125, 126, 115, 119, 116, 121]
    private static let keyCodeA: UInt16 = 0

    /// Global key monitors get no events until the app is trusted for Accessibility, so this
    /// asks for the permission and starts as soon as it is granted.
    func start() {
        // Same key as kAXTrustedCheckOptionPrompt, which Swift 6 rejects as non-Sendable global state.
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) { return install() }
        // There is no public notification for the grant: check every 2 s until it arrives.
        trustPoll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted() else { return }
                self.trustPoll?.invalidate()
                self.trustPoll = nil
                self.install()
            }
        }
    }

    private func install() {
        guard monitor == nil else { return }
        let events: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .leftMouseDragged]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        log.info("input monitor installed")
    }

    private func handle(_ event: NSEvent) {
        // The ⌘C / ⇧⌘← / ⌘V we post ourselves say nothing about what the user did.
        guard !Keystroke.isOurs(event) else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.type {
        case .keyDown:
            detector.keyDown()
            if flags.contains(.command) && event.keyCode == Self.keyCodeA {
                selectionGuess.selectAll()
            } else {
                selectionGuess.keyDown(
                    command: flags.contains(.command),
                    shift: flags.contains(.shift),
                    navigation: Self.navigationKeyCodes.contains(event.keyCode)
                )
            }
        case .leftMouseDown:
            selectionGuess.mouseDown(clickCount: event.clickCount, shift: flags.contains(.shift))
        case .leftMouseDragged:
            selectionGuess.mouseDragged()
        case .flagsChanged:
            let fired = detector.flagsChanged(
                option: flags.contains(.option),
                command: flags.contains(.command),
                other: flags.contains(.shift) || flags.contains(.control)
            )
            if fired { onHotkey(selectionGuess.hasSelection) }
        default:
            break
        }
    }
}
