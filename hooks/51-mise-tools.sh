#!/usr/bin/env bash
#
# Installs the tool versions pinned in mise/.config/mise/config.toml
# (currently just Node LTS). `mise activate` in .zshrc only puts an
# *already-installed* version on PATH — the actual download/build
# happens here, once, so a fresh shell after bootstrap has a working
# `node` immediately instead of erroring until the user runs this by hand.
#
# Idempotent: `mise install` no-ops for versions already present.

set -euo pipefail

mise install
echo "mise tools installed: $(mise list --current)"
