import Foundation
import Carbon.HIToolbox
import ApplicationServices

final class InputSwitch {
    enum Method: Int, CaseIterable {
        case capsLock = 0
        case tisToggle = 1
        case shortcut = 2

        var title: String {
            switch self {
            case .capsLock:
                return "방안 A: CapsLock"
            case .tisToggle:
                return "방안 B: 입력 소스 직접 전환"
            case .shortcut:
                return "방안 C: 시스템 단축키"
            }
        }

        var requiresAccessibility: Bool {
            switch self {
            case .capsLock, .shortcut:
                return true
            case .tisToggle:
                return false
            }
        }
    }

    static let syntheticEventTag: Int64 = 0x53534846 // 'SHF'

    private static let englishSourceIDs: Set<String> = [
        "com.apple.keylayout.ABC",
        "com.apple.keylayout.US"
    ]

    private static let koreanSourceIDs: Set<String> = [
        "com.apple.inputmethod.Korean.2SetKorean",
        "com.apple.inputmethod.Korean.3SetKorean"
    ]

    private var englishSource: TISInputSource?
    private var koreanSource: TISInputSource?

    init() {
        refreshInputSources()
    }

    func refreshInputSources() {
        englishSource = nil
        koreanSource = nil

        guard let unmanagedList = TISCreateInputSourceList(nil, false) else { return }
        let sourceList = unmanagedList.takeRetainedValue()
        let count = CFArrayGetCount(sourceList)

        for index in 0..<count {
            let rawValue = CFArrayGetValueAtIndex(sourceList, index)
            let source = unsafeBitCast(rawValue, to: TISInputSource.self)
            guard isEnabledSource(source) else { continue }

            if englishSource == nil, let identifier = inputSourceID(source), Self.englishSourceIDs.contains(identifier) {
                englishSource = source
                continue
            }

            if koreanSource == nil, let identifier = inputSourceID(source), Self.koreanSourceIDs.contains(identifier) {
                koreanSource = source
                continue
            }
        }
    }

    var hasSupportedPair: Bool {
        refreshInputSources()
        return englishSource != nil && koreanSource != nil
    }

    func currentSymbol() -> String {
        guard let identifier = currentInputSourceID() else { return "?" }
        if Self.englishSourceIDs.contains(identifier) {
            return "A"
        }
        if Self.koreanSourceIDs.contains(identifier) {
            return "가"
        }
        return "?"
    }

    func toggle(using method: Method) -> Bool {
        refreshInputSources()
        guard let englishSource = englishSource, let koreanSource = koreanSource else { return false }

        switch method {
        case .capsLock:
            return synthesizeCapsLock()
        case .tisToggle:
            return toggleUsingTIS(english: englishSource, korean: koreanSource)
        case .shortcut:
            return synthesizeShortcut()
        }
    }

    private func toggleUsingTIS(english: TISInputSource, korean: TISInputSource) -> Bool {
        guard let currentID = currentInputSourceID() else { return false }
        let target: TISInputSource
        if Self.koreanSourceIDs.contains(currentID) {
            target = english
        } else if Self.englishSourceIDs.contains(currentID) {
            target = korean
        } else {
            // Current language outside of whitelist, bail out safely.
            return false
        }

        let status = TISSelectInputSource(target)
        return status == noErr
    }

    private func synthesizeCapsLock() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        source.userData = Self.syntheticEventTag
        guard let capsDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_CapsLock), keyDown: true) else { return false }
        capsDown.post(tap: .cghidEventTap)
        return true
    }

    private func synthesizeShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        source.userData = Self.syntheticEventTag

        guard
            let optionDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Option), keyDown: true),
            let spaceDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Space), keyDown: true),
            let spaceUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Space), keyDown: false),
            let optionUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Option), keyDown: false)
        else { return false }

        optionDown.flags = [.maskAlternate]
        optionDown.post(tap: .cghidEventTap)

        spaceDown.flags = [.maskAlternate]
        spaceDown.post(tap: .cghidEventTap)

        spaceUp.flags = [.maskAlternate]
        spaceUp.post(tap: .cghidEventTap)

        optionUp.flags = []
        optionUp.post(tap: .cghidEventTap)

        return true
    }

    private func currentInputSourceID() -> String? {
        guard let unmanaged = TISCopyCurrentKeyboardInputSource() else { return nil }
        let source = unmanaged.takeRetainedValue()
        return inputSourceID(source)
    }

    private func inputSourceID(_ source: TISInputSource) -> String? {
        guard let unmanaged = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        let value = unmanaged.takeUnretainedValue()
        return value as? String
    }

    private func isEnabledSource(_ source: TISInputSource) -> Bool {
        guard let unmanaged = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else { return false }
        let value = unmanaged.takeUnretainedValue()
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }
        return false
    }
}
