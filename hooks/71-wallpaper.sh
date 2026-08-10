#!/usr/bin/env bash
#
# Create ~/.local/share/wallpapers/.current, a symlink hyprpaper.conf and
# hyprlock.conf both point at instead of a hardcoded filename — so
# picking a new wallpaper via ~/bin/wallpaper (which repoints this same
# symlink) changes both the desktop and the lock screen together,
# without editing either config.
#
# Guarded on the symlink not already existing: this only sets the
# *initial* target (the generated tokyonight-mountains.png). Once
# ~/bin/wallpaper has repointed it to something else, re-running
# bootstrap.sh must never reset that choice back to the default.

set -euo pipefail

WALLPAPER_DIR="$HOME/.local/share/wallpapers"
CURRENT_LINK="$WALLPAPER_DIR/.current"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/tokyonight-mountains.png"

if [[ -L $CURRENT_LINK ]]; then
  echo "$CURRENT_LINK already set (-> $(readlink "$CURRENT_LINK")), leaving it."
else
  ln -sf "$DEFAULT_WALLPAPER" "$CURRENT_LINK"
  echo "Set $CURRENT_LINK -> $DEFAULT_WALLPAPER"
fi
