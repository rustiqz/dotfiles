#!/usr/bin/env bash
#
# Mask dunst.service (user scope) so it can never claim the
# org.freedesktop.Notifications D-Bus name ahead of swaync.
#
# This machine had dunst installed and its systemd --user unit already
# running — not something this repo put there, and not required by
# anything else installed (`pacman -Qi dunst` shows no reverse deps), so
# presumably leftover from an earlier manual experiment. dunst.service
# ships as `Type=dbus, BusName=org.freedesktop.Notifications`, the same
# D-Bus-activation pattern as the xdg-desktop-portal services (see
# hypr/.config/hypr/autostart.lua) — a plain `disable` only stops
# boot-time enablement, not activation-on-demand the next time any app
# sends a notification, so `mask` is required, not just `disable`.
#
# Guarded on the package actually being installed, and on the mask
# already being in place, so re-running is a no-op either way.

set -euo pipefail

if pacman -Qq dunst &>/dev/null; then
  # is-enabled exits non-zero for both "masked" and "static" units, so
  # the state string (not the exit code) is what actually distinguishes
  # them — capture it regardless of exit status.
  state=$(systemctl --user is-enabled dunst.service 2>/dev/null || true)
  if [[ $state != masked ]]; then
    systemctl --user mask --now dunst.service
    echo "Masked dunst.service — swaync can now own org.freedesktop.Notifications."
  else
    echo "dunst.service already masked."
  fi
else
  echo "dunst not installed, nothing to mask."
fi
