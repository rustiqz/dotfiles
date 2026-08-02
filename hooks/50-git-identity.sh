#!/usr/bin/env bash
#
# Move git identity (user.name/email) out of ~/.gitconfig and into
# ~/.config/git/config.local — untracked (matches the repo's *.local
# convention), included by the tracked git/.config/git/config.
#
# Why this has to also touch ~/.gitconfig: git resolves config in order
# system -> XDG (~/.config/git/config) -> ~/.gitconfig -> repo .git/config,
# with later sources overriding earlier ones. If user.name/email are
# still set in ~/.gitconfig, they'd silently shadow config.local forever
# regardless of what's in it — so this hook has to remove them there,
# not just add them elsewhere.
#
# Idempotent: config.local is only ever created if missing (never
# overwritten, so manual edits survive re-runs), and the ~/.gitconfig
# unset is guarded on the key actually being present.

set -euo pipefail

LOCAL_CONF="$HOME/.config/git/config.local"

if [[ ! -f $LOCAL_CONF ]]; then
  # Seed from whatever's currently in ~/.gitconfig, so a value the user
  # already set doesn't get lost in the move — only falls back to a
  # placeholder if neither was ever configured.
  name=$(git config --global user.name 2>/dev/null || echo "CHANGE_ME")
  email=$(git config --global user.email 2>/dev/null || echo "you@example.com")
  mkdir -p "$(dirname "$LOCAL_CONF")"
  cat > "$LOCAL_CONF" <<EOF
[user]
	name = $name
	email = $email
EOF
  echo "Wrote $LOCAL_CONF (name=$name, email=$email)"
else
  echo "$LOCAL_CONF already exists, leaving it alone"
fi

if git config --global --get user.name &>/dev/null; then
  git config --global --unset user.name
  echo "Removed user.name from ~/.gitconfig (now sourced from config.local)"
fi
if git config --global --get user.email &>/dev/null; then
  git config --global --unset user.email
  echo "Removed user.email from ~/.gitconfig (now sourced from config.local)"
fi
