#!/usr/bin/env bash
#
# Global Node CLI tools installed via pnpm, for tools that aren't really
# "part of a project" — currently just prettier, which
# nvim/.config/nvim/lua/plugins/formatting.lua shells out to by name.
#
# Needs mise's node on $PATH already (hooks/51-mise-tools.sh runs first —
# glob order in bootstrap.sh's hooks/ loop is execution order, hence the
# 6x numbering here vs 5x there).
#
# Idempotent: pnpm add -g on an already-installed package just confirms
# the version and exits, it doesn't reinstall.

set -euo pipefail

eval "$(mise activate bash)"

# Hooks run in a plain, non-login bash — .zshrc's PNPM_HOME/PATH export
# never runs, and pnpm refuses to install globally without it (confirmed:
# it errors naming the exact directory rather than silently falling back).
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"

pnpm add -g prettier

echo "Global Node tools installed: $(prettier --version)"
