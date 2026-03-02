import EventKit
import CoreLocation
import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppViewModel()
    @State private var showMissionBanner = false
    @State private var showRefreshError = false
    @State private var showCalendarPicker = false
    @State private var showUpcomingAlarms = false
    @State private var showAlarmSettings = false

    var body: some View {
        ZStack {
            NLColors.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: NLSpacing.sectionGap) {
                    heroSection
                    if shouldShowPermissionsCard {
                        permissionsCard
                    }
                    calendarCard
                    refreshCard
                    if showMissionBanner {
                        missionAccomplishedBanner
                            .transition(
                                .move(edge: .bottom)
                                .combined(with: .opacity)
                            )
                    }
                }
                .padding(.horizontal, NLSpacing.pagePadding)
                .padding(.top, NLSpacing.pagePadding)
                .padding(.bottom, NLSpacing.scrollBottomPadding)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAlarmSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NLColors.primary)
                    .accessibilityLabel("Alarm Settings")
                }
                .padding(.horizontal, NLSpacing.pagePadding)
                .padding(.bottom, NLSpacing.pagePadding)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: isFullyConfigured) { _, configured in
            withAnimation(.easeInOut(duration: 0.3)) {
                showMissionBanner = configured
            }
        }
        .onAppear {
            showMissionBanner = isFullyConfigured
        }
        .onChange(of: model.shouldShowCalendarPicker) { _, shouldShow in
            if shouldShow {
                showCalendarPicker = true
            }
        }
        .sheet(isPresented: $showCalendarPicker, onDismiss: {
            model.shouldShowCalendarPicker = false
        }) {
            CalendarSelectionSheet(model: model)
        }
        .sheet(isPresented: $showUpcomingAlarms) {
            UpcomingAlarmsSheet(model: model)
        }
        .sheet(isPresented: $showAlarmSettings) {
            AlarmSettingsSheet(model: model)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .center, spacing: NLSpacing.innerGap) {
            VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                Text("Never Late")
                    .font(NLTypography.heroTitle)
                    .foregroundStyle(NLColors.textPrimary)
                Text("Calendar alarms,\ngently persistent.")
                    .font(NLTypography.body)
                    .foregroundStyle(NLColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image("ClockHeadMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: NLSpacing.cardRadius, style: .continuous))
        }
        .padding(.top, NLSpacing.compactGap)
    }

    // MARK: - Permissions Card

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: NLSpacing.innerGap) {
            cardSectionHeader("Permissions")
            permissionRow(
                title: "Calendar Access",
                status: calendarStatusText,
                statusColor: calendarStatusColor,
                showEnable: model.hasCalendarAccess == false
                    && model.calendarStatus != .denied
                    && model.calendarStatus != .restricted,
                showSettings: model.calendarStatus == .denied,
                action: { Task { await model.requestCalendarAccess() } }
            )
            Divider()
                .background(NLColors.cardBorder)
            permissionRow(
                title: "Notifications",
                status: notificationStatusText,
                statusColor: notificationStatusColor,
                showEnable: model.notificationStatus == .notDetermined,
                showSettings: model.notificationStatus == .denied,
                action: { Task { await model.requestNotificationAccess() } }
            )
            if model.settings.geofenceEnabled {
                Divider()
                    .background(NLColors.cardBorder)
                permissionRow(
                    title: "Location Access",
                    status: locationStatusText,
                    statusColor: locationStatusColor,
                    showEnable: model.locationStatus == .notDetermined || model.locationStatus == .authorizedWhenInUse,
                    showSettings: model.locationStatus == .denied,
                    action: { Task { await model.requestLocationAccess() } }
                )
            }
        }
        .nlCardStyle()
    }

    private func permissionRow(
        title: String,
        status: String,
        statusColor: Color,
        showEnable: Bool,
        showSettings: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: NLSpacing.microGap) {
                Text(title)
                    .font(NLTypography.body)
                    .foregroundStyle(NLColors.textPrimary)
                Text(status)
                    .font(NLTypography.caption)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            if showEnable {
                Button("Enable", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(NLColors.primary)
                    .controlSize(.small)
            } else if showSettings {
                Button("Fix in Settings") { model.openSettings() }
                    .buttonStyle(.bordered)
                    .tint(NLColors.destructive)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: NLSpacing.innerGap) {
            cardSectionHeader("Calendars")

            if model.hasCalendarAccess {
                if model.calendars.isEmpty {
                    Text("No calendars found. Connect a calendar account in Settings.")
                        .font(NLTypography.body)
                        .foregroundStyle(NLColors.textSecondary)
                    Button("Open Settings") { model.openSettings() }
                        .buttonStyle(.borderedProminent)
                        .tint(NLColors.primary)
                } else {
                    if model.settings.selectedCalendarIds.isEmpty {
                        Text(selectionSummaryText)
                            .font(NLTypography.body)
                            .foregroundStyle(NLColors.textSecondary)
                        Button("Choose Calendars") {
                            model.openCalendarPicker()
                            showCalendarPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(NLColors.primary)
                    } else {
                        VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                            ForEach(selectedCalendars, id: \.calendarIdentifier) { calendar in
                                HStack(spacing: NLSpacing.compactGap) {
                                    Circle()
                                        .fill(Color(calendar.cgColor))
                                        .frame(width: 10, height: 10)
                                    Text(calendar.title)
                                        .font(NLTypography.body)
                                        .foregroundStyle(NLColors.textPrimary)
                                }
                            }
                        }
                        Button("Change Selection") {
                            model.openCalendarPicker()
                            showCalendarPicker = true
                        }
                        .buttonStyle(.bordered)
                        Text("\(selectedCalendarCount) selected")
                            .font(NLTypography.caption)
                            .foregroundStyle(NLColors.textTertiary)
                    }
                }
            } else {
                Text("Calendar access is required to monitor alarms.")
                    .font(NLTypography.body)
                    .foregroundStyle(NLColors.textSecondary)
            }
        }
        .nlCardStyle()
    }

    // MARK: - Refresh Card

    private var refreshCard: some View {
        VStack(alignment: .leading, spacing: NLSpacing.innerGap) {
            cardSectionHeader("Refresh")

            Text(lastRefreshText)
                .font(NLTypography.caption)
                .foregroundStyle(NLColors.textSecondary)

            HStack(spacing: NLSpacing.compactGap) {
                Button(model.isRefreshing ? "Refreshing…" : "Refresh Alarms") {
                    guard model.hasCalendarAccess else {
                        showRefreshError = true
                        return
                    }
                    showRefreshError = false
                    Task { await model.refreshCalendars() }
                }
                .buttonStyle(.borderedProminent)
                .tint(NLColors.primary)
                .disabled(model.isRefreshing)
                Button("Upcoming") {
                    showUpcomingAlarms = true
                }
                .buttonStyle(.bordered)
            }

            if showRefreshError {
                Text("Enable calendar access above first.")
                    .font(NLTypography.caption)
                    .foregroundStyle(NLColors.warning)
            }
        }
        .nlCardStyle()
    }

    // MARK: - Mission Accomplished Banner

    private var missionAccomplishedBanner: some View {
        VStack(spacing: NLSpacing.innerGap) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: NLTypography.largeIconSize))
                .foregroundStyle(NLColors.primary)
            Text("You're covered.")
                .font(NLTypography.pageTitle)
                .foregroundStyle(NLColors.textPrimary)
            Text("Go be late somewhere else.")
                .font(NLTypography.body)
                .foregroundStyle(NLColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .nlCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: NLSpacing.cardRadius, style: .continuous)
                .strokeBorder(NLColors.primary.opacity(0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Helpers

    private var isFullyConfigured: Bool {
        model.hasCalendarAccess
            && (model.notificationStatus == .authorized || model.notificationStatus == .provisional)
            && (model.settings.geofenceEnabled == false || model.locationStatus == .authorizedAlways)
            && !model.settings.selectedCalendarIds.isEmpty
    }

    private var shouldShowPermissionsCard: Bool {
        if model.hasCalendarAccess == false { return true }
        if model.notificationStatus != .authorized && model.notificationStatus != .provisional { return true }
        if model.settings.geofenceEnabled {
            return model.locationStatus != .authorizedAlways
        }
        return false
    }

    private var selectedCalendarCount: Int {
        let validIds = Set(model.calendars.map { $0.calendarIdentifier })
        return model.settings.selectedCalendarIds.intersection(validIds).count
    }

    private var selectedCalendars: [EKCalendar] {
        let selectedIds = model.settings.selectedCalendarIds
        return model.calendars
            .filter { selectedIds.contains($0.calendarIdentifier) }
            .sorted { $0.title < $1.title }
    }

    private var lastRefreshText: String {
        guard let last = model.lastRefresh else {
            return "Never refreshed. Bold strategy."
        }
        return "Last refresh: \(last.formatted(date: .abbreviated, time: .shortened))"
    }

    private var selectionSummaryText: String {
        if model.settings.selectedCalendarIds.isEmpty {
            return "Pick which calendars Never Late should scan."
        }
        return "Choose which calendars Never Late should scan."
    }

    private var calendarStatusText: String {
        switch model.calendarStatus {
        case .fullAccess:    return "✓ Good to go"
        case .authorized:    return "✓ Good to go"
        case .writeOnly:     return "Write-only access"
        case .denied:        return "Tap to fix in Settings"
        case .restricted:    return "Restricted by device policy"
        case .notDetermined: return "Not yet"
        @unknown default:    return "Unknown"
        }
    }

    private var calendarStatusColor: Color {
        if model.hasCalendarAccess { return NLColors.connected }
        if model.calendarStatus == .denied || model.calendarStatus == .restricted { return NLColors.destructive }
        return NLColors.textTertiary
    }

    private var notificationStatusText: String {
        switch model.notificationStatus {
        case .authorized:    return "✓ Good to go"
        case .provisional:   return "✓ Provisional"
        case .denied:        return "Tap to fix in Settings"
        case .notDetermined: return "Not yet"
        case .ephemeral:     return "Ephemeral"
        @unknown default:    return "Unknown"
        }
    }

    private var notificationStatusColor: Color {
        switch model.notificationStatus {
        case .authorized, .provisional: return NLColors.connected
        case .denied:                   return NLColors.destructive
        default:                        return NLColors.textTertiary
        }
    }

    private var locationStatusText: String {
        switch model.locationStatus {
        case .authorizedAlways:   return "✓ Good to go"
        case .authorizedWhenInUse:return "Needs Always for geofence alarms"
        case .denied:             return "Tap to fix in Settings"
        case .restricted:         return "Restricted by device policy"
        case .notDetermined:      return "Not yet"
        @unknown default:         return "Unknown"
        }
    }

    private var locationStatusColor: Color {
        switch model.locationStatus {
        case .authorizedAlways: return NLColors.connected
        case .denied, .restricted: return NLColors.destructive
        default: return NLColors.textTertiary
        }
    }

    /// Gold uppercase section label used at the top of each card.
    @ViewBuilder
    private func cardSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(NLTypography.sectionHeader)
            .tracking(NLTypography.sectionHeaderTracking)
            .foregroundStyle(NLColors.primary)
    }
}

