#!/usr/bin/env bash
#
# dump-repo.sh — print the repo's structure and file contents as one
# pasteable block.
#
# Purpose: hand the current state of the setup to a fresh session without
# describing it by hand. Read-only.
#
# Usage:
#   ./scripts/dump-repo.sh              # everything
#   ./scripts/dump-repo.sh hooks        # only paths matching "hooks"
#   ./scripts/dump-repo.sh | wl-copy    # straight to clipboard

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILTER="${1:-}"          # optional substring to limit which files are dumped
cd "$DOTFILES"

echo "# dotfiles dump — $(date -Is)"
echo "# host: $(hostnamectl --static 2>/dev/null || hostname)"
[[ -n $FILTER ]] && echo "# filtered to paths matching: $FILTER"
echo

# --- structure ---------------------------------------------------------------
# Tree first, so the reader sees the layout before the contents. Falls back
# to find when tree isn't installed.
echo "## Structure"
echo '```'
if command -v tree &>/dev/null; then
  tree -a -I '.git' --charset=ascii
else
  find . -path ./.git -prune -o -print | sort
fi
echo '```'
echo

# --- git state ---------------------------------------------------------------
# Uncommitted work is exactly the context a fresh session needs, since it
# won't match whatever was last discussed.
if [[ -d .git ]]; then
  echo "## Git"
  echo '```'
  echo "branch:  $(git branch --show-current)"
  echo "remote:  $(git remote get-url origin 2>/dev/null || echo 'none')"
  echo "last:    $(git log -1 --format='%h %s' 2>/dev/null || echo 'no commits')"
  echo
  echo "status:"
  git status --short
  echo '```'
  echo
fi

# --- file contents -----------------------------------------------------------
# Every tracked-ish file, excluding .git and binaries. Each is fenced with
# its language hint so it renders correctly when pasted into a chat.
echo "## Files"
while IFS= read -r f; do
  f=${f#./}
  [[ -n $FILTER && $f != *"$FILTER"* ]] && continue

  # Skip binaries — `file` reports charset=binary for anything non-text.
  file -b --mime "$f" | grep -q 'charset=binary' && { echo "### $f (binary, skipped)"; continue; }

  # Language hint from extension, so syntax highlighting works downstream.
  case "$f" in
    *.sh|bootstrap.sh) lang=bash ;;
    *.conf|*.txt)      lang=ini  ;;
    *.lua)             lang=lua  ;;
    *.toml)            lang=toml ;;
    *)                 lang=""   ;;
  esac

  echo "### $f"
  echo "\`\`\`$lang"
  cat "$f"
  echo '```'
  echo
done < <(find . -path ./.git -prune -o -type f -print | sort)

# --- system state ------------------------------------------------------------
# Config files alone don't capture what's installed or running, which is
# half of what makes a machine reproducible.
echo "## System state"
echo '```'
echo "kernel:   $(uname -r)"
echo "pacman:   $(pacman -Q pacman | awk '{print $2}')"
echo "paru:     $(paru --version 2>/dev/null | head -1 || echo 'BROKEN OR MISSING')"
echo "gpu:      $(lspci | grep -E 'VGA|3D' | sed 's/.*: //')"
echo "session:  ${XDG_CURRENT_DESKTOP:-unknown} / ${XDG_SESSION_TYPE:-unknown}"
echo "shell:    $SHELL"
echo "swap:     $(swapon --show=NAME,SIZE --noheadings | tr '\n' ' ')"
echo
echo "explicitly installed packages ($(pacman -Qqe | wc -l) total):"
# -Qqe = explicitly installed only, excluding dependencies. This is the
# set that actually belongs in the manifests.
pacman -Qqe | tr '\n' ' ' | fold -s -w 100
echo '```'
