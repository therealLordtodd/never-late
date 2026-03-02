# Never Late — AI Agent Instructions

Be direct, concise, and blunt. Go beyond surface meaning. Anticipate intent. Fix documentation and clarity issues proactively. Act as an intellectual collaborator, not a tool.

---

## Project Overview

Calendaring app with persistent alarms

**Tech stack:** SwiftUI / iOS

## Repositories & Local Paths

| App | Repository | Local Path |
|-----|-----------|------------|
| **Never Late** | https://github.com/therealLordtodd/never-late.git | `/Users/todd/Documents/Programming/Never Late` |

## Project Directory Structure

```
Never Late/         ← Project root
├── AGENTS.md           ← This file — AI agent instructions
├── CLAUDE.md           ← Claude Code auto-loaded config
├── plane-api.md        ← Plane API reference for this project
├── zammad-api.md       ← Zammad API reference
├── Code Review/        ← Code review process and vector definitions
├── Style Guide/        ← Design system documentation
└── docs/plans/         ← Design docs and implementation plans
```

---

## Support VM — `support.toddcowing.com`

This VM hosts the support stack and the support-bot that bridges bug intake into Plane.

**What it's for:**
- **Zammad** — support intake and ticketing (`https://support.toddcowing.com`)
- **Plane** — project tracking (`https://project.toddcowing.com`)
- **support-bot** — reads new Zammad tickets and creates Plane issues automatically

**SSH access:**
```bash
ssh todd@support.toddcowing.com   # key: ~/.ssh/id_ed25519
```

Bot logs: `/var/log/support-bot.log`

If debugging intake failures, check the VM time (UTC vs Pacific) before interpreting timestamps.

---

## Zammad — Support Ticket Intake

Zammad is the support ticketing system. Users submit bugs via email or web form; tickets are automatically forwarded to Plane via the support-bot.

**URL:** https://support.toddcowing.com
**Intake email:** intake@toddcowing.com
**API reference:** `zammad-api.md` in this project root

**Credentials** — source before making API calls:
```bash
source ~/.claude/credentials.env
# Provides: $ZAMMAD_API_KEY, $ZAMMAD_BASE_URL
```

**Common agent use cases:**
- Read open tickets to understand incoming bugs
- Add an internal note to a ticket (e.g. "Fixed in commit abc123")
- Close or update ticket status after a fix ships
- Cross-reference a Plane issue with its originating Zammad ticket

Full API reference: `zammad-api.md`

---

## Project Management — Plane

**URL:** https://project.toddcowing.com
**Workspace:** `bang-and-co`
**Project:** Never Late (`NL`)
**Project ID:** `e5ad798c-521a-414c-ab85-d63117e69664`

Use Plane to check current issues before starting work, update status as work progresses, and file new issues when you discover bugs or scope gaps.

**Credentials:**
```bash
source ~/.claude/credentials.env
# Provides: $PLANE_API_KEY, $PLANE_BASE_URL
```

Full API reference: `plane-api.md` in this project root.

### Plane Onboarding (New Project Setup)

When setting up a new project for the first time:

**1. Create the Plane project** in the `bang-and-co` workspace:
```bash
source ~/.claude/credentials.env
curl -X POST "$PLANE_BASE_URL/api/v1/workspaces/bang-and-co/projects/" \
  -H "X-API-Key: $PLANE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Never Late",
    "identifier": "NL",
    "description": "Calendaring app with persistent alarms",
    "network": 2
  }'
```

**2. Note the returned `id`** — that is your `e5ad798c-521a-414c-ab85-d63117e69664`. Fill it in everywhere in this file and in `plane-api.md`.

**3. Get state IDs** for the new project and fill them in `plane-api.md`:
```bash
curl -s -H "X-API-Key: $PLANE_API_KEY" \
  "$PLANE_BASE_URL/api/v1/workspaces/bang-and-co/projects/e5ad798c-521a-414c-ab85-d63117e69664/states/"
```

