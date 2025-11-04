import AppKit

final class TinyHUD {
    private let window: NSWindow
    private let textField: NSTextField
    private let displayDuration: TimeInterval = 0.45
    private var hideWorkItem: DispatchWorkItem?

    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 96, height: 96)
        window = NSWindow(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        window.alphaValue = 0

        textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 42, weight: .semibold)
        textField.textColor = .white
        textField.alignment = .center
        textField.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: contentRect)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 16
        contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.55).cgColor
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        window.contentView = contentView
    }

    func show(symbol: String) {
        DispatchQueue.main.async { [weak self] in
            self?.present(symbol: symbol)
        }
    }

    private func present(symbol: String) {
        hideWorkItem?.cancel()
        textField.stringValue = symbol

        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let windowSize = window.frame.size
        let origin = NSPoint(
            x: screenRect.midX - windowSize.width / 2,
            y: screenRect.midY - windowSize.height / 2
        )
        window.setFrameOrigin(origin)

        if !window.isVisible {
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                self.window.animator().alphaValue = 0
            } completionHandler: {
                self.window.orderOut(nil)
            }
        }

        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
    }
}
