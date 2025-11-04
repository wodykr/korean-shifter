import Foundation

@_silgen_name("CGSIsSecureEventInputEnabled")
private func CGSIsSecureEventInputEnabled() -> Bool

final class SecureInputMonitor {
    var stateDidChange: ((Bool) -> Void)?

    private var timer: DispatchSourceTimer?
    private(set) var isSecureInputActive: Bool = false

    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(100))
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
        let secureActive = CGSIsSecureEventInputEnabled()
        if secureActive != isSecureInputActive {
            isSecureInputActive = secureActive
            stateDidChange?(secureActive)
        }
    }
}
