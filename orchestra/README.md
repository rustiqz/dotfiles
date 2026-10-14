# Orchestra — Claude Code as architect, Codex as implementer

A two-agent setup where Claude Code owns design and coordination, Codex owns
implementation, and the handoff between them happens through files on disk
rather than through either agent's context window.

## The core idea

The naive version of this — Claude shells out to `codex exec` and reads the
output — makes things worse, not better. Codex streams its entire reasoning
transcript back, so a single delegation can put 30k tokens of noise into the
orchestrator's context, and you burn two usage limits to get one feature.

This setup inverts that with three moves:

1. **Every Codex call goes through a wrapper** (`codex-task`) that writes the
   transcript to disk and returns only a schema-constrained JSON report.
2. **That wrapper is only ever called from inside a subagent**, which has its
   own context window. Even the JSON report and the diff stat land there first;
   the main thread gets three sentences.
3. **The specification is a file, not a prompt.** Claude writes an LLD to
   `.design/lld/`, and passes Codex the *path*. Neither agent ever holds a copy of
   the other's context.

The design documents are the interface. That is the whole architecture.

```
   ┌─────────────────────────────────────────────────────┐
   │  Claude Code — main thread (Opus)                   │
   │  problem framing · HLD · LLD · decisions · review   │
   └───────┬───────────────────────────────────┬─────────┘
           │ writes                            │ delegates
           ▼                                   ▼
   ┌───────────────────┐          ┌──────────────────────────┐
   │  .design/hld/        │          │ subagent: codex-implementer │
   │  .design/lld/        │◀─ reads ─│ (haiku, isolated context)   │
   │  .design/adr/        │          └────────────┬─────────────┘
   │  AGENTS.md        │                       │ codex-task --spec
   └───────────────────┘                       ▼
           ▲                        ┌──────────────────────┐
           │                        │  Codex CLI           │
           │                        │  --profile impl      │
           │                        │  --output-schema     │
           │                        └──────────┬───────────┘
           │                                   │
           │  ~40 lines of JSON      ┌──────────▼───────────┐
           └─────────────────────────│ .design/runs/<id>/    │
                                     │ transcript.jsonl     │  ← never read
                                     │ report.json          │  ← this only
                                     └──────────────────────┘
```

## What each piece does

### The wrapper — `bin/codex-task`

The single choke point. `settings.json` explicitly denies bare `Bash(codex exec:*)`
so this cannot be bypassed.

It runs `codex exec` with four flags that do the actual work:

| Flag | Why |
|---|---|
| `--output-schema` | Forces Codex's final message into a fixed JSON shape with length caps on every field. This is the mechanism — a model told "be brief" is not brief; a model handed a schema with `maxLength: 600` is. |
| `--output-last-message` | Writes that JSON to a file rather than mixing it into the event stream. |
| `--json` | Sends the full event stream to `transcript.jsonl` on disk, where it is available for human debugging and invisible to both models. |
| `--profile` | Selects `impl`, `cheap`, or `review` — see below. |

It also derives the changed-file list from `git status` rather than from Codex's
self-report, because models are unreliable narrators about what they edited.

### The subagents — `claude/agents/`

Subagents are where the context savings come from. Each runs in its own window
and returns only a summary.

| Agent | Model | Job |
|---|---|---|
| `codex-implementer` | haiku | Runs `codex-task`, reads the JSON, returns three sentences. Absorbs the delegation noise. One retry, then escalates. |
| `codex-reviewer` | haiku | Independent second-opinion review. Read-only sandbox — it reports findings, it cannot apply them. |
| `verifier` | haiku | Runs typecheck/lint/test. Returns `PASS` or ≤10 `file:line — message` lines. Never a stack trace. |
| `spec-auditor` | sonnet | Reads a draft LLD as a context-free implementer would and lists what it would have to guess at. `memory: project` so it learns your recurring gaps. |

Three of the four run on Haiku because they are mechanical. `spec-auditor`
needs real judgement, so it gets Sonnet. The orchestrator stays on Opus.

`codex-implementer` sets `experimental.cacheTtl: 1h` — delegations come in
bursts, and an hour-long prompt cache across a batch is meaningful.

### The skills — `skills/`

One tree, symlinked into both `~/.claude/skills` and `~/.codex/skills`. Both
tools read the same `SKILL.md` format, so there is no second copy to keep in sync.

