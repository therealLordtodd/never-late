# Code Review Process

## Overview

Never Late uses a two-pass, **13-vector** review process tuned for a single-platform iOS app.

- **Pass A (7 vectors):** correctness and operational safety
- **Pass B (6 vectors):** code quality and maintainability

Run vectors **sequentially** (one at a time). Parallel review floods context and degrades accuracy.

Every finding must include:
- Severity (`Critical` / `High` / `Medium` / `Low`)
- `file:line`
- Why this is a problem
- Concrete fix direction
- **Estimated Reality (0–100%)** confidence

All findings are posted to Plane in the **Code Review** module.

Every posted issue must include model attribution:
`Reviewed by: OpenAI / GPT-5 Codex`

---

## Priority Hierarchy

**Correctness first, then robustness, then craft.**

### Tier 1: Must Fix (ship blockers)

| Priority | Vector | Pass |
|---|---|---|
| P1 | Security & Input Validation | A |
| P2 | Concurrency & Thread Safety | A |
| P3 | Error Handling & Resilience | A |
| P4 | Persistence & State Integrity | B |

### Tier 2: Should Fix (stability and user trust)

| Priority | Vector | Pass |
|---|---|---|
| P5 | Memory & Resource Management | A |
| P6 | iOS Integration & Compatibility | A |
| P7 | Edge Cases & Boundary Conditions | A |
| P8 | Efficiency & Performance | B |
| P9 | UX & Accessibility | A |

### Tier 3: Craft (quality leverage)

| Priority | Vector | Pass |
|---|---|---|
| P10 | Clarity | B |
| P11 | Complexity | B |
| P12 | Documentation | B |
| P13 | Style Guide Compliance | B |

---

## Pass A: Feature Correctness (7 Vectors)

### A1. Security & Input Validation — P1
Focus: unsafe inputs, privacy exposure, unsafe URL handling, permission misuse.

### A2. Error Handling & Resilience — P3
Focus: swallowed errors, missing fallback paths, weak recovery behavior, poor failure messaging.

### A3. Concurrency & Thread Safety — P2
Focus: actor violations, races, cancellation handling, deadlocks, thread-unsafe shared state.

### A4. UX & Accessibility — P9
Focus: VoiceOver labels/hints, tap targets, icon-only controls, empty/loading/error states.

### A5. Memory & Resource Management — P5
Focus: observer lifecycle, timers, retain cycles, long-lived tasks, cleanup.

### A6. iOS Integration & Compatibility — P6
Focus: EventKit/Notifications lifecycle behavior, background refresh behavior, iOS availability guards.

### A7. Edge Cases & Boundary Conditions — P7
Focus: date/time boundaries, timezone handling, empty data, large data sets, malformed state.

---

## Pass B: Code Quality (6 Vectors)

### B1. Clarity — P10
Focus: naming, readability, obvious control flow.

### B2. Complexity — P11
Focus: unnecessary indirection, duplication, dead code, avoidable branching.

### B3. Documentation — P12
Focus: missing explanations around non-obvious behavior and fragile assumptions.

### B4. Persistence & State Integrity — P4
Focus: `UserDefaults` key safety, state consistency, stale identifiers, persistence invariants.

### B5. Efficiency & Performance — P8
Focus: redundant work, repeated heavy queries, main-thread blocking, avoidable churn.

### B6. Style Guide Compliance — P13
Focus: token usage, button/sheet conventions, animation standards, accessibility conventions.

---

## Execution Workflow

1. Define review scope (changed files + coupled files).
2. Run Pass A vectors sequentially.
3. Run Pass B vectors sequentially.
4. Deduplicate overlapping findings.
5. Sort by priority.
6. Post findings to Plane Code Review module.
7. Fix in priority order.

For small patches, run a lightweight pass (`A2`, `A3`, `A6`, `A7`, `B4`, `B6`) before merge.
