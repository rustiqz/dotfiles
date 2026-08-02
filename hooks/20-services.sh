#!/usr/bin/env bash
#
# Enable system services. Kept in one hook so the full set of enabled
# units is visible in a single file rather than scattered across the repo.
#
# `enable --now` both enables at boot and starts immediately.
# Enabling an already-enabled unit is a no-op, so this is idempotent.

set -euo pipefail

# Helper: enable a unit only if it exists, so this hook doesn't fail on a
# machine where the owning package isn't installed (e.g. no bluetooth HW).
enable_if_present() {
  if systemctl list-unit-files "$1" &>/dev/null && \
     systemctl list-unit-files "$1" | grep -q "$1"; then
    echo "  enabling $1"
    sudo systemctl enable --now "$1"
  else
    echo "  skipping $1 (not installed)"
  fi
}

echo "System services:"
enable_if_present NetworkManager.service
enable_if_present bluetooth.service
enable_if_present systemd-timesyncd.service   # NTP clock sync
enable_if_present fstrim.timer                # weekly SSD TRIM (ext4)
enable_if_present paccache.timer              # prunes old pkg cache versions
enable_if_present power-profiles-daemon.service

# User services: PipeWire runs per-session, not system-wide.
#
# These are socket-activated by default — pipewire.socket starts the daemon
# on the first client connection. That means the .service units show as
# "disabled" while still being active, which is correct and intended.
# We enable the *sockets* rather than the services so activation works
# from a clean login without starting daemons that may not be needed.
echo "User services:"
systemctl --user enable --now pipewire.socket pipewire-pulse.socket
systemctl --user enable --now wireplumber.service   # session manager, not socket-activated

echo "Services enabled."
