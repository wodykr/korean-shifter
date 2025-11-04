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
    private let loginItemManager: LoginItemManager? = {
        if #available(macOS 13.0, *) {
            return LoginItemManager.shared
        }
        return nil
    }()

    private var needsInputMonitoringPermission: Bool = false
    private var needsAccessibilityPermission: Bool = false
    private var isSecureInputActive: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Sync login item state on launch
        if let loginItemManager = loginItemManager {
            let actualState = loginItemManager.isEnabled
            if actualState != settings.loginItemEnabled {
                print("🔄 Syncing login item state: \(actualState)")
                settings.loginItemEnabled = actualState
            }
        }

        statusMenu.delegate = self

        eventTap.switchHandler = { [weak self] in
            return self?.handleSwitchRequest() ?? .ignored
        }
        eventTap.tapStateChangedHandler = { [weak self] isEnabled in
            DispatchQueue.main.async {
                print("⚡️ tapStateChanged: \(isEnabled)")
                // If tap successfully started, we have permission
                if isEnabled {
                    self?.needsInputMonitoringPermission = false
                    self?.needsAccessibilityPermission = !AXIsProcessTrusted()
                }
                self?.refreshState()
            }
        }
        eventTap.tapInstallationFailedHandler = { [weak self] in
            DispatchQueue.main.async {
                print("⛔️ Event tap installation failed - no permission")
                let hasInputPermission = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
                let hasAccessibilityPermission = AXIsProcessTrusted()
                self?.needsInputMonitoringPermission = !hasInputPermission
                self?.needsAccessibilityPermission = !hasAccessibilityPermission
                if self?.needsInputMonitoringPermission == true {
                    self?.settings.isEnabled = false  // Auto-disable if no Input Monitoring permission
                }
                self?.eventTap.stop()
                self?.refreshState()
            }
        }

        secureInputMonitor.stateDidChange = { [weak self] (isActive: Bool) in
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
        print("🔧 evaluatePermissionsAndStartTap called")

        // Check if we already have Input Monitoring permission
        let hasInputPermission = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        print("  - IOHIDCheckAccess result: \(hasInputPermission ? "granted" : "not granted")")

        needsInputMonitoringPermission = !hasInputPermission
        if needsInputMonitoringPermission && settings.isEnabled {
            print("  ⚠️ Permission missing on launch - disabling setting")
            settings.isEnabled = false
        }

        let hasAccessibilityPermission = AXIsProcessTrusted()
        print("  - AXIsProcessTrusted: \(hasAccessibilityPermission)")
        needsAccessibilityPermission = !hasAccessibilityPermission

        if needsInputMonitoringPermission {
            ensureInputMonitoringRegistration()
        }

        // If we have permission and settings say enabled, start the tap
        // Otherwise, just update state (which will keep tap stopped)
        updateEventTap()
    }

    private func updateEventTap() {
        print("🔧 updateEventTap called")
        print("  - needsInputMonitoringPermission: \(needsInputMonitoringPermission)")
        print("  - settings.isEnabled: \(settings.isEnabled)")
        print("  - needsAccessibilityPermission: \(needsAccessibilityPermission)")

        eventTap.multiTapEnabled = settings.multiTapEnabled
        guard settings.isEnabled else {
            print("  ❌ Not enabled - stopping event tap")
            eventTap.stop()
            return
        }

        if needsInputMonitoringPermission {
            print("  ❌ Need Input Monitoring permission - stopping event tap")
            eventTap.stop()
            return
        }

        let hasAccessibilityPermission = AXIsProcessTrusted()
        needsAccessibilityPermission = !hasAccessibilityPermission

        let mode: EventTap.Mode = hasAccessibilityPermission ? .consume : .observeOnly
        print("  ✅ Starting event tap (mode: \(mode == .consume ? "consume" : "observe"))")
        _ = eventTap.start(mode: mode)
    }

    private func ensureInputMonitoringRegistration() {
        print("📇 ensureInputMonitoringRegistration - probing Input Monitoring entry")
        let started = eventTap.start(mode: .observeOnly)
        if started {
            needsInputMonitoringPermission = false
            DispatchQueue.main.async { [weak self] in
                self?.eventTap.stop()
                self?.refreshState()
            }
        }
    }
    private func handleSwitchRequest() -> EventTap.SwitchAction {
        print("🔵 handleSwitchRequest called")
        print("  - settings.isEnabled: \(settings.isEnabled)")
        print("  - needsInputMonitoringPermission: \(needsInputMonitoringPermission)")
        print("  - needsAccessibilityPermission: \(needsAccessibilityPermission)")
        print("  - hasSupportedPair: \(inputSwitch.hasSupportedPair)")
        print("  - isSecureInputActive: \(isSecureInputActive)")

        guard settings.isEnabled else {
            print("  ❌ Not enabled")
            return .ignored
        }

        if needsInputMonitoringPermission {
            print("  ❌ Need permission - ignoring trigger")
            return .ignored
        }

        guard inputSwitch.hasSupportedPair else {
            print("  ❌ No supported pair")
            return .ignored
        }

        if isSecureInputActive {
            print("  ❌ Secure input active - ignoring")
            return .ignored
        }

        print("  ✅ Attempting to toggle")
        let didSwitch = inputSwitch.toggle()
        print("  - didSwitch: \(didSwitch)")

        if didSwitch {
            if settings.showMiniHUD {
                tinyHUD.show(symbol: inputSwitch.currentSymbol(), animated: !settings.disableAnimation)
            }
            DispatchQueue.main.async { [weak self] in
                self?.refreshState()
            }
            return .switched
        }

        return .ignored
    }

    private func refreshState() {
        print("🔄 refreshState called")
        let context = StatusMenu.Context(
            isMasterEnabled: settings.isEnabled,
            showMiniHUD: settings.showMiniHUD,
            multiTapEnabled: settings.multiTapEnabled,
            disableAnimation: settings.disableAnimation,
            loginItemEnabled: settings.loginItemEnabled,
            isSwitchAvailable: inputSwitch.hasSupportedPair,
            isSecureInputActive: isSecureInputActive,
            needsInputMonitoringPermission: needsInputMonitoringPermission,
            needsAccessibilityPermission: needsAccessibilityPermission,
            currentSymbol: inputSwitch.currentSymbol()
        )

        statusMenu.update(context: context)
    }
}

