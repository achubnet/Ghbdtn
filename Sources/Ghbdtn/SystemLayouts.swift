import Carbon
import LayoutCore
import os

/// `LayoutSwitching` over the enabled system layouts: the first Latin and the first Cyrillic
/// one, refreshed whenever the user changes their input sources.
@MainActor
final class SystemLayouts: LayoutSwitching {
    private let log = Logger(category: "layouts")
    private var latin: InputSources.Entry?
    private var cyrillic: InputSources.Entry?
    private(set) var converter: LayoutConverter?
    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    var currentScript: Script? {
        guard let id = InputSources.currentLayoutID() else { return nil }
        if id == latin?.layout.id { return .latin }
        if id == cyrillic?.layout.id { return .cyrillic }
        return nil
    }

    func select(_ script: Script) {
        guard let entry = script == .latin ? latin : cyrillic else { return }
        InputSources.select(entry.source)
    }

    private func reload() {
        let entries = InputSources.enabledLayouts()
        latin = entries.first { $0.layout.script == .latin }
        cyrillic = entries.first { $0.layout.script == .cyrillic }
        if let latin, let cyrillic {
            converter = LayoutConverter(latin: latin.layout, cyrillic: cyrillic.layout)
            log.info("layouts: \(latin.layout.id, privacy: .public) <-> \(cyrillic.layout.id, privacy: .public)")
        } else {
            converter = nil
            log.error("need one Latin and one Cyrillic keyboard layout enabled")
        }
    }
}