**4. Create a "Code Review" module** for housing review findings:
```bash
curl -X POST "$PLANE_BASE_URL/api/v1/workspaces/bang-and-co/projects/e5ad798c-521a-414c-ab85-d63117e69664/modules/" \
  -H "X-API-Key: $PLANE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Code Review", "status": "backlog"}'
```

> **Pages require session auth, not API keys.** See `plane-api.md` for the session auth procedure.

---

## Build Policy

Before handing off any implementation work, build the project and report the result.

**Build command:** `xcodebuild -project "/Users/todd/Documents/Programming/Never Late/Never Late.xcodeproj" -scheme "Never Late" -configuration Debug -destination "platform=iOS Simulator,id=D6A7D96D-9D68-4737-B244-D2F3EFB1E1A8"`

---

## Logging Requirement

All logging must use the project's centralized logging facade (`AppLog`). Never use `print()` or raw logging APIs.

**Categories:**

| Logger | Use for |
|--------|---------|
| `AppLog.db` | Database queries, fetches, writes, connection lifecycle |
| `AppLog.auth` | Login, logout, credential storage |
| `AppLog.ui` | User-facing actions: navigation, clipboard, window events |
| `AppLog.network` | HTTP/REST calls, external API interactions |
| `AppLog.app` | App lifecycle, startup, shutdown, migrations |
| `AppLog.ai` | AI chat, tool calls, provider API interactions |

**Levels:**
- `.info` — Normal operations
- `.warning` — Recoverable issues
- `.error` — Failures
- `.debug` — Verbose debug detail (do not commit to main)

**Pattern — log at entry AND outcome for any fallible operation:**
```
AppLog.db.info("Fetching records.")
do {
    let result = try await fetch()
    AppLog.db.info("Fetched records.", metadata: ["count": result.count])
} catch {
    AppLog.db.error("Failed to fetch.", metadata: ["error": error.localizedDescription])
}
```

**Never log:** passwords, tokens, API keys, or PII beyond what's needed for debugging.

---

## Data Integrity Policy

### Soft Delete — No Hard Deletes

Rows are never hard-deleted. Mark records inactive instead (e.g. `active = false` or `deleted_at = now()`).

**Prohibited:** `DELETE FROM`, `DROP TABLE` (in app code), `TRUNCATE` (in app code).

### Mutation Logging

All database writes must go through the project's mutation logging system. No direct writes that bypass audit capture.

---

## Code Review Process

Two-pass, 13-vector code review system tuned for an iOS app. Reviews run daily or more often.

- **Pass A** (7 vectors): Feature correctness and operational safety
- **Pass B** (6 vectors): Code quality and maintainability

Process doc: `Code Review/CODE REVIEW PROCESS.md`
Vector definitions: `Code Review/code_review_vectors/`
Slash command: `/review`

Run vectors sequentially exactly as defined in `Code Review/CODE REVIEW PROCESS.md`.

All findings are posted to the **Code Review** module in Plane, with severity, file:line, suggested fix, and estimated reality.

**Priority:** Correctness first, then robustness, then craft.

**Model attribution:** Every Plane issue from a code review must include:
`Reviewed by: OpenAI / GPT-5 Codex`

---

## Style Guide Compliance

Before any UI work, read:

1. `Style Guide/Unified Standards.md` — Cross-app rules. Read first.
2. `Style Guide/App Style Guide.md` — App-specific tokens and components.
3. `Style Guide/platform-notes/Apple Apps.md` — If building for Apple platforms.

Never Late is currently iOS-only. Ignore Windows platform guidance unless project scope changes.

---

## Documentation & Clarity

When you find documentation or clarity issues, fix them proactively without waiting for approval.

---

## Workflow Style

Direct collaboration between Todd and Claude on the active branch. Work directly in the repository unless otherwise specified.
