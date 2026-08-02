# ~/dotfiles/hooks/20-services.sh
#
# Enables systemd units. `enable` is idempotent, and --now also starts
# the unit immediately so a first run doesn't require a reboot.

set -euo pipefail

enable_unit() {
  # Skip units whose package isn't installed on this machine — keeps the
  # hook portable across hosts with different package sets.
  systemctl list-unit-files "$1" &>/dev/null || return 0
  sudo systemctl enable --now "$1"
}

enable_unit NetworkManager.service   # network (already on under GNOME)
enable_unit bluetooth.service        # bluetooth adapter at boot
enable_unit fstrim.timer             # weekly SSD TRIM — important on ext4,
                                     # which has no continuous discard by default
enable_unit reflector.timer          # periodic mirrorlist refresh
enable_unit paccache.timer           # prunes /var/cache/pacman, keeping the
                                     # last 3 versions of each package
enable_unit systemd-timesyncd.service # NTP clock sync
