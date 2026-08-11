#!/usr/bin/env bash
#
# Apply the default theme (tokyonight) on first bootstrap, via
# bin/bin/theme itself rather than duplicating its logic here.
#
# Guarded on kitty's active-theme.conf symlink specifically existing:
# that's created for every theme (every theme defines kitty.conf), so
# its presence means bin/bin/theme has already been run at least once
# — respect whatever the user last switched to, same reasoning as
# hooks/71-wallpaper.sh not resetting a later wallpaper pick back to
# the default on every bootstrap re-run.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -L $DOTFILES/kitty/.config/kitty/active-theme.conf ]]; then
  echo "A theme is already active ($(readlink "$DOTFILES/kitty/.config/kitty/active-theme.conf")), leaving it."
else
  "$DOTFILES/bin/bin/theme" tokyonight
fi
