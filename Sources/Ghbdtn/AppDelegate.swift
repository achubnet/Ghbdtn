import AppKit
import ApplicationServices
import LayoutCore
import ServiceManagement
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let log = Logger(subsystem: "com.skriptoff.Ghbdtn", category: "app")
    private let converter = SelectionConverter()
    private var detector = HotkeyDetector()
    private var selectionGuess = SelectionGuess()

    /// Arrows, Home/End, Page Up/Down: keys that move the caret (and extend a selection with Shift).
    private static let navigationKeyCodes: Set<UInt16> = [123, 124, 125, 126, 115, 119, 116, 121]
    private static let keyCodeA: UInt16 = 0

    private var statusItem: NSStatusItem!
    private var eventMonitor: Any?
    private var trustPollTimer: Timer?

    private let launchAtLoginItem = NSMenuItem(title: "Запуск при старте", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Разрешить доступ в Универсальном доступе…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let layoutsItem = NSMenuItem(title: "Нужны раскладки: латиница и кириллица", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        enableLaunchAtLoginOnFirstRun()
        startMonitoringWhenTrusted()
    }

    // MARK: - Status item & menu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = StatusIcon.image()

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        launchAtLoginItem.target = self
        accessibilityItem.target = self
        layoutsItem.isEnabled = false
        menu.addItem(launchAtLoginItem)
        menu.addItem(accessibilityItem)
        menu.addItem(layoutsItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        accessibilityItem.isHidden = AXIsProcessTrusted()
        layoutsItem.isHidden = converter.isReady
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            log.error("login item toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func enableLaunchAtLoginOnFirstRun() {
        let key = "didConfigureLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            // Happens when run outside an .app bundle; will retry on next launch.
            log.error("login item registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Hotkey monitoring

    /// Global key monitors only deliver events once the app is trusted for Accessibility,
    /// so ask for the permission and install the monitor as soon as it is granted.
    private func startMonitoringWhenTrusted() {
        // Same key as kAXTrustedCheckOptionPrompt, which Swift 6 rejects as non-Sendable global state.
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            installEventMonitor()
            return
        }
        trustPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted() else { return }
                self.trustPollTimer?.invalidate()
                self.trustPollTimer = nil
                self.installEventMonitor()
            }
        }
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        let events: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .leftMouseDragged]
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { event in
            MainActor.assumeIsolated {
                (NSApp.delegate as? AppDelegate)?.handle(event)
            }
        }
        log.info("hotkey monitor installed")
    }

    private func handle(_ event: NSEvent) {
        // ⌘C / ⌥⇧← / ⌘V that we post ourselves say nothing about what the user did.
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
            if fired { converter.convertSelection(likelySelected: selectionGuess.hasSelection) }
        default:
            break
        }
    }
}
