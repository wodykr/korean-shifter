import Foundation
import Carbon

final class SecureInputMonitor {
    var stateDidChange: ((Bool) -> Void)?

    private var timer: DispatchSourceTimer?
    private(set) var isSecureInputActive: Bool = false

    // Dynamically load the private API symbol at runtime
    private let CGSIsSecureEventInputEnabled: (() -> Bool)? = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW) else {
            return nil
        }
        defer { dlclose(handle) }
        guard let symbol = dlsym(handle, "CGSIsSecureEventInputEnabled") else {
            return nil
        }
        typealias FunctionType = @convention(c) () -> Bool
        return unsafeBitCast(symbol, to: FunctionType.self)
    }()

    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.evaluate()
        }
        self.timer = timer
        timer.resume()
        evaluate()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func evaluate() {
        guard let checkFunction = CGSIsSecureEventInputEnabled else {
            // If we can't load the function, assume secure input is not active
            return
        }
        let secureActive = checkFunction()
        if secureActive != isSecureInputActive {
            isSecureInputActive = secureActive
            stateDidChange?(secureActive)
        }
    }
}
