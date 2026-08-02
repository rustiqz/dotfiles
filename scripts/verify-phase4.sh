#!/usr/bin/env bash
#
# verify-phase4.sh — assert that Phase 4 (editor) is fully applied.
#
# Read-only: makes no changes, so it is safe to run any time. Exit
# criterion for Phase 4, same pass/fail/warn pattern as the earlier
# verify-phase*.sh scripts.
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

# Not an `-L` check on $path itself — see verify-phase2.sh for why
# (stow tree-folding: a whole new target dir gets one symlink, not
# one per file inside it).
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
for p in neovim tmux wl-clipboard; do
  chk_pkg "$p"
done

# ---------------------------------------------------------------------------
hdr "Stow links"
# ---------------------------------------------------------------------------
chk_link "$HOME/.config/nvim/init.lua"
chk_link "$HOME/.tmux.conf"
chk_link "$HOME/bin/work"

# ---------------------------------------------------------------------------
hdr "bin/work"
# ---------------------------------------------------------------------------
if [[ -x $HOME/bin/work ]]; then
  ok "~/bin/work is executable"
else
  no "~/bin/work missing or not executable"
fi
# Via `zsh -ic`, not the calling shell's own $PATH: this script runs as
# plain bash, which never sources .zshrc's PATH export — same reasoning
# as verify-phase2.sh's `zsh -ic 'starship init zsh'` check.
if zsh -ic 'command -v work' &>/dev/null; then
  ok "'work' resolves on \$PATH in an interactive shell"
else
  no "'work' not on \$PATH — check zsh/.zshrc's PATH export"
fi

# ---------------------------------------------------------------------------
hdr "tmux plugins (TPM)"
# ---------------------------------------------------------------------------
for plugin in tpm tmux-sensible tmux-resurrect tmux-continuum; do
  [[ -d $HOME/.tmux/plugins/$plugin ]] && ok "plugin installed: $plugin" \
                                        || no "plugin missing: $plugin (run hooks/60-tmux-plugins.sh)"
done

# ---------------------------------------------------------------------------
hdr "Neovim LSP / tooling (mason-managed)"
# ---------------------------------------------------------------------------
# Checked as files on disk, not by launching nvim headless — mason
# installs these on nvim's first real launch, not at `nvim --headless`
# time, so a headless probe here would just report them missing on a
# machine that's never actually had nvim opened once yet.
MASON_BIN="$HOME/.local/share/nvim/mason/bin"
if [[ -d $MASON_BIN ]]; then
  for server in vtsls lua-language-server vscode-eslint-language-server; do
    [[ -x $MASON_BIN/$server ]] && ok "mason server installed: $server" \
                                 || no "mason server missing: $server — open nvim once to trigger install"
  done
else
  wa "mason hasn't installed anything yet — open nvim once (mason.nvim installs LSP servers on first launch, not at bootstrap time)"
fi

if version=$(zsh -ic 'prettier --version' 2>/dev/null); then
  ok "prettier on \$PATH in an interactive shell ($version)"
else
  no "prettier not on \$PATH — check PNPM_HOME in zsh/.zshrc, or run hooks/61-node-globals.sh"
fi

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 4 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 4 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
