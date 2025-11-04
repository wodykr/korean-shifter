import Foundation
import Carbon.HIToolbox

final class InputSwitch {

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
        print("🔍 InputSwitch.refreshInputSources()")
        englishSource = nil
        koreanSource = nil

        guard let unmanagedList = TISCreateInputSourceList(nil, false) else {
            print("  ❌ Failed to create input source list")
            return
        }
        let sourceList = unmanagedList.takeRetainedValue()
        let count = CFArrayGetCount(sourceList)
        print("  - Found \(count) input sources")

        for index in 0..<count {
            let rawValue = CFArrayGetValueAtIndex(sourceList, index)
            let source = unsafeBitCast(rawValue, to: TISInputSource.self)
            guard isEnabledSource(source) else { continue }

            if let identifier = inputSourceID(source) {
                print("  - Enabled source: \(identifier)")
            }

            if englishSource == nil, let identifier = inputSourceID(source), Self.englishSourceIDs.contains(identifier) {
                print("    ✅ Found English source: \(identifier)")
                englishSource = source
                continue
            }

            if koreanSource == nil, let identifier = inputSourceID(source), Self.koreanSourceIDs.contains(identifier) {
                print("    ✅ Found Korean source: \(identifier)")
                koreanSource = source
                continue
            }
        }

        print("  - English source: \(englishSource != nil ? "✅" : "❌")")
        print("  - Korean source: \(koreanSource != nil ? "✅" : "❌")")
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

    func toggle() -> Bool {
        print("🔄 InputSwitch.toggle() called")
        refreshInputSources()
        guard let englishSource = englishSource, let koreanSource = koreanSource else {
            print("  ❌ Missing English or Korean source")
            return false
        }

        return toggleUsingTIS(english: englishSource, korean: koreanSource)
    }

    private func toggleUsingTIS(english: TISInputSource, korean: TISInputSource) -> Bool {
        guard let currentID = currentInputSourceID() else {
            print("  ❌ Cannot get current input source ID")
            return false
        }

        print("  - Current input source: \(currentID)")

        let target: TISInputSource
        if Self.koreanSourceIDs.contains(currentID) {
            print("  - Switching from Korean to English")
            target = english
        } else if Self.englishSourceIDs.contains(currentID) {
            print("  - Switching from English to Korean")
            target = korean
        } else {
            print("  ❌ Current language '\(currentID)' not in whitelist")
            return false
        }

        let status = TISSelectInputSource(target)
        print("  - TISSelectInputSource status: \(status)")
        let success = status == noErr
        print("  - Result: \(success ? "✅ Success" : "❌ Failed")")
        return success
    }

    private func currentInputSourceID() -> String? {
        guard let unmanaged = TISCopyCurrentKeyboardInputSource() else { return nil }
        let source = unmanaged.takeRetainedValue()
        return inputSourceID(source)
    }

    private func inputSourceID(_ source: TISInputSource) -> String? {
        guard let rawValue = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        let value = Unmanaged<CFString>.fromOpaque(rawValue).takeUnretainedValue()
        return value as String
    }

    private func isEnabledSource(_ source: TISInputSource) -> Bool {
        guard let rawValue = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else { return false }
        let value = Unmanaged<CFBoolean>.fromOpaque(rawValue).takeUnretainedValue()
        return CFBooleanGetValue(value)
    }
}
