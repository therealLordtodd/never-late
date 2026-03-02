import BackgroundTasks
import EventKit
import Foundation

enum BackgroundRefreshConstants {
    static let taskId = "com.toddcowing.neverlate.refresh"
}

final class BackgroundRefreshWorker {
    private let calendarAccess = CalendarAccess()
    private let scheduler = NotificationScheduler()

    func refreshAlarms() async {
        let status = calendarAccess.authorizationStatus()
        guard CalendarAccess.hasReadAccess(status) else { return }

        let notifStatus = await scheduler.authorizationStatus()
        guard notifStatus == .authorized || notifStatus == .provisional else { return }

        let calendars = calendarAccess.calendars()
        let selectedIds = SettingsSnapshot.selectedCalendarIds()
        let behavior = SettingsSnapshot.alarmBehavior()
        let selected = calendars.filter { selectedIds.contains($0.calendarIdentifier) }
        guard selected.isEmpty == false else { return }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let events = calendarAccess.events(from: now, to: end, in: selected)
        let alarms = await calendarAccess.alarms(for: events, now: now, behavior: behavior)
        await scheduler.schedule(alarms: alarms)
    }
}

final class BackgroundRefreshScheduler {
    static let shared = BackgroundRefreshScheduler()
    private init() {}

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundRefreshConstants.taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 30)
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLog.app.info("Background refresh scheduled")
        } catch {
            AppLog.app.error("Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }
}
