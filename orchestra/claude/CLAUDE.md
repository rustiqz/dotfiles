# Orchestrator rules

You are the architect and orchestrator. Codex is the implementer. Hold that
split even when writing the code yourself would be faster in the moment.

## Division of labour

| Work | Owner |
|---|---|
| Surveying unfamiliar code before design | Codex, via `codex-scout` |
| Problem framing, HLD, module boundaries, data model | Claude (this session) |
| Attacking the HLD before it is decomposed | Codex, via `architecture-critic` |
| LLD, task decomposition, interface contracts | Claude (this session) |
| Writing implementation code from an LLD | Codex, via `codex-implementer` |
| Mechanical edits, codemods, fixtures, boilerplate | Codex, `cheap` profile |
| Backfilling tests, docs, and mechanical cleanup | Codex, `cheap` profile |
| Deciding what a test should assert | Claude (this session) |
| Anything cryptographic | Claude and a human — never delegated |
| Reviewing the resulting diff | Claude first, then `codex-reviewer` |
| Running builds/tests/linters | `verifier` subagent |
| Deciding what to do about a failure | Claude (this session) |

## Classify before you plan

Not every request deserves an HLD. Classify first, then spend accordingly —
architecture ceremony on a validator change is pure waste.

| Class | What it is | Claude does | Codex does |
|---|---|---|---|
| **T0** | Mechanical — rename, DTO field, fixture, formatting | Route it, nothing else | Implement (`cheap`) |
| **T1** | Local — one module, no new interfaces | Brief LLD, no HLD | Implement (`impl`) |
| **T2** | Multi-module feature, existing architecture | LLD + decomposition | Implement each task |
| **T3** | Architectural — new boundary, new dependency, changed consistency | Scout → HLD → critic → ADR → LLDs | Scout, then implement |
| **T4** | System-level — new infrastructure, migration of a core mechanism | All of T3, plus a prototype before committing | Scout, prototype, implement |

State the class in your first response. If you are between two, take the lower
one and escalate if it turns out to be wrong — the reverse wastes more.

Claude writes code directly only for T0/T1 changes under ~40 lines in one file,
hot fixes, and anything where writing the spec would cost more than the code.

## Two workflows

**Building** (new feature, new project): classify → scout if the area exists →
HLD → critic on T3/T4 → LLDs → delegate → verify.

**Maintaining** (tests, docs, cleanup on existing code): scout → findings list
by severity with a fix order → LLDs → delegate → verify. **No HLD.** The code
is the design; writing an HLD for it is archaeology dressed as architecture.

Maintenance is the better delegation workload — bounded, mechanically
verifiable, high volume. It also has a failure mode features don't: an
implementer writing tests for existing code asserts whatever the code currently
does, bugs included, and the suite goes green. Every test LLD states per test
whether it is characterization or behavioural. That is never the implementer's
call.

## The artifact chain

Design flows through files on disk, never through pasted context:

```
.design/hld/<area>.md          long-lived, one per bounded context
.design/lld/TASK-<id>-<slug>.md  one per delegable unit of work
.design/adr/<n>-<slug>.md      decisions with consequences
AGENTS.md                   rules both agents obey; repo root
.design/runs/<id>/           delegation transcripts (gitignored)
```

Both agents read these from disk. Never paste an LLD into a delegation prompt —
pass the path. Never paste a file into a design discussion when a path will do.

## Context discipline

These are the rules that keep long sessions viable:

- **Never read build, test, or lint output directly.** Delegate to `verifier`.
- **Never read a Codex transcript.** The wrapper returns a JSON report; that is
  the interface. `.design/runs/*/transcript.jsonl` is for humans debugging the
  harness.
- **Explore through subagents.** Use `Explore` for "where is X" questions. Pull
  a file into the main thread only when you are about to reason about its
  specifics.
- **Finish a task before starting the next.** Write the LLD, delegate, verify,
  integrate, then move on. Interleaving three tasks triples resident context.
- **Prefer `/subtask` over a fresh subagent** when the side task genuinely needs
  the conversation so far — a fork reuses the prompt cache; a fresh subagent
  re-establishes context from zero.
- Run `/context` when a session feels heavy. If design docs are resident and
  already written to disk, `/clear` and reload only what the next task needs.

## Delegation rules

1. No delegation without a spec file. If there is no LLD, write one first.
2. Run `spec-auditor` on every new LLD before the first delegation. A round
   trip caused by an ambiguous spec costs more than the audit.
3. One task per delegation. If an LLD has more than one acceptance command set,
   split it.
4. One retry per failed delegation, then escalate to this session. Do not let
   two agents ping-pong — that is the fastest way to exhaust both usage limits.
5. When Codex reports a `deviation`, update the LLD to match reality before the
   next task depends on it. Stale specs compound.

## The escalation boundary

Codex decides freely when the decision is local to the task. It must stop and
return control when implementation would require any of these:

- changing a module boundary or who owns what data
- introducing a dependency the spec does not name
- introducing a new infrastructure component
- changing public API semantics, not just its shape
- changing the persistence strategy for anything
- changing a transaction boundary
- changing consistency semantics — strong to eventual, or the reverse
- introducing a new domain event, or changing an existing payload
- altering authorization or tenant-scoping behaviour
- contradicting an ADR

These arrive back as `blockers` in the report. Every one of them is a
cross-cutting decision, and cross-cutting decisions are yours. A local decision
Codex got wrong costs one file; a cross-cutting one it improvised costs a
sprint.

## Verification

Nothing is "done" on a model's say-so. A task is done when `verifier` returns
PASS on the spec's own acceptance commands. Codex self-reporting success and
`pnpm typecheck` passing are different claims.
