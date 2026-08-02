#!/usr/bin/env bash
#
# Bootstrap TPM (tmux plugin manager) and install the plugins listed in
# tmux/.tmux.conf's `@plugin` lines. TPM isn't a pacman package — it's a
# git-cloned script, same pattern as paru in bootstrap.sh itself.
#
# Idempotent: clone only happens if the directory is missing; TPM's own
# install script is safe to re-run (skips already-installed plugins).

set -euo pipefail

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [[ ! -d $TPM_DIR ]]; then
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Runs TPM's installer directly rather than going through a live tmux
# server + prefix keybinding — there isn't necessarily one running
# during bootstrap, and this is the same install path TPM's own
# `scripts/install_plugins.sh` uses under the hood.
"$TPM_DIR/bin/install_plugins"

echo "tmux plugins installed."
