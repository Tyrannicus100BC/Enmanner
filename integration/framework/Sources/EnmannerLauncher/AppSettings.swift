import Foundation

@MainActor
final class AppSettings {
    private enum Key {
        static let pageZoom = "EnmannerPageZoom"
        static let opensExternalLinksInBrowser = "EnmannerOpensExternalLinksInBrowser"
        static let includesRecentOutputInErrors = "EnmannerIncludesRecentOutputInErrors"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var pageZoom: Double {
        get {
            guard defaults.object(forKey: Key.pageZoom) != nil else { return 1 }
            return min(max(defaults.double(forKey: Key.pageZoom), 0.5), 2)
        }
        set {
            defaults.set(min(max(newValue, 0.5), 2), forKey: Key.pageZoom)
        }
    }

    var opensExternalLinksInBrowser: Bool {
        get {
            guard defaults.object(forKey: Key.opensExternalLinksInBrowser) != nil else {
                return true
            }
            return defaults.bool(forKey: Key.opensExternalLinksInBrowser)
        }
        set {
            defaults.set(newValue, forKey: Key.opensExternalLinksInBrowser)
        }
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