// MARK: - Card style

private extension View {
    func nlCardStyle() -> some View {
        self
            .padding(NLSpacing.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: NLSpacing.cardRadius, style: .continuous)
                    .fill(NLColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: NLSpacing.cardRadius, style: .continuous)
                            .strokeBorder(NLColors.cardBorder, lineWidth: 1)
                    )
            )
    }
}

private struct CalendarSelectionSheet: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []

    private var isFirstSelection: Bool {
        model.settings.selectedCalendarIds.isEmpty
    }

    private var groupedCalendars: [CalendarGroup] {
        let grouped = Dictionary(grouping: model.calendars) { calendar in
            calendar.source.sourceIdentifier
        }
        return grouped
            .map { key, calendars in
                let source = calendars.first?.source
                return CalendarGroup(
                    id: key,
                    title: source?.title ?? "Unknown Account",
                    type: source.map { sourceTypeLabel($0.sourceType) } ?? "Unknown",
                    calendars: calendars.sorted { $0.title < $1.title }
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            NLColors.appBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: NLSpacing.sectionGap) {
                VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                    Text("Choose Calendars")
                        .font(NLTypography.pageTitle)
                        .foregroundStyle(NLColors.textPrimary)
                    Text("Pick the calendars Never Late should monitor for alarms.")
                        .font(NLTypography.body)
                        .foregroundStyle(NLColors.textSecondary)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: NLSpacing.sectionGap) {
                        ForEach(groupedCalendars) { group in
                            GroupBox {
                                VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                                    VStack(alignment: .leading, spacing: NLSpacing.microGap) {
                                        Text(group.title)
                                            .font(NLTypography.body)
                                            .foregroundStyle(NLColors.textPrimary)
                                        Text(group.type)
                                            .font(NLTypography.caption)
                                            .foregroundStyle(NLColors.textSecondary)
                                    }
                                    .padding(.bottom, NLSpacing.tinyGap)
                                    ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                                        Toggle(isOn: Binding(
                                            get: { selection.contains(calendar.calendarIdentifier) },
                                            set: { isOn in
                                                if isOn {
                                                    selection.insert(calendar.calendarIdentifier)
                                                } else {
                                                    selection.remove(calendar.calendarIdentifier)
                                                }
                                            }
                                        )) {
                                            HStack(spacing: NLSpacing.compactGap) {
                                                Circle()
                                                    .fill(Color(calendar.cgColor))
                                                    .frame(width: 10, height: 10)
                                                Text(calendar.title)
                                                    .font(NLTypography.body)
                                                    .foregroundStyle(NLColors.textPrimary)
                                            }
                                        }
                                        .tint(NLColors.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                if selection.isEmpty {
                    Text("Select at least one calendar to continue.")
                        .font(NLTypography.caption)
                        .foregroundStyle(NLColors.error)
                }

                HStack(spacing: NLSpacing.compactGap) {
                    Spacer()
                    if isFirstSelection == false {
                        Button("Cancel") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                    Button("Save") {
                        Task { await model.applyCalendarSelection(selection) }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NLColors.primary)
                    .disabled(selection.isEmpty)
                }
            }
            .padding(NLSpacing.pagePadding)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selection = model.settings.selectedCalendarIds
        }
    }
}

private struct CalendarGroup: Identifiable {
    let id: String
    let title: String
    let type: String
    let calendars: [EKCalendar]
}

private func sourceTypeLabel(_ type: EKSourceType) -> String {
    switch type {
    case .local: return "On My iPhone"
    case .calDAV: return "CalDAV"
    case .exchange: return "Exchange"
    case .mobileMe: return "iCloud"
    case .subscribed: return "Subscribed"
    case .birthdays: return "Birthdays"
    @unknown default: return "Other"
    }
}

private struct UpcomingAlarmsSheet: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NLColors.appBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: NLSpacing.sectionGap) {
                VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                    Text("Upcoming Alarms")
                        .font(NLTypography.pageTitle)
                        .foregroundStyle(NLColors.textPrimary)
                    Text("Upcoming alarms for today.")
                        .font(NLTypography.body)
                        .foregroundStyle(NLColors.textSecondary)
                }

                if model.todayAlarms.isEmpty {
                    Text("No alarms left today.")
                        .font(NLTypography.body)
                        .foregroundStyle(NLColors.textSecondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                            ForEach(Array(model.todayAlarms.prefix(50).enumerated()), id: \.offset) { _, alarm in
                                VStack(alignment: .leading, spacing: NLSpacing.tinyGap) {
                                    Text(alarm.event.title)
                                        .font(NLTypography.body)
                                        .foregroundStyle(NLColors.textPrimary)
                                    Text("\(alarm.event.startDate.formatted(date: .abbreviated, time: .shortened)) · \(alarm.event.calendar.title)")
                                        .font(NLTypography.caption)
                                        .foregroundStyle(NLColors.textSecondary)
                                    Text(alarmDescription(alarm))
                                        .font(NLTypography.caption)
                                        .foregroundStyle(NLColors.textTertiary)
                                }
                                .padding(NLSpacing.pagePadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: NLSpacing.cardRadius, style: .continuous)
                                        .fill(NLColors.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: NLSpacing.cardRadius, style: .continuous)
                                                .strokeBorder(NLColors.cardBorder, lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(NLSpacing.pagePadding)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await model.refreshTodayAlarms() }
        }
    }

    private func alarmDescription(_ item: CalendarEventAlarm) -> String {
        if item.kind == .timeToLeave {
            return "Alarm: \(item.detail)"
        }
        return "Alarm: \(item.detail)"
    }
}

private struct AlarmSettingsSheet: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var barrageCount = SettingsStore.defaultBarrageCount
    @State private var intervalSeconds = SettingsStore.defaultBarrageIntervalSeconds
    @State private var snoozeMinutes = SettingsStore.defaultSnoozeMinutes
    @State private var timeToLeaveEnabled = SettingsStore.defaultTimeToLeaveEnabled
    @State private var timeToLeavePrepMinutes = SettingsStore.defaultTimeToLeavePrepMinutes
    @State private var timeToLeaveFallbackMinutes = SettingsStore.defaultTimeToLeaveFallbackMinutes
    @State private var timeToLeaveTransport = SettingsStore.defaultTimeToLeaveTransport
    @State private var geofenceEnabled = SettingsStore.defaultGeofenceEnabled
    @State private var geofenceDefaultRadiusMeters = SettingsStore.defaultGeofenceDefaultRadiusMeters
    @State private var geofenceRearmMinutes = SettingsStore.defaultGeofenceRearmMinutes

    var body: some View {
        ZStack {
            NLColors.appBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: NLSpacing.sectionGap) {
                VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                    Text("Alarm Settings")
                        .font(NLTypography.pageTitle)
                        .foregroundStyle(NLColors.textPrimary)
                    Text("Tune barrage, time-to-leave, and geofence behavior.")
                        .font(NLTypography.body)
                        .foregroundStyle(NLColors.textSecondary)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: NLSpacing.innerGap) {
                        GroupBox {
                            VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                                Stepper("Barrage notifications: \(barrageCount)", value: $barrageCount, in: 1...60)
                                Stepper("Seconds between notifications: \(intervalSeconds)", value: $intervalSeconds, in: 5...120, step: 5)
                                Stepper("Default snooze (minutes): \(snoozeMinutes)", value: $snoozeMinutes, in: 1...60)
                            }
                            .font(NLTypography.body)
                            .foregroundStyle(NLColors.textPrimary)
                            .padding(.vertical, NLSpacing.tinyGap)
                        } label: {
                            Text("Barrage")
                                .font(NLTypography.pageTitle)
                                .foregroundStyle(NLColors.textPrimary)
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                                Toggle("Enable time-to-leave alarms", isOn: $timeToLeaveEnabled)
                                if timeToLeaveEnabled {
                                    Stepper(
                                        "Prep buffer before leaving: \(timeToLeavePrepMinutes) min",
                                        value: $timeToLeavePrepMinutes,
                                        in: 0...60,
                                        step: 5
                                    )
                                    Stepper(
                                        "Fallback lead time: \(timeToLeaveFallbackMinutes) min",
                                        value: $timeToLeaveFallbackMinutes,
                                        in: 5...180,
                                        step: 5
                                    )
                                    Picker("Travel mode", selection: $timeToLeaveTransport) {
                                        ForEach(TimeToLeaveTransport.allCases) { mode in
                                            Text(mode.title).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            .font(NLTypography.body)
                            .foregroundStyle(NLColors.textPrimary)
                            .padding(.vertical, NLSpacing.tinyGap)
                        } label: {
                            Text("Time To Leave")
                                .font(NLTypography.pageTitle)
                                .foregroundStyle(NLColors.textPrimary)
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: NLSpacing.compactGap) {
                                Toggle("Enable location enter/leave alarms", isOn: $geofenceEnabled)
                                if geofenceEnabled {
                                    Stepper(
                                        "Default geofence radius: \(geofenceDefaultRadiusMeters) m",
                                        value: $geofenceDefaultRadiusMeters,
                                        in: 100...1000,
                                        step: 50
                                    )
                                    Stepper(
                                        "Re-arm delay: \(geofenceRearmMinutes) min",
                                        value: $geofenceRearmMinutes,
                                        in: 1...60
                                    )
                                    Text("Ignore additional crossings until this delay expires.")
                                        .font(NLTypography.caption)
                                        .foregroundStyle(NLColors.textSecondary)
                                }
                            }
                            .font(NLTypography.body)
                            .foregroundStyle(NLColors.textPrimary)
                            .padding(.vertical, NLSpacing.tinyGap)
                        } label: {
                            Text("Geofence Alarms")
                                .font(NLTypography.pageTitle)
                                .foregroundStyle(NLColors.textPrimary)
                        }
                    }
                }

                HStack(spacing: NLSpacing.compactGap) {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Button("Save") {
                        Task {
                            await model.updateAlarmBehavior(
                                barrageCount: barrageCount,
                                barrageIntervalSeconds: intervalSeconds,
                                snoozeMinutes: snoozeMinutes,
                                timeToLeaveEnabled: timeToLeaveEnabled,
                                timeToLeavePrepMinutes: timeToLeavePrepMinutes,
                                timeToLeaveFallbackMinutes: timeToLeaveFallbackMinutes,
                                timeToLeaveTransport: timeToLeaveTransport,
                                geofenceEnabled: geofenceEnabled,
                                geofenceDefaultRadiusMeters: geofenceDefaultRadiusMeters,
                                geofenceRearmMinutes: geofenceRearmMinutes
                            )
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NLColors.primary)
                }
            }
            .padding(NLSpacing.pagePadding)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            barrageCount = model.settings.barrageCount
            intervalSeconds = model.settings.barrageIntervalSeconds
            snoozeMinutes = model.settings.snoozeMinutes
            timeToLeaveEnabled = model.settings.timeToLeaveEnabled
            timeToLeavePrepMinutes = model.settings.timeToLeavePrepMinutes
            timeToLeaveFallbackMinutes = model.settings.timeToLeaveFallbackMinutes
            timeToLeaveTransport = model.settings.timeToLeaveTransport
            geofenceEnabled = model.settings.geofenceEnabled
            geofenceDefaultRadiusMeters = model.settings.geofenceDefaultRadiusMeters
            geofenceRearmMinutes = model.settings.geofenceRearmMinutes
        }
    }
}

#Preview {
    ContentView()
}
