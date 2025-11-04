import Foundation
import ApplicationServices

final class EventTap {
    struct SwitchDecision {
        let didSwitch: Bool
        let shouldConsume: Bool

        static let consumedAndSwitched = SwitchDecision(didSwitch: true, shouldConsume: true)
        static let consumeOnly = SwitchDecision(didSwitch: false, shouldConsume: true)
        static let ignore = SwitchDecision(didSwitch: false, shouldConsume: false)
    }

    var switchHandler: (() -> SwitchDecision)?
    var tapStateChangedHandler: ((Bool) -> Void)?
    var tapInstallationFailedHandler: (() -> Void)?

    var multiTapEnabled: Bool = true
    var multiTapMinimumInterval: TimeInterval = 0.09

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var leftShiftPressed = false
    private var triggeredDuringCurrentHold = false
    private var lastTriggerTime: TimeInterval = 0

    private let callback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let eventTap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
        return eventTap.handleEvent(proxy: proxy, type: type, event: event)
    }

    deinit {
        stop()
    }

    func start() {
        stop()

        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEventTapCreate(
            .cgSessionEventTap,
            .headInsertEventTap,
            .defaultTap,
            CGEventMask(mask),
            callback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            tapInstallationFailedHandler?()
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEventTapEnable(tap, true)
        tapStateChangedHandler?(true)
    }

    func stop() {
        if let tap = eventTap {
            CGEventTapEnable(tap, false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let source = runLoopSource {
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
            CGEventTapEnable(tap, true)
            leftShiftPressed = false
            triggeredDuringCurrentHold = false
            tapStateChangedHandler?(true)
            return nil
        default:
            break
        }

        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == InputSwitch.syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            handleFlagsChanged(event: event)
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.keyboardEventAutorepeat) == 1 {
            return nil
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if keyCode != 49 { // Space
            return Unmanaged.passUnretained(event)
        }

        guard leftShiftPressed else {
            return Unmanaged.passUnretained(event)
        }

        let currentTime = event.timestampTimeInterval
        if multiTapEnabled {
            if currentTime - lastTriggerTime < multiTapMinimumInterval {
                return nil
            }
        } else if triggeredDuringCurrentHold {
            return nil
        }

        guard let decision = switchHandler?() else {
            return Unmanaged.passUnretained(event)
        }

        if decision.didSwitch {
            lastTriggerTime = currentTime
            triggeredDuringCurrentHold = true
        }

        if decision.shouldConsume {
            return nil
        }

        return Unmanaged.passUnretained(event)
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
        let nanoseconds = CGEventGetTimestamp(self)
        return TimeInterval(nanoseconds) / TimeInterval(NSEC_PER_SEC)
    }
}
