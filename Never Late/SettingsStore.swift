import Foundation

enum TimeToLeaveTransport: String, CaseIterable, Sendable, Identifiable {
    case driving
    case walking
    case transit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving: return "Driving"
        case .walking: return "Walking"
        case .transit: return "Transit"
        }
    }
}

struct AlarmBehaviorSnapshot: Sendable {
    let barrageCount: Int
    let barrageIntervalSeconds: Int
    let snoozeMinutes: Int
    let timeToLeaveEnabled: Bool
    let timeToLeavePrepMinutes: Int
    let timeToLeaveFallbackMinutes: Int
    let timeToLeaveTransport: TimeToLeaveTransport
    let geofenceEnabled: Bool
    let geofenceDefaultRadiusMeters: Int
    let geofenceRearmMinutes: Int
    let snoozedUntil: Date?
}

enum SettingsKeys {
    static let selectedCalendarIds = "selectedCalendarIds"
    static let didChooseCalendars = "didChooseCalendars"
    static let barrageCount = "barrageCount"
    static let barrageIntervalSeconds = "barrageIntervalSeconds"
    static let snoozeMinutes = "snoozeMinutes"
    static let timeToLeaveEnabled = "timeToLeaveEnabled"
    static let timeToLeavePrepMinutes = "timeToLeavePrepMinutes"
    static let timeToLeaveFallbackMinutes = "timeToLeaveFallbackMinutes"
    static let timeToLeaveTransport = "timeToLeaveTransport"
    static let geofenceEnabled = "geofenceEnabled"
    static let geofenceDefaultRadiusMeters = "geofenceDefaultRadiusMeters"
    static let geofenceRearmMinutes = "geofenceRearmMinutes"
    static let snoozedUntil = "snoozedUntil"
}

enum SettingsSnapshot {
    static func selectedCalendarIds() -> Set<String> {
        if let saved = UserDefaults.standard.array(forKey: SettingsKeys.selectedCalendarIds) as? [String] {
            return Set(saved)
        }
        return []
    }

    static func alarmBehavior() -> AlarmBehaviorSnapshot {
        let savedCount = UserDefaults.standard.integer(forKey: SettingsKeys.barrageCount)
        let savedInterval = UserDefaults.standard.integer(forKey: SettingsKeys.barrageIntervalSeconds)
        let savedSnooze = UserDefaults.standard.integer(forKey: SettingsKeys.snoozeMinutes)
        let prep = UserDefaults.standard.integer(forKey: SettingsKeys.timeToLeavePrepMinutes)
        let fallback = UserDefaults.standard.integer(forKey: SettingsKeys.timeToLeaveFallbackMinutes)
        let transportRaw = UserDefaults.standard.string(forKey: SettingsKeys.timeToLeaveTransport)
            ?? SettingsStore.defaultTimeToLeaveTransport.rawValue
        let transport = TimeToLeaveTransport(rawValue: transportRaw) ?? SettingsStore.defaultTimeToLeaveTransport
        let savedGeofenceRadius = UserDefaults.standard.integer(forKey: SettingsKeys.geofenceDefaultRadiusMeters)
        let savedGeofenceRearmMinutes = UserDefaults.standard.integer(forKey: SettingsKeys.geofenceRearmMinutes)
        let geofenceRearmMinutes = savedGeofenceRearmMinutes > 0
            ? savedGeofenceRearmMinutes
            : SettingsStore.defaultGeofenceRearmMinutes
        let snoozedUntil = UserDefaults.standard.object(forKey: SettingsKeys.snoozedUntil) as? Date

        return AlarmBehaviorSnapshot(
            barrageCount: savedCount > 0 ? savedCount : SettingsStore.defaultBarrageCount,
            barrageIntervalSeconds: savedInterval > 0 ? savedInterval : SettingsStore.defaultBarrageIntervalSeconds,
            snoozeMinutes: savedSnooze > 0 ? savedSnooze : SettingsStore.defaultSnoozeMinutes,
            timeToLeaveEnabled: UserDefaults.standard.object(forKey: SettingsKeys.timeToLeaveEnabled) != nil
                ? UserDefaults.standard.bool(forKey: SettingsKeys.timeToLeaveEnabled)
                : SettingsStore.defaultTimeToLeaveEnabled,
            timeToLeavePrepMinutes: prep > 0 ? prep : SettingsStore.defaultTimeToLeavePrepMinutes,
            timeToLeaveFallbackMinutes: fallback > 0 ? fallback : SettingsStore.defaultTimeToLeaveFallbackMinutes,
            timeToLeaveTransport: transport,
            geofenceEnabled: UserDefaults.standard.object(forKey: SettingsKeys.geofenceEnabled) != nil
                ? UserDefaults.standard.bool(forKey: SettingsKeys.geofenceEnabled)
                : SettingsStore.defaultGeofenceEnabled,
            geofenceDefaultRadiusMeters: savedGeofenceRadius > 0
                ? savedGeofenceRadius
                : SettingsStore.defaultGeofenceDefaultRadiusMeters,
            geofenceRearmMinutes: geofenceRearmMinutes,
            snoozedUntil: snoozedUntil
        )
    }

