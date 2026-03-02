# Never Late Full Code Review

Date: 2026-03-02
Scope: Entire iOS app source under `Never Late/*.swift`
Process: `Code Review/CODE REVIEW PROCESS.md` (Pass A + Pass B)

## Findings Posted to Plane (Code Review module)

1. NL-1 (High)
- Title: Snooze does not suppress pending event alarms
- File refs: `Never Late/NotificationScheduler.swift:56`, `Never Late/NotificationScheduler.swift:148`
- Estimated Reality: 95%

2. NL-2 (High)
- Title: Today alarm list misses alarms that fire today for next-day events
- File ref: `Never Late/AppViewModel.swift:199`
- Estimated Reality: 96%

3. NL-3 (Medium)
- Title: NotificationCenter observers are never removed from AppViewModel
- File ref: `Never Late/AppViewModel.swift:37`
- Estimated Reality: 90%

4. NL-4 (Medium)
- Title: Shared SettingsStore is mutable across UI and background contexts without isolation
- File refs: `Never Late/SettingsStore.swift:3`, `Never Late/BackgroundRefresh.swift:12`
- Estimated Reality: 82%

5. NL-5 (Low)
- Title: Gear icon button lacks explicit accessibility label
- File ref: `Never Late/ContentView.swift:39`
- Estimated Reality: 94%

Model attribution used in all issues:
- Reviewed by: OpenAI / GPT-5 Codex
