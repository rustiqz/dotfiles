---
description: Plan maintenance work - tests, docs, or cleanup - on existing code
argument-hint: <area, or path to an existing audit>
---

Maintenance work on: $ARGUMENTS

This is not the feature flow. There is no HLD — the code already exists and its
shape is the design. Do not write one.

1. If an audit or findings list already exists, read it. That document is the
   plan; do not redo the analysis.
2. Otherwise invoke `codex-scout` to map the area, then produce a findings list
   grouped by severity with an explicit fix order — and stop there for my review.
3. Apply the `test-suite` or `documentation` skill depending on the work.
4. Decompose into LLDs. For test work, each LLD must state per test whether it
   is **characterization** (asserts current behaviour, bugs included) or
   **behavioural** (asserts a stated requirement). Never leave that to the
   implementer.
5. Route by class: mechanical cleanup, dead tests, and duplication go to
   `cheap`. Anything requiring a decision about what the code *should* do stays
   with me first.

Every test LLD carries this line in `Out of scope`: no test may be weakened,
loosened, or skipped to make the suite pass.
