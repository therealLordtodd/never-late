import EventKit
import Foundation
import UserNotifications
import UIKit
import Combine
import CoreLocation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var calendars: [EKCalendar] = []
    @Published var isRefreshing = false
    @Published var lastRefresh: Date?
    @Published var shouldShowCalendarPicker = false
    @Published var upcomingAlarms: [CalendarEventAlarm] = []
    @Published var todayAlarms: [CalendarEventAlarm] = []

    let settings = SettingsStore.shared
    private let foregroundRefresh = ForegroundRefreshTimer()
    private var settingsObserver: AnyCancellable?
    private var eventStoreChangedObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var geofenceAuthorizationObserver: NSObjectProtocol?

    private let calendarAccess = CalendarAccess()
    private let scheduler = NotificationScheduler()
    private let geofenceMonitor = GeofenceAlarmMonitor.shared

    init() {
        calendarStatus = calendarAccess.authorizationStatus()
        locationStatus = geofenceMonitor.authorizationStatus()
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        Task {
            notificationStatus = await scheduler.authorizationStatus()
            await refreshCalendars()
            foregroundRefresh.start { [weak self] in
                await self?.refreshCalendars()
            }
        }
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshCalendars() }
        }
        // Re-check permission state whenever the app returns to foreground.
        // The iOS 17 calendar permission sheet can briefly background the app;
        // without this observer the UI won't update when the user comes back.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshCalendars() }
        }
        geofenceAuthorizationObserver = NotificationCenter.default.addObserver(
            forName: .geofenceAuthorizationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.locationStatus = self?.geofenceMonitor.authorizationStatus() ?? .notDetermined
                await self?.scheduleAlarmsIfPossible()
            }
        }
    }

    var hasCalendarAccess: Bool {
        CalendarAccess.hasReadAccess(calendarStatus)
    }

    var uiElementContext: String {
        """
        screen: Home
          alarmSettingsButtonVisible: true
        section: Permissions
          calendarAccessEnableButtonVisible: \((hasCalendarAccess == false && calendarStatus != .denied && calendarStatus != .restricted))
          calendarAccessFixInSettingsButtonVisible: \(calendarStatus == .denied)
          notificationsEnableButtonVisible: \(notificationStatus == .notDetermined)
          notificationsFixInSettingsButtonVisible: \(notificationStatus == .denied)
          locationAccessEnableButtonVisible: \((settings.geofenceEnabled && (locationStatus == .notDetermined || locationStatus == .authorizedWhenInUse)))
          locationAccessFixInSettingsButtonVisible: \((settings.geofenceEnabled && locationStatus == .denied))
        section: Calendars
          calendarOpenSettingsButtonVisible: \((hasCalendarAccess && calendars.isEmpty))
          chooseCalendarsButtonVisible: \(settings.selectedCalendarIds.isEmpty)
          changeSelectionButtonVisible: \((settings.selectedCalendarIds.isEmpty == false))
          selectedCalendarsCount: \(settings.selectedCalendarIds.count)
        section: Refresh
          refreshAlarmsButtonDisabled: \((isRefreshing || hasCalendarAccess == false))
          upcomingAlarmsButtonVisible: true
        screen: Calendar Selection
          calendarSelectionCancelButtonVisible: \(settings.selectedCalendarIds.isEmpty == false)
          calendarSelectionSaveButtonEnabledWhenSelectionCountGT0: true
        screen: Upcoming Alarms
          upcomingAlarmsDoneButtonVisible: true
        screen: Alarm Settings
        section: Barrage
          barrageNotificationsStepper: \(settings.barrageCount)
          secondsBetweenNotificationsStepper: \(settings.barrageIntervalSeconds)
          defaultSnoozeMinutesStepper: \(settings.snoozeMinutes)
        section: Time To Leave
          enableTimeToLeaveAlarmsToggle: \(settings.timeToLeaveEnabled)
          prepBufferBeforeLeavingStepper: \(settings.timeToLeavePrepMinutes)
          fallbackLeadTimeStepper: \(settings.timeToLeaveFallbackMinutes)
          travelModeDropdown: \(settings.timeToLeaveTransport.title)
        section: Geofence Alarms
          enableLocationEnterLeaveAlarmsToggle: \(settings.geofenceEnabled)
          defaultGeofenceRadiusStepper: \(settings.geofenceDefaultRadiusMeters)
          rearmDelayStepper: \(settings.geofenceRearmMinutes)
        section: Diagnostics
          enableDiagnosticLoggingToggle: \(settings.loggingEnabled)
          logVerbosityDropdown: \(settings.loggingVerbosity.displayName)
        """
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

    func requestLocationAccess() async {
        geofenceMonitor.requestAuthorization()
        locationStatus = geofenceMonitor.authorizationStatus()
    }

    func refreshCalendars() async {
        isRefreshing = true
        defer { isRefreshing = false }

        calendarStatus = calendarAccess.authorizationStatus()
        locationStatus = geofenceMonitor.authorizationStatus()
        if CalendarAccess.hasReadAccess(calendarStatus) {
            calendars = calendarAccess.calendars().sorted { $0.title < $1.title }
        } else {
            calendars = []
        }

        if calendars.isEmpty == false {
            let validIds = Set(calendars.map { $0.calendarIdentifier })
            let pruned = settings.selectedCalendarIds.intersection(validIds)
            if pruned != settings.selectedCalendarIds {
                settings.selectedCalendarIds = pruned
            }
            if settings.selectedCalendarIds.isEmpty {
                shouldShowCalendarPicker = true
            }
            await scheduleAlarmsIfPossible()
            await refreshTodayAlarms()
        } else {
            shouldShowCalendarPicker = false
            upcomingAlarms = []
            todayAlarms = []
        }

        lastRefresh = Date()
    }

    func toggleCalendar(_ calendar: EKCalendar) async {
        if settings.selectedCalendarIds.contains(calendar.calendarIdentifier) {
            settings.selectedCalendarIds.remove(calendar.calendarIdentifier)
        } else {
            settings.selectedCalendarIds.insert(calendar.calendarIdentifier)
        }
        settings.didChooseCalendars = true
        BackgroundRefreshScheduler.shared.schedule()
        await scheduleAlarmsIfPossible()
    }

    func confirmCalendarSelection() async {
        settings.didChooseCalendars = true
        shouldShowCalendarPicker = false
        await scheduleAlarmsIfPossible()
    }

    func applyCalendarSelection(_ selection: Set<String>) async {
        settings.selectedCalendarIds = selection
        settings.didChooseCalendars = true
        shouldShowCalendarPicker = false
        BackgroundRefreshScheduler.shared.schedule()
        await scheduleAlarmsIfPossible()
        await refreshTodayAlarms()
    }

    func openCalendarPicker() {
        shouldShowCalendarPicker = true
    }

    func updateAlarmBehavior(
        barrageCount: Int,
        barrageIntervalSeconds: Int,
        snoozeMinutes: Int,
        timeToLeaveEnabled: Bool,
        timeToLeavePrepMinutes: Int,
        timeToLeaveFallbackMinutes: Int,
        timeToLeaveTransport: TimeToLeaveTransport,
        geofenceEnabled: Bool,
        geofenceDefaultRadiusMeters: Int,
        geofenceRearmMinutes: Int,
        loggingEnabled: Bool,
        loggingVerbosity: AppLogVerbosity
    ) async {
        settings.barrageCount = barrageCount
        settings.barrageIntervalSeconds = barrageIntervalSeconds
        settings.snoozeMinutes = snoozeMinutes
        settings.timeToLeaveEnabled = timeToLeaveEnabled
        settings.timeToLeavePrepMinutes = timeToLeavePrepMinutes
        settings.timeToLeaveFallbackMinutes = timeToLeaveFallbackMinutes
        settings.timeToLeaveTransport = timeToLeaveTransport
        settings.geofenceEnabled = geofenceEnabled
        settings.geofenceDefaultRadiusMeters = geofenceDefaultRadiusMeters
        settings.geofenceRearmMinutes = geofenceRearmMinutes
        settings.loggingEnabled = loggingEnabled
        settings.loggingVerbosity = loggingVerbosity
        await scheduleAlarmsIfPossible()
        await refreshTodayAlarms()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func scheduleAlarmsIfPossible() async {
        let calStatus = calendarAccess.authorizationStatus()
        guard CalendarAccess.hasReadAccess(calStatus) else {
            upcomingAlarms = []
            todayAlarms = []
            return
        }
        let notifStatus = await scheduler.authorizationStatus()
        guard notifStatus == .authorized || notifStatus == .provisional else {
            upcomingAlarms = []
            todayAlarms = []
            return
        }

        let selectedCalendars = calendars.filter { settings.selectedCalendarIds.contains($0.calendarIdentifier) }
        guard selectedCalendars.isEmpty == false else {
            upcomingAlarms = []
            todayAlarms = []
            return
        }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let events = calendarAccess.events(from: now, to: end, in: selectedCalendars)
        let alarms = await calendarAccess.alarms(for: events, now: now, behavior: currentBehaviorSnapshot())
        upcomingAlarms = alarms.sorted { $0.fireDate < $1.fireDate }

        await scheduler.schedule(alarms: upcomingAlarms)
    }

    func refreshTodayAlarms() async {
        let calStatus = calendarAccess.authorizationStatus()
        guard CalendarAccess.hasReadAccess(calStatus) else {
            todayAlarms = []
            return
        }
        let notifStatus = await scheduler.authorizationStatus()
        guard notifStatus == .authorized || notifStatus == .provisional else {
            todayAlarms = []
            return
        }
        let selectedCalendars = calendars.filter { settings.selectedCalendarIds.contains($0.calendarIdentifier) }
        guard selectedCalendars.isEmpty == false else {
            todayAlarms = []
            return
        }
        let now = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let events = calendarAccess.events(from: now, to: end, in: selectedCalendars)
        let alarms = await calendarAccess.alarms(for: events, now: now, behavior: currentBehaviorSnapshot())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        todayAlarms = alarms
            .filter { $0.fireDate < endOfDay }
            .sorted { $0.fireDate < $1.fireDate }
    }

    private func currentBehaviorSnapshot() -> AlarmBehaviorSnapshot {
        AlarmBehaviorSnapshot(
            barrageCount: settings.barrageCount,
            barrageIntervalSeconds: settings.barrageIntervalSeconds,
            snoozeMinutes: settings.snoozeMinutes,
            timeToLeaveEnabled: settings.timeToLeaveEnabled,
            timeToLeavePrepMinutes: settings.timeToLeavePrepMinutes,
            timeToLeaveFallbackMinutes: settings.timeToLeaveFallbackMinutes,
            timeToLeaveTransport: settings.timeToLeaveTransport,
            geofenceEnabled: settings.geofenceEnabled,
            geofenceDefaultRadiusMeters: settings.geofenceDefaultRadiusMeters,
            geofenceRearmMinutes: settings.geofenceRearmMinutes,
            snoozedUntil: settings.snoozedUntil
        )
    }

    deinit {
        foregroundRefresh.stop()
        if let eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(eventStoreChangedObserver)
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        if let geofenceAuthorizationObserver {
            NotificationCenter.default.removeObserver(geofenceAuthorizationObserver)
        }
    }
}
