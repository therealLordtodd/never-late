import CoreLocation
import EventKit
import Foundation
import UserNotifications

enum NotificationConstants {
    static let categoryId = "NL_ALARM"
    static let snoozeActionId = "SNOOZE_ALARM"
    static let stopActionId = "STOP_ALARM"
    static let requestPrefix = "event-alarm-"
    static let barragePrefix = "barrage-alarm-"
    static let snoozeWakePrefix = "snooze-alarm-"
    static let snoozeBarragePrefix = "snooze-barrage-"
    static let geofenceRequestPrefix = "geofence-alarm-"
    static let geofenceBarragePrefix = "geofence-barrage-"
    static let threadId = "nl-alarm-thread"
    static let contentId = "nl-active-alarm"
}

final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            AppLog.app.error("Notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func registerCategories() {
        let behavior = SettingsSnapshot.alarmBehavior()
        let stop = UNNotificationAction(
            identifier: NotificationConstants.stopActionId,
            title: "Stop Alarm",
            options: [.destructive]
        )
        let snoozeTitle = "Snooze \(behavior.snoozeMinutes) min"
        let snooze = UNNotificationAction(
            identifier: NotificationConstants.snoozeActionId,
            title: snoozeTitle,
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationConstants.categoryId,
            actions: [stop, snooze],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func clearPendingEventAlarms() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.compactMap { request -> String? in
            if request.identifier.hasPrefix(NotificationConstants.requestPrefix)
                || request.identifier.hasPrefix(NotificationConstants.barragePrefix) {
                return request.identifier
            }
            return nil
        }
        guard identifiers.isEmpty == false else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        AppLog.app.info("Cleared pending event alarms (count: \(identifiers.count))")
    }

    func clearPersistentAlarms() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.compactMap { request -> String? in
            if request.identifier.hasPrefix(NotificationConstants.barragePrefix)
                || request.identifier.hasPrefix(NotificationConstants.snoozeWakePrefix)
                || request.identifier.hasPrefix(NotificationConstants.snoozeBarragePrefix)
                || request.identifier.hasPrefix(NotificationConstants.geofenceBarragePrefix) {
                return request.identifier
            }
            return nil
        }
        guard identifiers.isEmpty == false else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        AppLog.app.info("Cleared persistent alarms (count: \(identifiers.count))")
    }

    func clearDeliveredAlarmNotifications() async {
        let notifications = await center.deliveredNotifications()
        let identifiers = notifications.compactMap { item -> String? in
            let id = item.request.identifier
            if id.hasPrefix(NotificationConstants.requestPrefix)
                || id.hasPrefix(NotificationConstants.barragePrefix)
                || id.hasPrefix(NotificationConstants.snoozeWakePrefix)
                || id.hasPrefix(NotificationConstants.snoozeBarragePrefix)
                || id.hasPrefix(NotificationConstants.geofenceRequestPrefix)
                || id.hasPrefix(NotificationConstants.geofenceBarragePrefix) {
                return id
            }
            return nil
        }
        guard identifiers.isEmpty == false else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func schedule(alarms: [CalendarEventAlarm]) async {
        await clearPendingEventAlarms()
        await clearDeliveredAlarmNotifications()
        registerCategories()

        let now = Date()
        let behavior = SettingsSnapshot.alarmBehavior()
        let snoozedUntil = behavior.snoozedUntil
        let effectiveAlarms: [CalendarEventAlarm]
        let isSnoozeActive: Bool
        if let snoozedUntil, snoozedUntil > now {
            isSnoozeActive = true
            effectiveAlarms = alarms.filter { $0.fireDate >= snoozedUntil }
        } else {
            isSnoozeActive = false
            if snoozedUntil != nil {
                clearSnoozeState()
            }
            effectiveAlarms = alarms
        }

        let canUseGeofence = behavior.geofenceEnabled && GeofenceAlarmMonitor.shared.canMonitorProximityAlarms()
        let proximityAlarms = canUseGeofence
            ? effectiveAlarms.filter {
                guard let proximity = $0.alarm?.proximity else { return false }
                return proximity != EKAlarmProximity.none
            }
            : []
        GeofenceAlarmMonitor.shared.syncProximityAlarms(proximityAlarms)

        let schedulableAlarms = effectiveAlarms.filter {
            guard let proximity = $0.alarm?.proximity else { return true }
            if proximity == EKAlarmProximity.none { return true }
            // If geofence monitoring is off/unavailable, keep proximity alarms as timed fallbacks.
            return canUseGeofence == false
        }
        AppLog.app.info(
            "Scheduling alarms total=\(effectiveAlarms.count) schedulable=\(schedulableAlarms.count) proximity=\(proximityAlarms.count) geofenceActive=\(canUseGeofence)"
        )
        let barrageTarget = isSnoozeActive ? nil : schedulableAlarms.min { $0.fireDate < $1.fireDate }
        for alarm in schedulableAlarms {
            let event = alarm.event
            let fireDate = alarm.fireDate

            let content = UNMutableNotificationContent()
            content.title = event.title ?? "Calendar Alarm"
            if alarm.kind == .timeToLeave {
                content.body = "Time to leave"
            } else if let location = event.location, !location.isEmpty {
                content.body = location
            } else {
                content.body = "Upcoming event"
            }
            configureAlarmContent(content)
            content.userInfo = [
                "eventIdentifier": event.eventIdentifier ?? "",
                "eventTitle": event.title ?? "Calendar Alarm",
                "alarmKind": alarm.kind.rawValue
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = NotificationConstants.requestPrefix + UUID().uuidString
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                AppLog.app.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }

        if let target = barrageTarget {
            await schedulePersistentBurst(
                title: target.event.title ?? "Calendar Alarm",
                start: target.fireDate,
                prefix: NotificationConstants.barragePrefix
            )
        }
    }

    func scheduleGeofenceTrigger(title: String, body: String) async {
        let now = Date()
        let behavior = SettingsSnapshot.alarmBehavior()
        if let snoozedUntil = behavior.snoozedUntil, snoozedUntil > now {
            AppLog.app.info("Skipping geofence trigger while snoozed.")
            return
        }
        if let snoozedUntil = behavior.snoozedUntil, snoozedUntil <= now {
            clearSnoozeState()
        }

        registerCategories()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        configureAlarmContent(content)
        content.userInfo = [
            "eventTitle": title,
            "alarmKind": CalendarEventAlarmKind.calendar.rawValue,
            "source": "geofence"
        ]

        do {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let immediateRequest = UNNotificationRequest(
                identifier: NotificationConstants.geofenceRequestPrefix + UUID().uuidString,
                content: content,
                trigger: trigger
            )
            try await center.add(immediateRequest)
            await schedulePersistentBurst(
                title: title,
                start: now,
                prefix: NotificationConstants.geofenceBarragePrefix
            )
        } catch {
            AppLog.app.error("Failed to schedule geofence trigger: \(error.localizedDescription)")
        }
    }

    func scheduleSnooze(title: String) async {
        await clearPendingEventAlarms()
        await clearPersistentAlarms()
        await clearDeliveredAlarmNotifications()
        registerCategories()
        let behavior = SettingsSnapshot.alarmBehavior()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Snoozed"
        configureAlarmContent(content)

        let snoozeInterval = TimeInterval(behavior.snoozeMinutes * 60)
        let snoozedUntil = Date().addingTimeInterval(snoozeInterval)
        SettingsSnapshot.setSnoozedUntil(snoozedUntil)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationConstants.snoozeWakePrefix + UUID().uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            await schedulePersistentBurst(
                title: title,
                start: snoozedUntil,
                prefix: NotificationConstants.snoozeBarragePrefix
            )
        } catch {
            AppLog.app.error("Failed to schedule snooze: \(error.localizedDescription)")
        }
    }

    func clearSnoozeState() {
        SettingsSnapshot.setSnoozedUntil(nil)
    }

    private func schedulePersistentBurst(
        title: String,
        start: Date,
        prefix: String
    ) async {
        let behavior = SettingsSnapshot.alarmBehavior()
        let count = max(1, behavior.barrageCount)
        let interval = TimeInterval(max(1, behavior.barrageIntervalSeconds))
        guard count > 0 else { return }

        for index in 1...count {
            let fireDate = start.addingTimeInterval(interval * Double(index))
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Alarm"
            configureAlarmContent(content)

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = prefix + UUID().uuidString
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                AppLog.app.error("Failed to schedule persistent alarm: \(error.localizedDescription)")
                break
            }
        }
    }

    private func configureAlarmContent(_ content: UNMutableNotificationContent) {
        content.sound = .default
        content.categoryIdentifier = NotificationConstants.categoryId
        content.threadIdentifier = NotificationConstants.threadId
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
            content.targetContentIdentifier = NotificationConstants.contentId
        }
    }
}

