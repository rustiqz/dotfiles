#!/usr/bin/env bash
#
# verify-phase2.sh — assert that Phase 2 (shell & terminal) is fully applied.
#
# Read-only: makes no changes, so it is safe to run any time. Exit
# criterion for Phase 2, mirroring verify-phase1.sh's pass/fail/warn
# pattern — see that script for the rationale behind each helper.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh for why the
# postfix form causes a false failure on each counter's first increment.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

chk_pkg() {
  pacman -Qq "$1" &>/dev/null && ok "package $1" || no "package $1 MISSING"
}

chk_cmd() {
  command -v "$1" &>/dev/null && ok "command $1" || no "command $1 NOT FOUND"
}

# Assert $1 (a path under $HOME) resolves into this repo — i.e. stow put
# it there, rather than it being a stray real file some app wrote.
#
# Deliberately NOT an `-L` check on $path itself: when a whole target
# directory is new, stow symlinks the *directory* once (tree-folding)
# rather than every file inside it, so a stowed file often sits at a
# real (non-symlink) path reached through a symlinked ancestor dir.
# `realpath` resolves through that regardless of which level the
# symlink is actually at, so it's the check that matches what stow does.
chk_link() {
  local path=$1
  if [[ -e $path || -L $path ]]; then
    local target
    target=$(realpath -e "$path" 2>/dev/null) || { no "$path is a broken symlink"; return; }
    [[ $target == "$DOTFILES"/* ]] && ok "linked: $path" \
                                    || no "$path exists but resolves outside this repo ($target) — stray file?"
  else
    no "$path missing"
  fi
}

# ---------------------------------------------------------------------------
hdr "Packages"
# ---------------------------------------------------------------------------
for p in kitty zsh zsh-autosuggestions zsh-syntax-highlighting \
         zsh-history-substring-search starship fzf ripgrep fd bat eza \
         zoxide git-delta btop lazygit jq curl; do
  chk_pkg "$p"
done

# ---------------------------------------------------------------------------
hdr "Stow links"
# ---------------------------------------------------------------------------
chk_link "$HOME/.config/kitty/kitty.conf"
chk_link "$HOME/.config/kitty/tokyonight.conf"
chk_link "$HOME/.zshrc"
chk_link "$HOME/.config/starship.toml"
chk_link "$HOME/.config/bat/config"
chk_link "$HOME/.config/git/config"
chk_link "$HOME/.config/lazygit/config.yml"
chk_link "$HOME/.config/btop/btop.conf"

# ---------------------------------------------------------------------------
hdr "Login shell"
# ---------------------------------------------------------------------------
current_shell=$(getent passwd "$USER" | cut -d: -f7)
zsh_path=$(command -v zsh || true)
if [[ -n $zsh_path && $current_shell == "$zsh_path" ]]; then
  ok "login shell is zsh ($zsh_path)"
else
  no "login shell is $current_shell, not zsh — log out/in after chsh to take effect"
fi

# ---------------------------------------------------------------------------
hdr "Shell init (runtime, not just presence in .zshrc)"
# ---------------------------------------------------------------------------
# Each of these actually executes the init command a fresh shell would
# run, rather than grepping .zshrc for the line — catches "installed but
# the binary errors out" as distinct from "not configured".
zsh -ic 'starship init zsh' &>/dev/null && ok "starship init zsh runs cleanly" \
                                        || no "starship init zsh failed"
zsh -ic 'zoxide init zsh' &>/dev/null   && ok "zoxide init zsh runs cleanly" \
                                        || no "zoxide init zsh failed"
[[ -f /usr/share/fzf/key-bindings.zsh ]] && ok "fzf key-bindings.zsh present" \
                                          || no "fzf key-bindings.zsh missing (package layout changed?)"

# Plugin files referenced directly by zsh/.zshrc — if these paths are
# wrong, the shell silently starts without the plugin rather than erroring.
for f in \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
do
  [[ -f $f ]] && ok "plugin file: $(basename "$f")" || no "plugin file missing: $f"
done

# ---------------------------------------------------------------------------
hdr "Theming"
# ---------------------------------------------------------------------------
if command -v bat &>/dev/null; then
  # Captured into a variable rather than piped straight into `grep -q`:
  # pipefail turns grep's early exit-on-match (which SIGPIPEs bat mid-write)
  # into a false pipeline failure. See verify-phase1.sh's fonts section
  # for the same fix with fc-list.
  themes=$(bat --list-themes 2>/dev/null)
  grep -qx "tokyonight_night" <<<"$themes" \
    && ok "bat theme cache contains tokyonight_night" \
    || no "bat theme cache missing tokyonight_night (run hooks/41-bat-theme.sh)"
else
  no "bat not installed — can't check theme"
fi

if command -v btop &>/dev/null; then
  btop --version &>/dev/null && [[ -f /usr/share/btop/themes/tokyo-night.theme ]] \
    && ok "btop tokyo-night theme present (bundled)" \
    || wa "btop tokyo-night.theme not found at expected path — check btop version"
fi

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 2 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 2 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
