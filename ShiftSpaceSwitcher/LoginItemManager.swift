import Foundation
import ServiceManagement

@available(macOS 13.0, *)
final class LoginItemManager {
    static let shared = LoginItemManager()
    
    private init() {}
    
    var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
    }
    
    func enable() throws {
        print("🚀 Enabling login item...")
        do {
            try SMAppService.mainApp.register()
            print("  ✅ Login item registered")
        } catch {
            print("  ❌ Failed to register login item: \(error)")
            throw error
        }
    }
    
    func disable() throws {
        print("🛑 Disabling login item...")
        do {
            try SMAppService.mainApp.unregister()
            print("  ✅ Login item unregistered")
        } catch {
            print("  ❌ Failed to unregister login item: \(error)")
            throw error
        }
    }
    
    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}
