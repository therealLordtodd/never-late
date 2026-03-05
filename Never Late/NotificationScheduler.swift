import CoreLocation
import EventKit
import Foundation
import UserNotifications

enum NotificationConstants {
    static let categoryId = "NL_ALARM"
    static let snoozeActionId = "SNOOZE_ALARM"
    static let dismissActionId = "DISMISS_ALARM"
    static let legacyStopActionId = "STOP_ALARM"
    static let requestPrefix = "event-alarm-"
    static let barragePrefix = "barrage-alarm-"
    static let snoozeWakePrefix = "snooze-alarm-"
    static let snoozeBarragePrefix = "snooze-barrage-"
    static let geofenceRequestPrefix = "geofence-alarm-"
    static let geofenceBarragePrefix = "geofence-barrage-"
    static let contentId = "nl-active-alarm"
}

final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private static let logDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    private static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    func requestAuthorization() async -> Bool {
        do {
            var options: UNAuthorizationOptions = [.alert, .sound, .badge]
            if #available(iOS 15.0, *) {
                options.insert(.timeSensitive)
            }
            let granted = try await center.requestAuthorization(options: options)
            await logNotificationSettings(context: "request-authorization")
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
        let snoozeTitle = "Snooze \(behavior.snoozeMinutes) min"
        let snooze = UNNotificationAction(
            identifier: NotificationConstants.snoozeActionId,
            title: snoozeTitle,
            options: []
        )
        // .customDismissAction makes the system dismiss (swipe / X button) trigger our
        // didReceive handler so we can clear all pending barrage notifications at once.
        // No custom dismiss action needed — the system dismiss button is the standard UX.
        let category = UNNotificationCategory(
            identifier: NotificationConstants.categoryId,
            actions: [snooze],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )
        center.setNotificationCategories([category])
    }

    func clearPendingEventAlarms() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.compactMap { request -> String? in
            if request.identifier.hasPrefix(NotificationConstants.requestPrefix) {
                return request.identifier
            }
            return nil
        }
        guard identifiers.isEmpty == false else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        AppLog.app.info("Cleared pending event alarms (count: \(identifiers.count))")
    }

    private func clearPendingEventBarrages(exceptKey: String?) async {
        let requests = await center.pendingNotificationRequests()
        let keepPrefix = exceptKey.map { NotificationConstants.barragePrefix + $0 + "-" }
        let identifiers = requests.compactMap { request -> String? in
            let id = request.identifier
            guard id.hasPrefix(NotificationConstants.barragePrefix) else { return nil }
            if let keepPrefix, id.hasPrefix(keepPrefix) {
                return nil
            }
            return id
        }
        guard identifiers.isEmpty == false else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        AppLog.app.info("Cleared pending event barrages (count: \(identifiers.count))")
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

    /// iOS caps pending local notifications at 64 per app.
    private static let iosNotificationLimit = 64
    /// Slots reserved for snooze-wake, geofence triggers, and headroom.
    private static let reservedSlots = 4

    func schedule(alarms: [CalendarEventAlarm]) async {
        await logNotificationSettings(context: "schedule")
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
        let barrageKey = barrageTarget.map(eventBarrageKey(for:))

        // Fetch all pending once to avoid redundant queries.
        let allPending = await center.pendingNotificationRequests()

        // Compute removal lists from the single snapshot.
        let eventIdsToRemove = allPending
            .compactMap { $0.identifier.hasPrefix(NotificationConstants.requestPrefix) ? $0.identifier : nil }
        let keepPrefix = barrageKey.map { NotificationConstants.barragePrefix + $0 + "-" }
        let barrageIdsToRemove = allPending.compactMap { request -> String? in
            let id = request.identifier
            guard id.hasPrefix(NotificationConstants.barragePrefix) else { return nil }
            if let keepPrefix, id.hasPrefix(keepPrefix) { return nil }
            return id
        }

        // Cap event alarms to stay within iOS 64-notification limit.
        let reservedForBarrage = barrageTarget != nil ? max(1, behavior.barrageCount) : 0
        let nonEventPendingCount = allPending.filter { req in
            !req.identifier.hasPrefix(NotificationConstants.requestPrefix)
                && !barrageIdsToRemove.contains(req.identifier)
        }.count
        let maxEventSlots = max(
            0,
            Self.iosNotificationLimit - reservedForBarrage - Self.reservedSlots - nonEventPendingCount
        )
        let cappedAlarms = Array(schedulableAlarms.prefix(maxEventSlots))
        if cappedAlarms.count < schedulableAlarms.count {
            AppLog.app.warning(
                "Capped event alarms to stay within iOS 64-notification limit.",
                metadata: [
                    "scheduled": "\(cappedAlarms.count)",
                    "total": "\(schedulableAlarms.count)",
                    "dropped": "\(schedulableAlarms.count - cappedAlarms.count)",
                    "nonEventPending": "\(nonEventPendingCount)",
                    "reservedBarrage": "\(reservedForBarrage)"
                ]
            )
        }

        // Build all new requests before clearing old ones to minimize the notification gap.
        var newRequests: [UNNotificationRequest] = []
        for alarm in cappedAlarms {
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
            content.threadIdentifier = threadIdentifier(for: alarm)

            let scheduledFireDate = max(fireDate, now.addingTimeInterval(1))
            let trigger = makeDateTrigger(for: scheduledFireDate)
            let identifier = NotificationConstants.requestPrefix + UUID().uuidString
            newRequests.append(
                UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            )
        }

        // Remove old then add new in quick succession to minimize the gap.
        let allIdsToRemove = eventIdsToRemove + barrageIdsToRemove
        if allIdsToRemove.isEmpty == false {
            center.removePendingNotificationRequests(withIdentifiers: allIdsToRemove)
        }

        var failedCount = 0
        for request in newRequests {
            do {
                try await center.add(request)
            } catch {
                failedCount += 1
                AppLog.app.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
        if failedCount > 0 {
            AppLog.app.warning(
                "Some alarm notifications failed to schedule.",
                metadata: ["failed": "\(failedCount)", "attempted": "\(newRequests.count)"]
            )
        }

        if let target = barrageTarget {
            await schedulePersistentBurst(
                title: target.event.title ?? "Calendar Alarm",
                start: target.fireDate,
                prefix: NotificationConstants.barragePrefix,
                stableIdBase: (barrageKey.map { NotificationConstants.barragePrefix + $0 + "-" }),
                threadIdentifier: threadIdentifier(for: target)
            )
        }

        AppLog.app.info(
            "Finished scheduling notifications.",
            metadata: [
                "scheduled": "\(newRequests.count - failedCount)",
                "failed": "\(failedCount)",
                "capped": "\(cappedAlarms.count < schedulableAlarms.count)"
            ]
        )
        await logPendingAlarmSnapshot(context: "event-refresh")
        await logDeliveredAlarmSnapshot(context: "event-refresh")
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
        content.threadIdentifier = geofenceThreadIdentifier(title: title)

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
                prefix: NotificationConstants.geofenceBarragePrefix,
                threadIdentifier: geofenceThreadIdentifier(title: title)
            )
            await logPendingAlarmSnapshot(context: "geofence-trigger")
            await logDeliveredAlarmSnapshot(context: "geofence-trigger")
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
        content.threadIdentifier = snoozeThreadIdentifier(title: title)

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
                prefix: NotificationConstants.snoozeBarragePrefix,
                threadIdentifier: snoozeThreadIdentifier(title: title)
            )
            await logPendingAlarmSnapshot(context: "snooze")
            await logDeliveredAlarmSnapshot(context: "snooze")
        } catch {
            AppLog.app.error("Failed to schedule snooze: \(error.localizedDescription)")
        }
    }

    func clearSnoozeState() {
        SettingsSnapshot.setSnoozedUntil(nil)
    }

    func logDeliveredAlarmSnapshot(context: String) async {
        let delivered = await center.deliveredNotifications()
            .filter { isAlarmRequestIdentifier($0.request.identifier) }
            .sorted { $0.date > $1.date }

        let latest = delivered.first
        let latestAt = latest.map { Self.logDateTimeFormatter.string(from: $0.date) } ?? "none"
        let latestTitle = latest?.request.content.title ?? "none"
        let latestId = latest?.request.identifier ?? "none"
        let latestThree = delivered
            .prefix(3)
            .map { notification in
                let title = notification.request.content.title.isEmpty ? "Alarm" : notification.request.content.title
                let time = Self.logTimeFormatter.string(from: notification.date)
                return "\(title) @ \(time)"
            }
            .joined(separator: " | ")
        let latestThreeText = latestThree.isEmpty ? "none" : latestThree

        AppLog.app.info(
            "Delivered alarm snapshot.",
            metadata: [
                "context": context,
                "deliveredAlarmCount": "\(delivered.count)",
                "latestDeliveredAt": latestAt,
                "latestDeliveredId": latestId,
                "latestDeliveredTitle": latestTitle,
                "latestThree": latestThreeText
            ]
        )
    }

    private func schedulePersistentBurst(
        title: String,
        start: Date,
        prefix: String,
        stableIdBase: String? = nil,
        threadIdentifier: String
    ) async {
        let behavior = SettingsSnapshot.alarmBehavior()
        let count = max(1, behavior.barrageCount)
        let interval = TimeInterval(max(1, behavior.barrageIntervalSeconds))
        guard count > 0 else { return }
        let now = Date()
        var failedCount = 0

        for index in 1...count {
            let fireDate = start.addingTimeInterval(interval * Double(index))
            if fireDate <= now {
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Alarm"
            configureAlarmContent(content)
            content.threadIdentifier = threadIdentifier

            let trigger = makeDateTrigger(for: fireDate)
            let identifier: String
            if let stableIdBase {
                identifier = "\(stableIdBase)\(index)"
            } else {
                identifier = prefix + UUID().uuidString
            }
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                failedCount += 1
                AppLog.app.error("Failed to schedule persistent alarm: \(error.localizedDescription)")
            }
        }
        if failedCount > 0 {
            AppLog.app.warning(
                "Some barrage notifications failed to schedule.",
                metadata: ["failed": "\(failedCount)", "total": "\(count)"]
            )
        }
    }

    private func makeDateTrigger(for fireDate: Date) -> UNNotificationTrigger {
        let interval = max(1, fireDate.timeIntervalSinceNow)
        return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    }

    private func logNotificationSettings(context: String) async {
        let settings = await center.notificationSettings()
        AppLog.app.info(
            "Notification settings snapshot.",
            metadata: [
                "context": context,
                "authorization": authorizationStatusLabel(settings.authorizationStatus),
                "alert": notificationSettingLabel(settings.alertSetting),
                "lockScreen": notificationSettingLabel(settings.lockScreenSetting),
                "notificationCenter": notificationSettingLabel(settings.notificationCenterSetting),
                "banner": alertStyleLabel(settings.alertStyle),
                "sound": notificationSettingLabel(settings.soundSetting),
                "scheduledDelivery": notificationSettingLabel(settings.scheduledDeliverySetting),
                "timeSensitive": notificationSettingLabel(settings.timeSensitiveSetting)
            ]
        )

        if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
            AppLog.app.warning("Notifications are not fully authorized.")
        }
        if settings.alertSetting != .enabled {
            AppLog.app.warning("Alert presentation is disabled in iOS notification settings.")
        }
        if settings.lockScreenSetting != .enabled {
            AppLog.app.warning("Lock screen alerts are disabled in iOS notification settings.")
        }
        if settings.soundSetting != .enabled {
            AppLog.app.warning("Notification sound is disabled in iOS notification settings.")
        }
        if settings.scheduledDeliverySetting == .enabled && settings.timeSensitiveSetting != .enabled {
            AppLog.app.warning("Scheduled Summary is enabled and Time Sensitive is not enabled; alarm delivery may be delayed.")
        }
    }

    private func logPendingAlarmSnapshot(context: String) async {
        let requests = await center.pendingNotificationRequests()
        let alarmRequests = requests.filter { isAlarmRequestIdentifier($0.identifier) }
        let now = Date()

        let withDates = alarmRequests.compactMap { request -> (UNNotificationRequest, Date)? in
            guard let date = triggerDate(from: request.trigger) else { return nil }
            return (request, date)
        }
        .sorted { $0.1 < $1.1 }

        let next = withDates.first
        let nextAt = next.map { Self.logDateTimeFormatter.string(from: $0.1) } ?? "none"
        let nextInSeconds = next.map { max(0, Int($0.1.timeIntervalSince(now))) } ?? -1
        let nextIdentifier = next?.0.identifier ?? "none"
        let nextTitle = next?.0.content.title ?? "none"
        let preview = withDates
            .prefix(3)
            .map { item in
                let title = item.0.content.title.isEmpty ? "Alarm" : item.0.content.title
                let time = Self.logTimeFormatter.string(from: item.1)
                return "\(title) @ \(time)"
            }
            .joined(separator: " | ")
        let previewText = preview.isEmpty ? "none" : preview

        AppLog.app.info(
            "Pending alarm snapshot.",
            metadata: [
                "context": context,
                "pendingAlarmCount": "\(alarmRequests.count)",
                "nextAlarmAt": nextAt,
                "nextAlarmInSeconds": "\(nextInSeconds)",
                "nextAlarmId": nextIdentifier,
                "nextAlarmTitle": nextTitle,
                "nextThree": previewText
            ]
        )
    }

    private func isAlarmRequestIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(NotificationConstants.requestPrefix)
            || identifier.hasPrefix(NotificationConstants.barragePrefix)
            || identifier.hasPrefix(NotificationConstants.snoozeWakePrefix)
            || identifier.hasPrefix(NotificationConstants.snoozeBarragePrefix)
            || identifier.hasPrefix(NotificationConstants.geofenceRequestPrefix)
            || identifier.hasPrefix(NotificationConstants.geofenceBarragePrefix)
    }

    private func triggerDate(from trigger: UNNotificationTrigger?) -> Date? {
        if let trigger = trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        if let trigger = trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        return nil
    }

    private func eventBarrageKey(for alarm: CalendarEventAlarm) -> String {
        let eventKey = sanitizeIdentifier(alarm.event.calendarItemIdentifier)
        let fireSecond = Int(alarm.fireDate.timeIntervalSince1970)
        return "\(eventKey)-\(alarm.kind.rawValue)-\(fireSecond)"
    }

    private func configureAlarmContent(_ content: UNMutableNotificationContent) {
        content.sound = .default
        content.categoryIdentifier = NotificationConstants.categoryId
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }
    }

    private func threadIdentifier(for alarm: CalendarEventAlarm) -> String {
        let eventKey = sanitizeIdentifier(alarm.event.calendarItemIdentifier)
        return "nl-event-\(eventKey)"
    }

    private func geofenceThreadIdentifier(title: String) -> String {
        "nl-geofence-\(sanitizeIdentifier(title))"
    }

    private func snoozeThreadIdentifier(title: String) -> String {
        "nl-snooze-\(sanitizeIdentifier(title))"
    }

    private func sanitizeIdentifier(_ raw: String) -> String {
        let sanitized = raw.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]",
            with: "-",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "alarm" : sanitized
    }

    private func notificationSettingLabel(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "notSupported"
        case .disabled: return "disabled"
        case .enabled: return "enabled"
        @unknown default: return "unknown"
        }
    }

    private func authorizationStatusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private func alertStyleLabel(_ style: UNAlertStyle) -> String {
        switch style {
        case .none: return "none"
        case .banner: return "banner"
        case .alert: return "alert"
        @unknown default: return "unknown"
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

/// Threading model: All mutable state and CLLocationManager interactions run on the main thread.
/// CLLocationManager was created on main (via AppDelegate), so delegate callbacks arrive on main.
/// Public methods dispatch to main explicitly. Do not call mutable-state methods from background queues.
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
        dispatchPrecondition(condition: .onQueue(.main))
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
        dispatchPrecondition(condition: .onQueue(.main))
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
