# Bold UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign Never Late from a plain white utility screen into a bold dark-navy + gold themed app that matches the clock-head mascot icon and has personality.

**Architecture:** Three new token files (`NLColors`, `NLTypography`, `NLSpacing`) establish the design system. `ContentView` is fully rewritten to use those tokens, dropping `NavigationStack` in favor of a full-bleed dark layout with a hero section, themed cards, and a "mission accomplished" banner. The mascot PNG becomes a content image asset as well as the app icon.

**Tech Stack:** SwiftUI, iOS 17+, SF Pro/Display fonts (system), `sips` for image resizing, `xcodebuild` for verification.

---

## Build command (use after every task)

```bash
xcodebuild -project "/Users/todd/Documents/Programming/Never Late/Never Late.xcodeproj" \
  -scheme "Never Late" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=D6A7D96D-9D68-4737-B244-D2F3EFB1E1A8" \
  build 2>&1 | tail -5
```

Expected last line on success: `** BUILD SUCCEEDED **`

---

## Task 1: Create NLColors.swift

**Files:**
- Create: `Never Late/NLColors.swift`

**Step 1: Create the file**

```swift
import SwiftUI

/// Design-system color tokens for Never Late.
/// Never use raw color values in views — always reference these tokens.
enum NLColors {
    // MARK: - Backgrounds
    static let appBackground   = Color(red: 0.051, green: 0.106, blue: 0.165) // #0D1B2A
    static let cardBackground  = Color(red: 0.086, green: 0.133, blue: 0.212) // #162236

    // MARK: - Borders
    /// Use with .opacity(1) — the 8% is baked into the design; apply as-is.
    static let cardBorder      = Color.white.opacity(0.08)

    // MARK: - Brand
    static let primary         = Color(red: 0.961, green: 0.651, blue: 0.137) // #F5A623

    // MARK: - Text
    static let textPrimary     = Color.white
    static let textSecondary   = Color(red: 0.478, green: 0.608, blue: 0.749) // #7A9BBF
    static let textTertiary    = Color(red: 0.290, green: 0.416, blue: 0.541) // #4A6A8A

    // MARK: - Status
    static let connected       = Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
    static let destructive     = Color(red: 1.000, green: 0.322, blue: 0.322) // #FF5252
    static let error           = Color(red: 1.000, green: 0.322, blue: 0.322) // #FF5252
    static let warning         = Color(red: 0.961, green: 0.651, blue: 0.137) // reuses primary gold
}
```

**Step 2: Build to verify the file compiles**

Run the build command above.
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
cd "/Users/todd/Documents/Programming/Never Late"
git add "Never Late/NLColors.swift"
git commit -m "feat: add NLColors design token definitions"
```

---

## Task 2: Create NLTypography.swift

**Files:**
- Create: `Never Late/NLTypography.swift`

**Step 1: Create the file**

```swift
import SwiftUI

/// Design-system typography tokens for Never Late.
/// Never use raw .font() modifiers in views — always reference these tokens.
enum NLTypography {
    /// 38pt Bold — app hero title
    static let heroTitle     = Font.system(size: 38, weight: .bold,     design: .default)
    /// 22pt Bold — page/section titles
    static let pageTitle     = Font.system(size: 22, weight: .bold,     design: .default)
    /// 13pt Semibold — card section headers (apply .textCase(.uppercase) + .tracking(0.5) at call site)
    static let sectionHeader = Font.system(size: 13, weight: .semibold, design: .default)
    /// 16pt Regular — body copy
    static let body          = Font.system(size: 16, weight: .regular,  design: .default)
    /// 13pt Regular — captions, helper text
    static let caption       = Font.system(size: 13, weight: .regular,  design: .default)
    /// 13pt Mono — IDs, timestamps, technical values
    static let mono          = Font.system(size: 13, weight: .regular,  design: .monospaced)
}
```

**Step 2: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
cd "/Users/todd/Documents/Programming/Never Late"
git add "Never Late/NLTypography.swift"
git commit -m "feat: add NLTypography design token definitions"
```

---

## Task 3: Create NLSpacing.swift

**Files:**
- Create: `Never Late/NLSpacing.swift`

**Step 1: Create the file**

```swift
import CoreFoundation

/// Design-system spacing tokens for Never Late.
/// Never use raw numeric spacing values in views — always reference these tokens.
enum NLSpacing {
    static let microGap:    CGFloat = 2
    static let tinyGap:     CGFloat = 4
    static let compactGap:  CGFloat = 8
    static let innerGap:    CGFloat = 12
    static let sectionGap:  CGFloat = 20
    static let pagePadding: CGFloat = 24
    static let cardRadius:  CGFloat = 20
    static let buttonRadius: CGFloat = 12
}
```

