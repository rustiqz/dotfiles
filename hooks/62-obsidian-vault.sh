#!/usr/bin/env bash
#
# Create ~/vault, the Obsidian vault, as its own git repo — separate
# from this dotfiles repo on purpose, synced (once the obsidian-git
# community plugin is installed, see the printed note below) to
# whatever remote the user points it at, the same *.local escape-hatch
# pattern as git identity (hooks/50-git-identity.sh) and ssh config:
# if ~/.config/git/obsidian-vault.local holds a URL, clone from it;
# otherwise just git-init a fresh local vault and leave adding a
# remote to the user, since there's nothing to clone yet.
#
# Must run before hooks/73-theme.sh: that hook (and bin/bin/theme
# itself) only symlinks the Obsidian CSS snippet once ~/vault already
# exists, so vault creation has to happen first. Filename order
# (62 < 73) guarantees that.
#
# Idempotent: entirely skipped if ~/vault already exists, exactly like
# hooks/71-wallpaper.sh not resetting a later choice back to default —
# this only ever sets the *initial* state.

set -euo pipefail

VAULT="$HOME/vault"
REMOTE_FILE="$HOME/.config/git/obsidian-vault.local"

if [[ -d $VAULT ]]; then
  echo "$VAULT already exists, leaving it."
  exit 0
fi

if [[ -f $REMOTE_FILE ]]; then
  REMOTE_URL=$(<"$REMOTE_FILE")
  echo "Cloning Obsidian vault from $REMOTE_URL"
  git clone "$REMOTE_URL" "$VAULT"
else
  echo "No $REMOTE_FILE found — creating a fresh local vault at $VAULT"
  mkdir -p "$VAULT"
  git -C "$VAULT" init -q
  echo "  (add a remote later with: git -C $VAULT remote add origin <url>," \
       "or write the URL into $REMOTE_FILE and re-run bootstrap.sh to clone instead)"
fi

# Seed appearance.json so the theme-switcher's CSS snippet (see
# bin/bin/theme) is enabled by default, without clobbering anything —
# only written when this run is the one creating .obsidian/ in the
# first place (a freshly cloned vault already has its own real
# appearance.json, which this must not overwrite).
if [[ ! -d $VAULT/.obsidian ]]; then
  mkdir -p "$VAULT/.obsidian"
  cat > "$VAULT/.obsidian/appearance.json" <<'EOF'
{
  "cssTheme": "",
  "enabledCssSnippets": ["active-theme"]
}
EOF
  echo "  Seeded $VAULT/.obsidian/appearance.json with the active-theme snippet enabled"
fi

cat <<'EOF'

Obsidian vault ready. One manual step left (community plugins can't be
scripted headlessly — no different from Mason installing LSP binaries
on Neovim's first real launch, see CLAUDE.md): open Obsidian, point it
at ~/vault, then Settings -> Community plugins -> Browse -> search
"Git" -> install & enable "Obsidian Git" for git-based sync.
EOF
