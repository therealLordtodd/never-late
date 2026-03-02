import Foundation

final class ForegroundRefreshTimer {
    private var timer: Timer?

    func start(_ action: @escaping @Sendable () async -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            Task { await action() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
