# HLD: Orchestra TUI (`orq`)

> Status: draft — for review before any code
> Owner: Rusteezz   Last updated: 2026-09-23
> Note: written with the `design-docs` skill, as a first real test of the templates.

## Problem

The Orchestra setup produces a substantial artifact layer — specs at several
stages of completion, delegation runs with reports and transcripts, a token
ledger across two agents, and a design store spanning multiple projects. All of
it is invisible unless you run shell commands, and the questions you actually
ask are cross-cutting:

- Which specs are written but not yet delegated?
- What did the last five delegations cost, and is the ratio getting worse?
- Why did TASK-014 come back `partial`?
- What's the state of Vaultiq's design store versus Monitra's?

Today these are answered by `ls`, `jq`, `cat`, and `agent-budget` — or worse, by
asking Claude, which pulls the answer into the context window you are trying to
protect.

## Constraints

| Constraint | Type |
|---|---|
| Must not require a daemon, server, or background process | **hard** |
| Must not duplicate state — the filesystem stays the source of truth | **hard** |
| Must not attempt to drive or wrap Claude Code | **hard** |
| Single binary, no runtime dependency | **hard** |
| Must work when Orchestra is disabled (`orchestra off`) | **hard** |
| Rust + Ratatui + Crossterm, matching Monitra's stack | soft (chosen) |
| Pinned toolchain, as Monitra does | soft (chosen) |

## Non-goals

Stated first, because this is the section that decides whether the project stays
finishable:

- **Not a chat interface.** No conversation, no agent invocation with prompts,
  no Claude Code integration of any kind.
- **Not a spec editor.** It opens `$EDITOR`; it does not implement editing.
- **Not a design tool.** It never decides what a spec should say.
- **Not a dashboard for someone else.** Single operator, local filesystem.
- **No write path to the design store beyond status stamping.** See §Data model.
- **No git operations.** It reads `git status` output the wrapper already
  captured; it does not stage, commit, or branch.

## Context map

| Component | Relationship | Changes needed |
|---|---|---|
| `~/design/<project>/` | Primary data source — read | none |
| `.design/runs/<id>/` | Run reports, usage, diffstat — read | none |
| `bin/codex-task` | Launched for re-runs | stamp `status:` into spec frontmatter |
| `bin/agent-budget` | Logic reimplemented in-process | none (keep the CLI too) |
| `~/.local/share/orchestra/ledger.tsv` | Read for history | none |
| `templates/LLD.md` | Gains a `status:` frontmatter field | add the field |

## Design

### The central idea: derived state, not stored state

There is no database and no state file. Everything the TUI shows is computed
from files that already exist. This is the decision the rest of the design
hangs off, and it exists because a second source of truth would rot the moment
you edit a spec outside the TUI — which you will, constantly, in Neovim.

A spec's stage is derived as follows:

```
spec file exists in .design/lld/              → DRAFT
  + frontmatter `audited: true`               → READY
  + a run directory references it             → RUNNING (no report yet)
  + report.json status = completed            → BUILT
  + report.json status = partial | blocked    → NEEDS ATTENTION
  + frontmatter `status: done`                → DONE
```

Only the last is stamped by tooling; everything else is inferred from files the
system already writes. Run directories are named `<timestamp>-<spec-basename>`,
so the spec↔run link already exists without a schema.

### Panes

Five views, switched by number key. Each answers one of the questions above.

```
┌─ orq ──────────────────────────────────────────────────────────┐
│ 1 Projects  2 Board  3 Runs  4 Budget  5 Store       ? help    │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│                         (active pane)                          │
│                                                                │
├────────────────────────────────────────────────────────────────┤
│ plankea-helpdesk-hub-node · 14 specs · 3 need attention         │
└────────────────────────────────────────────────────────────────┘
```

**1 — Projects.** Every directory in `~/design/`. Per project: spec counts by
stage, last activity, whether the repo is currently linked. Selecting one scopes
every other pane to it.

**2 — Board.** Specs as columns by derived stage: DRAFT / READY / RUNNING /
BUILT / NEEDS ATTENTION / DONE. This is the view that answers "what's in
flight". Enter opens the spec in `$EDITOR`.

**3 — Runs.** Delegation history, newest first: status, profile, tokens in/out,
files changed, duration. Enter drills into the report. `t` opens the transcript
in a pager.

**The transcript viewer is the single highest-value feature.** Today, reading a
transcript means either `less`-ing a 3,000-line JSONL file or asking Claude —
which pollutes the context the whole system exists to protect. A pane that
renders the event stream as a readable timeline gives you the debugging path
without the token cost.

**4 — Budget.** The ledger, plus the metric that matters: tokens per changed
file, trended over time. A rising line means specs are getting thinner. This is
the only feedback loop in Orchestra that improves upstream design, and it
currently requires reading a table by eye.

**5 — Store.** Raw design-store browser — HLDs, LLDs, ADRs across all projects,
with search. For when you know you wrote something down and not where.

### Actions

Deliberately few. Every one is safe to press by accident.

| Key | Action | Why it's safe |
|---|---|---|
| `Enter` | Open in `$EDITOR` | Read/edit, you're in control |
| `t` | View transcript | Read-only |
| `r` | Re-run a delegation | Prompts for confirmation; runs the existing spec unchanged |
| `d` | Mark done | Stamps `status: done` in frontmatter |
| `y` | Copy slash command to clipboard | You paste it into Claude Code yourself |

