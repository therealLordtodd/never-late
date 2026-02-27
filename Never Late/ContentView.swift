import EventKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppViewModel()
    @State private var showMissionBanner = false

    var body: some View {
        ZStack {
            NLColors.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: NLSpacing.sectionGap) {
                    heroSection
                    permissionsCard
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
                .frame(width: 90, height: 90)
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
                showEnable: model.hasCalendarAccess == false && model.calendarStatus != .denied,
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
                    ForEach(model.calendars, id: \.calendarIdentifier) { calendar in
                        Toggle(isOn: Binding(
                            get: { model.settings.selectedCalendarIds.contains(calendar.calendarIdentifier) },
                            set: { _ in Task { await model.toggleCalendar(calendar) } }
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
                    Text("\(model.settings.selectedCalendarIds.count) selected")
                        .font(NLTypography.caption)
                        .foregroundStyle(NLColors.textTertiary)
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

            Button(model.isRefreshing ? "Refreshing…" : "Refresh Alarms") {
                Task { await model.refreshCalendars() }
            }
            .buttonStyle(.borderedProminent)
            .tint(NLColors.primary)
            .disabled(model.isRefreshing)
            .frame(maxWidth: .infinity)
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
            && !model.settings.selectedCalendarIds.isEmpty
    }

    private var lastRefreshText: String {
        guard let last = model.lastRefresh else {
            return "Never refreshed. Bold strategy."
        }
        return "Last refresh: \(last.formatted(date: .abbreviated, time: .shortened))"
    }

    private var calendarStatusText: String {
        switch model.calendarStatus {
        case .fullAccess:    return "✓ Good to go"
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

#Preview {
    ContentView()
}