- `design-docs` — HLD/LLD/ADR authoring, with templates
- `delegate-to-codex` — the routing table and the retry policy
- `nestjs-backend` — transaction boundaries, TypeORM migration patterns,
  BullMQ vs Temporal, the after-commit rule
- `frontend-web` — state boundaries, the four fetch states, API contracts
- `mobile-app` — offline behaviour, process death, navigation as state

The domain skills are written as *things an LLD must decide*, not as tutorials.
Their job is to stop a spec shipping with the transaction boundary unstated.

### The hooks — `claude/hooks/`

Hooks are deterministic where prompts are probabilistic.

- `require-spec.sh` (PreToolUse) — blocks a `codex-task` call whose `--spec`
  file is missing, or which has no `## Acceptance` section. A spec with no
  acceptance commands can never be proven done, so the delegation is refused
  before it costs anything.
- `post-edit-typecheck.sh` (PostToolUse) — typechecks after Claude edits a
  `.ts` file. Two lines of context now instead of a debugging session later.
- `log-delegation.sh` (SubagentStop) — appends token usage to a ledger.

### The Codex profiles — `codex/`

Profiles in current Codex are **separate files** next to `config.toml`, selected
with `--profile <name>`, not `[profiles.x]` blocks inside it.

| Profile | Model | Effort | Sandbox | For |
|---|---|---|---|---|
| `impl` | gpt-5.6 | high | workspace-write | Normal feature work from a complete LLD |
| `cheap` | gpt-5.6-terra | low | workspace-write | Renames, DTOs, fixtures, codemods — work where the LLD removed all the thinking |
| `review` | gpt-5.6 | high | **read-only** | Second-opinion review. Cannot patch what it finds, by construction. |

## Token management, concretely

Nine mechanisms, roughly in order of impact:

1. **Subagent isolation.** The delegation transcript never enters the main
   thread. This is most of the saving.
2. **Schema-constrained returns.** `--output-schema` with `maxLength` caps on
   every field, rather than asking for brevity.
3. **Path-passing, not context-passing.** The LLD is read from disk by whoever
   needs it. It is never duplicated into a prompt.
4. **Model tiering.** Haiku for mechanical subagents, Sonnet for auditing,
   Opus only in the orchestrator. `CLAUDE_CODE_SUBAGENT_MODEL=haiku` catches
   any unlabelled helper.
5. **Deterministic verification via hooks.** Neither model spends tokens
   discovering breakage a script can report in two lines.
6. **Fresh `exec` by default, `resume` only for fix-ups.** A new session starts
   small; resuming carries the whole prior context forward. The retry path uses
   `resume`; new tasks do not.
7. **One-retry policy.** Two agents ping-ponging on a failing test is the single
   fastest way to exhaust both limits. After one retry it comes back to you.
8. **Prompt cache reuse.** `cacheTtl: 1h` on the implementer; `/subtask` forks
   instead of fresh subagents when the side task needs conversation history.
9. **`agent-budget`** reports tokens-per-changed-file per run. A high ratio
   means the implementer spent its budget exploring rather than writing, which
   traces back to a thin spec almost every time. It is the metric that tells you
   your LLDs need work.

Also worth setting: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: 75`, so compaction lands
at a task boundary rather than mid-delegation.

## The workflow

```
/hld invoice voucher reconciliation     → .design/hld/invoice-vouchers.md
                                          (ends at the task breakdown; you approve)

/lld TASK-014                           → .design/lld/TASK-014-voucher-apply.md
                                          (spec-auditor runs; you fix gaps)

/delegate .design/lld/TASK-014-*.md        → codex-implementer → verifier → report

/review2 transaction boundaries         → your review vs Codex's, in three buckets

