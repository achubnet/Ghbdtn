import AppKit
import LayoutCore
import os

/// Composition root: wires the system services to the conversion flow and the menu.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(category: "app")
    private let layouts: SystemLayouts
    private let converter: SelectionConverter
    private let input = InputMonitor()
    private var menu: StatusMenu?

    override init() {
        let layouts = SystemLayouts()
        self.layouts = layouts
        converter = SelectionConverter(
            layouts: layouts,
            clipboard: SystemClipboardTextIO(),
            accessibility: SystemAccessibilityTextIO()
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menu = StatusMenu(layouts: layouts)
        LoginItem.enableOnFirstRun()
        input.onHotkey = { [weak self] likelySelected in
            guard let self else { return }
            Task {
                let outcome = await self.converter.convert(likelySelected: likelySelected)
                self.log.info("\(String(describing: outcome), privacy: .public)")
            }
        }
        input.start()
    }
}
