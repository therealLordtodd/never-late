import EventKit
import Foundation
import UserNotifications
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var calendars: [EKCalendar] = []
    @Published var isRefreshing = false
    @Published var lastRefresh: Date?

    let settings = SettingsStore()
    private let foregroundRefresh = ForegroundRefreshTimer()

    private let calendarAccess = CalendarAccess()
    private let scheduler = NotificationScheduler()

    init() {
        calendarStatus = calendarAccess.authorizationStatus()
        Task {
            notificationStatus = await scheduler.authorizationStatus()
            await refreshCalendars()
            foregroundRefresh.start { [weak self] in
                await self?.refreshCalendars()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshCalendars() }
        }
        // Re-check permission state whenever the app returns to foreground.
        // The iOS 17 calendar permission sheet can briefly background the app;
        // without this observer the UI won't update when the user comes back.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshCalendars() }
        }
    }

    var hasCalendarAccess: Bool {
        if #available(iOS 17.0, *) {
            return calendarStatus == .fullAccess
        } else {
            return calendarStatus == .authorized
        }
    }

    func requestCalendarAccess() async {
        _ = await calendarAccess.requestAccess()
        // Always refresh regardless of granted value: refreshCalendars re-reads
        // the authorisation status and loads calendars for all outcomes including
        // write-only access or a user who previously granted access.
        await refreshCalendars()
    }

    func requestNotificationAccess() async {
        let granted = await scheduler.requestAuthorization()
        notificationStatus = await scheduler.authorizationStatus()
        if granted {
            await refreshCalendars()
        }
    }

    func refreshCalendars() async {
        isRefreshing = true
        defer { isRefreshing = false }

        calendarStatus = calendarAccess.authorizationStatus()
        if hasCalendarReadAccess(calendarStatus) {
            calendars = calendarAccess.calendars().sorted { $0.title < $1.title }
        } else {
            calendars = []
        }

        if calendars.isEmpty == false {
            if settings.selectedCalendarIds.isEmpty {
                settings.selectedCalendarIds = Set(calendars.map { $0.calendarIdentifier })
            }
            await scheduleAlarmsIfPossible()
        }

        lastRefresh = Date()
    }

    func toggleCalendar(_ calendar: EKCalendar) async {
        if settings.selectedCalendarIds.contains(calendar.calendarIdentifier) {
            settings.selectedCalendarIds.remove(calendar.calendarIdentifier)
        } else {
            settings.selectedCalendarIds.insert(calendar.calendarIdentifier)
        }
        BackgroundRefreshScheduler.shared.schedule()
        await scheduleAlarmsIfPossible()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func scheduleAlarmsIfPossible() async {
        let calStatus = calendarAccess.authorizationStatus()
        guard hasCalendarReadAccess(calStatus) else { return }
        let notifStatus = await scheduler.authorizationStatus()
        guard notifStatus == .authorized || notifStatus == .provisional else { return }

        let selectedCalendars = calendars.filter { settings.selectedCalendarIds.contains($0.calendarIdentifier) }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let events = calendarAccess.events(from: now, to: end, in: selectedCalendars)
        let alarms = calendarAccess.alarms(for: events, now: now)

        await scheduler.schedule(alarms: alarms)
    }

    private func hasCalendarReadAccess(_ status: EKAuthorizationStatus) -> Bool {
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    deinit {
        foregroundRefresh.stop()
    }
}
