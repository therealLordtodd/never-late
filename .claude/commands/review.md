Execute a code review following the project's two-pass review process.

## Argument Handling

This command accepts optional arguments: $ARGUMENTS

**Parse the arguments as follows:**

- **No arguments** (`$ARGUMENTS` is empty) → Run ALL vectors (full review)
- **`?`** → Print the vector list below and STOP. Do not run any review.
- **One or more vector names** → Run ONLY the named vectors, in the priority order shown below. Match by short name (e.g. `security`, `clarity`) — case-insensitive, partial prefix match is fine (e.g. `sec` matches `security`).

### Vector Reference (print this for `/review ?`)

```
Pass A — Feature Correctness
  A1  security        Security & Input Validation         P1
  A3  concurrency     Concurrency & Thread Safety         P2
  A2  errors          Error Handling & Resilience          P3
  A5  memory          Memory & Resource Management         P5
  A6  integration     Integration & Compatibility          P6
  A7  edge-cases      Edge Cases & Boundary Conditions     P7
  A4  ux              UX & Accessibility                   P12
  A8  logging         Logging & Observability               P14

Pass B — Code Quality
  B4  database        Database & Persistence               P4
  B5  efficiency      Efficiency                           P8
  B1  clarity         Clarity                              P9
  B7  style           Style Guide Compliance               P9
  B2  complexity      Complexity                           P10
  B3  documentation   Documentation                        P11
  B6  library         Library & Cross-Platform              P13

Usage:
  /review           Review all vectors
  /review ?         Show this list
  /review security  Review security only
  /review clarity style documentation   Review those three vectors
```

If an argument doesn't match any vector, tell the user and show the list.

## Setup (skip if `/review ?`)

1. Read `Code Review/CODE REVIEW PROCESS.md` to understand the two-pass system, priority hierarchy, and conflict resolution rules.
2. Read `AGENTS.md` for project-level coding standards (logging, portability, data integrity, style guide compliance).
3. Identify the scope — ask the user which files or feature to review if not obvious from context. Use `git diff` or `git log` to determine recently changed files if needed.

## Execution

Run each selected review vector **sequentially** (one at a time — never parallel). For each vector:

1. Read the vector file from `Code Review/code_review_vectors/`
2. Use the **Agent Prompt** from that file, replacing `[FEATURE]` with the actual feature/files being reviewed
3. Read all in-scope source files
4. Produce structured findings: Severity, File:Line, Description, Suggested Fix
5. Report findings to the user before moving to the next vector

### Full Vector Order (when running all or a subset, maintain this priority order)

**Pass A — Feature Correctness**

1. `A1 - Security & Input Validation.md` (P1)
2. `A3 - Concurrency & Thread Safety.md` (P2)
3. `A2 - Error Handling & Resilience.md` (P3)
4. `A5 - Memory & Resource Management.md` (P5)
5. `A6 - Integration & Compatibility.md` (P6)
6. `A7 - Edge Cases & Boundary Conditions.md` (P7)
7. `A4 - UX & Accessibility.md` (P12)
8. `A8 - Logging & Observability.md` (P14) — *check against AGENTS.md logging requirements*

**Pass B — Code Quality**

1. `B4 - Database & Persistence.md` (P4) — *check against AGENTS.md data integrity policy (soft delete, mutation logging)*
2. `B5 - Efficiency.md` (P8)
3. `B1 - Clarity.md` (P9)
4. `B7 - Style Guide Compliance.md` (P9) — *read style guides from `Style Guide/` and applicable platform notes before executing this vector*
5. `B2 - Complexity.md` (P10)
6. `B3 - Documentation.md` (P11)
7. `B6 - Library & Cross-Platform.md` (P13) — *check against AGENTS.md portability rules*

## After All Selected Vectors Complete

1. **Deduplicate** — merge findings that appear in multiple vectors
2. **Prioritize** — sort by priority (P1 highest, P15 lowest)
3. **Present summary** — group by tier (Correctness / Robustness / Craft) with total counts
4. Report only problems found in current code. Missing features and future plans are tasks, not findings.