private enum GeofenceConstants {
    static let regionPrefix = "nl-geofence-"
    static let payloadStoreKey = "geofenceAlarmPayloads"
    static let maxMonitoredRegions = 20
    static let minRadius: CLLocationDistance = 100
    static let maxRadius: CLLocationDistance = 1_000
}

private struct GeofencePayload {
    let title: String
    let body: String
}

extension Notification.Name {
    static let geofenceAuthorizationDidChange = Notification.Name("GeofenceAuthorizationDidChange")
}

final class GeofenceAlarmMonitor: NSObject, CLLocationManagerDelegate {
    static let shared = GeofenceAlarmMonitor()

    private let manager = CLLocationManager()
    private let scheduler = NotificationScheduler()
    private var lastTriggerAtByRegionId: [String: Date] = [:]

    private override init() {
        super.init()
        manager.delegate = self
    }

    func activate() {
        DispatchQueue.main.async { [weak self] in
            _ = self?.manager.authorizationStatus
        }
    }

    func authorizationStatus() -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() {
        DispatchQueue.main.async { [weak self] in
            self?.ensureAuthorizationForMonitoring()
        }
    }

    func canMonitorProximityAlarms() -> Bool {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return false }
        guard CLLocationManager.locationServicesEnabled() else { return false }
        return manager.authorizationStatus == .authorizedAlways
    }

    func syncProximityAlarms(_ alarms: [CalendarEventAlarm]) {
        DispatchQueue.main.async { [weak self] in
            self?.applyProximityAlarms(alarms)
        }
    }

    private func applyProximityAlarms(_ alarms: [CalendarEventAlarm]) {
        let behavior = SettingsSnapshot.alarmBehavior()
        guard behavior.geofenceEnabled else {
            stopAllManagedRegions()
            return
        }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            AppLog.app.warning("Region monitoring is unavailable on this device.")
            stopAllManagedRegions()
            return
        }
        guard CLLocationManager.locationServicesEnabled() else {
            AppLog.app.warning("Location services are disabled; cannot monitor geofence alarms.")
            stopAllManagedRegions()
            return
        }

        ensureAuthorizationForMonitoring()
        guard manager.authorizationStatus == .authorizedAlways else {
            stopAllManagedRegions()
            return
        }

        let now = Date()
        let desired = alarms
            .filter { alarm in
                guard let proximity = alarm.alarm?.proximity else { return false }
                return proximity != .none && alarm.event.endDate > now
            }
            .sorted { $0.fireDate < $1.fireDate }
            .compactMap { config(for: $0, behavior: behavior) }

        let cappedDesired = Array(desired.prefix(GeofenceConstants.maxMonitoredRegions))
        let desiredIds = Set(cappedDesired.map { $0.region.identifier })

        var payloads = loadPayloads()
        payloads = payloads.filter { desiredIds.contains($0.key) }
        for config in cappedDesired {
            payloads[config.region.identifier] = config.payload
        }
        savePayloads(payloads)

        let managedRegions = manager.monitoredRegions.filter {
            $0.identifier.hasPrefix(GeofenceConstants.regionPrefix)
        }
        let existingIds = Set(managedRegions.map(\.identifier))
        for region in managedRegions where desiredIds.contains(region.identifier) == false {
            manager.stopMonitoring(for: region)
            AppLog.app.info("Stopped monitoring stale geofence region.")
        }
        for config in cappedDesired where existingIds.contains(config.region.identifier) == false {
            manager.startMonitoring(for: config.region)
            AppLog.app.info("Started geofence monitoring for calendar alarm.")
        }
    }

    private func ensureAuthorizationForMonitoring() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
            AppLog.app.info("Requested Always location authorization for geofence alarms.")
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            AppLog.app.info("Requested location upgrade to Always for geofence alarms.")
        case .authorizedAlways:
            break
        case .restricted, .denied:
            AppLog.app.warning("Location authorization is restricted/denied for geofence alarms.")
        @unknown default:
            AppLog.app.warning("Unknown location authorization status.")
        }
    }

    private func stopAllManagedRegions() {
        let managedRegions = manager.monitoredRegions.filter {
            $0.identifier.hasPrefix(GeofenceConstants.regionPrefix)
        }
        for region in managedRegions {
            manager.stopMonitoring(for: region)
        }
        savePayloads([:])
    }

    private func config(
        for alarm: CalendarEventAlarm,
        behavior: AlarmBehaviorSnapshot
    ) -> (region: CLCircularRegion, payload: GeofencePayload)? {
        guard let ekAlarm = alarm.alarm else { return nil }
        let proximity = ekAlarm.proximity
        guard proximity != .none else { return nil }

        let structured = ekAlarm.structuredLocation ?? alarm.event.structuredLocation
        guard let geoLocation = structured?.geoLocation else {
            AppLog.app.warning("Skipping proximity alarm without geolocation.")
            return nil
        }
        let coordinate = geoLocation.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            AppLog.app.warning("Skipping proximity alarm with invalid geolocation.")
            return nil
        }

        let radius = sanitizedRadius(structured?.radius ?? 0, fallbackMeters: behavior.geofenceDefaultRadiusMeters)
        let regionId = regionIdentifier(for: alarm.event, proximity: proximity)
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: regionId)
        region.notifyOnEntry = (proximity == .enter)
        region.notifyOnExit = (proximity == .leave)

        let title = alarm.event.title ?? "Calendar Alarm"
        let body = (proximity == .enter) ? "Arrived at event location" : "Left event location"
        return (region, GeofencePayload(title: title, body: body))
    }

    private func regionIdentifier(for event: EKEvent, proximity: EKAlarmProximity) -> String {
        let eventKey = event.calendarItemIdentifier
        let start = Int(event.startDate.timeIntervalSince1970)
        return "\(GeofenceConstants.regionPrefix)\(eventKey)-\(start)-\(proximity.rawValue)"
    }

    private func sanitizedRadius(
        _ radius: CLLocationDistance,
        fallbackMeters: Int
    ) -> CLLocationDistance {
        if radius <= 0 {
            let fallback = CLLocationDistance(fallbackMeters)
            return min(max(fallback, GeofenceConstants.minRadius), GeofenceConstants.maxRadius)
        }
        return min(max(radius, GeofenceConstants.minRadius), GeofenceConstants.maxRadius)
    }

    private func shouldProcessTrigger(for regionId: String) -> Bool {
        let now = Date()
        let behavior = SettingsSnapshot.alarmBehavior()
        let cooldown = TimeInterval(max(1, behavior.geofenceRearmMinutes) * 60)
        if let last = lastTriggerAtByRegionId[regionId],
            now.timeIntervalSince(last) < cooldown {
            return false
        }
        lastTriggerAtByRegionId[regionId] = now
        return true
    }

    private func handleRegionTrigger(_ region: CLRegion) {
        guard region.identifier.hasPrefix(GeofenceConstants.regionPrefix) else { return }
        guard shouldProcessTrigger(for: region.identifier) else { return }

        let payload = loadPayloads()[region.identifier]
        let title = payload?.title ?? "Calendar Alarm"
        let body = payload?.body ?? "Location alarm"
        Task {
            await scheduler.scheduleGeofenceTrigger(title: title, body: body)
        }
    }

    private func loadPayloads() -> [String: GeofencePayload] {
        guard let raw = UserDefaults.standard.dictionary(forKey: GeofenceConstants.payloadStoreKey)
            as? [String: [String: String]] else {
            return [:]
        }
        return raw.reduce(into: [:]) { partialResult, pair in
            let title = pair.value["title"] ?? "Calendar Alarm"
            let body = pair.value["body"] ?? "Location alarm"
            partialResult[pair.key] = GeofencePayload(title: title, body: body)
        }
    }

    private func savePayloads(_ payloads: [String: GeofencePayload]) {
        let raw = payloads.reduce(into: [String: [String: String]]()) { partialResult, pair in
            partialResult[pair.key] = [
                "title": pair.value.title,
                "body": pair.value.body
            ]
        }
        UserDefaults.standard.set(raw, forKey: GeofenceConstants.payloadStoreKey)
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        NotificationCenter.default.post(name: .geofenceAuthorizationDidChange, object: nil)
        switch manager.authorizationStatus {
        case .authorizedAlways:
            AppLog.app.info("Location authorization granted: always.")
        case .authorizedWhenInUse:
            AppLog.app.warning("Location authorization is when-in-use; geofence alarms need always.")
        case .denied, .restricted:
            AppLog.app.warning("Location authorization denied/restricted; geofence alarms disabled.")
        case .notDetermined:
            break
        @unknown default:
            AppLog.app.warning("Unknown location authorization status.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        handleRegionTrigger(region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        handleRegionTrigger(region)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLog.app.error("Location manager error: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let regionId = region?.identifier ?? "unknown"
        AppLog.app.error(
            "Failed geofence monitoring for region \(regionId): \(error.localizedDescription)"
        )
    }
}
