import Foundation

final class AppSettings {
    static let shared = AppSettings()

    private enum Key: String {
        case isEnabled
        case disableAnimation
        case showMiniHUD
        case methodRawValue
        case multiTapEnabled
    }

    private let defaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.isEnabled.rawValue: true,
            Key.disableAnimation.rawValue: true,
            Key.showMiniHUD.rawValue: false,
            Key.methodRawValue.rawValue: InputSwitch.Method.tisToggle.rawValue,
            Key.multiTapEnabled.rawValue: true
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.isEnabled.rawValue) }
    }

    var disableAnimation: Bool {
        get { defaults.bool(forKey: Key.disableAnimation.rawValue) }
        set { defaults.set(newValue, forKey: Key.disableAnimation.rawValue) }
    }

    var showMiniHUD: Bool {
        get { defaults.bool(forKey: Key.showMiniHUD.rawValue) }
        set { defaults.set(newValue, forKey: Key.showMiniHUD.rawValue) }
    }

    var multiTapEnabled: Bool {
        get { defaults.bool(forKey: Key.multiTapEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.multiTapEnabled.rawValue) }
    }

    var method: InputSwitch.Method {
        get {
            let rawValue = defaults.integer(forKey: Key.methodRawValue.rawValue)
            return InputSwitch.Method(rawValue: rawValue) ?? .tisToggle
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.methodRawValue.rawValue)
        }
    }
}
