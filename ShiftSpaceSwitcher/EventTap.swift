import Foundation
import ApplicationServices

final class EventTap {
    enum Mode {
        case consume
        case observeOnly
    }

    enum SwitchAction {
        case switched
        case ignored
    }

    var switchHandler: (() -> SwitchAction)?
    var tapStateChangedHandler: ((Bool) -> Void)?
    var tapInstallationFailedHandler: (() -> Void)?

    var multiTapEnabled: Bool = true
    var multiTapMinimumInterval: TimeInterval = 0.09

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var leftShiftPressed = false
    private var triggeredDuringCurrentHold = false
    private var lastTriggerTime: TimeInterval = 0
    private var shouldConsumeSwitchKey = false

    private let callback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let eventTap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
        return eventTap.handleEvent(proxy: proxy, type: type, event: event)
    }

    deinit {
        stop()
    }

    @discardableResult
    func start(mode: Mode) -> Bool {
        print("🎯 EventTap.start() called (\(mode == .consume ? "consume" : "observeOnly"))")
        stop()

        shouldConsumeSwitchKey = (mode == .consume)

        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let options: CGEventTapOptions = (mode == .consume) ? .defaultTap : .listenOnly
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("  ❌ Failed to create event tap")
            tapInstallationFailedHandler?()
            return false
        }

        print("  ✅ Event tap created successfully")
        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("  ✅ Event tap enabled")
        tapStateChangedHandler?(true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        eventTap = nil
        runLoopSource = nil
        leftShiftPressed = false
        triggeredDuringCurrentHold = false
        tapStateChangedHandler?(false)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let tap = eventTap else { return Unmanaged.passUnretained(event) }

        switch type {
        case .tapDisabledByUserInput, .tapDisabledByTimeout:
            print("⚠️ EventTap disabled by \(type == .tapDisabledByUserInput ? "user input" : "timeout")")
            print("  🔄 Attempting to re-enable...")

            tapStateChangedHandler?(false)

            // Try to re-enable the tap
            CGEvent.tapEnable(tap: tap, enable: true)
            leftShiftPressed = false
            triggeredDuringCurrentHold = false

            // Check if we successfully re-enabled
            // If permission was revoked, the tap will fail to re-enable
            // and the app should detect it
            let isEnabled = CGEvent.tapIsEnabled(tap: tap)
            tapStateChangedHandler?(isEnabled)
            if !isEnabled {
                DispatchQueue.main.async { [weak self] in
                    self?.tapInstallationFailedHandler?()
                }
            }
            return Unmanaged.passUnretained(event)
        default:
            break
        }

        if type == .flagsChanged {
            handleFlagsChanged(event: event)
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if keyCode != 49 { // Space
            // Not Space key - let all events through (including autorepeat)
            return Unmanaged.passUnretained(event)
        }

        guard leftShiftPressed else {
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.keyboardEventAutorepeat) == 1 {
            return consumeOrPass(event)
        }

        let currentTime = event.timestampTimeInterval
        if multiTapEnabled {
            if currentTime - lastTriggerTime < multiTapMinimumInterval {
                return consumeOrPass(event)
            }
        } else if triggeredDuringCurrentHold {
            return consumeOrPass(event)
        }

        guard let action = switchHandler?() else {
            return Unmanaged.passUnretained(event)
        }

        if case .switched = action {
            lastTriggerTime = currentTime
            triggeredDuringCurrentHold = true
            return consumeOrPass(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func consumeOrPass(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        shouldConsumeSwitchKey ? nil : Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == 56 else { return }

        let isPressed = event.flags.contains(.maskShift)
        if isPressed != leftShiftPressed {
            leftShiftPressed = isPressed
            if !isPressed {
                triggeredDuringCurrentHold = false
            }
        }
    }
}

private extension CGEvent {
    var timestampTimeInterval: TimeInterval {
        let nanoseconds = self.timestamp
        return TimeInterval(nanoseconds) / TimeInterval(NSEC_PER_SEC)
    }
}
