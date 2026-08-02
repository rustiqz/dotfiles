#!/usr/bin/env bash
#
# Install the TokyoNight syntax theme for bat (and, transitively, delta —
# see git/.config/git/config's syntax-theme setting).
#
# bat themes are Sublime Text .tmTheme (XML) files, not something worth
# hand-authoring, so this pulls the upstream copy folke/tokyonight.nvim
# ships in its extras/ directory rather than vendoring a hand-rolled one.
#
# Idempotent: re-downloading and rebuilding the cache are both cheap and
# harmless to repeat.

set -euo pipefail

THEME_DIR="$(bat --config-dir)/themes"
mkdir -p "$THEME_DIR"

curl -fsSL \
  https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme \
  -o "$THEME_DIR/tokyonight_night.tmTheme"

# Rebuild bat's binary theme cache so it picks up the new file.
bat cache --build

echo "bat theme installed: TokyoNight"
