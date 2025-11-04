import AppKit

protocol StatusMenuDelegate: AnyObject {
    func statusMenu(_ menu: StatusMenu, didChangeEnabled isEnabled: Bool)
    func statusMenu(_ menu: StatusMenu, didChangeDisableAnimation disable: Bool)
    func statusMenu(_ menu: StatusMenu, didChangeMiniHUD isEnabled: Bool)
    func statusMenu(_ menu: StatusMenu, didChangeMultiTap isEnabled: Bool)
    func statusMenu(_ menu: StatusMenu, didSelect method: InputSwitch.Method)
    func statusMenuRequestedAbout(_ menu: StatusMenu)
    func statusMenuRequestedQuit(_ menu: StatusMenu)
}

final class StatusMenu: NSObject {
    struct Context {
        let isMasterEnabled: Bool
        let disableAnimation: Bool
        let showMiniHUD: Bool
        let multiTapEnabled: Bool
        let selectedMethod: InputSwitch.Method
        let isSwitchAvailable: Bool
        let isSecureInputActive: Bool
        let needsPermissions: Bool
        let needsAccessibilityPermission: Bool
        let currentSymbol: String
    }

    weak var delegate: StatusMenuDelegate?

    private let statusItem: NSStatusItem
    private let menu: NSMenu

    private let enableItem: NSMenuItem
    private let animationItem: NSMenuItem
    private let miniHUDItem: NSMenuItem
    private let multiTapItem: NSMenuItem
    private let methodAItem: NSMenuItem
    private let methodBItem: NSMenuItem
    private let methodCItem: NSMenuItem
    private let aboutItem: NSMenuItem
    private let quitItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()

        enableItem = NSMenuItem(title: "활성화", action: #selector(toggleEnabled), keyEquivalent: "")
        animationItem = NSMenuItem(title: "한/영 전환 애니메이션 끄기", action: #selector(toggleAnimation), keyEquivalent: "")
        miniHUDItem = NSMenuItem(title: "한/영 전환 미니 알림", action: #selector(toggleMiniHUD), keyEquivalent: "")
        multiTapItem = NSMenuItem(title: "멀티탭 모드", action: #selector(toggleMultiTap), keyEquivalent: "")
        methodAItem = NSMenuItem(title: "방안 A", action: #selector(selectMethod(_:)), keyEquivalent: "")
        methodBItem = NSMenuItem(title: "방안 B", action: #selector(selectMethod(_:)), keyEquivalent: "")
        methodCItem = NSMenuItem(title: "방안 C", action: #selector(selectMethod(_:)), keyEquivalent: "")
        aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        quitItem = NSMenuItem(title: "Exit", action: #selector(quitApp), keyEquivalent: "")

        super.init()

        enableItem.target = self
        animationItem.target = self
        miniHUDItem.target = self
        multiTapItem.target = self
        methodAItem.target = self
        methodBItem.target = self
        methodCItem.target = self
        aboutItem.target = self
        quitItem.target = self

        methodAItem.representedObject = InputSwitch.Method.capsLock
        methodBItem.representedObject = InputSwitch.Method.tisToggle
        methodCItem.representedObject = InputSwitch.Method.shortcut

        methodAItem.state = .off
        methodBItem.state = .off
        methodCItem.state = .off

        let separator1 = NSMenuItem.separator()
        let separator2 = NSMenuItem.separator()

        menu.items = [
            enableItem,
            animationItem,
            miniHUDItem,
            multiTapItem,
            separator1,
            methodAItem,
            methodBItem,
            methodCItem,
            separator2,
            aboutItem,
            quitItem
        ]

        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.image = StatusMenu.makeSymbolImage(text: "⇄")
        statusItem.button?.appearsDisabled = false
        statusItem.button?.toolTip = "ShiftSpaceSwitcher"
    }

    func update(context: Context) {
        enableItem.state = context.isMasterEnabled ? .on : .off
        animationItem.state = context.disableAnimation ? .on : .off
        miniHUDItem.state = context.showMiniHUD ? .on : .off
        multiTapItem.state = context.multiTapEnabled ? .on : .off

        let methodItems = [methodAItem, methodBItem, methodCItem]
        methodItems.forEach { $0.state = .off }
        switch context.selectedMethod {
        case .capsLock:
            methodAItem.state = .on
        case .tisToggle:
            methodBItem.state = .on
        case .shortcut:
            methodCItem.state = .on
        }

        let methodsEnabled = context.isSwitchAvailable && !context.needsPermissions
        methodAItem.isEnabled = methodsEnabled
        methodBItem.isEnabled = methodsEnabled
        methodCItem.isEnabled = methodsEnabled && !context.disableAnimation

        let icon = StatusMenu.makeSymbolImage(text: context.currentSymbol)
        statusItem.button?.image = icon

        let tooltip: String
        if !context.isSwitchAvailable {
            tooltip = "ENG/KOR 입력 소스가 감지되지 않았습니다."
        } else if context.needsPermissions {
            tooltip = "ShiftSpaceSwitcher: 입력 모니터링 권한이 필요합니다."
        } else if context.needsAccessibilityPermission {
            tooltip = "ShiftSpaceSwitcher: 손쉬운 사용 권한이 필요합니다."
        } else if context.isSecureInputActive {
            tooltip = "ShiftSpaceSwitcher: 보안 입력 중"
        } else {
            tooltip = "ShiftSpaceSwitcher"
        }
        statusItem.button?.toolTip = tooltip
        statusItem.button?.appearsDisabled = (
            !context.isMasterEnabled ||
            !context.isSwitchAvailable ||
            context.needsPermissions ||
            context.needsAccessibilityPermission ||
            context.isSecureInputActive
        )

        enableItem.isEnabled = true
        animationItem.isEnabled = context.isMasterEnabled
        miniHUDItem.isEnabled = context.isMasterEnabled
        multiTapItem.isEnabled = context.isMasterEnabled
    }

    private static func makeSymbolImage(text: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        NSBezierPath(rect: rect).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textRect = attributed.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin])
        let origin = NSPoint(
            x: rect.midX - textRect.width / 2,
            y: rect.midY - textRect.height / 2
        )
        attributed.draw(at: origin)

        image.isTemplate = true
        return image
    }

    @objc private func toggleEnabled() {
        let newValue = enableItem.state != .on
        delegate?.statusMenu(self, didChangeEnabled: newValue)
    }

    @objc private func toggleAnimation() {
        let newValue = animationItem.state != .on
        delegate?.statusMenu(self, didChangeDisableAnimation: newValue)
    }

    @objc private func toggleMiniHUD() {
        let newValue = miniHUDItem.state != .on
        delegate?.statusMenu(self, didChangeMiniHUD: newValue)
    }

    @objc private func toggleMultiTap() {
        let newValue = multiTapItem.state != .on
        delegate?.statusMenu(self, didChangeMultiTap: newValue)
    }

    @objc private func selectMethod(_ sender: NSMenuItem) {
        guard let method = sender.representedObject as? InputSwitch.Method else { return }
        delegate?.statusMenu(self, didSelect: method)
    }

    @objc private func showAbout() {
        delegate?.statusMenuRequestedAbout(self)
    }

    @objc private func quitApp() {
        delegate?.statusMenuRequestedQuit(self)
    }
}
