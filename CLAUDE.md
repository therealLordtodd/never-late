# Never Late

> Claude Code loads this file automatically at the start of every session.

## Quick Start

All project rules, coding standards, and architectural policies are in **`AGENTS.md`** — read it before any implementation work.

Before any **UI work**, also read:
1. `Style Guide/Unified Standards.md` — Cross-app rules. **Read first.**
2. `Style Guide/App Style Guide.md` — App-specific tokens and components.
3. `Style Guide/platform-notes/Apple Apps.md` — If building for Apple platforms.

---

## Project Overview

Calendaring app with persistent alarms

**Tech stack:** SwiftUI / iOS

| App | Repository | Local Path |
|-----|-----------|------------|
| **Never Late** | https://github.com/therealLordtodd/never-late.git | `/Users/todd/Documents/Programming/Never Late` |

---

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `Style Guide/` | Mandatory design system docs. Read before any UI work. |
| `Code Review/` | Two-pass iOS review system (13 vectors). Reviews run daily+. |
| `docs/plans/` | Design documents and implementation plans. |

---

## Critical Rules (Always Follow)

### Code Quality
- Use **`AppLog`** for all logging — never `print()`
- Keep logging behind `AppLog` and Diagnostics settings; respect build gate `NLAllowDiagnosticLogging`
- **Soft delete only** — never hard-delete rows from the database
- **All mutations** go through the mutation logging system
- **Build** the project before handing off work: `xcodebuild -project "/Users/todd/Documents/Programming/Never Late/Never Late.xcodeproj" -scheme "Never Late" -configuration Debug -destination "platform=iOS Simulator,id=D6A7D96D-9D68-4737-B244-D2F3EFB1E1A8"`

### Design System
- **Never use raw color values** — always use `NLColors` tokens
- **Never use raw font modifiers** — always use `NLTypography` tokens
- **Never use raw spacing values** — always use `NLSpacing` tokens
- **Every button** has an explicit button style — no unstyled buttons
- **Name every interactive control as a computed property** using the UI element suffix rules in `AGENTS.md`

---

## Workflow Style

Direct collaboration between Todd and Claude on the active branch. No git worktrees unless explicitly requested.

---

## Code Review Process

Two-pass, 13-vector iOS review system:
- **Pass A** (7 vectors): Feature correctness + operational safety
- **Pass B** (6 vectors): Code quality + maintainability

Process: `Code Review/CODE REVIEW PROCESS.md`
Slash command: `/review`

Run vectors sequentially as defined in the process doc. Post findings to Plane's `Code Review` module with severity, file:line, suggested fix, estimated reality, and:
`Reviewed by: OpenAI / GPT-5 Codex`

---

## Plane API

Full reference: **`plane-api.md`**

> **Pages require session auth, not API keys.** See `plane-api.md` for the session auth procedure.

---

## Zammad API

Full reference: **`zammad-api.md`**

Support VM SSH: `ssh todd@support.toddcowing.com`
