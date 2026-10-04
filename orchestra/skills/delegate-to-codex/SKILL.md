---
name: delegate-to-codex
description: Routes implementation work to Codex CLI through the codex-task wrapper and integrates the result. Use after an LLD is written and audited, when code needs to be written rather than designed. Covers profile selection, retry policy, and what to do with the returned report.
allowed-tools: Read, Glob, Grep
---

## Before delegating

Check all four, in order. Any "no" stops the delegation:

1. An LLD exists at `.design/lld/TASK-<id>-*.md`.
2. `spec-auditor` returned `READY` on it.
3. The LLD has an `## Acceptance` section with literal shell commands.
4. The working tree is clean, or the dirty files are unrelated to this task.

## Routing

| Signal in the LLD | Agent | Profile |
|---|---|---|
| `complexity: mechanical` — renames, DTOs, fixtures, codemods | `codex-implementer` | `cheap` |
| Normal feature work from a complete spec | `codex-implementer` | `impl` |
| Touches money, auth, transactions, or migrations | `codex-implementer` (`impl`), then `codex-reviewer` | both |
| Spec is incomplete, or the design is still in flux | nobody — go back to `design-docs` | — |
| Under ~40 lines in one file | this session, directly | — |

## Handling the report

The subagent returns JSON. Act on it as follows:

- **`completed`** — run `verifier` against the spec's own acceptance commands.
  Trust the verifier, not the report. Then review the diff yourself before the
  independent review.
- **`partial`** — the subagent has already used its one retry. Read the
  `verification.first_error` values. If it is a spec gap, fix the LLD and
  re-delegate. If it is a genuine bug, decide whether to fix it here or
  re-delegate with a tightened spec. Do not start a third attempt on the
  original spec.
- **`blocked`** — this is a design question that came back to you. Answer it in
  the LLD, not in a follow-up prompt. The spec is the durable artifact.
- **`deviations` non-empty** — update the LLD to match what was actually built,
  now. A downstream task written against a stale spec will fail in a way that
  looks like an implementation bug.

## What never goes in the main thread

Transcripts, diffs longer than about 60 lines, test runner output, lint output,
and Codex's reasoning. If you find yourself wanting one of these, you want a
subagent instead.
