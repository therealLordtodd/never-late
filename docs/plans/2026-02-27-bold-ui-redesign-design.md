# Bold UI Redesign — Never Late
**Date:** 2026-02-27
**Status:** Approved

---

## Problem

The current UI is plain white, doesn't fill the screen, and has no personality. The app is for people who are chronically late but have a sense of humor about it. The design should reflect that — bold, playful, confident. The clock-head mascot icon already establishes the aesthetic.

---

## Goals

1. Fix screen-filling (full bleed dark background into safe areas)
2. Establish the dark navy + gold design system (define `NLColors`, `NLTypography`, `NLSpacing` tokens)
3. Redesign `ContentView` to match the new theme
4. Add the mascot as a hero element
5. Add "mission accomplished" state when fully configured
6. Set the app icon to `ClockHead Icon.png`

---

## Design Tokens

### NLColors

| Token | Value | Usage |
|---|---|---|
| `appBackground` | `#0D1B2A` | Full-screen dark navy background |
| `cardBackground` | `#162236` | Card / panel fill |
| `cardBorder` | `#FFFFFF` @ 8% opacity | Subtle card edge highlight |
| `primary` | `#F5A623` | Gold — buttons, toggles, active states |
| `textPrimary` | `#FFFFFF` | Primary text |
| `textSecondary` | `#7A9BBF` | Subdued blue-gray |
| `textTertiary` | `#4A6A8A` | Placeholder / disabled |
| `connected` | `#4CAF50` | Granted / success |
| `destructive` | `#FF5252` | Denied / error |
| `error` | `#FF5252` | Error text |
| `warning` | `#F5A623` | Warning (reuses gold) |

### NLTypography

| Token | Definition |
|---|---|
| `heroTitle` | SF Pro Display, 38pt, Bold |
| `pageTitle` | SF Pro Display, 22pt, Bold |
| `sectionHeader` | SF Pro Text, 13pt, Semibold, uppercase, 0.5pt tracking |
| `body` | SF Pro Text, 16pt, Regular |
| `caption` | SF Pro Text, 13pt, Regular |
| `mono` | SF Mono, 13pt, Regular |

### NLSpacing

| Token | Value |
|---|---|
| `microGap` | 2pt |
| `tinyGap` | 4pt |
| `compactGap` | 8pt |
| `innerGap` | 12pt |
| `sectionGap` | 20pt |
| `pagePadding` | 24pt |
| `cardRadius` | 20pt |
| `buttonRadius` | 12pt |

---

## Layout Structure

### Screen: ContentView

Remove `NavigationStack` entirely. Replace with a `ZStack` with a full-bleed dark navy background (`.ignoresSafeArea()`), containing a `ScrollView`.

**Section 1 — Hero**
- `HStack`: App name + tagline on the left, mascot PNG on the right
- App name: "Never Late" in `heroTitle`
- Tagline: "Calendar alarms, gently persistent." in `body`, `textSecondary` color
- Mascot: `ClockHead Icon.png` displayed at ~120×120pt, trailing edge

**Section 2 — Permissions Card**
- Dark card (`cardBackground`, `cardRadius`, `cardBorder`)
- Section label: "PERMISSIONS" in `sectionHeader` / `primary` color
- Two rows: Calendar Access + Notifications
- Each row: title + status text on left, action on right
- When not granted: gold `Enable` button (`.bordered`, `.tint(NLColors.primary)`)
- When granted: "✓ Good to go" in `connected` color, no button
- When denied: "Tap to fix in Settings" in `destructive`, button opens Settings

**Section 3 — Calendars Card**
- Hidden until `hasCalendarAccess == true`
- Same dark card style
- Section label: "CALENDARS" in `sectionHeader` / `primary` color
- Calendar list with colored dot + name + gold-tinted `Toggle`
- Footer: "X calendars selected" in `caption` / `textTertiary`
- When no access: placeholder text "Calendar access is required."

**Section 4 — Refresh Card**
- Dark card style
- Section label: "REFRESH" in `sectionHeader` / `primary` color
- Last refresh timestamp in `caption` / `textSecondary`
  - If never refreshed: "Never refreshed. Bold strategy."
- "Refresh Alarms" button: `.borderedProminent`, `.tint(NLColors.primary)`, full width

**Section 5 — Mission Accomplished Banner**
- Appears (animated slide-in, 0.3s ease-in-out) when:
  - Both permissions granted AND ≥1 calendar selected
- Gold-bordered dark card
- Large gold `✓` checkmark icon
- "You're covered." in `pageTitle`
- "Go be late somewhere else." in `body` / `textSecondary`

---

## Copy Changes

| Location | Old | New |
|---|---|---|
| Permission status | "Not determined" | "Not yet" |
| Permission status | "Granted" | "✓ Good to go" |
| Permission status | "Denied" | "Tap to fix in Settings" |
| Refresh — never refreshed | "No refresh yet" | "Never refreshed. Bold strategy." |
| Mission banner | (new) | "You're covered. / Go be late somewhere else." |

---

## App Icon

- Add `ClockHead Icon.png` to `Assets.xcassets/AppIcon.appiconset`
- Generate all required sizes from the source PNG (1024×1024 source needed; current asset is 512×512 — check if Xcode accepts it or if we need to upscale)
- Remove placeholder icon if present

---

## Files Touched

| File | Change |
|---|---|
| `Never Late/NLColors.swift` | **New** — color token definitions |
| `Never Late/NLTypography.swift` | **New** — typography token definitions |
| `Never Late/NLSpacing.swift` | **New** — spacing token definitions |
| `Never Late/ContentView.swift` | **Rewrite** — full redesign |
| `Assets.xcassets/AppIcon.appiconset` | **Update** — set clock-head icon |
| `Style Guide/App Style Guide.md` | **Update** — fill in placeholders with real tokens |

---

## Non-Goals

- No new screens
- No changes to business logic (`AppViewModel`, `NotificationScheduler`, etc.)
- No animations beyond the mission banner slide-in
- No second mascot asset (use one PNG for all states)
