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
| `NLColors.appBackground` | `#091734` | Full-screen background — always use with `.ignoresSafeArea()` |
| `NLColors.cardBackground` | `#162236` | Card / panel fill |
| `NLColors.cardBorder` | `white @ 8%` | Subtle card edge — apply as-is, no extra opacity |
| `NLColors.primary` | `#F5A623` | Gold — primary buttons, toggles, section headers, active states |
| `NLColors.textPrimary` | `#FFFFFF` | Primary text |
| `NLColors.textSecondary` | `#7A9BBF` | Subdued blue-gray secondary text |
| `NLColors.textTertiary` | `#4A6A8A` | Placeholder / disabled text |
| `NLColors.connected` | `#4CAF50` | Success / granted states |
| `NLColors.destructive` | `#FF5252` | Destructive button tints |
| `NLColors.error` | alias of `destructive` | Error text — diverge from destructive here if design calls for it |
| `NLColors.warning` | `#F5A623` | Warning icons (reuses primary gold) |

---

## Typography Tokens

| Token | Definition | Usage |
|-------|-----------|-------|
| `NLTypography.heroTitle` | SF Pro, 38pt, Bold | App name in hero section |
| `NLTypography.pageTitle` | SF Pro, 22pt, Bold | Page and sheet titles |
| `NLTypography.sectionHeader` | SF Pro, 13pt, Semibold | Card section headers — always pair with `.textCase(.uppercase)` + `.tracking(NLTypography.sectionHeaderTracking)` |
| `NLTypography.body` | SF Pro, 16pt, Regular | Body text |
| `NLTypography.caption` | SF Pro, 13pt, Regular | Captions, labels, helper text |
| `NLTypography.mono` | SF Mono, 13pt, Regular | Timestamps, IDs, technical values |
| `NLTypography.largeIconSize` | `44pt` (CGFloat) | Large decorative SF Symbol icons (e.g. mission banner checkmark) — use as `.font(.system(size: NLTypography.largeIconSize))` |
| `NLTypography.sectionHeaderTracking` | `0.5pt` (CGFloat) | Letter tracking for section headers — always paired with `NLTypography.sectionHeader` |

---

## Spacing Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `NLSpacing.microGap` | 2pt | Micro gaps (e.g. between label and status text) |
| `NLSpacing.tinyGap` | 4pt | Tight element grouping |
| `NLSpacing.compactGap` | 8pt | Within-group field spacing |
| `NLSpacing.innerGap` | 12pt | Internal component spacing |
| `NLSpacing.sectionGap` | 20pt | Between cards/sections |
| `NLSpacing.pagePadding` | 24pt | Outer page padding + card internal padding |
| `NLSpacing.cardRadius` | 20pt | Card corner radius |
| `NLSpacing.buttonRadius` | 12pt | Button corner radius |
| `NLSpacing.scrollBottomPadding` | 48pt | Bottom padding on scrollable screens to clear home indicator |

---

## Component Library

| Component | File | Purpose |
|-----------|------|---------|
| `nlCardStyle()` | `ContentView.swift` | Dark card with border — apply via `.nlCardStyle()` on any `View` |
| `cardSectionHeader(_:)` | `ContentView.swift` | Gold uppercase section label — pass raw title, function handles casing |

---

## Layout Patterns

### Primary Layout
Single scrollable screen. Full-bleed dark navy background via `ZStack` + `NLColors.appBackground.ignoresSafeArea()`.
No `NavigationStack`. Sections stack vertically: hero → permissions → calendars → refresh → mission banner.

### Navigation
None — single screen app.

### Color Scheme
Always apply `.preferredColorScheme(.dark)` at the root view so system UI elements (toggles, dividers, status bar) match the dark theme.

### Button Conventions
- Setup/primary actions (e.g. "Enable"): `.borderedProminent` + `.tint(NLColors.primary)`
- Destructive moderate actions (e.g. "Fix in Settings"): `.bordered` + `.tint(NLColors.destructive)`
- Full-width primary actions (e.g. "Refresh Alarms"): add `.frame(maxWidth: .infinity)`

---

## Non-Conforming UI Summary

| Location | What it does | Why it's different | Tracking |
|----------|-------------|-------------------|---------|
| `ContentView` | `nlCardStyle()` is a `private extension View` | File-local until a second screen warrants a shared component | — |
| `calendarCard` | Uses `Color(calendar.cgColor)` — not a design token | Calendar colors are user data, not a design decision | — |
