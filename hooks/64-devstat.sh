#!/usr/bin/env bash
#
# Enables the user timer that keeps devstat's CI cache warm and notifies
# when a repo's CI turns red (systemd/.config/systemd/user/devstat-ci.*,
# stowed). User-level systemd — no sudo, and it runs whether the session
# is Hyprland or the GNOME fallback.
#
# Idempotent: daemon-reload + enable --now are no-ops when already done.
# Skips without gh, since the timer would only ever serve "unavailable".

set -euo pipefail

if ! command -v gh &>/dev/null; then
  echo "gh not installed — skipping devstat CI timer" >&2
  exit 0
fi

systemctl --user daemon-reload
systemctl --user enable --now devstat-ci.timer
echo "devstat CI timer: $(systemctl --user is-active devstat-ci.timer)"