`y` is how the TUI and Claude Code interoperate: no IPC, no wrapping. The TUI
tells you what to run; you run it. That boundary is what keeps this from
becoming a fragile integration.

### Module boundaries

```
src/
  main.rs         arg parsing, terminal setup/teardown
  app.rs          App state, the event loop, pane dispatch
  model/
    project.rs    a design-store project
    spec.rs       LLD parsing (frontmatter + sections), stage derivation
    run.rs        run directory: report.json, usage.json, diffstat
    ledger.rs     ledger.tsv parsing, ratio computation
  source.rs       the FILESYSTEM SEAM - a trait, so the model layer
                  never touches std::fs directly
  ui/
    projects.rs  board.rs  runs.rs  budget.rs  store.rs
    transcript.rs   JSONL event stream -> readable timeline
  action.rs       the five actions, each behind a confirmation where it writes
```

`source.rs` is the seam that matters. A `Source` trait with a filesystem
implementation means the whole model layer is testable against fixtures with no
temp directories — the same reasoning as Monitra's `ResultSink`.

### Control flow

Cold start: scan `~/design/` (tens of files, milliseconds) → build the model →
render. `R` rescans. No watching, no inotify. A manual refresh is correct here:
the data changes when *you* do something, and a file watcher is a background
concern this explicitly does not want.

### Failure paths

| Condition | Behaviour |
|---|---|
| `~/design/` missing | Empty state with the `design-store init` command shown |
| Malformed frontmatter | Spec shows as DRAFT with a parse warning; never panics |
| `report.json` absent or truncated | Run shows RUNNING or UNKNOWN, transcript still openable |
| Ledger missing | Budget pane shows the runs it can find, notes the ledger is absent |
| Orchestra disabled | Works normally — it reads files, not config |

The rule: a malformed file degrades one row. It never takes down the view.

## Alternatives considered

| Option | Why not |
|---|---|
| Shell scripts + `fzf` | Would cover the Store pane in an afternoon, nothing else. No trend view, no transcript rendering. Worth doing first as a probe. |
| A web dashboard | Needs a server, breaks the no-daemon constraint, and leaves the terminal. |
| A Claude Code plugin | Runs *inside* the context window — exactly backwards. |
| Extend `agent-budget` with more subcommands | Real option. Cheaper. Gets the budget trend but never the board or transcript viewer. |
| Neovim plugin | Fits the workflow, but ties it to one editor and means Lua rather than Rust practice. |

## Risks

| Risk | Mitigation |
|---|---|
| **This becomes the project instead of Vaultiq and Monitra** | Hard scope cap: v0 is panes 3 and 4 only. If that isn't genuinely useful within a week of use, stop. |
| Stage derivation rules drift from what the tooling writes | Derivation lives in one module with fixture tests; `codex-task` gains exactly one write (`status:`) and no more |
| Ratatui learning curve competes with Monitra's TUI | This is the argument *for* building it — same stack, lower stakes, and what you learn transfers directly to Monitra's unfinished TUI |
| Feature creep into agent invocation | The `y`-copies-to-clipboard boundary is in the non-goals for exactly this reason |

## Task breakdown

Ordered so the riskiest thing is proven first. Panes 3 and 4 are v0 because they
deliver the transcript viewer and the ratio trend — the two things with no
current workaround.

| Task | Scope | Depends on | Complexity |
|---|---|---|---|
| TUI-001 | Cargo scaffold, pinned toolchain, terminal setup/teardown, empty frame | — | mechanical |
| TUI-002 | `Source` trait + filesystem impl + fixtures | TUI-001 | normal |
| TUI-003 | `model/run.rs` — parse run dirs, reports, usage | TUI-002 | normal |
| TUI-004 | **Runs pane** — list, drill into report | TUI-003 | normal |
| TUI-005 | **Transcript viewer** — JSONL → timeline, paged | TUI-003 | normal |
| TUI-006 | `model/ledger.rs` + ratio computation | TUI-002 | normal |
| TUI-007 | **Budget pane** with trend | TUI-006 | normal |
| — | **v0 ends here. Use it for a week before continuing.** | | |
| TUI-008 | `model/spec.rs` — frontmatter, stage derivation | TUI-002 | normal |
| TUI-009 | Board pane | TUI-008 | normal |
| TUI-010 | Projects pane | TUI-008 | mechanical |
| TUI-011 | Store pane + search | TUI-008 | normal |
| TUI-012 | Actions: editor, re-run, mark done, clipboard | TUI-009 | normal |

## Open questions

1. Does `codex-task` stamp `status:` into the spec, or does the TUI own that
   write? Stamping in the wrapper keeps the CLI and TUI consistent, but means
   the wrapper edits files in the design store — currently it only appends to
   `runs/`. **Leaning: the TUI owns it**, since it's the only thing that knows
   you consider a task finished.
2. Is the Store pane worth building at all, or does `rg` + `fzf` already cover
   it? Defer until after v0.
3. Should `r` (re-run) exist, given `/delegate` in Claude Code does the same
   thing with better context? Possibly `y` alone is enough.