**Step 2: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
cd "/Users/todd/Documents/Programming/Never Late"
git add "Never Late/NLSpacing.swift"
git commit -m "feat: add NLSpacing design token definitions"
```

---

## Task 4: Add mascot as a content image asset

The mascot PNG needs to be in the asset catalog so ContentView can load it with `Image("ClockHeadMascot")`.

**Files:**
- Create directory: `Never Late/Assets.xcassets/ClockHeadMascot.imageset/`
- Create: `Never Late/Assets.xcassets/ClockHeadMascot.imageset/Contents.json`
- Copy: `Art Assets/ClockHead Icon.png` → `Never Late/Assets.xcassets/ClockHeadMascot.imageset/ClockHeadMascot.png`

**Step 1: Create the imageset directory and Contents.json**

Create the directory:
```bash
mkdir -p "/Users/todd/Documents/Programming/Never Late/Never Late/Assets.xcassets/ClockHeadMascot.imageset"
```

Create `Never Late/Assets.xcassets/ClockHeadMascot.imageset/Contents.json`:

```json
{
  "images" : [
    {
      "filename" : "ClockHeadMascot.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 2: Copy the PNG into the imageset**

```bash
cp "/Users/todd/Documents/Programming/Never Late/Art Assets/ClockHead Icon.png" \
   "/Users/todd/Documents/Programming/Never Late/Never Late/Assets.xcassets/ClockHeadMascot.imageset/ClockHeadMascot.png"
```

**Step 3: Build to verify asset resolves**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
cd "/Users/todd/Documents/Programming/Never Late"
git add "Never Late/Assets.xcassets/ClockHeadMascot.imageset"
git commit -m "feat: add ClockHead mascot as content image asset"
```

---

## Task 5: Set the app icon

**Files:**
- Modify: `Never Late/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Copy: `Art Assets/ClockHead Icon.png` → `Never Late/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

**Step 1: Copy the PNG into the appiconset**

```bash
cp "/Users/todd/Documents/Programming/Never Late/Art Assets/ClockHead Icon.png" \
   "/Users/todd/Documents/Programming/Never Late/Never Late/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
```

**Step 2: Replace Contents.json with single-image format (Xcode 15 / iOS 17)**

Replace the entire contents of `Never Late/Assets.xcassets/AppIcon.appiconset/Contents.json` with:

```json
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 3: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
cd "/Users/todd/Documents/Programming/Never Late"
git add "Never Late/Assets.xcassets/AppIcon.appiconset"
git commit -m "feat: set ClockHead mascot as app icon"
```

---

## Task 6: Rewrite ContentView.swift

This is the main event. Replace the entire file.

**Files:**
- Modify: `Never Late/ContentView.swift`

**Step 1: Replace the entire file**

```swift
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
                .padding(.bottom, 48)
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
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                    .buttonStyle(.bordered)
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
                .font(.system(size: 44))
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
        if #available(iOS 17.0, *) {
            switch model.calendarStatus {
            case .fullAccess:  return "✓ Good to go"
            case .writeOnly:   return "Write-only access"
            case .denied:      return "Tap to fix in Settings"
            case .restricted:  return "Restricted by device policy"
            case .notDetermined: return "Not yet"
            @unknown default:  return "Unknown"
            }
        } else {
            switch model.calendarStatus {
            case .authorized, .fullAccess: return "✓ Good to go"
            case .writeOnly:   return "Write-only access"
            case .denied:      return "Tap to fix in Settings"
            case .restricted:  return "Restricted by device policy"
            case .notDetermined: return "Not yet"
            @unknown default:  return "Unknown"
            }
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
    private func cardSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(NLTypography.sectionHeader)
            .tracking(0.5)
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
```

**Step 2: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`

If there are compiler errors, fix them before proceeding. Common issues:
- `EKAuthorizationStatus.authorized` may only exist on older iOS — the `#available(iOS 17.0, *)` guard already handles this, but double-check the `calendarStatusText` switch covers all cases for the deployment target.

**Step 3: Commit**

```bash
cd "/Users/todd/Documents/Programming/Never Late"
git add "Never Late/ContentView.swift"
git commit -m "feat: bold UI redesign - dark navy/gold theme, mascot hero, mission accomplished banner"
```

---

## Task 7: Update the Style Guide

Fill in the previously-blank `Style Guide/App Style Guide.md` with the real token values.

**Files:**
- Modify: `Style Guide/App Style Guide.md`

**Step 1: Replace the file contents**

```markdown
# App Style Guide — Never Late

> App-specific tokens and components. Read Unified Standards.md first.

---

## Design Philosophy

Bold, dark, and a little cheeky. This app is for people who are chronically late but own it.
Dark navy background, gold accents, a running clock-head mascot. The UI should feel like a
confident utility — not a generic settings screen.

---

## Color Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `NLColors.appBackground` | `#0D1B2A` | Full-screen background (use with `.ignoresSafeArea()`) |
| `NLColors.cardBackground` | `#162236` | Card / panel fill |
| `NLColors.cardBorder` | `white @ 8%` | Subtle card edge — apply as-is, no extra opacity |
| `NLColors.primary` | `#F5A623` | Gold — buttons, toggles, section headers, active states |
| `NLColors.textPrimary` | `#FFFFFF` | Primary text |
| `NLColors.textSecondary` | `#7A9BBF` | Subdued blue-gray secondary text |
| `NLColors.textTertiary` | `#4A6A8A` | Placeholder / disabled text |
| `NLColors.connected` | `#4CAF50` | Success / granted states |
| `NLColors.destructive` | `#FF5252` | Destructive button tints |
| `NLColors.error` | `#FF5252` | Error text |
| `NLColors.warning` | `#F5A623` | Warning icons (reuses primary gold) |

---

## Typography Tokens

| Token | Definition | Usage |
|-------|-----------|-------|
| `NLTypography.heroTitle` | SF Pro Display, 38pt, Bold | App name in hero section |
| `NLTypography.pageTitle` | SF Pro Display, 22pt, Bold | Page and sheet titles |
| `NLTypography.sectionHeader` | SF Pro Text, 13pt, Semibold | Card section headers — always uppercase + 0.5pt tracking |
| `NLTypography.body` | SF Pro Text, 16pt, Regular | Body text |
| `NLTypography.caption` | SF Pro Text, 13pt, Regular | Captions, labels, helper text |
| `NLTypography.mono` | SF Mono, 13pt, Regular | Timestamps, IDs, technical values |

---

## Spacing Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `NLSpacing.microGap` | 2pt | Micro gaps (e.g. between label and status) |
| `NLSpacing.tinyGap` | 4pt | Tight element grouping |
| `NLSpacing.compactGap` | 8pt | Within-group field spacing |
| `NLSpacing.innerGap` | 12pt | Internal component spacing |
| `NLSpacing.sectionGap` | 20pt | Between cards/sections |
| `NLSpacing.pagePadding` | 24pt | Outer page padding + card internal padding |
| `NLSpacing.cardRadius` | 20pt | Card corner radius |
| `NLSpacing.buttonRadius` | 12pt | Button corner radius |

---

## Component Library

| Component | File | Purpose |
|-----------|------|---------|
| `nlCardStyle()` | `ContentView.swift` | Dark card with border — apply via `.nlCardStyle()` |
| `cardSectionHeader(_:)` | `ContentView.swift` | Gold uppercase section label |

---

## Layout Patterns

### Primary Layout
Single scrollable screen. Full-bleed dark navy background via `ZStack` + `Color.ignoresSafeArea()`.
No `NavigationStack`. Sections stack vertically: hero → permissions → calendars → refresh → mission banner.

### Navigation
None — single screen app.

### Color Scheme
Always force `.preferredColorScheme(.dark)` at the root view so system UI elements (toggles, dividers) match the theme.

---

## Non-Conforming UI Summary

| Location | What it does | Why it's different | Tracking |
|----------|-------------|-------------------|---------|
| `ContentView` | Uses private `nlCardStyle()` extension | Local until a second screen warrants a shared component | — |
```

**Step 2: Build to verify (no Swift changes, but confirms nothing broke)**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
cd "/Users/todd/Documents/Programming/Never Late"
git add "Style Guide/App Style Guide.md"
git commit -m "docs: fill in App Style Guide with real NL token values"
```

---

## Final verification

Run the full build one more time and confirm clean output:

```bash
xcodebuild -project "/Users/todd/Documents/Programming/Never Late/Never Late.xcodeproj" \
  -scheme "Never Late" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=D6A7D96D-9D68-4737-B244-D2F3EFB1E1A8" \
  build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: One line — `** BUILD SUCCEEDED **`

Then run the app in the simulator and verify visually:
- Full dark navy background, no white edges
- Hero section: "Never Late" large + mascot image right-aligned
- Cards: dark with subtle border, gold section headers
- Enable buttons: gold bordered
- Granted permissions: green "✓ Good to go"
- Mission accomplished banner: slides in when both permissions granted + calendar selected
- App icon: clock-head guy in the simulator home screen
