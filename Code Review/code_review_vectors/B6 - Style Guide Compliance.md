# B6 — Style Guide Compliance

**Pass:** Pass B
**Priority:** P13
**Focus:** Design token usage, button/sheet/form patterns, error display, loading state patterns, animation standards, accessibility tooltips.

## Agent Prompt

> You are a code reviewer focused on design system and style guide compliance. Review [FEATURE] in Never Late (SwiftUI / iOS).
>
> First read the project style guides: `Style Guide/Unified Standards.md`, `Style Guide/App Style Guide.md`, and any applicable platform notes in `Style Guide/platform-notes/`.
>
> Then check for:
> 1. Raw color/font/spacing values instead of design system tokens
> 2. Buttons missing explicit button styles
> 3. Forms not using the project's standard grouping pattern
> 4. Sheet buttons not at the bottom of the sheet
> 5. Destructive confirmations not using the standard alert/dialog pattern
> 6. Async data loading not using the project's standard async pattern
> 7. Icon-only interactive elements missing accessibility labels
> 8. Animations not using the project's standard durations
> 9. Loading states not following the standard pattern (spinner + separate label)
>
> For each finding: Severity (Critical/High/Medium/Low), File and line number, Description, Suggested fix with code snippet. Focus only on code added or modified in this feature.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
