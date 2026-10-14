# HLD: <area name>

> Status: draft | accepted | superseded by <link>
> Owner: <name>   Last updated: <date>

## Problem

What is broken or missing today, in terms of user or business outcome. Two
paragraphs maximum. If you cannot state the problem without describing the
solution, the problem is not understood yet.

## Constraints

Hard limits that eliminate designs: existing schema, deployed API contracts,
throughput, latency budget, compliance, team size, deadline. Mark each as
**hard** (cannot change) or **soft** (costs something to change).

## Non-goals

What this explicitly does not solve. This section prevents scope drift more
effectively than any amount of planning.

## Context map

Which existing modules this touches, and how. Name real paths.

| Module | Relationship | Changes needed |
|---|---|---|
| | | |

## Design

The shape of the solution. Components and their responsibilities. What owns
what data. Where the boundaries are and why they are there.

Include a diagram only if it says something prose cannot.

### Data model

Entities, their key fields, and their relationships. New tables, changed
columns, new indexes. Ownership: which module may write to each table.

### Control flow

The main path, end to end, as a numbered sequence. Then the notable failure
paths — what happens on timeout, on duplicate, on partial failure.

### Consistency and transactions

What must be atomic. What may be eventually consistent and how long "eventually"
is allowed to be. Where the outbox / retry / idempotency key lives.

## Alternatives considered

| Option | Why not |
|---|---|
| | |

At least one real alternative. If there was genuinely only one option, say what
constraint forced it.

## Risks

Each risk with its mitigation, or an explicit acceptance. Include the
operational ones: migration under load, rollback path, backfill duration.

## Task breakdown

The LLDs this HLD decomposes into, in dependency order. Each must be
independently verifiable.

| Task | Scope | Depends on | Complexity |
|---|---|---|---|
| TASK-001-<slug> | | — | normal |
| TASK-002-<slug> | | TASK-001 | mechanical |

## Open questions

Things that must be answered before implementation starts. An HLD with open
questions in the critical path is not ready to decompose.
