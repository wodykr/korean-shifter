import AppKit

protocol StatusMenuDelegate: AnyObject {
    func statusMenu(_ menu: StatusMenu, didChangeEnabled isEnabled: Bool)
    func statusMenu(_ menu: StatusMenu, didChangeMiniHUD isEnabled: Bool)
    func statusMenu(_ menu: StatusMenu, didChangeMultiTap isEnabled: Bool)
    func statusMenu(_ menu: StatusMenu, didChangeDisableAnimation isEnabled: Bool)
    func statusMenu(_ menu: StatusMenu, didChangeLoginItem isEnabled: Bool)
    func statusMenuRequestedAbout(_ menu: StatusMenu)
    func statusMenuRequestedQuit(_ menu: StatusMenu)
}

final class StatusMenu: NSObject {
    struct Context {
        let isMasterEnabled: Bool
        let showMiniHUD: Bool
        let multiTapEnabled: Bool
        let disableAnimation: Bool
        let loginItemEnabled: Bool
        let isSwitchAvailable: Bool
        let isSecureInputActive: Bool
        let needsInputMonitoringPermission: Bool
        let needsAccessibilityPermission: Bool
        let currentSymbol: String
    }

    weak var delegate: StatusMenuDelegate?

    private let statusItem: NSStatusItem
    private let menu: NSMenu

    private let enableItem: NSMenuItem
    private let miniHUDItem: NSMenuItem
    private let multiTapItem: NSMenuItem
    private let disableAnimationItem: NSMenuItem
    private let loginItemItem: NSMenuItem
    private let aboutItem: NSMenuItem
    private let quitItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()

        enableItem = NSMenuItem(title: "활성화", action: #selector(toggleEnabled), keyEquivalent: "")
        miniHUDItem = NSMenuItem(title: "한/영 전환 미니 알림", action: #selector(toggleMiniHUD), keyEquivalent: "")
        multiTapItem = NSMenuItem(title: "멀티탭 모드", action: #selector(toggleMultiTap), keyEquivalent: "")
        disableAnimationItem = NSMenuItem(title: "한/영 전환 애니메이션 끄기", action: #selector(toggleDisableAnimation), keyEquivalent: "")
        loginItemItem = NSMenuItem(title: "로그인 시 자동 실행", action: #selector(toggleLoginItem), keyEquivalent: "")
        aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        quitItem = NSMenuItem(title: "Exit", action: #selector(quitApp), keyEquivalent: "")

        super.init()

        enableItem.target = self
        miniHUDItem.target = self
        multiTapItem.target = self
        disableAnimationItem.target = self
        loginItemItem.target = self
        aboutItem.target = self
        quitItem.target = self

        let separator = NSMenuItem.separator()

        menu.items = [
            enableItem,
            miniHUDItem,
            multiTapItem,
            disableAnimationItem,
            loginItemItem,
            separator,
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
        miniHUDItem.state = context.showMiniHUD ? .on : .off
        multiTapItem.state = context.multiTapEnabled ? .on : .off
        disableAnimationItem.state = context.disableAnimation ? .on : .off
        loginItemItem.state = context.loginItemEnabled ? .on : .off

        let icon = StatusMenu.makeSymbolImage(text: context.currentSymbol)
        statusItem.button?.image = icon

        let tooltip: String
        if !context.isSwitchAvailable {
            tooltip = "ENG/KOR 입력 소스가 감지되지 않았습니다."
        } else if context.needsInputMonitoringPermission {
            tooltip = "ShiftSpaceSwitcher: 입력 모니터링 권한이 필요합니다."
        } else if context.needsAccessibilityPermission {
            tooltip = "ShiftSpaceSwitcher: 손쉬운사용 권한이 필요합니다 (공백 방지)."
        } else if context.isSecureInputActive {
            tooltip = "ShiftSpaceSwitcher: 보안 입력 중"
        } else {
            tooltip = "ShiftSpaceSwitcher"
        }
        statusItem.button?.toolTip = tooltip
        statusItem.button?.appearsDisabled = (
            !context.isMasterEnabled ||
            !context.isSwitchAvailable ||
            context.needsInputMonitoringPermission ||
            context.isSecureInputActive
        )

        enableItem.isEnabled = true
        miniHUDItem.isEnabled = context.isMasterEnabled
        multiTapItem.isEnabled = context.isMasterEnabled
        disableAnimationItem.isEnabled = context.isMasterEnabled
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

    @objc private func toggleMiniHUD() {
        let newValue = miniHUDItem.state != .on
        delegate?.statusMenu(self, didChangeMiniHUD: newValue)
    }

    @objc private func toggleMultiTap() {
        let newValue = multiTapItem.state != .on
        delegate?.statusMenu(self, didChangeMultiTap: newValue)
    }

    @objc private func toggleDisableAnimation() {
        let newValue = disableAnimationItem.state != .on
        delegate?.statusMenu(self, didChangeDisableAnimation: newValue)
    }

    @objc private func toggleLoginItem() {
        let newValue = loginItemItem.state != .on
        delegate?.statusMenu(self, didChangeLoginItem: newValue)
    }

    @objc private func showAbout() {
        delegate?.statusMenuRequestedAbout(self)
    }

    @objc private func quitApp() {
        delegate?.statusMenuRequestedQuit(self)
    }
}
