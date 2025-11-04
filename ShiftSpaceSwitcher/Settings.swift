import Foundation

final class AppSettings {
    static let shared = AppSettings()

    private enum Key: String {
        case isEnabled
        case showMiniHUD
        case multiTapEnabled
        case loginItemEnabled
        case disableAnimation
    }

    private let defaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.isEnabled.rawValue: false,  // Start disabled, user must explicitly enable
            Key.showMiniHUD.rawValue: false,
            Key.multiTapEnabled.rawValue: true,
            Key.loginItemEnabled.rawValue: false,
            Key.disableAnimation.rawValue: false
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.isEnabled.rawValue) }
    }

    var showMiniHUD: Bool {
        get { defaults.bool(forKey: Key.showMiniHUD.rawValue) }
        set { defaults.set(newValue, forKey: Key.showMiniHUD.rawValue) }
    }

    var multiTapEnabled: Bool {
        get { defaults.bool(forKey: Key.multiTapEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.multiTapEnabled.rawValue) }
    }

    var loginItemEnabled: Bool {
        get { defaults.bool(forKey: Key.loginItemEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.loginItemEnabled.rawValue) }
    }

    var disableAnimation: Bool {
        get { defaults.bool(forKey: Key.disableAnimation.rawValue) }
        set { defaults.set(newValue, forKey: Key.disableAnimation.rawValue) }
    }
}