extension AppDelegate: StatusMenuDelegate {
    func statusMenu(_ menu: StatusMenu, didChangeEnabled isEnabled: Bool) {
        print("📱 User toggled enabled: \(isEnabled)")

        if isEnabled {
            // User wants to enable
            print("  🔄 Attempting to enable...")

            // Check current permission status
            let hasInputPermission = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
            let hasAccessibilityPermission = AXIsProcessTrusted()
            print("  - Input Monitoring status: \(hasInputPermission ? "granted" : "not granted")")
            print("  - Accessibility status: \(hasAccessibilityPermission ? "granted" : "not granted")")

            guard hasInputPermission else {
                print("  ❌ Input Monitoring permission missing - requesting access")
                settings.isEnabled = false
                needsInputMonitoringPermission = true

                ensureInputMonitoringRegistration()

                let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
                print("  - IOHIDRequestAccess returned: \(granted)")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Permissions.openInputMonitoring()
                }

                refreshState()
                return
            }

            settings.isEnabled = true
            needsInputMonitoringPermission = false
            needsAccessibilityPermission = !hasAccessibilityPermission

            if !hasAccessibilityPermission {
                print("  ⚠️ Accessibility permission missing - cannot suppress space key")
                _ = Permissions.promptForAccessibilityPermission()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Permissions.openAccessibility()
                }
            }

            updateEventTap()
            refreshState()
        } else {
            // User wants to disable
            print("  ⏸️ Disabling...")
            settings.isEnabled = false
            eventTap.stop()
            refreshState()
        }
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

    func statusMenu(_ menu: StatusMenu, didChangeDisableAnimation isEnabled: Bool) {
        settings.disableAnimation = isEnabled
        refreshState()
    }

    func statusMenu(_ menu: StatusMenu, didChangeLoginItem isEnabled: Bool) {
        guard let loginItemManager = loginItemManager else {
            print("⚠️ LoginItemManager not available (requires macOS 13+)")
            return
        }

        print("📱 User toggled login item: \(isEnabled)")
        let previousValue = settings.loginItemEnabled
        settings.loginItemEnabled = isEnabled

        do {
            if isEnabled {
                try loginItemManager.enable()
                print("  ✅ Login item enabled")
            } else {
                try loginItemManager.disable()
                print("  ✅ Login item disabled")
            }
        } catch {
            print("  ❌ Failed to toggle login item: \(error)")
            settings.loginItemEnabled = previousValue
        }

        let actualState = loginItemManager.isEnabled
        if actualState != settings.loginItemEnabled {
            settings.loginItemEnabled = actualState
        }

        refreshState()
    }

    func statusMenuRequestedAbout(_ menu: StatusMenu) {
        let alert = NSAlert()
        alert.messageText = "ShiftSpaceSwitcher"
        alert.informativeText = "왼쪽 Shift+Space 로 한/영 전환을 수행합니다.\nInput Monitoring 권한이 필요합니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    func statusMenuRequestedQuit(_ menu: StatusMenu) {
        NSApp.terminate(nil)
    }
}
