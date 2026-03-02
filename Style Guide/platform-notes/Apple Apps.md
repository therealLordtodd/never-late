# Apple Platform Notes (iOS)

These rules apply to Never Late (SwiftUI on iOS).

---

## Concurrency

- `ObservableObject` view models that mutate `@Published` UI state must be `@MainActor`.
- Do not share mutable singleton state across background tasks without actor isolation.
- Prefer `async/await`. Bridge callback APIs with `withCheckedContinuation` only when needed.
- Long-running operations should respect cancellation.

---

## EventKit + Notifications

- Treat EventKit as eventually consistent. Refresh after permission changes and foreground re-entry.
- Reconcile calendar IDs against currently available calendars before scheduling.
- Notification categories/actions must be registered at launch and when action labels depend on settings.
- Snooze/stop flows must clear pending notifications that would violate user intent.

---

## Logging (AppLog)

Use `AppLog` only. Never use `print()`.

Categories:
- `AppLog.app`
- `AppLog.ui`
- `AppLog.network`
- `AppLog.auth`
- `AppLog.db`
- `AppLog.ai`

Levels:
- `.info` for normal flow
- `.warning` for recoverable conditions
- `.error` for failures
- `.debug` for temporary diagnostics (do not ship)

For fallible operations, log at entry and outcome.
Never log secrets or unnecessary PII.

---

## SwiftUI Patterns

- Prefer `.task` for async load flows tied to view lifecycle.
- Use `@Environment(\.dismiss)` for sheet dismissal.
- Every icon-only interactive control must have an accessibility label.
- Use design tokens (`NLColors`, `NLTypography`, `NLSpacing`) for visual styling.

---

## Persistence + State

- Keep `UserDefaults` keys centralized as constants.
- Validate persisted IDs against current system resources before use.
- Preserve behavior across cold launch, foreground re-entry, and permission transitions.

---

## Build Policy

Before handoff, run:

```bash
xcodebuild -project "/Users/todd/Documents/Programming/Never Late/Never Late.xcodeproj" -scheme "Never Late" -configuration Debug -destination "platform=iOS Simulator,id=D6A7D96D-9D68-4737-B244-D2F3EFB1E1A8"
```