    static func setSnoozedUntil(_ date: Date?) {
        UserDefaults.standard.set(date, forKey: SettingsKeys.snoozedUntil)
        Task { @MainActor in
            SettingsStore.shared.snoozedUntil = date
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    static let defaultBarrageCount = 30
    static let defaultBarrageIntervalSeconds = 10
    static let defaultSnoozeMinutes = 5
    static let defaultTimeToLeaveEnabled = true
    static let defaultTimeToLeavePrepMinutes = 10
    static let defaultTimeToLeaveFallbackMinutes = 30
    static let defaultTimeToLeaveTransport: TimeToLeaveTransport = .driving
    static let defaultGeofenceEnabled = true
    static let defaultGeofenceDefaultRadiusMeters = 200
    static let defaultGeofenceRearmMinutes = 5

    @Published var selectedCalendarIds: Set<String> {
        didSet {
            save()
        }
    }
    @Published var didChooseCalendars: Bool {
        didSet {
            save()
        }
    }
    @Published var barrageCount: Int {
        didSet {
            save()
        }
    }
    @Published var barrageIntervalSeconds: Int {
        didSet {
            save()
        }
    }
    @Published var snoozeMinutes: Int {
        didSet {
            save()
        }
    }
    @Published var timeToLeaveEnabled: Bool {
        didSet {
            save()
        }
    }
    @Published var timeToLeavePrepMinutes: Int {
        didSet {
            save()
        }
    }
    @Published var timeToLeaveFallbackMinutes: Int {
        didSet {
            save()
        }
    }
    @Published var timeToLeaveTransportRaw: String {
        didSet {
            save()
        }
    }
    @Published var geofenceEnabled: Bool {
        didSet {
            save()
        }
    }
    @Published var geofenceDefaultRadiusMeters: Int {
        didSet {
            save()
        }
    }
    @Published var geofenceRearmMinutes: Int {
        didSet {
            save()
        }
    }
    var snoozedUntil: Date? {
        didSet {
            save()
        }
    }

    var timeToLeaveTransport: TimeToLeaveTransport {
        get { TimeToLeaveTransport(rawValue: timeToLeaveTransportRaw) ?? Self.defaultTimeToLeaveTransport }
        set { timeToLeaveTransportRaw = newValue.rawValue }
    }

    private init() {
        if let saved = UserDefaults.standard.array(forKey: SettingsKeys.selectedCalendarIds) as? [String] {
            selectedCalendarIds = Set(saved)
        } else {
            selectedCalendarIds = []
        }
        didChooseCalendars = UserDefaults.standard.bool(forKey: SettingsKeys.didChooseCalendars)

        let savedCount = UserDefaults.standard.integer(forKey: SettingsKeys.barrageCount)
        barrageCount = savedCount > 0 ? savedCount : Self.defaultBarrageCount

        let savedInterval = UserDefaults.standard.integer(forKey: SettingsKeys.barrageIntervalSeconds)
        barrageIntervalSeconds = savedInterval > 0 ? savedInterval : Self.defaultBarrageIntervalSeconds

        let savedSnooze = UserDefaults.standard.integer(forKey: SettingsKeys.snoozeMinutes)
        snoozeMinutes = savedSnooze > 0 ? savedSnooze : Self.defaultSnoozeMinutes

        if UserDefaults.standard.object(forKey: SettingsKeys.timeToLeaveEnabled) != nil {
            timeToLeaveEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.timeToLeaveEnabled)
        } else {
            timeToLeaveEnabled = Self.defaultTimeToLeaveEnabled
        }
        let prep = UserDefaults.standard.integer(forKey: SettingsKeys.timeToLeavePrepMinutes)
        timeToLeavePrepMinutes = prep > 0 ? prep : Self.defaultTimeToLeavePrepMinutes

        let fallback = UserDefaults.standard.integer(forKey: SettingsKeys.timeToLeaveFallbackMinutes)
        timeToLeaveFallbackMinutes = fallback > 0 ? fallback : Self.defaultTimeToLeaveFallbackMinutes

        timeToLeaveTransportRaw = UserDefaults.standard.string(forKey: SettingsKeys.timeToLeaveTransport)
            ?? Self.defaultTimeToLeaveTransport.rawValue
        if UserDefaults.standard.object(forKey: SettingsKeys.geofenceEnabled) != nil {
            geofenceEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.geofenceEnabled)
        } else {
            geofenceEnabled = Self.defaultGeofenceEnabled
        }
        let geofenceRadius = UserDefaults.standard.integer(forKey: SettingsKeys.geofenceDefaultRadiusMeters)
        geofenceDefaultRadiusMeters = geofenceRadius > 0 ? geofenceRadius : Self.defaultGeofenceDefaultRadiusMeters
        let geofenceMinutes = UserDefaults.standard.integer(forKey: SettingsKeys.geofenceRearmMinutes)
        geofenceRearmMinutes = geofenceMinutes > 0 ? geofenceMinutes : Self.defaultGeofenceRearmMinutes
        snoozedUntil = UserDefaults.standard.object(forKey: SettingsKeys.snoozedUntil) as? Date
    }

