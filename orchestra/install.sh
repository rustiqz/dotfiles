#!/usr/bin/env bash
# install.sh — wires this tree into ~/.claude, ~/.codex, and ~/.local/bin.
#
# Idempotent: safe to re-run after editing anything here. Uses symlinks, so
# edits in this repo take effect immediately with no reinstall step.
#
# Designed to sit inside a GNU Stow dotfiles repo. If you prefer Stow to own
# the linking, run with --stow-layout instead: it arranges the files under
# stow/ package directories and leaves the linking to `stow`.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Self-heal executable bits. Some transfer paths (zip on certain filesystems,
# cloud storage, Windows) strip the exec bit; this makes `bash install.sh` work
# regardless of how the archive reached you.
chmod +x "$SRC"/bin/* "$SRC"/claude/hooks/*.sh "$SRC/install.sh" 2>/dev/null || true
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CFG_DIR="$HOME/.config/orchestra"

log()  { printf '  %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

# link <source> <destination> — symlink, backing up anything real that is there.
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.bak.$(date +%s)"
    log "backed up existing $dst"
  fi
  ln -s "$src" "$dst"
  log "linked $(basename "$dst")"
}

step "Checking prerequisites"
for cmd in claude codex jq git; do
  if command -v "$cmd" >/dev/null 2>&1; then
    log "$cmd: $(command -v "$cmd")"
  else
    log "MISSING: $cmd"
    [[ "$cmd" == "jq" ]] && log "  -> hooks need jq to parse tool input; install it first"
  fi
done

step "Installing Claude Code configuration -> $CLAUDE_HOME"
# CLAUDE.md and settings.json are linked, not copied, so this repo stays the
# single source of truth and `git diff` shows drift.
link "$SRC/claude/CLAUDE.md"     "$CLAUDE_HOME/CLAUDE.md"
link "$SRC/claude/settings.json" "$CLAUDE_HOME/settings.json"

# Subagents, commands, and hooks are linked per-file rather than by directory,
# so a plugin or another tool can add its own files alongside these without
# being clobbered on the next install.
for f in "$SRC"/claude/agents/*.md;    do link "$f" "$CLAUDE_HOME/agents/$(basename "$f")";   done
for f in "$SRC"/claude/commands/*.md;  do link "$f" "$CLAUDE_HOME/commands/$(basename "$f")"; done
for f in "$SRC"/claude/hooks/*.sh;     do chmod +x "$f"; link "$f" "$CLAUDE_HOME/hooks/$(basename "$f")"; done

step "Installing shared skills"
# One skills tree, two consumers. Both Claude Code and Codex read the Agent
# Skills SKILL.md format, so the same directory serves both and there is no
# copy to keep in sync.
for d in "$SRC"/skills/*/; do
  name="$(basename "$d")"
  link "$d" "$CLAUDE_HOME/skills/$name"
  link "$d" "$CODEX_HOME/skills/$name"
done

step "Installing Codex configuration -> $CODEX_HOME"
# Codex profiles are separate files alongside config.toml, selected with
# --profile <name>, which layers <name>.config.toml on top of the base.
# Profiles are read-only from Codex's point of view, so they are symlinked and
# stay in sync with this tree.
for f in "$SRC"/codex/{impl,cheap,review}.config.toml; do
  [[ -f "$f" ]] && link "$f" "$CODEX_HOME/$(basename "$f")"
done

# config.toml is DIFFERENT: Codex writes to it - directory trust decisions, TUI
# state, and anything you set with `codex config`. Symlinking it would make the
# tool dirty your dotfiles repo on every trusted directory, and an install.sh
# rerun would clobber those settings. So it is COPIED, once, and never
# overwritten. Your local edits and Codex's own writes both survive upgrades.
if [[ -f "$CODEX_HOME/config.toml" ]]; then
  log "config.toml exists - left alone (Codex writes to it; not managed here)"
  if ! diff -q <(sed 's/#.*//' "$SRC/codex/config.toml") \
                <(sed 's/#.*//' "$CODEX_HOME/config.toml") >/dev/null 2>&1; then
    log "  it differs from the shipped default: $SRC/codex/config.toml"
  fi
else
  mkdir -p "$CODEX_HOME"
  cp "$SRC/codex/config.toml" "$CODEX_HOME/config.toml"
  log "copied config.toml (not symlinked - Codex writes to this file)"
fi

# The universal agent rules. Codex aggregates AGENTS.md hierarchically, so this
# is read for every project and a repo's own AGENTS.md layers on top rather
# than replacing it. Writing the shared rules once here is why a per-repo
# AGENTS.md can be a dozen lines instead of eighty.
link "$SRC/codex/AGENTS.md" "$CODEX_HOME/AGENTS.md"

step "Installing executables -> $BIN_DIR"
for f in "$SRC"/bin/*; do chmod +x "$f"; link "$f" "$BIN_DIR/$(basename "$f")"; done
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) log "WARNING: $BIN_DIR is not on PATH — add it to your zshrc" ;;
esac

step "Installing shared assets"
link "$SRC/templates/codex-report.schema.json" "$CFG_DIR/codex-report.schema.json"

step "Done"
cat <<'EOF'

Next, per repository - ONE command:

  cd <your repo>
  design-store link

What it does depends on whether the repo already tracks agent rules:

  * AGENTS.md / CLAUDE.md NOT in git  -> seeds them in ~/design/<repo>/agents/,
    symlinks all three in, and anchors them in .git/info/exclude. Nothing is
    committed.

  * AGENTS.md / CLAUDE.md ARE tracked -> leaves them alone. A tracked file is
    one the team owns; symlinking over it shows as a type-change in git and
    would break every other clone. Only .design is linked.
    Force the symlink anyway with --no-agents if you really want it.

Then fill in the domain vocabulary table in whichever AGENTS.md applies. That
table does more for output quality than everything else in this install.

To share store-held rules with a team later:  git add -f AGENTS.md

Verify the wiring:
  orchestra status        # what is on, off, and missing - start here
  claude /doctor          # should list the new agents, skills, and commands
  codex doctor            # should show the profiles and skills

Optional, decorative:
  orq-wall                # ambient workshop scene at http://localhost:7717
  orq-wall --theme bay    # sci-fi hangar instead of a forge
  orq-wall --sync-note    # how to make it span machines

Turning it off (nothing is ever deleted):
  orchestra off hooks     # hooks only; agents and skills keep working
  orchestra off here      # this repo only
  orchestra off           # everything global
  orchestra on [...]      # reverse any of the above
  orchestra uninstall     # remove symlinks, restore backups
EOF
