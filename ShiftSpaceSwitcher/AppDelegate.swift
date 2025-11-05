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
    private var didSeedInputMonitoringRegistration: Bool = false

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
                    self?.didSeedInputMonitoringRegistration = false
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
        if needsInputMonitoringPermission {
            didSeedInputMonitoringRegistration = false
        } else {
            _ = ensureInputMonitoringRegistration(allowPrompt: false)
        }

        let hasAccessibilityPermission = AXIsProcessTrusted()
        print("  - AXIsProcessTrusted: \(hasAccessibilityPermission)")
        needsAccessibilityPermission = !hasAccessibilityPermission

        // If we have permission and settings say enabled, start the tap
        // Otherwise, just update state (which will keep tap stopped)
        updateEventTap()
    }

    private func updateEventTap() {
        print("🔧 updateEventTap called")
        print("  - needsInputMonitoringPermission: \(needsInputMonitoringPermission)")
        print("  - settings.isEnabled: \(settings.isEnabled)")
        print("  - needsAccessibilityPermission: \(needsAccessibilityPermission)")

        eventTap.multiTapEnabled = true
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
        if !hasAccessibilityPermission {
            print("  ❌ Need Accessibility permission - stopping event tap")
            needsAccessibilityPermission = true
            eventTap.stop()
            return
        }

        needsAccessibilityPermission = false

        print("  ✅ Starting event tap (mode: consume)")
        _ = eventTap.start(mode: .consume)
    }

    @discardableResult
    private func ensureInputMonitoringRegistration(allowPrompt: Bool) -> Bool {
        let hasPermissionBefore = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted

        if allowPrompt && !hasPermissionBefore {
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            print("📇 IOHIDRequestAccess returned: \(granted)")
        }

        let hasPermissionAfter = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        needsInputMonitoringPermission = !hasPermissionAfter
        guard hasPermissionAfter else {
            didSeedInputMonitoringRegistration = false
            return false
        }

        if !didSeedInputMonitoringRegistration {
            let seeded = seedInputMonitoringEntry()
            didSeedInputMonitoringRegistration = seeded
            if !seeded {
                needsInputMonitoringPermission = true
                return false
            }
        }

        return true
    }

    private func seedInputMonitoringEntry() -> Bool {
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, _ in
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            print("⚠️ seedInputMonitoringEntry: tapCreate failed")
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            print("⚠️ seedInputMonitoringEntry: failed to create run loop source")
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        CFRunLoopSourceInvalidate(source)
        CFMachPortInvalidate(tap)
        return true
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

        if needsAccessibilityPermission {
            print("  ❌ Need accessibility permission - ignoring trigger")
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
                tinyHUD.show(symbol: inputSwitch.currentSymbol())
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
            print("  🔄 Attempting to enable...")

            let inputPermissionBefore = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
            let accessibilityPermissionBefore = AXIsProcessTrusted()
            print("  - Input Monitoring status: \(inputPermissionBefore ? "granted" : "not granted")")
            print("  - Accessibility status: \(accessibilityPermissionBefore ? "granted" : "not granted")")

            let inputGranted = ensureInputMonitoringRegistration(allowPrompt: !inputPermissionBefore)
            needsInputMonitoringPermission = !inputGranted

            var accessibilityGranted = accessibilityPermissionBefore
            if !accessibilityPermissionBefore {
                print("  ⚠️ Accessibility permission missing - requesting trust")
                let trusted = Permissions.promptForAccessibilityPermission()
                accessibilityGranted = trusted || AXIsProcessTrusted()
                needsAccessibilityPermission = !accessibilityGranted
                if !accessibilityGranted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        Permissions.openAccessibility()
                    }
                }
            } else {
                needsAccessibilityPermission = false
            }

            if !inputGranted {
                settings.isEnabled = false
                didSeedInputMonitoringRegistration = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Permissions.openInputMonitoring()
                }
                refreshState()
                return
            }

            if !accessibilityGranted {
                settings.isEnabled = false
                eventTap.stop()
                refreshState()
                return
            }

            settings.isEnabled = true
            needsInputMonitoringPermission = false
            needsAccessibilityPermission = false

            updateEventTap()
            refreshState()
        } else {
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
        alert.messageText = "Korean Shifter"
        alert.informativeText = """
왼쪽 Shift+Space 조합으로 한/영 전환 하는 것이 익숙한 사람들을 위하여 작은 유틸리티를 만들었습니다. 정상적인 작동을 위하여 [손쉬운 사용] 및 [입력 모니터링] 권한이 필요합니다.

이 프로그램은 오로지 영어/한글 두가지 언어를 사용하는 사람들을 위해 작성되었습니다. 그 외 사용의 경우 오작동 할 수 있으니 주의해주세요.
"""
        alert.alertStyle = .informational
        alert.addButton(withTitle: "깃허브 열기")
        alert.addButton(withTitle: "확인")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let url = URL(string: "https://github.com/wodykr/korean-shifter") {
            NSWorkspace.shared.open(url)
        }
    }

    func statusMenuRequestedQuit(_ menu: StatusMenu) {
        NSApp.terminate(nil)
    }
}
