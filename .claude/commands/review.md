Execute a code review following the project's two-pass review process.

## Argument Handling

This command accepts optional arguments: $ARGUMENTS

Parse arguments as:
- No arguments: run all vectors (full review)
- `?`: print vector list and stop
- One or more vector names: run only those vectors in priority order below

Match by short name (case-insensitive, prefix match allowed).

### Vector Reference (for `/review ?`)

```
Pass A — Feature Correctness
  A1  security       Security & Input Validation         P1
  A3  concurrency    Concurrency & Thread Safety         P2
  A2  errors         Error Handling & Resilience         P3
  A5  memory         Memory & Resource Management        P5
  A6  integration    iOS Integration & Compatibility     P6
  A7  edge-cases     Edge Cases & Boundary Conditions    P7
  A4  ux             UX & Accessibility                  P9

Pass B — Code Quality
  B4  persistence    Persistence & State Integrity       P4
  B5  efficiency     Efficiency & Performance            P8
  B1  clarity        Clarity                             P10
  B2  complexity     Complexity                          P11
  B3  documentation  Documentation                       P12
  B6  style          Style Guide Compliance              P13

Usage:
  /review
  /review ?
  /review security
  /review persistence style
```

If an argument doesn't match any vector, report it and print the vector list.

## Setup (skip for `/review ?`)

1. Read `Code Review/CODE REVIEW PROCESS.md`.
2. Read `AGENTS.md`.
3. Identify scope (changed files and tightly-coupled files). Ask user only if scope is unclear.

## Execution

Run selected vectors sequentially only.

For each vector:
1. Read vector file from `Code Review/code_review_vectors/`.
2. Use the vector's Agent Prompt, replacing `[FEATURE]` with actual scope.
3. Read in-scope source.
4. Produce findings with:
   - Severity (`Critical`/`High`/`Medium`/`Low`)
   - `file:line`
   - Why it is a problem
   - Suggested fix
   - Estimated Reality (0–100%)

## Full Vector Order

Pass A
1. `A1 - Security & Input Validation.md`
2. `A3 - Concurrency & Thread Safety.md`
3. `A2 - Error Handling & Resilience.md`
4. `A5 - Memory & Resource Management.md`
5. `A6 - Integration & Compatibility.md`
6. `A7 - Edge Cases & Boundary Conditions.md`
7. `A4 - UX & Accessibility.md`

Pass B
1. `B4 - Database & Persistence.md`
2. `B5 - Efficiency.md`
3. `B1 - Clarity.md`
4. `B2 - Complexity.md`
5. `B3 - Documentation.md`
6. `B6 - Style Guide Compliance.md`

## After Review

1. Deduplicate overlaps.
2. Sort by priority.
3. Post findings to Plane Code Review module with severity, file:line, fix direction, Estimated Reality.
4. Include attribution in every issue:
   `Reviewed by: OpenAI / GPT-5 Codex`
