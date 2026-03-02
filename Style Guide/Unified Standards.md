# Unified Cross-App Standards

These standards apply to Never Late and any sibling apps that adopt the same design system.

---

## 1. Design System Parity

All apps MUST share the same design token definitions:

| Token File | Status |
|-----------|--------|
| `NLColors` | Define once, use everywhere. All apps adopt the full color set. |
| `NLSpacing` | Define once, use everywhere. All apps adopt the full spacing token set. |
| `NLTypography` | Define once, use everywhere. All apps adopt the full typography enum. |

## 2. Color Standards

### Error Text: `NLColors.error`
Error text (inline messages, validation errors, status text) uses the designated error color token. This applies to all apps.

### Destructive Actions: `NLColors.destructive`
Button tints for destructive actions use the destructive color. This is for button chrome only, not text.

### Text Colors: Always use tokens
- `NLColors.textPrimary` — never raw `.foregroundStyle(.primary)`
- `NLColors.textSecondary` — never raw `.foregroundStyle(.secondary)`
- `NLColors.textTertiary` — never raw `.foregroundStyle(.tertiary)`

### Status Colors: Always tokens
- `NLColors.connected` for success/connected — never raw `.green`
- `NLColors.warning` for warnings — never raw `.orange`
- `NLColors.destructive` for destructive button tints — never raw `.red`
- `NLColors.error` for error text — never raw `.red`

---

## 3. Button Standards

### Primary Action
```code
Button("Label") { action() }
    .buttonStyle(.borderedProminent)
    .tint(NLColors.primary)
    .controlSize(.regular)  // default for sheets and forms
    // .controlSize(.large) for full-page auth screens only
    // .controlSize(.small) for inline toolbar/rail buttons only
```

### Secondary Action
```code
Button("Cancel") { dismiss() }
    .buttonStyle(.bordered)
    // NO .tint — uses system default
```

### Destructive Button (severe)
```code
Button("Delete") { action() }
    .buttonStyle(.borderedProminent)
    .tint(NLColors.destructive)
```

### Destructive Button (moderate)
```code
Button("Clear") { action() }
    .buttonStyle(.bordered)
    .tint(NLColors.destructive)
```

### Plain Text Link
```code
Button("View all") { action() }
    .buttonStyle(.plain)
    .foregroundStyle(NLColors.primary)
```

### Rules
1. **Every button MUST have an explicit button style** — no unstyled buttons.
2. **Size rules**: large for auth-screen CTAs, small for inline/toolbar, regular (or omitted) for form/sheet actions.
3. **Secondary buttons are never tinted** — tint is reserved for primary and destructive.

---

## 4. Sheet Standards

### Layout Pattern
```code
VStack(spacing: NLSpacing.innerGap) {
    // Title
    Text("Sheet Title")
        .font(NLTypography.pageTitle)

    // Content
    // ...

    // Action buttons at BOTTOM
    HStack {
        Spacer()
        Button("Cancel") { dismiss() }
            .buttonStyle(.bordered)
        Button("Save") { save() }
            .buttonStyle(.borderedProminent)
            .tint(NLColors.primary)
    }
}
.padding(NLSpacing.pagePadding)
.frame(width: 420)  // 420 simple | 520 complex | 600 large | 700 extra-large
```

### Rules
1. **Buttons always at the bottom** — never in a header bar.
2. **Title** uses the page title typography token.
3. **Padding** uses the page padding spacing token — same in all apps.
4. **Dismiss** via the environment dismiss mechanism — never set a boolean directly.

---

## 5. Form Standards

### Grouping
Use the platform's form grouping component (e.g., `GroupBox` on Apple platforms) for all form sections.

### Rules
1. **Always use the grouping component** for form sections.
2. **Labeled fields** (caption label above input) should be a shared design system component.
3. **Compact gap (8pt)** between fields within a group.
4. **Section gap (20pt)** between groups.

