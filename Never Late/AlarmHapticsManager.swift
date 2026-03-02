import CoreHaptics
import Foundation

final class AlarmHapticsManager {
    static let shared = AlarmHapticsManager()

    private let engine: CHHapticEngine?
    private var timer: Timer?
    private var isActive = false

    private init() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            engine = try? CHHapticEngine()
        } else {
            engine = nil
        }
    }

    func start() {
        guard isActive == false else { return }
        guard let engine else {
            AppLog.app.warning("Haptics not supported on this device.")
            return
        }
        isActive = true
        do {
            try engine.start()
        } catch {
            AppLog.app.error("Failed to start haptics engine: \(error.localizedDescription, privacy: .public)")
            isActive = false
            return
        }

        playPulse()
        let interval = TimeInterval(max(1, SettingsSnapshot.alarmBehavior().barrageIntervalSeconds))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playPulse()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if isActive {
            engine?.stop(completionHandler: { error in
                if let error {
                    AppLog.app.error("Failed to stop haptics engine: \(error.localizedDescription, privacy: .public)")
                }
            })
        }
        isActive = false
    }

    private func playPulse() {
        guard let engine else { return }
        let interval = TimeInterval(max(1, SettingsSnapshot.alarmBehavior().barrageIntervalSeconds))
        let duration: TimeInterval = min(5, interval)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: duration
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            AppLog.app.error("Failed to play haptic pulse: \(error.localizedDescription, privacy: .public)")
        }
    }
}