/ledger                                 → what it cost
```

The gates are deliberate. `/hld` stops at the breakdown, `/lld` stops at the
audit verdict, `/delegate` stops after one task. Each stop is a place where a
bad direction costs one document instead of a day.

## Install

```bash
git clone <this> ~/dotfiles/orchestra   # or wherever your Stow tree lives
cd ~/dotfiles/orchestra
./install.sh
```

It symlinks rather than copies, so edits here take effect immediately. Existing
files are backed up with a timestamp, and re-running is safe.

Then, per repository:

```bash
cp templates/AGENTS.md ./AGENTS.md
cp templates/CLAUDE.project.md ./CLAUDE.md
mkdir -p .design/hld .design/lld .design/adr
echo '.agent/' >> .gitignore
```

Fill in the **domain vocabulary** table in the project `CLAUDE.md`. An agent
that does not know what your nouns mean writes code like a contractor on day
one, and that section fixes more output-quality problems than anything else here.

The project `CLAUDE.md` imports `AGENTS.md` with `@AGENTS.md`, so both agents
read one copy of the rules.

Verify:

```bash
claude /doctor     # lists the new agents, skills, commands
codex doctor       # shows profiles and skills
agent-budget       # empty, but should run
```

## Prerequisites

`claude`, `codex`, `jq`, `git`. The hooks need `jq` to parse tool input; without
it they exit silently and you lose the spec gate.

## The alternative worth knowing about

OpenAI ships an official Codex plugin for Claude Code:

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/codex:setup
```

It gives you `/codex:review` and `/codex:rescue` with no setup. Worth installing
alongside this — but note it delegates by streaming, with no schema on the
return and no spec-file discipline, so it is the thing that makes long sessions
expensive. Use it for one-off reviews; use this for the main loop.

Note also that `codex mcp-server` is deprecated. Wiring Codex into Claude Code
as an MCP server is the old path; the wrapper or the plugin are the current ones.

## Things to tune after a week

- If `spec-auditor` keeps flagging the same gap, add it to the LLD template.
- If `agent-budget` shows high tokens-per-file, your LLDs are too thin — the
  fix is upstream in `design-docs`, not in the delegation.
- If `cheap` produces work you keep rejecting, move that task class to `impl`.
- If the main thread still fills up fast, check `/context`: usually a large
  file got read directly instead of through `Explore`.

---

## Where design docs live

They are **not** in your work repos. `bin/design-store` keeps them in one
central, independently-versioned store and links it in:

```
~/design/                              <- its own git repo, yours alone
  plankea-helpdesk-hub-node/
    hld/  lld/  adr/  runs/
  plankea-task-hub-workers-node/
    hld/  lld/  adr/  runs/

<work repo>/.design -> ~/design/<repo>    (one symlink, locally ignored)
```

```bash
cd ~/code/plankea-helpdesk-hub-node
design-store link      # creates the store dir, symlinks .design, ignores it
design-store status    # what's linked, doc counts per project
```

The symlink is added to `.git/info/exclude`, not `.gitignore` — so it is
ignored on your machine and never appears in a diff anyone reviews.

The agents always see the stable relative path `.design/lld/TASK-014-*.md`, so
no tooling needs to know where the store actually is. Move the store, relink,
nothing else changes.

**What this costs you.** Design docs lose their git-level link to the commit
that implemented them, and teammates can't read them. If a spec later becomes
something the team should own, promote that one file into the repo — but the
drafts, the abandoned alternatives, and the delegation runs stay out.

**Two files do stay in the repo:** `AGENTS.md` and `CLAUDE.md`. They're small,
they make every agent on the team behave consistently, and `CLAUDE.md` imports
`@AGENTS.md` so the rules exist exactly once. That is worth the clutter.

## Scope: what is global, what is per-repo

| Layer | Location | Scope |
|---|---|---|
| Orchestrator rules | `~/.claude/CLAUDE.md` | every repo |
| Settings, env, hooks | `~/.claude/settings.json` | every repo |
| Subagents | `~/.claude/agents/` | every repo |
| Slash commands | `~/.claude/commands/` | every repo |
| Stack skills | `~/.claude/skills/` + `~/.codex/skills/` | every repo |
| Codex profiles | `~/.codex/*.config.toml` | every repo |
| `codex-task`, `agent-budget`, `design-store` | `~/.local/bin/` | every repo |
| **Repo rules and vocabulary** | `<repo>/CLAUDE.md` + `AGENTS.md` | that repo |
| **Repo-specific skills** | `<repo>/.claude/skills/` | that repo |
| **Design docs** | `~/design/<repo>/` via `.design` | that repo |

Precedence runs project over user, so a repo-level skill or agent with the same
`name` overrides the global one. That is the escape hatch: when one codebase
needs a different convention, drop a `.claude/skills/nestjs-backend/SKILL.md`
in it and the global version stops applying there.

Everything in this tree is installed globally by design — the whole point is
that you don't re-scaffold per repo. What is genuinely per-repo is only the
vocabulary and the specs.

## Skills: what's here, what to add next

**Installed now** (5, shared by both agents):

