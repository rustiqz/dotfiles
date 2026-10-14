# Orchestra — Architecture

**Claude Code as architect and control plane; Codex as a constrained execution engine.**

Version 1.0 · review draft · nothing installed until this document is agreed.

---

## Table of contents

1. [Purpose and scope](#1-purpose-and-scope)
2. [Principles](#2-principles)
3. [Topology](#3-topology)
4. [Component reference](#4-component-reference)
5. [The delegation contract](#5-the-delegation-contract)
6. [Complexity classification and routing](#6-complexity-classification-and-routing)
7. [The two workflows](#7-the-two-workflows)
8. [Token economics](#8-token-economics)
9. [Scope model: global, per-repo, per-project](#9-scope-model)
10. [The design store](#10-the-design-store)
11. [The skills model](#11-the-skills-model)
12. [Per-project configuration](#12-per-project-configuration)
13. [Safety boundaries](#13-safety-boundaries)
14. [Failure modes and what catches each](#14-failure-modes)
15. [Installation and verification](#15-installation-and-verification)
16. [Operating it](#16-operating-it)
17. [Known limits and deliberate omissions](#17-known-limits)
18. [Maintaining the setup itself](#18-maintaining-the-setup-itself)
19. [Appendix: complete file inventory](#19-appendix-file-inventory)
20. [Enabling and disabling](#20-enabling-and-disabling)

---

## 1. Purpose and scope

### What this is

A two-agent development system. Claude Code owns problem framing, architecture,
specification, decisions, and review. Codex owns writing code. The handoff
between them happens through files on disk rather than through either agent's
context window.

### The problem it solves

The obvious version of two-agent delegation costs more than not delegating.
If Claude shells out to `codex exec` and reads the result, Codex streams its
entire reasoning transcript back — one delegation can put tens of thousands of
tokens of noise into the orchestrator's context, and you burn two usage limits
to ship one feature. Every published writeup of this pattern reports the same
tradeoff: better output, higher cost, longer runtime, therefore a selective
rather than default tool.

This system is designed to make it cheap enough to be the default.

### Scope of use

Three workload shapes, all of which this must handle:

| Workload | Projects | Dominant activity |
|---|---|---|
| **Greenfield, unfamiliar stacks** | Vaultiq, Monitra | Design, ADRs, learning the stack |
| **Maintenance on known code** | Plankea repos | Tests, documentation, cleanup |
| **Feature work** | occasional, across all | The classic design → implement loop |

The system is not optimized for feature work alone. Maintenance is the higher-
volume workload and the better fit for delegation; greenfield is where design
quality matters most and delegation matters least.

### Non-goals

- Not a multi-agent framework. No agent swarm, no peer negotiation, no
  autonomous long-running loops. Two agents, one direction of authority.
- Not a replacement for reading your own code.
- Not a team tool. It assumes a single operator.
- Not a CI system. Verification runs locally, in a session.

---

## 2. Principles

These are the load-bearing ideas. Everything else is implementation.

### 2.1 Claude thinks across tasks; Codex thinks inside a task

The division is by *scope of reasoning*, not by difficulty. A hard algorithm
inside one file is Codex's work. An easy decision that touches three modules is
Claude's. This is what keeps the agents from fighting over architecture.

### 2.2 The specification is the interface

Not the prompt, not the conversation, not a summary. A file at a stable path,
which Codex reads itself. Consequences:

- Neither agent ever holds a copy of the other's context.
- A correction is made to the spec, so it persists.
- Losing the entire conversation loses nothing durable.
- The spec is reviewable before any tokens are spent implementing it.

### 2.3 Enforcement over instruction

Anything that must be true every time is a mechanism, not a rule in a markdown
file. A model asked to remember fifteen token-economy rules will comply at hour
one and drift by hour four. So:

| Requirement | Weak form (rejected) | Mechanism used |
|---|---|---|
| Codex returns a short report | "be concise" | JSON schema with `maxLength` caps |
| No delegation without a spec | "always write a spec first" | `PreToolUse` hook blocks the call |
| Transcripts stay out of context | "don't read transcripts" | permission `deny` rule |
| Code is typechecked after edits | "remember to typecheck" | `PostToolUse` hook |

Markdown is for judgement calls. Mechanisms are for invariants.

### 2.4 Ground truth beats self-report

Models are unreliable narrators about their own work. A Codex report saying
"tests pass" is a claim, not evidence. So the changed-file list comes from
`git status`, not from the report; and the acceptance commands are re-run by a
separate agent that did not write the code.

### 2.5 Spend context where it changes a decision

Reading a file into the orchestrator is a cost that persists for the rest of
the session. Exploration, verification output, and delegation transcripts never
earn that. They go to subagents, whose windows are disposable.

### 2.6 Fail early, where failure is cheap

An ambiguous spec costs a round trip. A wrong HLD costs every LLD written
against it. A wrong boundary on a greenfield project costs the project. The
gates in this system are placed so that being wrong is discovered at the
cheapest available point: `spec-auditor` before delegation,
`architecture-critic` before decomposition.

---

## 3. Topology

```
                                 YOU
                                  │
                                  ▼
    ┌──────────────────────────────────────────────────────────┐
    │  CLAUDE CODE — main thread (Opus)                        │
    │                                                          │
    │  classify · frame · HLD · LLD · decide · review · accept │
    └───┬──────────────┬──────────────┬───────────────┬────────┘
        │              │              │               │
   ① scout        ② critique     ③ audit spec    ④ delegate
        │              │              │               │
        ▼              ▼              ▼               ▼
  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌──────────────┐
  │codex-    │  │architecture-│  │spec-     │  │codex-        │
  │scout     │  │critic       │  │auditor   │  │implementer   │
  │(haiku)   │  │(haiku)      │  │(sonnet)  │  │(haiku)       │
  └────┬─────┘  └──────┬──────┘  └────┬─────┘  └──────┬───────┘
       │               │              │               │
       │ codex-task    │ codex-task   │ (reads spec)  │ codex-task
       │ --profile     │ --profile    │               │ --profile
       │   review      │   review     │               │   impl|cheap
       ▼               ▼              │               ▼
  ┌─────────────────────────────┐     │      ┌──────────────────┐
  │  CODEX CLI  (read-only)     │     │      │ CODEX CLI        │
  │  maps code / attacks design │     │      │ (workspace-write)│
  └──────────────┬──────────────┘     │      └────────┬─────────┘
                 │                    │               │
                 │                    │               ▼
                 │                    │      ┌──────────────────┐
                 │                    │      │  repository      │
                 │                    │      └────────┬─────────┘
                 │                    │               │
                 │                    │          ⑤ verify
                 │                    │               ▼
                 │                    │      ┌──────────────────┐
                 │                    │      │ verifier (haiku) │
                 │                    │      │ PASS / ≤10 errs  │
                 │                    │      └────────┬─────────┘
                 │                    │               │
                 │                    │          ⑥ 2nd opinion
                 │                    │               ▼
                 │                    │      ┌──────────────────┐
                 │                    │      │ codex-reviewer   │
                 │                    │      │ (read-only)      │
                 │                    │      └────────┬─────────┘
                 ▼                    ▼               ▼
    ┌────────────────────────────────────────────────────────────┐
    │  ~/design/<project>/    ← the shared, durable memory        │
    │  hld/   lld/   adr/   runs/                                 │
    │  linked into each repo as .design (gitignored symlink)      │
    └────────────────────────────────────────────────────────────┘
```

**What crosses each boundary.** The arrows out of the main thread carry a path
and an instruction — a few hundred tokens. The arrows back carry a summary — a
few hundred tokens. Everything large (transcripts, diffs, test output, file
contents) lives inside a subagent window or on disk, and never enters the main
thread.

---

## 4. Component reference

### 4.1 `bin/codex-task` — the delegation wrapper

**The single choke point.** Every invocation of Codex in this system goes
through it; `settings.json` denies bare `Bash(codex exec:*)` so it cannot be
bypassed.

What it does:

1. Validates the spec file exists.
2. Creates a run directory under `.design/runs/<timestamp>-<spec>/`.
3. Records `git rev-parse HEAD` as a pre-run baseline.
4. Builds a deliberately tiny prompt — it passes the *path* to the spec, never
   the spec's contents.
5. Invokes `codex exec` with:

   | Flag | Effect |
   |---|---|
   | `--profile <impl\|cheap\|review>` | selects the reasoning tier |
   | `--sandbox <mode>` | write access, explicit per call |
   | `--ask-for-approval never` | no interactive stall in unattended runs |
   | `--json` | event stream → `transcript.jsonl` on disk |
   | `--output-last-message` | final report → `report.json` on disk |
   | `--output-schema` | **constrains that report to a fixed shape** |
   | `--skip-git-repo-check` | tolerates non-git scratch dirs |

6. After the run, derives the changed-file list from `git status` — ground
   truth, not self-report.
7. Extracts token usage from the event stream into `usage.json`.
8. Prints **only**: the run id, the report JSON, and a 40-line diffstat.

Resume path: `--resume <session-id>` continues a prior Codex session for a
fix-up. Used for retries only; new tasks always start fresh, because a fresh
session starts with a small context and a resumed one carries everything
forward.

### 4.2 `templates/codex-report.schema.json` — the return contract

The mechanism that makes delegation cheap. Every field is capped:

| Field | Constraint | Purpose |
|---|---|---|
| `status` | enum: completed / partial / blocked | drives the orchestrator's next move |
| `summary` | `maxLength: 600` | four sentences, not a narrative |
| `changed_files[]` | `maxItems: 40`, `why` capped at 160 | cross-checked against git |
| `verification.commands[]` | `first_error` capped at 400 | first failing assertion only, never full output |
| `deviations[]` | `maxItems: 10` | where reality departed from the spec |
| `blockers[]` | `maxItems: 10` | decisions escalated back to the orchestrator |

`additionalProperties: false` throughout. A model told "be brief" is not brief;
a model handed a schema with a 600-character ceiling has no choice.

### 4.3 Subagents — `claude/agents/`

Six agents. Each runs in its own context window and returns a summary.

| Agent | Model | Effort | Sandbox | Returns |
|---|---|---|---|---|
| `codex-scout` | haiku | low | read-only | A structural map of an area (~1,500 tok) |
| `architecture-critic` | haiku | low | read-only | ≤12 ranked objections to a draft HLD |
| `spec-auditor` | sonnet | medium | n/a | Gap list + `READY` / `NOT READY` |
| `codex-implementer` | haiku | low | workspace-write | Report JSON + 3 sentences |
| `verifier` | haiku | low | n/a | `PASS`, or ≤10 `file:line — message` |
| `codex-reviewer` | haiku | low | read-only | ≤12 findings in 3 severity buckets |

Three design notes:

- **Five of six run on Haiku.** They are harnesses and reporters, not thinkers.
  `spec-auditor` is the exception — judging whether a spec is implementable
  requires real reasoning, so it gets Sonnet. The orchestrator stays on Opus.
- **`codex-implementer` sets `experimental.cacheTtl: 1h`.** Delegations arrive
  in bursts; an hour-long prompt cache across a batch is material.
- **Everything read-only is read-only by sandbox, not by instruction.** The
  scout, the critic, and the reviewer physically cannot write. A reviewer that
  can silently apply its own findings produces unreviewable changes.

### 4.4 Hooks — `claude/hooks/`

| Hook | Event | Behaviour |
|---|---|---|
| `require-spec.sh` | `PreToolUse` on Bash | Blocks `codex-task` if `--spec` is missing, the file doesn't exist, or it has no `## Acceptance` section. **Exit 2 blocks the call** and returns the reason to the agent. |
| `post-edit-typecheck.sh` | `PostToolUse` on Edit/Write | Typechecks after Claude edits a `.ts` file. Non-blocking; reports ≤5 errors for that file. |
| `log-delegation.sh` | `SubagentStop` | Appends `ts / agent / run / status / in_tok / out_tok` to a ledger. |

The spec gate is the most important of the three. A spec with no acceptance
commands can never be proven done, so the delegation is refused before it costs
anything. This is also what makes "no delegation without a written spec" an
invariant rather than a hope.

All three need `jq`. Without it they exit silently and the spec gate is lost.

### 4.5 Codex profiles — `codex/`

Profiles in current Codex are **separate files** next to `config.toml`, layered
by `--profile <name>`. Not `[profiles.x]` blocks inside it — older guides get
this wrong.

| Profile | Model | Effort | Sandbox | Approval | For |
|---|---|---|---|---|---|
| `impl` | gpt-5.6 | high | workspace-write | never | Feature work from a complete LLD |
| `cheap` | gpt-5.6-terra | low | workspace-write | never | Renames, DTOs, fixtures, codemods, dead-test removal |
| `review` | gpt-5.6 | high | **read-only** | never | Scouting, critique, code review |

Base `config.toml` covers interactive use: `medium` effort, `on-request`
approval, `web_search = "cached"`, `alternate_screen = false` for tmux.

### 4.6 Slash commands — `claude/commands/`

| Command | Flow | Stops at |
|---|---|---|
| `/scout <area>` | `codex-scout` → present map | before designing |
| `/hld <feature>` | classify → scout → HLD → critic (T3/T4) | the task breakdown, for approval |
| `/lld <task>` | LLD from template → `spec-auditor` | the audit verdict |
| `/delegate <spec>` | pre-checks → `codex-implementer` → `verifier` → review | after one task |
| `/maintain <area>` | scout → findings by severity → LLDs | your review of the fix order |
| `/review2 [focus]` | your review, then `codex-reviewer`, bucketed | recommendations, no fixes applied |
| `/ledger` | `agent-budget` | — |

**Every command stops.** The gates are the point. Each stop is a place where a
wrong direction costs one document instead of a day.

### 4.7 `bin/design-store` — out-of-repo design docs

Manages `~/design/`, one directory per project, symlinked into each repo as
`.design`. See §10.

### 4.8 `bin/agent-budget` — cross-agent token ledger

Reads run directories and the hook ledger, reports per-run input/output tokens
and — the useful metric — **tokens per changed file**. See §8.5.

---

## 5. The delegation contract

### 5.1 Preconditions

A delegation may begin only when all four hold. The first is enforced by hook;
the rest are enforced by the `delegate-to-codex` skill.

1. An LLD exists at `.design/lld/TASK-<id>-*.md`, with an `## Acceptance` section.
2. `spec-auditor` returned `READY` on it.
3. The task is one unit of work — one acceptance command set.
4. The working tree is clean, or its dirty files are unrelated.

### 5.2 What Codex receives

A prompt of roughly 120 tokens: the spec path, and instructions to follow
`AGENTS.md`, not redesign, not add dependencies, run the acceptance commands,
and return JSON matching the schema. Codex reads everything else itself.

### 5.3 The escalation boundary

Codex decides freely when the decision is local to the file it is changing. It
must stop and report a **blocker** when implementation would require:

- changing a module boundary, or moving data ownership between modules
- adding a dependency the spec does not name
- adding a new infrastructure component
- changing what a public API *means*, not just its shape
- changing how something is persisted
- changing a transaction boundary
- changing consistency semantics
- adding a domain event, or changing an existing payload
- changing authorization or tenant-scoping behaviour
- contradicting a decision recorded in an ADR

This list appears in `AGENTS.md`, where Codex reads it, framed explicitly:
**reporting one of these is a successful outcome, not a failure.** These are
cross-cutting decisions and cross-cutting decisions belong to the orchestrator.
A local decision Codex got wrong costs one file; a cross-cutting one it
improvised costs a sprint and will look plausible until it doesn't.

### 5.4 Retry policy

**One retry, then escalate.** The `codex-implementer` subagent may run
`codex-task --resume` exactly once when verification fails. If it still fails,
it returns `partial` and the orchestrator decides.

Two agents ping-ponging on a failing test is the single fastest way to exhaust
both usage windows, and neither agent can tell that it's happening.

### 5.5 Handling the return

| Status | Orchestrator's move |
|---|---|
| `completed` | Run `verifier` independently. Trust it, not the report. Then read the diff. |
| `partial` | Retry already spent. Read `first_error`. Spec gap → fix the LLD and re-delegate. Real bug → decide where to fix it. **Never a third attempt on the original spec.** |
| `blocked` | A design question came back to you. Answer it *in the LLD*, not in a follow-up prompt. |
| `deviations` non-empty | Update the LLD to match what was built, immediately. A downstream task written against a stale spec fails in a way that looks like an implementation bug. |

---

## 6. Complexity classification and routing

Stated in the orchestrator's first response, before any work.

| Class | What it is | Claude does | Codex does |
|---|---|---|---|
| **T0** | Mechanical — rename, DTO field, fixture, formatting | Route it | Implement (`cheap`) |
| **T1** | Local — one module, no new interfaces | Brief LLD, no HLD | Implement (`impl`) |
| **T2** | Multi-module, existing architecture | LLD + decomposition | Implement each task |
| **T3** | Architectural — new boundary, dependency, or consistency change | Scout → HLD → **critic** → ADR → LLDs | Scout, then implement |
| **T4** | System-level — new infrastructure, core mechanism migration | All of T3, plus a prototype before committing | Scout, prototype, implement |

When between two classes, take the lower and escalate if wrong — the reverse
wastes more. Don't produce an HLD to change a validator.

**Claude writes code directly** for T0/T1 under ~40 lines in one file, hot
fixes, and anything where writing the spec costs more than writing the code.

### Routing to a Codex profile

| Signal | Profile |
|---|---|
| LLD front-matter `complexity: mechanical`; cleanup, dead tests, duplication | `cheap` |
| Normal implementation from a complete LLD | `impl` |
| Money, auth, transactions, migrations | `impl`, then `codex-reviewer` |
| Scouting, critique, review | `review` (read-only) |
| **Anything cryptographic** | **not delegated — see §13.2** |

---

## 7. The two workflows

The system has two pipelines, and using the wrong one is a real failure mode.

### 7.1 Building

For new features and new projects. Design precedes code.

```
classify (T0–T4)
   ↓
codex-scout            ← only if the area already exists
   ↓
HLD                    ← .design/hld/<area>.md
   ↓
architecture-critic    ← T3/T4 only; findings presented unsoftened
   ↓
revise HLD + ADRs
   ↓
[YOU APPROVE the task breakdown]
   ↓
LLD per task           ← .design/lld/TASK-<id>-<slug>.md
   ↓
spec-auditor           ← READY / NOT READY
   ↓
codex-implementer      ← one task
   ↓
verifier               ← independent re-run of acceptance commands
   ↓
your diff review → codex-reviewer (if sensitive)
   ↓
integrate; update LLD if deviations
```

### 7.2 Maintaining

For tests, documentation, and cleanup on code that already exists. **No HLD.**
The code is the design; writing an HLD for it is archaeology dressed as
architecture.

```
codex-scout (or an existing audit)
   ↓
findings list, grouped by severity, with an explicit fix order
   ↓
[YOU APPROVE the fix order]
   ↓
LLD per fix
   ↓
route: decisions stay with Claude, mechanics go to `cheap`
   ↓
codex-implementer → verifier
```

### 7.3 Why maintenance is the better delegation workload

Bounded, mechanically verifiable, high volume, and boring — every property that
makes delegation pay. This is where the setup earns its keep, more than feature
work does.

It also carries a failure mode that features do not. **An implementer writing
tests for existing code will assert whatever the code currently does, bugs
included.** The test passes, coverage rises, the bug is now enshrined in the
suite as intended behaviour, and nothing about the output looks wrong.

The countermeasure is structural, in the `test-suite` skill:

| Kind | Asserts | Labelled |
|---|---|---|
| **Characterization** | Today's behaviour, bugs included | Yes, in the test name or a comment |
| **Behavioural** | A stated requirement | — |

The LLD states which, **per test**. The implementer never decides. And every
test LLD carries one line in `Out of scope`: *no test may be weakened,
loosened, or skipped to make the suite pass.* Without it, a failing test is an
obstacle an implementer routes around.

### 7.4 Trivial path

```
you ask → Claude classifies T0 → Codex implements → tests → done
```

No ceremony. The classifier exists to make this path available.

---

## 8. Token economics

Nine mechanisms, ordered by impact.

### 8.1 Subagent isolation — the largest single saving

Delegation transcripts, verification output, scout exploration, and review
findings all land in a subagent's window. The main thread receives a summary.
A delegation that would have cost ~30,000 tokens of transcript costs ~400.

### 8.2 Schema-constrained returns

`--output-schema` with `maxLength` on every field. Not a request for brevity —
a ceiling. See §4.2.

### 8.3 Path-passing, never context-passing

The spec is read from disk by whoever needs it. It is never duplicated into a
prompt, and the conversation history is never sent to Codex.

### 8.4 Model tiering

Opus in the orchestrator. Sonnet for `spec-auditor`. Haiku everywhere else.
`CLAUDE_CODE_SUBAGENT_MODEL=haiku` catches any unlabelled helper.
`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2` prevents a subagent growing its own
tree, which makes spend unattributable.

### 8.5 Scouting instead of reading

`codex-scout` returns ~1,500 tokens of structure where reading twenty files
would cost tens of thousands — and it spends *Codex's* budget, in a read-only
sandbox, before the design work begins.

This is the cheapest win in the system and it happens before, not during.

### 8.6 Deterministic verification via hooks

Neither model spends tokens discovering breakage that a script reports in two
lines.

### 8.7 Fresh sessions by default

A new `codex exec` starts small. `resume` carries prior context forward. New
tasks get fresh; retries get resume.

### 8.8 Cache reuse

`cacheTtl: 1h` on `codex-implementer`. Prefer `/subtask` forks over fresh
subagents when the side task genuinely needs conversation history — a fork
reuses the prompt cache; a subagent rebuilds from zero.

### 8.9 Measurement: tokens per changed file

`agent-budget` reports this per run. **A high ratio means the implementer spent
its budget exploring rather than writing**, which traces back to a thin spec
almost every time. It is the metric that tells you your LLDs need work, and the
only feedback loop in the system that improves the upstream design.

### Supporting settings

| Setting | Value | Why |
|---|---|---|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 75 | Compaction lands at a task boundary, not mid-delegation |
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` | 3 | Beyond this you cannot reason about what changed in one tree |

### What this deliberately does not do

It does not try to make delegation free. A delegation that produces a real
feature will cost real tokens on the Codex side. The goal is that it costs
almost nothing on the *orchestrator* side, so the expensive context stays clean
and usable for the work only it can do.

---

## 9. Scope model

| Layer | Location | Applies to |
|---|---|---|
| Orchestrator rules | `~/.claude/CLAUDE.md` | every repo |
| Settings, env, hooks | `~/.claude/settings.json` | every repo |
| Subagents | `~/.claude/agents/` | every repo |
| Slash commands | `~/.claude/commands/` | every repo |
| **Activity** skills | `~/.claude/skills/` + `~/.codex/skills/` | every repo |
| Codex profiles | `~/.codex/*.config.toml` | every repo |
| Executables | `~/.local/bin/` | every repo |
| Universal agent rules | `~/.codex/AGENTS.md` | every repo |
| Repo stack + vocabulary | `~/design/<repo>/agents/`, symlinked in | that repo |
| **Stack** skills | `<repo>/.claude/skills/` | that repo |
| Design docs | `~/design/<repo>/` via `.design` | that repo |

Precedence is **project over user**. A repo-level skill or agent with the same
`name` overrides the global one. That is the escape hatch when one codebase
needs a different convention.

Everything global is global by design — the point is that you don't
re-scaffold per repo. What is genuinely per-repo is the vocabulary and the specs.

---

## 10. The design store

### The problem

Design docs belong next to the code conceptually, but committing them to a
company repo puts every spec, abandoned alternative, and half-finished LLD into
code review and repo history.

### The shape

```
~/design/                                  ← its own git repo, yours alone
  plankea-helpdesk-hub-node/
    hld/  lld/  adr/  runs/
  vaultiq/
    hld/  lld/  adr/  runs/
  monitra/
    hld/  lld/  adr/  runs/

<work repo>/.design → ~/design/<repo>      ← one symlink, locally ignored
```

`design-store link` creates the directory, makes the symlink, and adds it to
`.git/info/exclude` — **not** `.gitignore`, so it is ignored on your machine
and never appears in a diff anyone reviews. `runs/` is gitignored inside the
store, since transcripts are large and reproducible.

Agents always see the stable relative path `.design/lld/TASK-014-*.md`. No
tooling knows where the store actually lives; move it, relink, nothing changes.

### The cost, stated honestly

Design docs lose their git-level link to the implementing commit, and teammates
cannot read them. If a spec later becomes something the team should own,
promote that one file into the repo. Drafts, alternatives, and run logs stay out.

### Nothing is committed to the work repo

`design-store link` seeds `AGENTS.md` and `CLAUDE.md` inside the store and
symlinks them into the repo alongside `.design`. All three go into
`.git/info/exclude`.

Both tools read these from the working directory and neither cares about git
status, so this behaves identically to committing them — minus the commit.
What you gain: they are version-controlled (the store is a git repo), they
survive a fresh clone of the work repo, and re-creating them is one command.

Committing agent configuration to a company repo is a social decision that
needs buy-in, and on a solo project there is nobody to share it with. When you
do want a team to have them: `git add -f AGENTS.md`. If a real `AGENTS.md`
already exists in the repo — a teammate's, or yours from before — `link`
adopts it into the store rather than clobbering it.

### Three layers of agent rules

Both Codex and Claude Code aggregate these hierarchically, so the universal
rules are written once and a per-repo file holds only what is local:

| Layer | File | Holds |
|---|---|---|
| Global, Codex | `~/.codex/AGENTS.md` | Role, hard rules, escalation boundary, commit trailer, report format — ~70 lines |
| Global, Claude | `~/.claude/CLAUDE.md` | Orchestrator rules, classifier, workflows |
| Per-repo | `~/design/<project>/agents/AGENTS.md` | Stack, conventions, **domain vocabulary**, sharp edges — a dozen lines |

The per-repo file was previously a near-copy of the global one in every
repository. Splitting it means a rule change happens in one place.

---

## 11. The skills model

### 11.1 Two axes

The split that makes this survive a stack change:

**Activity skills — global.** They describe how you work, and they hold whether
the code is Rust, TypeScript, or Kotlin.

| Skill | Covers |
|---|---|
| `design-docs` | HLD/LLD/ADR authoring + templates |
| `delegate-to-codex` | Routing, profile selection, retry, return handling |
| `test-suite` | Characterization vs behavioural, isolation, audit order |
| `documentation` | Audience-first docs, what code can't tell you |
| `greenfield` | Day-one decisions and their order |

**Stack skills — per-repo.** A Rust CLI, a browser extension, and a NestJS
service share nothing useful.

| Skill | Placement |
|---|---|
| `nestjs-backend` | Global — the exception, used by both Plankea and Vaultiq's sync server |
| `frontend-web` | Per-repo, where there's a web client |
| `mobile-app` | Per-repo, on Vaultiq's native clients |
| `rust-cli` (to write) | Monitra's `.claude/skills/` |
| `browser-extension` (to write) | Vaultiq extension's `.claude/skills/` |

### 11.2 How to write one

Skills encode **decisions an LLD must make**, not library documentation. The
agents already know NestJS. What they don't know is that you require external
side effects after commit, or that a range of acceptable HTTP statuses means
the author didn't know what should happen.

Constraints:

- Keep each under ~150 lines. **Skill descriptions load into every session**;
  Claude Code warns past ~15k tokens of them combined.
- Write the `description` for routing — it decides whether the skill fires.
  Put substance in the body, which loads only when invoked.
- Use progressive disclosure: a short `SKILL.md` plus `references/` files
  loaded on demand.
- Both Claude Code and Codex read the same `SKILL.md` format, so one tree
  serves both via symlink.

### 11.3 Worth adding, in order

1. `multi-tenancy` — tenant scoping as an invariant. For Plankea this is the
   highest-value missing skill, because the failure mode is silent.
2. `rust-cli` — for Monitra: error typing, no-unwrap policy, module seams.
3. `applied-crypto` — for Vaultiq. See §13.2; mostly a skill about *not*
   implementing.
4. `typeorm-migrations` — split from `nestjs-backend` as it grows.
5. `temporal-workflows` — determinism, activity boundaries, versioning.
6. `debugging` — reproduce, bisect, hypothesize, prove. Stops the
   add-logging-everywhere pattern.
7. `code-review` — your checklist, so `/review2` compares against something
   explicit.

### 11.4 Third-party

Install `anthropics/skills` (the `pdf` skill is on Plankea's document-worker
path) and `skill-creator`. Mine the Karpathy guardrails into `AGENTS.md` rather
than installing them — you already have that file. Read Superpowers, don't
install it; it is this architecture with a TDD spine, and running two workflow
frameworks helps nobody.

---
## 12. Per-project configuration

Three projects, three shapes. Each gets `AGENTS.md` + `CLAUDE.md` in the repo
and a directory in the design store.

### 12.1 Plankea repos — maintenance mode

| | |
|---|---|
| **Workflow** | `/maintain` — no HLD |
| **Dominant work** | Test suites, documentation, cleanup |
| **Profiles** | Heavy `cheap`; `impl` only for decisions about intended behaviour |
| **Skills** | `test-suite`, `documentation`, `nestjs-backend`, `multi-tenancy` |
| **Key risk** | Enshrining existing bugs in the test suite |

The existing e2e audit *is* the plan — a severity-ranked findings list with a
fix order already decided. Do not redo that analysis; `/maintain` reads it and
decomposes from it.

Fix order, which is deliberately not the order findings appear in:

1. **Assertion strictness.** Permissive assertions let broken behaviour pass,
   so every later improvement builds on an unreliable signal. Fix first even
   though the suite goes red.
2. **Shared mutable state.** The architectural root cause; fixing it unlocks
   isolation and single-test runs.
3. **The implicit execution chain.** Possible once state is isolated.
4. **Duplication and dead tests.** Mechanical — delegate wholesale to `cheap`.
5. **Cosmetics.** Stray logging, missing teardown, placeholders. Also `cheap`.

Steps 1–3 are **not** delegatable as written: they require deciding what the
code *should* do, which is a design question. Claude produces the intended
behaviour per test; Codex writes it.

### 12.2 Monitra — Rust, pinned toolchain

| | |
|---|---|
| **Workflow** | Mixed — TUI is greenfield, the rest is maintenance |
| **Hard constraint** | Pinned rustc; the `Cargo.toml` pin block is deliberate |
| **Profiles** | `impl` for anything touching the store or evaluator; `cheap` for mechanical |
| **Skills** | `rust-cli` (to write), `greenfield` for the TUI, `test-suite` |
| **Key risk** | Toolchain drift |

Append `templates/agents-fragments/rust-pinned-toolchain.md` to the repo's
`AGENTS.md`. **The pinned toolchain is the most-violated constraint when
delegating Rust** — an agent reaches for the newest std API or bumps a crate,
and you find out at compile time after a full delegation is spent. The fragment
makes a toolchain conflict a blocker rather than something to route around, and
requires verification with `cargo +<version>`, not whatever is on PATH.

The zero-warning build standard means `clippy -- -D warnings` belongs in every
`Acceptance` section.

### 12.3 Vaultiq — greenfield, multi-stack, security-critical

| | |
|---|---|
| **Workflow** | `greenfield` — HLD and ADRs carry maximum weight |
| **Stacks** | Rust→WASM core, browser extension, NestJS sync server, native mobile, Tauri |
| **Profiles** | `impl`; `cheap` almost never |
| **Skills** | `greenfield`, `applied-crypto` (to write), `nestjs-backend` for the sync server |
| **Key risk** | Delegating cryptography |

Append `templates/agents-fragments/crypto-hard-rules.md` to `AGENTS.md`. See
§13.2 — this is the one hard exclusion in the system.

Because the clients are separate repos on different stacks, each gets its own
`.design` link into `~/design/vaultiq-<client>/`, but the **crypto core's HLD
and ADRs are shared**. The data model and the wire format are decided once and
every client inherits them. Cross-reference rather than duplicate; a divergence
between two clients' understanding of the ciphertext format is a corruption bug.

Sequence the build so the risky part fails first: the crypto core and its wire
format, proven end-to-end in the extension, before any second client exists.

---

## 13. Safety boundaries

### 13.1 Sandboxing

| Agent | Sandbox | Consequence |
|---|---|---|
| `codex-scout` | read-only | Cannot modify while exploring |
| `architecture-critic` | read-only | Cannot "fix" the design it critiques |
| `codex-reviewer` | read-only | Findings stay reviewable, never silently applied |
| `codex-implementer` | workspace-write | Repo only, not the wider system |

`--yolo` and `danger-full-access` are denied in `settings.json`. This is
structural, not advisory: a review agent that *can* patch what it finds will
eventually do so, and the change arrives unreviewed.

### 13.2 Cryptography — the one hard exclusion

**Codex must not write, modify, or optimize any cryptographic code.** Not
encryption routines, key derivation, parameter selection, RNG, nonce or salt
generation, signatures, MACs, constant-time comparison, or anything changing a
ciphertext's shape or what goes to the server.

It may wire up calls to a vetted library exactly as the spec dictates —
algorithm, library, parameters, and call sequence all named. If the spec does
not name a parameter, it does not choose one.

**Why this is categorically different from everything else in this document.**
The entire system rests on delegate-then-verify. Cryptographic code that is
wrong compiles, runs, and passes every test. The failure is silent and not
detectable by any verification here. It is the one category where "it works"
proves nothing, so the loop that makes the rest of this safe does not apply.

Vaultiq's zero-knowledge invariants hold everywhere, and a change violating one
is a blocker **even if the spec appears to ask for it**:

- The server never receives the master password or anything derived from it
  that could decrypt.
- Plaintext vault contents never leave the client — not in logs, telemetry,
  error messages, or crash reports.
- Anything sent to the server is encrypted client-side, including metadata
  designated sensitive.
- Keys live in memory no longer than needed; never on disk.

### 13.3 Secrets

`settings.json` denies `Read(./.env)` and `Read(./**/.env.*)`. `AGENTS.md`
forbids touching `.env*`, credentials, CI secrets, and migrations already on
main.

### 13.4 MCP servers

MCP output is untrusted input — a database row or issue body can carry
instructions aimed at the agent. Scope MCP servers to the subagent that needs
them via `mcpServers` frontmatter, never globally, so the blast radius is one
window and the report is filtered before reaching the main thread.

Also: tool descriptions load into every session whether used or not. Three
global servers can cost thousands of tokens before you type anything, which
works against §8 directly.

Recommended: Postgres on a **dedicated read-only dev role** (never prod),
scoped to a `schema-inspector` subagent; Context7 for version-specific docs;
Sentry and Playwright scoped. Prefer vendor-maintained servers and pin versions
— the original `@modelcontextprotocol/*` database servers were archived in
favour of vendor ones, and several popular community servers have security
findings filed.

### 13.5 Unattended execution

`--ask-for-approval never` means delegations do not stall. It does **not** mean
unsupervised: the sandbox is the boundary, the spec is the scope, and every run
is reviewed before integration. `/delegate` deliberately stops after one task.

---

## 14. Failure modes

Every failure this system is designed against, and the specific thing that
catches it.

| # | Failure | Caught by | Type |
|---|---|---|---|
| 1 | Codex transcript floods the orchestrator | Wrapper + subagent isolation + `deny` on bare `codex exec` | Mechanism |
| 2 | Codex returns a rambling report | `--output-schema` with `maxLength` caps | Mechanism |
| 3 | Delegation with no spec | `require-spec.sh` PreToolUse, exit 2 | Mechanism |
| 4 | Spec with no provable acceptance | Same hook greps for `## Acceptance` | Mechanism |
| 5 | Ambiguous spec → implementer improvises | `spec-auditor` before delegation | Agent |
| 6 | Two agents ping-pong to exhaustion | One-retry policy in `codex-implementer` | Rule |
| 7 | "Tests pass" is false | `verifier` independently re-runs acceptance | Agent |
| 8 | Codex misreports what it changed | Changed files derived from `git status` | Mechanism |
| 9 | Wrong architecture discovered after decomposition | `architecture-critic` on T3/T4 HLDs | Agent |
| 10 | Orchestrator burns context exploring | `codex-scout` before design | Agent |
| 11 | Tests enshrine existing bugs | Characterization/behavioural labelling per test in the LLD | Rule |
| 12 | Test weakened to make suite green | Mandatory `Out of scope` line in test LLDs | Rule |
| 13 | Cross-cutting decision improvised | Escalation list in `AGENTS.md` → blocker | Rule |
| 14 | Rust toolchain drift | Pin block + `cargo +<version>` in acceptance | Rule + verification |
| 15 | Wrong crypto, silently | **Categorical exclusion** — not delegated | Prohibition |
| 16 | LLD goes stale after deviations | `deviations` field + mandatory LLD update | Rule |
| 17 | Type errors found late | `post-edit-typecheck.sh` PostToolUse | Mechanism |
| 18 | Spend invisible across two agents | `agent-budget` + `log-delegation.sh` ledger | Instrumentation |
| 19 | Thin LLDs cost tokens silently | Tokens-per-changed-file ratio | Instrumentation |
| 20 | Review agent silently applies its findings | `review` profile is read-only by sandbox | Mechanism |
| 20a | **Scope creep — files touched outside the spec** | `check-scope` in `verifier`, exit 1 | **Mechanism** |
| 20b | Commit can't be traced back to its spec | `Design: TASK-<id>` commit trailer | Rule |
| 21 | Design docs or agent config clutter work repos | Design store + symlinks + `.git/info/exclude` | Mechanism |
| 22 | Subagent spawns its own tree | `MAX_SUBAGENT_SPAWN_DEPTH=2` | Mechanism |
| 23 | Compaction hits mid-delegation | `AUTOCOMPACT_PCT_OVERRIDE=75` | Mechanism |

**Thirteen of twenty-five are mechanisms** — enforced regardless of what either
model remembers. That ratio is the design goal of §2.3.

### Failures this does NOT catch

Stated plainly, because knowing the gaps is the point of a review:

- **A wrong LLD that is internally consistent.** `spec-auditor` checks for
  gaps, not correctness. A complete, clear, wrong spec passes and gets built.
- **Subtly wrong logic that satisfies its tests.** If the spec and the tests
  share a wrong assumption, nothing here notices.
- **Cumulative architectural drift.** Twenty individually-correct tasks can
  still erode a boundary. `check-scope` catches per-task creep, but nothing
  watches the trend across tasks; you have to.
- **Crypto.** Which is why it is excluded rather than mitigated.
- **A model that lies convincingly in a `blocked` report.** The escalation
  boundary depends on Codex recognizing it crossed one.

---

## 15. Installation and verification

### Prerequisites

`claude`, `codex`, `jq`, `git`, `pnpm` (for the TS projects), `cargo` (Monitra).
**Without `jq` the hooks exit silently and you lose the spec gate** — check it
first.

### Install

```bash
git clone <this> ~/dotfiles/orchestra
cd ~/dotfiles/orchestra
./install.sh
```

Symlinks rather than copies, so edits here take effect immediately and
`git diff` shows drift. Existing files are backed up with a timestamp.
Re-running is safe.

`install.sh` wires: `~/.claude/{CLAUDE.md, settings.json, agents/, commands/,
hooks/}`, `~/.codex/*.config.toml`, the shared `skills/` tree into **both**
`~/.claude/skills` and `~/.codex/skills`, `~/.local/bin/{codex-task,
agent-budget, design-store}`, and the report schema into
`~/.config/orchestra/`.

### Per repository

```bash
cd <repo>
design-store link
# seeds AGENTS.md + CLAUDE.md in the store and symlinks all three in
# then, where applicable, append to the store copy:
cat <orchestra>/templates/agents-fragments/rust-pinned-toolchain.md >> .design/agents/AGENTS.md
cat <orchestra>/templates/agents-fragments/crypto-hard-rules.md     >> .design/agents/AGENTS.md
```

Then fill in the **domain vocabulary** table in `AGENTS.md`. An agent that
doesn't know what your nouns mean writes code like a contractor on day one.
That table fixes more output-quality problems than anything else in this
install.

### Verification

```bash
claude /doctor      # lists the 6 agents, 8 skills, 7 commands
codex doctor        # shows the 3 profiles and the skills tree
design-store status # store contents, and whether this repo is linked
agent-budget        # empty ledger, but runs
```

### Smoke test before trusting it

Run these in order on a scratch repo:

1. `codex-task --spec /nonexistent.md` → should exit 66.
2. Write a spec with no `## Acceptance`, ask Claude to delegate it → the hook
   should block with exit 2 and an explanation.
3. Delegate a real one-file task → confirm the main thread receives a short
   report and **no transcript**. Check `/context` before and after; the delta
   should be small.
4. `agent-budget` → confirm the run appears with token counts.

If step 3's delta is large, something is bypassing the wrapper. Check the
`deny` rules before proceeding.

---

## 16. Operating it

### The loop

```
/scout <area>              understand what exists         (maintenance & T3+)
/hld <feature>             design it                      (T2+, greenfield)
/lld TASK-<id>             specify one task
/delegate <spec path>      build and verify it
/review2 [focus]           second opinion on the diff     (sensitive changes)
/maintain <area>           the no-HLD path
/ledger                    what it cost
```

### First week

Run the maintenance path on one Plankea test file end to end. It is the lowest
stakes, the most mechanical, and it exercises the whole chain — hook, wrapper,
schema, verifier, ledger — without risking anything.

Do not start Vaultiq on this until the loop is boring.

### What to tune after a week

| Symptom | Cause | Fix |
|---|---|---|
| `spec-auditor` flags the same gap repeatedly | LLD template is missing a section | Add it to `templates/LLD.md` |
| High tokens-per-changed-file in `agent-budget` | LLDs are too thin | Fix upstream in `design-docs`, not the delegation |
| `cheap` output keeps getting rejected | That task class needs reasoning | Move it to `impl` |
| Main thread fills fast | A large file was read directly | Route through `codex-scout` |
| Critic findings always trivial | HLD lacks specifics to attack | The HLD is too vague to implement either |
| Frequent `blocked` returns | Design decisions leaking into LLDs | Decide them in the HLD |

### Session hygiene

Watch for: the model revisiting approaches it already tried, or referencing
file states since edited. Both mean context rot — `/clear` and reload only what
the next task needs. The design store means you lose nothing by doing it.

---

## 17. Known limits

### Deliberate omissions

- **No parallel multi-task delegation by default.** Concurrency is capped at 3
  and `/delegate` handles one task. Parallel agents writing to one working tree
  produce diffs nobody can reason about.
- **No autonomous loops.** Every command stops at a gate.
- **No MCP route to Codex.** `codex mcp-server` is deprecated, and an MCP tool
  call returns its output into the calling context — reintroducing the exact
  problem this system solves.
- **No team features.** Single operator assumed.

### Bugs found in first use (fixed)

Recorded because the failure shapes generalize:

| Bug | Why it mattered |
|---|---|
| `.git/info/exclude` entries written unanchored | A bare `CLAUDE.md` matches at **any depth** in gitignore syntax, so it silently hid `apps/*/CLAUDE.md` — the per-package scoped instruction files. Now written as `/CLAUDE.md`, with migration for repos already affected. |
| Spec gate matched `codex-task` as a substring | `ls .design/runs/*codex-task*` was blocked. A gate that fires on unrelated commands trains you to work around it, which is worse than no gate. Now matches only at a command position. |
| `orchestra status` hard-coded four binary names | Reported a complete setup while omitting two binaries. Now derived from `bin/`. |
| `orchestra status` counted directories raw | Shared with your own commands and claude.ai-synced skills, so counts never matched. Now counts only what Orchestra owns, as `n/total`. |
| `config.toml` was symlinked into the dotfiles repo | **Codex writes to this file** — directory trust, TUI state. Symlinking meant the tool dirtied your dotfiles on every trusted directory, and reinstalling would clobber those writes. Now copied once and never overwritten; profiles stay symlinked since they are read-only. |

The pattern in three of the five: I assumed a file or string was owned solely
by this setup when it was actually shared — with git's pattern semantics, with
other tools writing to the same directories, with Codex writing to its own
config. Worth checking any future addition against that.

### Things that will break

- **Both CLIs ship fast.** Re-check Codex flags and Claude frontmatter fields
  every few months. Two things were already outdated in most published guides:
  profiles moved to separate files, and `codex mcp-server` was deprecated.
- **Hooks parse tool-call JSON.** A schema change in Claude Code will break
  them silently. The typecheck and ledger hooks degrade harmlessly; **the spec
  gate does not** — its failure mode is that delegation stops being gated.
  Re-run smoke test step 2 after any Claude Code upgrade.
- **`usage.json` extraction greps defensively** for Codex event fields. A
  format change shows `?` in the ledger rather than breaking a run.

### The alternative worth knowing

OpenAI ships an official Codex plugin for Claude Code
(`/plugin marketplace add openai/codex-plugin-cc`), giving `/codex:review` and
`/codex:rescue` with no setup. Worth having alongside for one-off reviews — but
it delegates by streaming, with no schema on the return and no spec discipline,
which is what makes long sessions expensive. Not the main loop.

---

## 18. Maintaining the setup itself

This is a system you now own. Guard against it becoming its own project.

- **It lives in your dotfiles repo**, symlinked. Changes are one edit, no
  reinstall.
- **Add a skill only when you've explained the same thing twice.** Not in
  anticipation. Seven planned skills is already ambitious; skill descriptions
  cost context in every session.
- **Delete what you don't use.** If `/review2` hasn't fired in a month, the
  agent is dead weight in every `/doctor` listing.
- **The ledger is the health check.** Run `/ledger` monthly. Rising
  tokens-per-file across projects means the LLD discipline is slipping.
- **Resist generalizing.** When a project needs something different, use a
  repo-level override rather than making the global config handle both cases.

The failure mode for a setup like this is that maintaining it becomes the work.
The gate: if a change to this tree doesn't make a *specific* recurring task
cheaper or safer, don't make it.

---

## 19. Appendix: file inventory

```
orchestra/
├── ARCHITECTURE.md              this document
├── README.md                    install + quick reference
├── install.sh                   idempotent symlink installer
│
├── bin/
│   ├── codex-task               the delegation wrapper — the choke point
│   ├── design-store             out-of-repo design docs
│   ├── agent-budget             cross-agent token ledger
│   ├── check-scope              diff-vs-spec scope enforcement
│   ├── orchestra                enable / disable / uninstall
│   └── orq-wall                 ambient workshop scene (decorative)
│
├── claude/                      → ~/.claude
│   ├── CLAUDE.md                orchestrator rules, classifier, escalation
│   ├── settings.json            env, permissions, hook registration
│   ├── agents/
│   │   ├── codex-scout.md           read-only code survey
│   │   ├── architecture-critic.md   adversarial HLD review
│   │   ├── spec-auditor.md          LLD gap analysis (sonnet)
│   │   ├── codex-implementer.md     delegation harness
│   │   ├── verifier.md              independent acceptance runs
│   │   └── codex-reviewer.md        second-opinion code review
│   ├── commands/
│   │   ├── scout.md  hld.md  lld.md  delegate.md
│   │   └── maintain.md  review2.md  ledger.md
│   └── hooks/
│       ├── require-spec.sh          PreToolUse — the spec gate
│       ├── post-edit-typecheck.sh   PostToolUse
│       └── log-delegation.sh        SubagentStop
│
├── codex/                       → ~/.codex
│   ├── config.toml              base
│   ├── impl.config.toml         high effort, workspace-write
│   ├── AGENTS.md                universal agent rules (all projects)
│   ├── cheap.config.toml        low effort, mechanical work
│   └── review.config.toml       high effort, read-only
│
├── skills/                      → ~/.claude/skills AND ~/.codex/skills
│   ├── design-docs/             + templates/{HLD,LLD,ADR}.md
│   ├── delegate-to-codex/
│   ├── test-suite/
│   ├── documentation/
│   ├── greenfield/
│   ├── nestjs-backend/
│   ├── frontend-web/
│   └── mobile-app/
│
└── templates/
    ├── AGENTS.project.md        per-repo stub: stack + vocabulary only
    ├── CLAUDE.project.md        per-repo stub (imports @AGENTS.md)
    ├── codex-report.schema.json the return contract
    └── agents-fragments/
        ├── rust-pinned-toolchain.md
        └── crypto-hard-rules.md
```

**48 files, ~3,500 lines.** Shell syntax, JSON validity, and skill frontmatter
validated.

---

## Decision log for this review

Points to confirm or reject before installing:

1. Design docs live outside work repos, in `~/design/`, symlinked — accepting
   that teammates can't read them.
2. `AGENTS.md` and `CLAUDE.md` also live in the store and are symlinked in.
   **Nothing** this setup produces is committed to a work repo.
3. Everything global except stack skills and specs.
4. Five Haiku subagents, one Sonnet, Opus orchestrator.
5. One retry per delegation, then escalate to you.
6. Cryptography categorically excluded from delegation.
7. Maintenance path has no HLD.
8. Test LLDs must label characterization vs behavioural per test.
9. Commands stop at gates rather than running through.
10. MCP servers scoped to subagents, never global — except possibly Context7.

---

## 20. Enabling and disabling

Everything is installed as symlinks, so turning the setup off means moving
links aside — nothing is deleted and re-enabling is instant. `bin/orchestra`
manages this at four granularities.

| Command | Effect | Use when |
|---|---|---|
| `orchestra status` | Reports global / hooks / this-repo state, missing binaries, whether `jq` is present | Always start here |
| `orchestra off hooks` | Rewrites `settings.json` without the `hooks` block, keeping env and permissions | A hook is misbehaving, or you want the agents without the gates |
| `orchestra off here` | Writes `.claude/settings.local.json` with empty hooks in the current repo | Someone else's codebase, a throwaway script, pairing with someone who has no Codex |
| `orchestra off` | Parks every agent, command, skill, `CLAUDE.md` and `settings.json` | Determining whether a problem is yours or the harness's |
| `orchestra on [hooks\|here]` | Reverses any of the above | — |
| `orchestra uninstall` | Removes all symlinks, restores timestamped backups | Leaving for good |

### How each level works

**`off hooks`** derives a hookless `settings.json` from whatever is currently
installed, so local edits to env or permissions survive. The full file is
parked, not regenerated. Note the warning it prints: **with hooks off, the spec
gate stops enforcing** — delegation no longer requires a spec file with an
acceptance section. That is the one protection you lose at this level.

**`off here`** relies on project settings taking precedence over user settings.
An empty `hooks: {}` in `.claude/settings.local.json` overrides the global
registrations for that repo only. The file is added to `.git/info/exclude`, so
it never appears in a commit.

**`off` (global)** moves the owned files into `~/.claude/.orchestra-disabled/`
and `~/.codex/.orchestra-disabled/`. It touches only files this setup owns —
listed explicitly in the script — so agents, skills, or commands installed by a
plugin or another tool in the same directories are left alone.

Codex profiles and `~/.local/bin` stay in place even when everything is off.
They are inert unless invoked, and leaving them means `design-store` and
`agent-budget` keep working.

**`uninstall`** confirms first, un-parks everything so nothing is orphaned,
removes each symlink by name, and restores the most recent `*.bak.*` that
`install.sh` created for any file it clobbered. It does **not** touch
`~/design`, the source tree, or the per-repo `AGENTS.md` / `CLAUDE.md` /
`.design` links — remove those by hand if you want them gone.

### What disabling does not affect

The design store, the source tree, and anything already written. Specs, HLDs,
and ADRs are plain markdown; they outlive the tooling that produced them, which
is the point of §2.2.


---

## 21. `orq-wall` — the ambient scene

Explicitly decorative. It answers one question at a glance — is anything
running anywhere, is anything stuck — and otherwise exists to be pleasant.

### Why it needs no instrumentation

`~/design/` is already the cross-project index: every project's runs land under
it. One scan of one directory sees every project on the machine. No agent
registry, no daemon, no IPC.

`codex-task` writes `meta.json` at run **start** (profile, spec, host, sandbox,
timestamp) and ticks a `heartbeat` file every 20 seconds. Without these a run
in progress is indistinguishable from a directory that was never populated —
`report.json` only appears when the run finishes.

### State derivation

| Files present | State |
|---|---|
| `meta.json`, no report, heartbeat < 2 min old | **working** |
| `meta.json`, no report, heartbeat stale | **stalled** — the process died |
| `report.json` status `completed` | **done** |
| `report.json` status `partial` / `blocked` | **blocked** |
| no runs | **idle** |

### What the scene shows

One workstation per project, wrapped to fit. A live delegation puts a figure at
the bench; the figure's colour encodes the Codex profile (blue `impl`, green
`cheap`, purple `review`), so a glance tells you which tier is burning tokens.
Blocked projects get a pulsing red lamp — the one signal worth being visually
loud, since it means something is waiting on you.

**The accumulated record** is the part that rewards looking weeks apart rather
than minutes: completed runs stack as finished pieces around each bench. A
project with forty shipped tasks looks materially different from one with four,
and Vaultiq's sparse corner next to Plankea's full one is real information
delivered without reading anything.

Lamps light after dark, from the system clock. Two themes: `forge` (workshop)
and `bay` (sci-fi hangar, with a starfield).

Clicking a station opens a panel: shipped count, files touched, spec/HLD/ADR
counts, last run time, and the current runs with their summaries and blockers.

### Cross-machine

The design store is a git repo, and `runs/` is gitignored because transcripts
are large. To span machines, ignore only the large files:

```gitignore
# ~/design/.gitignore — replace  */runs/  with:
*/runs/*/transcript.jsonl
*/runs/*/stderr.log
```

`meta.json`, `report.json`, `heartbeat`, and `usage.json` are a few hundred
bytes each and are all the wall reads. Push on one machine, pull on the other;
a cron pulling every minute suffices, since the wall polls its local copy.

Honest limitation: a powered-off machine leaves its last runs showing as
`stalled`. That is accurate — the wall cannot distinguish a dead process from a
dead laptop — but it looks more alarming than it is.

### Scope

Python 3 standard library, no dependencies, ~600 lines including the embedded
page. It reads files and serves a canvas. It does not write to the design
store, does not invoke agents, and does not need Orchestra to be enabled.

If it stops being fun, delete one file.