    private func save() {
        UserDefaults.standard.set(Array(selectedCalendarIds), forKey: SettingsKeys.selectedCalendarIds)
        UserDefaults.standard.set(didChooseCalendars, forKey: SettingsKeys.didChooseCalendars)
        UserDefaults.standard.set(barrageCount, forKey: SettingsKeys.barrageCount)
        UserDefaults.standard.set(barrageIntervalSeconds, forKey: SettingsKeys.barrageIntervalSeconds)
        UserDefaults.standard.set(snoozeMinutes, forKey: SettingsKeys.snoozeMinutes)
        UserDefaults.standard.set(timeToLeaveEnabled, forKey: SettingsKeys.timeToLeaveEnabled)
        UserDefaults.standard.set(timeToLeavePrepMinutes, forKey: SettingsKeys.timeToLeavePrepMinutes)
        UserDefaults.standard.set(timeToLeaveFallbackMinutes, forKey: SettingsKeys.timeToLeaveFallbackMinutes)
        UserDefaults.standard.set(timeToLeaveTransportRaw, forKey: SettingsKeys.timeToLeaveTransport)
        UserDefaults.standard.set(geofenceEnabled, forKey: SettingsKeys.geofenceEnabled)
        UserDefaults.standard.set(geofenceDefaultRadiusMeters, forKey: SettingsKeys.geofenceDefaultRadiusMeters)
        UserDefaults.standard.set(geofenceRearmMinutes, forKey: SettingsKeys.geofenceRearmMinutes)
        UserDefaults.standard.set(snoozedUntil, forKey: SettingsKeys.snoozedUntil)
    }
}
