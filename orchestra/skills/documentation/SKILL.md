---
name: documentation
description: Writing and maintaining documentation for existing code - READMEs, module docs, runbooks, and API references. Use when documenting a codebase, onboarding material, or explaining how an existing system works.
allowed-tools: Read, Write, Edit, Glob, Grep
---

## Write down what cannot be recovered from the code

The code already says what it does. Documentation that restates it is worse
than nothing, because it goes stale and then actively misleads.

Document the things the code cannot tell you:

- **Why** a boundary is where it is, and what was rejected
- **Invariants** the code assumes but does not enforce
- **Failure behaviour** — what happens on timeout, partial write, duplicate
- **Operational knowledge** — how to run it, what breaks first, what to check
- **History** — the constraint that made this shape necessary, and whether it
  still holds

A list of every method in a service is generated documentation. Write it from
the source or don't write it.

## Audience first

Decide before writing, and say so at the top:

| Doc | Reader | Answers |
|---|---|---|
| README | someone who just cloned it | what is this, how do I run it, how do I test it |
| Module doc | someone changing this module | what it owns, what it assumes, what breaks |
| Runbook | someone on-call at 3am | symptom → check → action, in that order |
| ADR | someone in a year asking "why like this" | the constraint, the decision, the cost |
| API reference | a consumer | contract, errors, versioning, limits |

Mixing two of these produces a document that serves neither.

## Documenting existing code

Do not read the code yourself to document it — that is what `codex-scout` is
for. The flow:

1. `codex-scout` maps the area and returns entry points, call graph, tables,
   events, and unknowns.
2. You turn the map into prose, structured for the audience above.
3. Everything the scout listed under `UNKNOWNS` becomes either a question for
   the human or an explicit "not documented, and here is why" line.

Never invent a rationale. If the code does something and nobody remembers why,
the honest sentence is that the reason is not recorded — and that sentence is
genuinely useful to the next reader.

## Keeping it true

- Documentation that cannot be verified will drift. Prefer statements a test or
  a script can check.
- Commands in a README should be copy-pasteable and actually run. Run them.
- Put the doc as close to the code as its scope: module docs next to the
  module, architecture in the design store, runbooks wherever on-call looks.
- Date anything that describes current state, so a reader can judge staleness.

## Delegation

Documentation is well suited to the `cheap` profile once the structure is
decided: given a scout map and a target audience, filling in the sections is
mechanical. What is not mechanical is deciding what deserves a document at all.
That stays with you.
