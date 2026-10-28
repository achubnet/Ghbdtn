import AppKit
import ApplicationServices
import LayoutCore

/// The menu bar icon and its menu.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let layouts: LayoutSwitching
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let launchAtLoginItem = NSMenuItem(title: "Запуск при старте", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Разрешить доступ в Универсальном доступе…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let layoutsItem = NSMenuItem(title: "Нужны раскладки: латиница и кириллица", action: nil, keyEquivalent: "")

    init(layouts: LayoutSwitching) {
        self.layouts = layouts
        super.init()

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
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    /// Shows the permission and layout hints only while they are needed.
    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = LoginItem.isEnabled ? .on : .off
        accessibilityItem.isHidden = AXIsProcessTrusted()
        layoutsItem.isHidden = layouts.converter != nil
    }

    @objc private func toggleLaunchAtLogin() {
        LoginItem.toggle()
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
