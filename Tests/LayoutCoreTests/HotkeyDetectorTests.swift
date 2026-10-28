import Testing
@testable import LayoutCore

@Suite struct HotkeyDetectorTests {
    @Test func firesWhenOptionAndCommandAreTappedTogether() {
        var detector = HotkeyDetector()
        #expect(detector.flagsChanged(option: false, command: true, other: false) == false)
        #expect(detector.flagsChanged(option: true, command: true, other: false) == false)
        #expect(detector.flagsChanged(option: false, command: true, other: false) == false)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == true)
    }

    @Test func firesRegardlessOfReleaseOrder() {
        var detector = HotkeyDetector()
        _ = detector.flagsChanged(option: true, command: false, other: false)
        _ = detector.flagsChanged(option: true, command: true, other: false)
        _ = detector.flagsChanged(option: true, command: false, other: false)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == true)
    }

    @Test func doesNotFireWhenAnotherKeyWasPressedWhileHeld() {
        var detector = HotkeyDetector()
        _ = detector.flagsChanged(option: true, command: true, other: false)
        detector.keyDown()
        #expect(detector.flagsChanged(option: false, command: false, other: false) == false)
    }

    @Test func doesNotFireWhenAnotherModifierJoined() {
        var detector = HotkeyDetector()
        _ = detector.flagsChanged(option: true, command: true, other: false)
        _ = detector.flagsChanged(option: true, command: true, other: true)
        _ = detector.flagsChanged(option: true, command: true, other: false)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == false)
    }

    @Test func doesNotFireForSingleModifier() {
        var detector = HotkeyDetector()
        _ = detector.flagsChanged(option: false, command: true, other: false)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == false)
    }

    @Test func recoversAfterTaintedSequence() {
        var detector = HotkeyDetector()
        // ⌘C
        _ = detector.flagsChanged(option: false, command: true, other: false)
        detector.keyDown()
        _ = detector.flagsChanged(option: false, command: false, other: false)
        // clean ⌥⌘ tap
        _ = detector.flagsChanged(option: true, command: true, other: false)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == true)
    }

    @Test func plainTypingBeforeTheTapDoesNotTaint() {
        var detector = HotkeyDetector()
        detector.keyDown()
        detector.keyDown()
        _ = detector.flagsChanged(option: true, command: true, other: false)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == true)
    }

    @Test func firesOnlyOncePerTap() {
        var detector = HotkeyDetector()
        _ = detector.flagsChanged(option: true, command: true, other: false)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == true)
        #expect(detector.flagsChanged(option: false, command: false, other: false) == false)
    }
}
