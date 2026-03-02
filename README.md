# New Project Template

A starter template for all new projects. Copy into a new project root to get:

- AI agent instructions (`CLAUDE.md` + `AGENTS.md`)
- Project management integration (Plane + Zammad)
- A two-pass, 15-vector code review system
- Style guide scaffold with platform-specific notes

---

## How to Use This Template

### 1. Copy template files into your project root

```bash
cp -r /Users/todd/Documents/Programming/New-Project-Template/. /path/to/new-project/
cd /path/to/new-project
rm -rf .git && git init
```

Or clone and re-init:
```bash
gh repo clone therealLordtodd/New-Project-Template /path/to/new-project
cd /path/to/new-project && rm -rf .git && git init
```

### 2. Fill in all `[PLACEHOLDER]` values

```bash
grep -r "\[" . --include="*.md" -l
```

Key placeholders:

| Placeholder | Replace with |
|------------|-------------|
| `Never Late` | Your app name, e.g. "Forever Zone 2" |
| `Calendaring app with persistent alarms` | One sentence describing the app |
| `SwiftUI / iOS` | e.g. "SwiftUI / macOS / Postgres" |
| `Never Late` | Primary app name |
| `https://github.com/therealLordtodd/never-late.git` | GitHub repo URL |
| `/Users/todd/Documents/Programming/Never Late` | Absolute path on disk |
| `e5ad798c-521a-414c-ab85-d63117e69664` | UUID from Plane after project creation |
| `NL` | Short all-caps code, e.g. `FZ2` |
| `AppLog` | Your logging class/module, e.g. `AppLog` |
| `NL` | Design system prefix, e.g. `FZ` for Forever Zone 2 |
| `xcodebuild -project "/Users/todd/Documents/Programming/Never Late/Never Late.xcodeproj" -scheme "Never Late" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 15"` | How to build the project |

### 3. Set up Plane (Bang & Co workspace)

Follow the **Plane Onboarding** section in `AGENTS.md` to create your project in Plane, then fill in `e5ad798c-521a-414c-ab85-d63117e69664` and `NL` everywhere.

### 4. Customize your Style Guide

- `Style Guide/Unified Standards.md` — fill in your design token names and cross-app rules
- `Style Guide/App Style Guide.md` — fill in your design tokens and component library
- `Style Guide/platform-notes/Apple Apps.md` — pre-populated for SwiftUI/macOS projects
- `Style Guide/platform-notes/Windows Apps.md` — fill in when targeting Windows

### 5. Customize Code Review vectors

The 15 vectors in `Code Review/code_review_vectors/` use `Never Late` and `SwiftUI / iOS` placeholders. Replace them with your project name and actual tech stack.

---

## Credentials

All agents source `~/.claude/credentials.env` for API keys:

```bash
source ~/.claude/credentials.env
# Provides: $PLANE_API_KEY, $PLANE_BASE_URL, $ZAMMAD_API_KEY, $ZAMMAD_BASE_URL
```

Do not commit credentials to any repo.

---

## Support Infrastructure

| Service | URL | Purpose |
|---------|-----|---------|
| Plane | https://project.toddcowing.com | Project management (Bang & Co workspace) |
| Zammad | https://support.toddcowing.com | Support ticket intake |
| Support VM | support.toddcowing.com | Hosts Zammad + support-bot |

SSH: `ssh todd@support.toddcowing.com` (key: `~/.ssh/id_ed25519`)
