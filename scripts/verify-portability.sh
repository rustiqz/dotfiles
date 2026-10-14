#!/usr/bin/env bash
#
# verify-portability.sh — assert the repo replays onto ANY machine and ANY
# account, not just the one it was built on. Three classes of bug, each of
# which has actually happened here (CLAUDE.md, clean-machine findings):
#
#   1. Baked-in identity: a tracked file containing this account's home
#      path or username (the qt5ct/qt6ct color_scheme_path bug).
#   2. Hand-installed dependencies: a command the configs/scripts call
#      that's on this machine only because it was installed by hand or
#      pulled in by an unrelated package (uwsm; later gh, python,
#      libnotify...). Checked with `pacman -Qo`: every such command's
#      package must be in packages/*.txt, or in base / base-devel, which
#      bootstrap guarantees.
#   3. Stow tree-folding on an empty $HOME: a not-yet-existing target dir
#      symlinked into the repo wholesale (~/.local, ~/.cargo, ~/.ssh,
#      ~/.config/systemd). Simulated with `stow -n` into a scratch $HOME,
#      using bootstrap.sh's own pre-create list so the two can't drift.
#
# Read-only. Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$DOTFILES"

# ---------------------------------------------------------------------------
hdr "No baked-in identity"
# ---------------------------------------------------------------------------
# Docs may mention the repo's GitHub owner; configs and scripts may not
# contain this machine's home path or username.
hits=$(git grep -n -I -F -e "$HOME" -- ':!*.md' 2>/dev/null)
[[ -z $hits ]] && ok "no tracked file contains $HOME" || no "home path baked in: $(head -3 <<<"$hits")"
user=$(id -un)
hits=$(git grep -n -I -w -F -e "$user" -- ':!*.md' ':!*.png' ':!*.jpg' 2>/dev/null)
[[ -z $hits ]] && ok "no tracked file contains the username '$user'" || no "username baked in: $(head -3 <<<"$hits")"
links=$(git ls-files -s | awk '$1 == "120000" {print $4}' | while read -r l; do
  t=$(git cat-file -p "HEAD:$l" 2>/dev/null || readlink "$l"); [[ $t == /* ]] && echo "$l -> $t"; done)
[[ -z $links ]] && ok "no tracked symlink has an absolute target" || no "absolute symlinks: $links"
grep -q 'git clone https://' README.md && ok "README clones over HTTPS (works before any SSH key exists)" \
                                      || no "README clone isn't HTTPS"

# ---------------------------------------------------------------------------
hdr "Every command used comes from a tracked package"
# ---------------------------------------------------------------------------
# The commands the bar, hub, launcher, devstat, hooks and keybinds call.
# Extend this list when adding a new dependency.
CMDS="python3 gh git docker tmux kitty lazydocker jq ss notify-send swaync swaync-client
pavucontrol blueman-manager nm-connection-editor nm-online nmcli uwsm xdg-open wl-copy
brightnessctl playerctl wpctl systemd-inhibit qs rofimoji just bacon btop wlogout rofi
hyprctl stow matugen fzf less curl rustup mold sccache tree-sitter nvim grim slurp cliphist
uptime hyprlock qalc rsvg-convert fastfetch pokeget"
guaranteed=$(pacman -Qgq base-devel 2>/dev/null; pacman -Si base 2>/dev/null | awk -F': ' '/^Depends On/{print $2}' | tr ' ' '\n')
for c in $CMDS; do
  path=$(command -v "$c") || { wa "$c not installed here — can't check its package"; continue; }
  pkg=$(pacman -Qoq "$path" 2>/dev/null | head -1)
  [[ -z $pkg ]] && { no "$c ($path) not owned by any package"; continue; }
  if grep -qE "^$pkg([[:space:]#]|$)" packages/pacman.txt packages/aur.txt; then
    ok "$c ← $pkg (manifest)"
  elif grep -qx "$pkg" <<<"$guaranteed"; then
    ok "$c ← $pkg (base/base-devel)"
  elif [[ $pkg == git || $pkg == stow ]]; then
    ok "$c ← $pkg (bootstrap installs it first)"
  else
    no "$c ← $pkg — not in any manifest (installed by hand or as another package's dependency)"
  fi
done

# ---------------------------------------------------------------------------
hdr "Stow onto an empty home"
# ---------------------------------------------------------------------------
dirs=$(grep -m1 -E '^for d in .*\.config .*; do$' bootstrap.sh | sed -E 's/^for d in (.*); do$/\1/')
[[ -n $dirs ]] && ok "bootstrap pre-creates: $dirs" || no "couldn't find bootstrap.sh's pre-create list"
H="$TMP/home"; mkdir -p "$H"
for d in $dirs; do mkdir -p "$H/$d"; done
skipped=""
for pkg in */; do
  pkg=${pkg%/}
  case $pkg in packages|hooks|host|themes|scripts|matugen|orchestra) continue ;; esac
  if [[ -z $(git ls-files -- "$pkg" | head -1) ]]; then skipped+="$pkg "; continue; fi
  stow -t "$H" "$pkg" 2>"$TMP/err" || no "stow $pkg failed on an empty home: $(head -2 "$TMP/err")"
done
[[ -n $skipped ]] && ok "untracked dirs not stowed: $skipped" || ok "no untracked top-level dirs"
for d in .local .local/share .local/state .cargo .ssh .config/systemd .config/systemd/user; do
  if [[ -L $H/$d ]]; then no "~/$d would be a symlink into the repo (tree-folded) — add it to bootstrap's pre-create list"
  elif [[ -d $H/$d ]]; then ok "~/$d stays a real directory"
  else wa "~/$d not created"; fi
done
[[ $(stat -c %a "$H/.ssh" 2>/dev/null) == 700 ]] || grep -q 'chmod 700 "$HOME/.ssh"' bootstrap.sh \
  && ok "bootstrap makes ~/.ssh 0700" || no "~/.ssh permissions not set by bootstrap"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPortable.\033[0m\n' \
                || printf '\033[1;31mNot portable yet — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
