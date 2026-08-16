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

# Display manager: GDM, and only GDM.
#
# Not done via enable_if_present above, for two reasons. First, a display
# manager is exclusive — /etc/systemd/system/display-manager.service is a
# single symlink, so `enable gdm` on a machine where sddm is already
# enabled doesn't switch anything, it just conflicts. Whatever is already
# enabled has to be disabled first, which means this has to look at the
# current state rather than blindly enabling. Second, deliberately no
# `--now`: starting a different display manager while a session is
# running kills that session, including the terminal running bootstrap.sh.
# The switch lands at the next boot instead.
#
# The original machine came up on GDM because that's what its GNOME install had already
# enabled; the second machine was on SDDM for the same accidental reason,
# which is how it ended up offering the plain hyprland.desktop session
# rather than the uwsm one. Neither was ever a decision this repo made,
# so now it makes it explicitly.
echo "Display manager:"
if systemctl list-unit-files gdm.service 2>/dev/null | grep -q '^gdm.service'; then
  # Resolves through the symlink to the real unit, e.g. sddm.service.
  # Empty when no display manager is enabled at all (fresh install).
  current=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)" 2>/dev/null || true)
  if [[ ${current:-} == gdm.service ]]; then
    echo "  gdm is already the active display manager"
  else
    if [[ -n ${current:-} && $current != .  && $current != / ]]; then
      echo "  disabling $current"
      sudo systemctl disable "$current"
    fi
    echo "  enabling gdm.service"
    sudo systemctl enable gdm.service
    echo "  NOTE: not started now on purpose — switching display manager"
    echo "        live would kill this session. Takes effect at next boot."
  fi
else
  echo "  skipping (gdm not installed)"
fi

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
