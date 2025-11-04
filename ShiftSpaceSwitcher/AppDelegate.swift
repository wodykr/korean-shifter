import AppKit
import ApplicationServices
import IOKit.hid

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let inputSwitch = InputSwitch()
    private let eventTap = EventTap()
    private let statusMenu = StatusMenu()
    private let tinyHUD = TinyHUD()
    private let secureInputMonitor = SecureInputMonitor()

    private var needsInputMonitoringPermission: Bool = false
    private var isSecureInputActive: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusMenu.delegate = self

        eventTap.switchHandler = { [weak self] in
            return self?.handleSwitchRequest() ?? .ignore
        }
        eventTap.tapStateChangedHandler = { [weak self] isEnabled in
            DispatchQueue.main.async {
                self?.refreshState()
            }
        }
        eventTap.tapInstallationFailedHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.needsInputMonitoringPermission = true
                self?.eventTap.stop()
                self?.refreshState()
            }
        }

        secureInputMonitor.stateDidChange = { [weak self] isActive in
            guard let self else { return }
            self.isSecureInputActive = isActive
            self.refreshState()
        }
        secureInputMonitor.start()

        evaluatePermissionsAndStartTap()
        refreshState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTap.stop()
        secureInputMonitor.stop()
    }

    private func evaluatePermissionsAndStartTap() {
        needsInputMonitoringPermission = !IOHIDCheckAccess(kIOHIDRequestTypeListenEvent, 0)
        updateEventTap()
    }

    private func updateEventTap() {
        eventTap.multiTapEnabled = settings.multiTapEnabled
        guard !needsInputMonitoringPermission, settings.isEnabled else {
            eventTap.stop()
            return
        }
        eventTap.start()
    }

    private func handleSwitchRequest() -> EventTap.SwitchDecision {
        guard settings.isEnabled else {
            return .ignore
        }

        if needsInputMonitoringPermission {
            Permissions.openInputMonitoring()
            return .consumeOnly
        }

        guard inputSwitch.hasSupportedPair else {
            return .ignore
        }

        if settings.method.requiresAccessibility && !AXIsProcessTrusted() {
            promptForAccessibilityPermission()
            return .ignore
        }

        if isSecureInputActive {
            return .consumeOnly
        }

        let didSwitch = inputSwitch.toggle(using: settings.method)
        if didSwitch {
            if settings.showMiniHUD {
                tinyHUD.show(symbol: inputSwitch.currentSymbol())
            }
            return .consumedAndSwitched
        }

        return .consumeOnly
    }

    private func refreshState() {
        if needsInputMonitoringPermission && IOHIDCheckAccess(kIOHIDRequestTypeListenEvent, 0) {
            needsInputMonitoringPermission = false
            updateEventTap()
        }
        let needsAccessibility = settings.method.requiresAccessibility && !AXIsProcessTrusted()
        let context = StatusMenu.Context(
            isMasterEnabled: settings.isEnabled,
            disableAnimation: settings.disableAnimation,
            showMiniHUD: settings.showMiniHUD,
            multiTapEnabled: settings.multiTapEnabled,
            selectedMethod: settings.method,
            isSwitchAvailable: inputSwitch.hasSupportedPair,
            isSecureInputActive: isSecureInputActive,
            needsPermissions: needsInputMonitoringPermission,
            needsAccessibilityPermission: needsAccessibility,
            currentSymbol: inputSwitch.currentSymbol()
        )

        statusMenu.update(context: context)
    }

    private func promptForAccessibilityPermission() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "ShiftSpaceSwitcher"
        alert.informativeText = "방안 A 또는 C를 사용하려면 손쉬운 사용(Accessibility) 권한이 필요합니다."
        alert.addButton(withTitle: "손쉬운 사용 열기")
        alert.addButton(withTitle: "취소")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Permissions.openAccessibility()
        }
    }
}

extension AppDelegate: StatusMenuDelegate {
    func statusMenu(_ menu: StatusMenu, didChangeEnabled isEnabled: Bool) {
        settings.isEnabled = isEnabled
        if isEnabled {
            if needsInputMonitoringPermission {
                Permissions.openInputMonitoring()
            }
        } else {
            eventTap.stop()
        }
        updateEventTap()
        refreshState()
    }

    func statusMenu(_ menu: StatusMenu, didChangeDisableAnimation disable: Bool) {
        settings.disableAnimation = disable
        if disable && settings.method == .shortcut {
            settings.method = .tisToggle
        }
        refreshState()
    }

    func statusMenu(_ menu: StatusMenu, didChangeMiniHUD isEnabled: Bool) {
        settings.showMiniHUD = isEnabled
        refreshState()
    }

    func statusMenu(_ menu: StatusMenu, didChangeMultiTap isEnabled: Bool) {
        settings.multiTapEnabled = isEnabled
        updateEventTap()
        refreshState()
    }

    func statusMenu(_ menu: StatusMenu, didSelect method: InputSwitch.Method) {
        if method.requiresAccessibility && !AXIsProcessTrusted() {
            promptForAccessibilityPermission()
            return
        }
        if method == .shortcut && settings.disableAnimation {
            return
        }
        settings.method = method
        refreshState()
    }

    func statusMenuRequestedAbout(_ menu: StatusMenu) {
        let alert = NSAlert()
        alert.messageText = "ShiftSpaceSwitcher"
        alert.informativeText = "왼쪽 Shift+Space 로 한/영 전환을 수행합니다.\nInput Monitoring 권한은 필수이며, 옵션에 따라 Accessibility 권한이 필요할 수 있습니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    func statusMenuRequestedQuit(_ menu: StatusMenu) {
        NSApp.terminate(nil)
    }
}
