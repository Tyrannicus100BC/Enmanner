import Foundation

@MainActor
final class AppSettings {
    private enum Key {
        static let includesRecentOutputInErrors = "EnmannerIncludesRecentOutputInErrors"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var includesRecentOutputInErrors: Bool {
        get {
            guard defaults.object(forKey: Key.includesRecentOutputInErrors) != nil else {
                return true
            }
            return defaults.bool(forKey: Key.includesRecentOutputInErrors)
        }
        set {
            defaults.set(newValue, forKey: Key.includesRecentOutputInErrors)
        }
    }
}
