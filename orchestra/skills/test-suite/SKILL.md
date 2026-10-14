---
name: test-suite
description: Designing, auditing, and backfilling test suites for existing code. Use when writing tests for code that already exists, auditing an existing suite, fixing flaky or permissive tests, or planning test coverage work. Covers characterization vs behavioural tests, isolation, and what makes a test assertion worth having.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

Backfilling tests onto existing code is the best delegation workload there is —
bounded, mechanically verifiable, high-volume, and boring. It is also the one
with the most dangerous silent failure mode.

## The rule that matters most

**An agent writing tests for existing code will assert whatever the code
currently does — including its bugs.** The test passes, coverage goes up, and
the bug is now enshrined in the suite as intended behaviour. Nothing about the
output looks wrong.

So every test written against existing code is one of two kinds, and the spec
must say which:

| Kind | Asserts | When |
|---|---|---|
| **Characterization** | What the code does *today*, bugs included | Before a refactor, to detect unintended change |
| **Behavioural** | What the code *should* do, from a stated requirement | Everywhere else |

Characterization tests must be labelled as such in the test name or a comment,
so the next person knows the assertion is a snapshot and not a contract.

Never let an implementer decide which kind it is writing. The LLD decides, and
for behavioural tests the LLD states the expected behaviour explicitly — if you
cannot state it without reading the implementation, you are writing a
characterization test whether you meant to or not.

## What a good assertion looks like

The failure mode to hunt for, in existing suites and in new ones:

```ts
// Worthless. Passes when the endpoint 500s.
expect([200, 400, 500]).toContain(res.status);

// Worth having.
expect(res.status).toBe(200);
expect(res.body.items).toHaveLength(3);
```

A range of acceptable statuses means the test author did not know what should
happen. That is a spec gap, not a test. Resolve it in the spec.

Related smells, all of which mean the test asserts nothing:

- `expect(true).toBe(true)` placeholders
- conditional skips that hide cascading failures
- assertions on a field's existence but never its value
- snapshot tests regenerated whenever they fail

## Isolation

Shared mutable state across tests is the root cause that produces most surface
symptoms — order dependence, flakes, and the inability to run one test alone.

- Each test creates what it needs and tears it down. A global object mutated by
  25 helper files is one test with 25 steps, not 25 tests.
- Prefer fixtures and factories that return fresh objects over a bootstrap
  object that accumulates state.
- A suite that requires `bail: true` to pass is telling you it is a single
  sequential chain. That is worth knowing but it is not a test suite.
- The bar: any test can run alone, and the whole suite can run in any order.

## Audit order

When improving an existing suite, fix in this order. It is not the order the
findings appear in — it is the order in which fixing one makes the next easier:

1. **Assertion strictness.** Permissive assertions let broken behaviour pass
   silently, so every other improvement is built on an unreliable signal.
   Tighten these first even though they will turn the suite red.
2. **Shared mutable state.** The architectural root cause. Fixing it unlocks
   isolation, parallelism, and single-test runs.
3. **The implicit execution chain.** Once state is isolated, order dependence
   can go.
4. **Duplication and dead tests.** Cheap, mechanical, safe to delegate wholesale.
5. **Cosmetics** — stray logging, missing teardown, placeholder tests.

Steps 4 and 5 are ideal `cheap` profile delegations. Steps 1–3 are not: they
require deciding what the code *should* do, which is a design question.

## What goes in the LLD

For a test task, the `Acceptance` section is unusual — the tests are the
deliverable, so acceptance is about the suite's properties, not its output:

- the exact test file paths to create
- for each test: the scenario, the assertion, and characterization vs behavioural
- what must NOT be mocked (anything touching a transaction, a migration, or a
  raw query needs a real database; mocks do not catch transaction bugs)
- the command that proves it, and that it must pass run alone AND in the full suite
- explicitly: no test may be weakened or skipped to make the suite green

That last line belongs in every test LLD. Without it, a failing test is an
obstacle an implementer will route around.
