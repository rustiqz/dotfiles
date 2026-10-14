# agent-hooks — local plugin marketplace (stowed to ~/.local/share/agent-hooks)

One plugin, `devstat-hooks`, whose only job is to tell `devstat`
(`bin/bin/devstat`) what each agent session is doing: working, waiting on a
permission prompt, or done. That state drives the dev island/hub and the
"agent needs input" / "agent finished" notifications.

## Why a plugin and not hooks in settings.json

`~/.claude/settings.json` is owned by the orchestra setup — it installs that
file as a symlink and parks it when switched off. Hooks written into it
would vanish on every toggle, or this repo would be editing a file another
tool manages. Plugin hooks merge *alongside* settings.json hooks instead.

**The plugin still needs two keys in whichever settings.json is active:**
`extraKnownMarketplaces.dotfiles-local` and
`enabledPlugins["devstat-hooks@dotfiles-local"]`. The docs say a plugin
with no `enabledPlugins` entry starts enabled (`defaultEnabled`), but that
did not hold for an *installed* plugin: with settings.json moved aside,
`claude plugin list` reported it `✘ disabled` (tested 2026-10-14, CLI
2.1.299). `hooks/63-agent-hooks.sh` checks for both keys and says which
file is missing them.

A marketplace added from a local path is loaded in place, so edits here
take effect without reinstalling. `hooks/63-agent-hooks.sh` registers it.

## Handler rules

- `async: true` on every handler **except UserPromptSubmit and Stop** — a
  status display must never slow a turn, but these two are where ordering
  and completion matter, and each costs ~80ms once per turn:
  - UserPromptSubmit: defensive ordering. Async handlers launched
    milliseconds apart can finish in any order; synchronous, "working" is
    on disk before the model even starts, so later events always see it.
  - Stop: async handlers still starting up when a session exits are
    killed. In a real headless run, Stop and SessionEnd launched together
    and only SessionEnd's code ever ran (traced with DEVSTAT_DEBUG=1), so
    the finished turn was never recorded. Synchronous, it always completes.
  Async-handler loss is harmless elsewhere: a missed SessionEnd leaves a
  state file whose pid is dead, which `devstat agents` deletes on sight.
- Shell form with `"$HOME/bin/devstat"` — expands per machine, so no
  username is baked into this tracked file (the qt5ct lesson in CLAUDE.md).
- `devstat agent-event` prints nothing and always exits 0: on SessionStart
  and UserPromptSubmit printed text becomes model context, and printed JSON
  is parsed as a hook decision.

## Install

`hooks/63-agent-hooks.sh` does this idempotently; by hand it is:

    claude plugin marketplace add ~/.local/share/agent-hooks
    /plugin install devstat-hooks --marketplace ~/.local/share/agent-hooks
