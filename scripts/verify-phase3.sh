#!/usr/bin/env bash
#
# verify-phase3.sh — assert that Phase 3 (dev toolchain) is fully applied.
#
# Read-only: makes no changes, so it is safe to run any time. Exit
# criterion for Phase 3, same pass/fail/warn pattern as the earlier
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

# Assert $1 (a path under $HOME) resolves into this repo. Not an `-L`
# check on $path itself — see verify-phase2.sh for why (stow tree-folding).
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
for p in mise pnpm docker docker-compose postgresql valkey direnv \
         temporal-cli bruno-bin; do
  chk_pkg "$p"
done

# ---------------------------------------------------------------------------
hdr "Stow links"
# ---------------------------------------------------------------------------
chk_link "$HOME/.config/mise/config.toml"

# ---------------------------------------------------------------------------
hdr "Node via mise"
# ---------------------------------------------------------------------------
if command -v mise &>/dev/null; then
  # `mise which` resolves the pinned version directly — doesn't require
  # the shell activation from .zshrc, so this passes even run non-interactively.
  if node_path=$(mise which node 2>/dev/null); then
    ok "mise-managed node installed ($("$node_path" --version))"
  else
    no "mise has no node installed — run: mise install"
  fi
else
  no "mise not installed"
fi

# ---------------------------------------------------------------------------
hdr "Docker"
# ---------------------------------------------------------------------------
systemctl is-active --quiet docker.service \
  && ok "unit docker.service active" || no "unit docker.service not active"
# Looked up via explicit username (reads the group database fresh) rather
# than the bare `groups` command (which shows the calling shell's cached
# session groups) — the latter would false-fail right after the hook runs,
# before the next login picks the new group up.
if getent group docker | grep -qw "$USER"; then
  ok "$USER is in the docker group"
else
  no "$USER not in the docker group"
fi

# ---------------------------------------------------------------------------
hdr "Git identity"
# ---------------------------------------------------------------------------
LOCAL_CONF="$HOME/.config/git/config.local"
if [[ -f $LOCAL_CONF ]]; then
  ok "config.local exists"
else
  no "config.local missing — run hooks/50-git-identity.sh"
fi
if git -C "$DOTFILES" ls-files --error-unmatch "$LOCAL_CONF" &>/dev/null; then
  no "config.local is tracked by git — it should be untracked (*.local)"
else
  ok "config.local is untracked, as intended"
fi
# Deliberately unscoped, not `--global`: `--global --get` only reads the
# literal ~/.gitconfig file, not the XDG fallback (~/.config/git/config)
# its [include] pulls config.local from — confirmed empirically, it's
# not just an unset-vs-set-elsewhere ambiguity. Unscoped resolution is
# also what every real git command (commit, etc.) actually uses.
email=$(git config user.email 2>/dev/null || echo "")
if [[ -z $email ]]; then
  no "git user.email doesn't resolve at all"
elif [[ $email == "you@example.com" ]]; then
  wa "git user.email is still the placeholder — edit $LOCAL_CONF"
else
  ok "git user.email resolves to $email"
fi
# If user.name/email are still set in ~/.gitconfig, they'd shadow
# config.local's values forever (see hooks/50-git-identity.sh) — the
# hook not having removed them is a real misconfiguration, not cosmetic.
if git config --global --get user.email &>/dev/null; then
  no "~/.gitconfig still sets user.email directly — shadows config.local"
else
  ok "~/.gitconfig doesn't set identity directly (config.local wins)"
fi

# ---------------------------------------------------------------------------
hdr "SSH"
# ---------------------------------------------------------------------------
if [[ -f $HOME/.ssh/id_ed25519 && -f $HOME/.ssh/id_ed25519.pub ]]; then
  ok "ed25519 keypair present"
  perms=$(stat -c '%a' "$HOME/.ssh/id_ed25519")
  [[ $perms == 600 ]] && ok "private key permissions are 600" \
                       || no "private key permissions are $perms, should be 600"
else
  no "no ed25519 keypair at ~/.ssh/id_ed25519 — generate with: ssh-keygen -t ed25519"
fi
# `ssh-add -l` exits 0 (identities listed) or 1 (agent up, empty) when the
# agent is reachable, and 2 specifically when it can't connect at all —
# only 2 means agent integration itself is broken.
ssh-add -l &>/dev/null; agent_status=$?
if [[ $agent_status -eq 2 ]]; then
  no "no ssh-agent reachable (\$SSH_AUTH_SOCK unset or dead)"
else
  ok "ssh-agent reachable"
fi

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 3 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 3 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
