---
name: design-docs
description: Authors High-Level Designs (HLDs), Low-Level Designs (LLDs), and ADRs using this project's templates and structure. Use when starting a new feature, module, or service, when the user asks for an HLD, LLD, design doc, architecture, or implementation plan, or before delegating any implementation work.
allowed-tools: Read, Write, Edit, Glob, Grep
---

Design docs are the interface between the orchestrator and the implementer.
Write them for someone with no conversation history.

## Which document

| Situation | Document |
|---|---|
| New bounded context, service, or cross-module feature | HLD — `.design/hld/<area>.md` |
| A choice with lasting consequences and rejected alternatives | ADR — `.design/adr/<n>-<slug>.md` |
| A unit of work small enough for one delegation | LLD — `.design/lld/TASK-<id>-<slug>.md` |

An HLD without LLDs is unbuildable. An LLD without an HLD usually means the
boundaries were never thought through. Write both; the HLD once per area, an
LLD per task.

## Sequence

1. **Frame** — restate the problem, the constraints, and what success means.
   If any of the three is unclear, stop and ask rather than guessing.
2. **Survey** — use the `Explore` subagent to find existing modules, entities,
   and patterns this must fit. Do not read files into the main thread yet.
3. **HLD** — fill `templates/HLD.md`. Decide boundaries before mechanisms.
4. **Decompose** — split into tasks of roughly 1–3 files each, ordered so every
   task is independently verifiable. A task that cannot be verified alone is
   two tasks.
5. **LLD per task** — fill `templates/LLD.md`. Be concrete to the point of
   tedium: exact paths, exact signatures, exact error codes.
6. **Audit** — run the `spec-auditor` subagent on each LLD. Fix what it flags.

## The rule that matters

Every ambiguity you leave in an LLD becomes an improvisation by the implementer,
and improvisations are only discovered at review time. When in doubt about
whether a detail belongs in the spec, it belongs in the spec.

The `Out of scope` section is not optional. It is the only thing standing
between you and an implementer that "helpfully" refactors three adjacent files.

## Templates

Read `templates/HLD.md`, `templates/LLD.md`, and `templates/ADR.md` from this
skill's directory when filling each out.
