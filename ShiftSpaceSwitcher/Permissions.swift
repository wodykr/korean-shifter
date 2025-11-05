import AppKit
import ApplicationServices

enum Permissions {
    static func openInputMonitoring() {
        // Open System Settings to Input Monitoring page
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openAccessibility() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    static func promptForAccessibilityPermission() -> Bool {
        let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
