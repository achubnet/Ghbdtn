import Foundation
import ServiceManagement
import os

/// Launch at login, turned on the first time the app runs.
@MainActor
enum LoginItem {
    private static let log = Logger(category: "login-item")
    private static let configuredKey = "didConfigureLoginItem"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func enableOnFirstRun() {
        guard !UserDefaults.standard.bool(forKey: configuredKey) else { return }
        // Fails when run outside an .app bundle; then it is retried on the next launch.
        if setEnabled(true) {
            UserDefaults.standard.set(true, forKey: configuredKey)
        }
    }

    static func toggle() {
        setEnabled(!isEnabled)
    }

    @discardableResult
    private static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            log.error("login item change failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
