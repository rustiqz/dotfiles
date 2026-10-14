---
task: TASK-<id>
slug: <short-slug>
hld: .design/hld/<area>.md
complexity: normal        # normal | mechanical  — routes the Codex profile
depends_on: []            # other TASK ids that must land first
---

# LLD: <one-line description>

## Objective

One paragraph. What this task makes true that is not true now.

## Out of scope

An explicit list. This is the highest-value section in the document — it is
what keeps an implementer from "improving" adjacent code.

- …
- …

## Files

Every file this task creates or modifies. Exact paths.

| Path | Action | Purpose |
|---|---|---|
| `src/<module>/<file>.ts` | create | |
| `src/<module>/<file>.ts` | modify | |

Anything not in this table must not be touched.

## Interfaces

Exact signatures. Types spelled out — no "a DTO with the usual fields".

```ts
// src/<module>/dto/<name>.dto.ts
export class CreateThingDto {
  @IsUUID() organizationId: string;
  @IsInt() @Min(1) quantity: number;
}

// src/<module>/<name>.service.ts
async createThing(
  dto: CreateThingDto,
  manager: EntityManager,
): Promise<ThingResponseDto>
```

## Data changes

Migrations, columns, indexes, constraints. Nullable or not. Defaults. Backfill
plan if the column is non-nullable on an existing table.

## Behaviour

Numbered steps for the main path. Then each failure path and what it produces.

1. …
2. …

**Inside the transaction:** …
**After commit:** …

## Error contract

| Condition | Exception | Code | HTTP |
|---|---|---|---|
| | | | |

## Side effects

Events emitted, jobs enqueued, caches invalidated — and their ordering relative
to commit. State the idempotency key for every job.

## Acceptance

Literal commands. The `verifier` subagent runs exactly these, and the task is
not done until they pass.

```bash
pnpm typecheck
pnpm test src/<module>/<name>.service.spec.ts
pnpm test:e2e test/<name>.e2e-spec.ts
```

Each test file and what it must assert:

- `<name>.service.spec.ts` — asserts …
- `<name>.e2e-spec.ts` — asserts …

## Notes for the implementer

Anything non-obvious: an existing helper to reuse, a pattern in a neighbouring
module to copy, a gotcha in the library version pinned here.
