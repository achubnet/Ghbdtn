import Foundation
import os

extension Logger {
    /// A logger under the app's bundle identifier.
    init(category: String) {
        self.init(subsystem: Bundle.main.bundleIdentifier ?? "Ghbdtn", category: category)
    }
}