---

## 6. Confirmation Dialogs

### Destructive Confirmations: Always use alerts
```code
// Use platform alert mechanism for destructive confirmations
```

### Rules
1. **Always use alerts** for destructive confirmations — not inline dialogs or sheets.
2. **Complex confirmations** (e.g., typed confirmation) use a custom sheet.
3. **Button order**: destructive first, cancel second.

---

## 7. Error Display Standards

### Inline Error Text
```code
// Error text uses NLColors.error + NLTypography.caption
```

### Rules
1. **Error text** is always `NLColors.error` + the caption typography token.
2. **Warning icon** uses the warning color.
3. **Error icon** uses the destructive/error color.
4. **Never use raw red** for error text — always use the token.

---

## 8. Loading State Standards

### Pattern
```code
// Pair a progress indicator with a caption label
// Use appropriate size: large for auth, regular for centered panels, small for inline
```

### Rules
1. **Always pair a loading indicator with a separate text label** — don't use single-component string init.
2. **Size matches context**: large for auth, regular for panels, small for inline/toolbar.

---

## 9. Animation Standards

### Standard Durations
| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| `micro` | 0.2s | ease-in-out | Sidebar toggle, filter expand/collapse, hover effects |
| `standard` | 0.3s | ease-in-out | Page transitions, sheet animations, auto-expand |

### Rules
1. **Two durations only**: 0.2s for micro-interactions, 0.3s for larger transitions.
2. **Default curve**: ease-in-out for state changes.
3. **Always specify duration and curve** — no bare animation calls without parameters.

---

## 10. Toolbar Standards

### Rules
1. **Consistent padding**: use the same horizontal and vertical toolbar padding across all apps.
2. **Background**: use the appropriate material/background for all toolbars.
3. **Always followed by a divider**.
4. **Page-level titles** use the page title token. Sub-pane titles use the section header token.

---

## 11. Accessibility Standards

### Icon-Only Controls
Every icon-only button MUST have an explicit accessibility label. No exceptions.

### Dynamic Type and VoiceOver
Primary screens must remain usable with larger text settings and VoiceOver enabled.

---

## 12. Split View Standards

If a screen uses split layout, use platform-native split components. Do not fake split panes with ad-hoc stacks and dividers.

---

## 13. Divider Standards

### Rules
1. **Toolbar dividers**: bare divider with no padding.
2. **Sidebar section dividers**: small horizontal padding on both sides.
3. **All other dividers**: bare divider.

---

## 14. Data Loading Standards

### Rules
1. **Use task-based loading** for all async data — not fire-and-forget on appear.
2. **Synchronous setup** (theme restoration, non-async configuration) can use appear events.

---

## 15. Sheet Dismiss Standards

### Rules
1. **Always use the environment dismiss mechanism** — never set a boolean directly.
2. **Call dismiss** after both cancel and successful save/action.

---

## 16. UI Element Naming Standards

### The Rule

Every interactive UI element that a user touches is a **named computed property** on the View. Anonymous inline controls are prohibited for any element that:
- Has a meaningful label or purpose
- May need to be discussed, debugged, or referenced
- Holds or displays state

### Pattern
```swift
// MARK: - Alarms

private var alarmNameTextField: some View {
    TextField("Alarm name...", text: $alarmName)
        .textFieldStyle(.roundedBorder)
}

private var alarmRepeatDropdown: some View {
    Picker("Repeat", selection: $selectedRepeat) {
        ForEach(RepeatOption.allCases) { Text($0.label).tag($0) }
    }
    .labelsHidden()
}
```

### Canonical Suffix List
`TextField` · `TextEditor` · `SearchField` · `Dropdown` · `Toggle` · `DatePicker` · `Stepper` · `Slider` · `Button` · `Table` · `List` · `Tab` · `Segment`

See `AGENTS.md` for the full naming rule set and the `uiElementContext` ViewModel pattern.
