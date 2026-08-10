#!/usr/bin/env bash
#
# Enable hyprpolkitagent's own systemd --user unit.
#
# Unlike everything else autostarted in Phase 5 (waybar, swaync,
# hyprpaper, hypridle — all `exec-once = uwsm app -- ...` in
# hypr/autostart.conf), hyprpolkitagent ships a proper unit with
# `WantedBy=graphical-session.target` (checked against its actual
# assets/hyprpolkitagent-service.in upstream, not assumed). That means
# it's designed to be enabled once and then autostart on its own every
# time the session reaches graphical-session.target — which UWSM's
# session already does — with no exec-once line needed at all. Adding
# one anyway would just start a second, redundant instance.
#
# `enable --now` is idempotent on an already-enabled unit.

set -euo pipefail

systemctl --user enable --now hyprpolkitagent.service
