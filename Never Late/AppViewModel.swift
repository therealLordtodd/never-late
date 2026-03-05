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
    private let alarmLookaheadDays = 30
    private var isRecalculatingAlarms = false
    private var needsRecalculateAfterCurrent = false

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
                upcomingAlarms = []
                todayAlarms = []
            } else {
                await recalculateAndScheduleAlarms()
            }
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
        await recalculateAndScheduleAlarms()
    }

    func confirmCalendarSelection() async {
        settings.didChooseCalendars = true
        shouldShowCalendarPicker = false
        await recalculateAndScheduleAlarms()
    }

    func applyCalendarSelection(_ selection: Set<String>) async {
        settings.selectedCalendarIds = selection
        settings.didChooseCalendars = true
        shouldShowCalendarPicker = false
        BackgroundRefreshScheduler.shared.schedule()
        await recalculateAndScheduleAlarms()
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
        settings.batchUpdate {
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
        }
        await recalculateAndScheduleAlarms()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func scheduleAlarmsIfPossible() async {
        await recalculateAndScheduleAlarms()
    }

    func refreshTodayAlarms() async {
        if upcomingAlarms.isEmpty == false {
            let now = Date()
            todayAlarms = filterTodayAlarms(from: upcomingAlarms, now: now)
            return
        }
        await recalculateAndScheduleAlarms()
    }

    private func recalculateAndScheduleAlarms() async {
        if isRecalculatingAlarms {
            needsRecalculateAfterCurrent = true
            AppLog.app.info("Alarm recalculation already in progress; queued another pass.")
            return
        }
        isRecalculatingAlarms = true
        needsRecalculateAfterCurrent = false
        defer {
            isRecalculatingAlarms = false
            if needsRecalculateAfterCurrent {
                needsRecalculateAfterCurrent = false
                Task { [weak self] in
                    await self?.recalculateAndScheduleAlarms()
                }
            }
        }

        let calStatus = calendarAccess.authorizationStatus()
        guard CalendarAccess.hasReadAccess(calStatus) else {
            AppLog.app.warning("Skipping alarm schedule: calendar access missing.")
            upcomingAlarms = []
            todayAlarms = []
            return
        }
        let notifStatus = await scheduler.authorizationStatus()
        guard notifStatus == .authorized || notifStatus == .provisional else {
            AppLog.app.warning("Skipping alarm schedule: notifications not authorized.")
            upcomingAlarms = []
            todayAlarms = []
            return
        }
        let selectedCalendars = calendars.filter { settings.selectedCalendarIds.contains($0.calendarIdentifier) }
        guard selectedCalendars.isEmpty == false else {
            AppLog.app.warning("Skipping alarm schedule: no calendars selected.")
            upcomingAlarms = []
            todayAlarms = []
            return
        }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: alarmLookaheadDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(alarmLookaheadDays * 24 * 60 * 60))
        let events = calendarAccess.events(from: now, to: end, in: selectedCalendars)
        let alarms = await calendarAccess.alarms(for: events, now: now, behavior: currentBehaviorSnapshot())
        let sorted = alarms.sorted { $0.fireDate < $1.fireDate }
        upcomingAlarms = sorted
        todayAlarms = filterTodayAlarms(from: sorted, now: now)
        let todayWindowEnd = operationalTodayWindowEnd(for: now)
        let nextAlarm = sorted.first?.fireDate
        let nextAlarmText = nextAlarm?.formatted(date: .abbreviated, time: .standard) ?? "none"
        let nextAlarmInSeconds = nextAlarm.map { Int($0.timeIntervalSince(now)) } ?? -1
        AppLog.app.info(
            "Calculated alarms for scheduling.",
            metadata: [
                "calendarCount": "\(selectedCalendars.count)",
                "eventCount": "\(events.count)",
                "alarmCount": "\(sorted.count)",
                "todayAlarmCount": "\(todayAlarms.count)",
                "todayWindowEnd": todayWindowEnd.formatted(date: .abbreviated, time: .standard),
                "nextAlarmAt": nextAlarmText,
                "nextAlarmInSeconds": "\(nextAlarmInSeconds)"
            ]
        )
        await scheduler.schedule(alarms: sorted)
    }

    private func filterTodayAlarms(from alarms: [CalendarEventAlarm], now: Date) -> [CalendarEventAlarm] {
        let endOfWindow = operationalTodayWindowEnd(for: now)
        return alarms
            .filter { $0.fireDate >= now && $0.fireDate < endOfWindow }
            .sorted { $0.fireDate < $1.fireDate }
    }

    private func operationalTodayWindowEnd(for now: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .hour, value: 25, to: startOfDay)
            ?? startOfDay.addingTimeInterval(25 * 60 * 60)
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
