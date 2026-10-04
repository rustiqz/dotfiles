---
name: nestjs-backend
description: Design and implementation conventions for NestJS/TypeScript backends using TypeORM, PostgreSQL, Redis/BullMQ, and Temporal. Use when designing or writing backend modules, services, entities, migrations, queue processors, or workflows in a NestJS codebase.
allowed-tools: Read, Write, Edit, Glob, Grep
---

Conventions an LLD must pin down, and an implementer must not deviate from.

## Module shape

One feature = one module directory. Inside it:

```
<feature>/
  <feature>.module.ts        wiring only; no logic
  <feature>.controller.ts    HTTP boundary; DTO in, DTO out, no business rules
  <feature>.service.ts       business logic; the only place decisions live
  dto/                       request/response DTOs, class-validator decorated
  entities/                  TypeORM entities
  <feature>.repository.ts    only when queries outgrow the service
```

Controllers never touch the repository. Services never return entities across
the HTTP boundary — map to a response DTO.

## Transactions

The rule that causes the most rework if left unstated in an LLD:

- A service method that writes to more than one table runs inside a transaction.
- The transaction is owned by the outermost caller and passed down as an
  `EntityManager`. Never open a nested transaction in a helper.
- **Nothing with an external side effect happens inside the transaction.** No
  queue enqueue, no HTTP call, no event emit, no email. Those go after commit,
  via an outbox row written inside the transaction or an explicit
  post-commit hook. A job that picks up a row the transaction later rolls back
  is the classic failure here.

Every LLD must state, explicitly: what is inside the transaction, what is after
commit, and how the manager reaches each call site.

## TypeORM

- Migrations are written by hand and committed. `synchronize` is off everywhere.
- A new non-nullable column needs a three-step migration: add nullable,
  backfill, then set not-null. State all three in the LLD.
- `find` with `relations` generates joins that surprise people at scale. For
  anything on a hot path, specify the query builder and the expected plan.
- Enums: prefer a Postgres enum type only when the values are genuinely stable.
  Adding a value to a PG enum is a migration; adding one to a check constraint
  or a lookup table is not.
- Soft deletes and unique indexes interact badly. A partial unique index
  (`WHERE deleted_at IS NULL`) is usually what you want — say so in the spec.

## Queues (BullMQ) and workflows (Temporal)

- Pick one per concern and say why in the LLD. Rough split: BullMQ for
  fire-and-forget work with simple retries; Temporal for multi-step processes
  that must survive a deploy and need durable state.
- Job payloads carry IDs, never whole entities. The worker re-reads current
  state. A payload serialized before a later update is stale by definition.
- Every job is idempotent, and the LLD names the idempotency key.
- Temporal activities must be deterministic in what they return to the
  workflow. Anything nondeterministic belongs inside the activity, not the
  workflow body.

## Errors and logging

- Throw typed Nest exceptions with a stable machine-readable `code`; the HTTP
  status is a presentation detail.
- Log with structured context (`{ correlationId, entityId }`), not string
  interpolation. Never log full request or entity bodies — that is where PII
  and secrets leak into log storage.

## Testing

- Service logic: unit tests with the repository mocked.
- Anything involving a transaction, a migration, or a raw query: an integration
  test against a real Postgres. Mocks do not catch transaction bugs.
- The LLD's `Acceptance` section names the test files and what each must assert.
