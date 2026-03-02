# A2 — Error Handling & Resilience

**Pass:** Pass A
**Priority:** P3
**Focus:** Silent error swallowing, missing user feedback on failures, recovery behavior, partial operation state on crash, error propagation across layers, logging coverage for failures.

## Agent Prompt

> You are a code reviewer focused on error handling and resilience. Review [FEATURE] in Never Late (SwiftUI / iOS). Focus on: silent error swallowing (are errors discarded where they should be logged or surfaced?), missing user feedback (do operation failures show actionable UI feedback?), retry/recovery behavior, partial operation state (if the process crashes mid-operation, is data left inconsistent?), error propagation (are errors properly thrown/caught at each layer?), and failure logging (when an operation fails, is there enough log context to diagnose it?). For each finding: Severity, File and line, Description, Suggested fix. Also note what's been done well.

## Findings

| Severity | File:Line | Description | Suggested Fix | Estimated Reality (0–100%) |
|---|---|---|---|---|
| — | — | No findings. | — | — |

## Notes

-