| Skill | Covers |
|---|---|
| `design-docs` | HLD/LLD/ADR authoring + templates |
| `delegate-to-codex` | Routing table, profile selection, retry policy |
| `nestjs-backend` | Module shape, transaction boundaries, TypeORM, BullMQ vs Temporal |
| `frontend-web` | State boundaries, the four fetch states, API contracts, a11y |
| `mobile-app` | Offline/sync, process death, navigation, release constraints |

**Worth adding, roughly in order of payback for this stack:**

1. `multi-tenancy` — tenant scoping as an invariant: which queries must filter
   by org, where the guard lives, what a cross-tenant leak looks like in review.
   For a multi-tenant B2B platform this is the highest-value skill you don't
   have, because the failure mode is silent.
2. `typeorm-migrations` — split out of `nestjs-backend` once it grows: the
   three-step non-nullable column, partial unique indexes with soft deletes,
   backfills under load, rollback plans.
3. `testing-strategy` — what gets a unit test vs an integration test vs e2e,
   fixture and factory conventions, what the `Acceptance` section should
   specify. Pairs directly with the `verifier` subagent.
4. `temporal-workflows` — determinism rules, activity boundaries, versioning a
   running workflow, what belongs here vs in BullMQ.
5. `debugging` — a root-cause procedure: reproduce, bisect, form a hypothesis,
   prove it. Stops the "add logging everywhere" pattern that burns context.
6. `api-conventions` — pagination, filtering, error envelope, versioning.
   Mostly value as a thing `spec-auditor` can check LLDs against.
7. `code-review` — your review checklist, so `/review2` compares against
   something explicit rather than whatever Claude thinks of that day.

Keep each under ~150 lines. Skill descriptions cost context in every session
and Claude Code warns past a combined 15k tokens, so write the description for
routing and put the substance in the body.

Write them the way the existing ones are written: as **decisions an LLD must
make**, not as tutorials. The job is to stop a spec shipping with the
transaction boundary unstated, not to teach the model NestJS.

## MCP servers

The important thing first: **an MCP server's tool descriptions load into every
session's context whether you use it or not.** Three servers in `.mcp.json` can
cost several thousand tokens before you type anything, which works directly
against everything else here.

So scope them to the subagent that needs them, using `mcpServers` in the agent's
frontmatter. The subagent gets the tools; the main conversation never pays:

```yaml
---
name: schema-inspector
description: Answers questions about the live database schema - tables, columns, indexes, constraints. Use when writing a migration or an LLD's data section.
tools: Read, Grep
model: haiku
mcpServers:
  - postgres:
      type: stdio
      command: npx
      args: ["-y", "<postgres-mcp-package>", "postgresql://readonly@localhost:5432/plankea_dev"]
---
Answer schema questions from the live database. Return only the columns,
types, and constraints asked about — never a full schema dump.
```

Worth having, for this stack:

| Server | Why | Where |
|---|---|---|
| **Postgres (read-only role)** | Claude reads the actual schema instead of inferring it from entity files. Removes a whole class of migration errors. | Scoped to a `schema-inspector` subagent |
| **Context7** | Version-specific library docs. NestJS and TypeORM churn enough that trained knowledge goes stale. | Global is defensible — it's small and broadly useful |
| **Sentry** | Pulls the real stack trace and frequency into a debugging session. | Scoped to a debugging subagent |
| **GitHub** | PR and issue context. Scope the token tightly — read-only to start. | Global if you live in PRs, otherwise scoped |
| **Playwright** | Frontend e2e verification. **Token-heavy** — a page snapshot can be tens of thousands of tokens. | Always scope to a subagent, never global |

Cautions that matter:

- Use a **dedicated read-only Postgres role** against a dev database. Never
  production credentials, never a role that can write.
- Prefer **vendor-maintained** servers. The original `@modelcontextprotocol/*`
  database servers were archived in favour of vendor versions, and a
  significant share of popular community servers have had security findings
  filed against them. Pin versions.
- MCP output is untrusted input. A row in a database or a GitHub issue body can
  contain instructions aimed at the agent. Scoping to a subagent limits the
  blast radius, since the subagent's report is scanned before it reaches the
  main thread.

Not worth it here: filesystem MCP (Claude Code already has file tools), and
memory MCP (CLAUDE.md, the design store, and `spec-auditor`'s `memory: project`
already cover it).
