#!/usr/bin/env bash
#
# Install the SDDM login-screen theme. All the work is in bin/bin/sddm-sync
# (copy theme + conf into /usr/share and /etc, derive palette and wallpaper
# from the active desktop theme); this hook exists so bootstrap runs it.
# A no-op where sddm isn't installed.
#
# Numbered after 71-wallpaper and 73-theme on purpose: sddm-sync derives the
# login screen's palette and background from the active theme and the current
# wallpaper, so both must exist first or a fresh machine gets the fallback.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SDDM theme:"
"$DOTFILES/bin/bin/sddm-sync"
