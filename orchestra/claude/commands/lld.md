---
description: Write and audit an LLD for one task from an approved HLD
argument-hint: <TASK-id or task description>
---

Write the LLD for: $ARGUMENTS

1. Read the parent HLD for constraints and boundaries.
2. Apply the `design-docs` skill and the relevant domain skill.
3. Fill every section of the LLD template. `Out of scope`, `Acceptance`, and
   the transaction boundaries are not optional.
4. Write to `.design/lld/TASK-<id>-<slug>.md`.
5. Run the `spec-auditor` subagent against it.
6. Fix what the audit flags, then report the verdict. Stop there — do not
   delegate until I say so.
