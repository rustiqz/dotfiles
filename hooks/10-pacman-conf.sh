# ~/dotfiles/hooks/10-pacman-conf.sh
#
# Tunes /etc/pacman.conf. This lives in a hook rather than a stow package
# because /etc is outside $HOME, needs root, and we want to EDIT the
# distro-shipped file rather than replace it (replacing it would hide
# .pacnew updates from future pacman releases).
#
# Every edit is guarded or idempotent, so re-running bootstrap.sh is safe.

set -euo pipefail
CONF=/etc/pacman.conf

# Parallel downloads. Recent Arch ships this uncommented at 5; older
# installs have it commented out. The optional '#' in the pattern
# handles both cases, and re-running just rewrites the same value.
sudo sed -i 's/^#\?ParallelDownloads = .*/ParallelDownloads = 10/' "$CONF"

# Colored output. Shipped commented; uncomment it.
sudo sed -i 's/^#Color$/Color/' "$CONF"

# Show old->new version numbers on upgrades. Genuinely useful when a
# system update breaks something and you need to know what moved.
sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' "$CONF"

# ILoveCandy: pac-man style progress bar. Not present in the default
# file at all, so append it after Color rather than uncommenting.
grep -q '^ILoveCandy' "$CONF" || sudo sed -i '/^Color$/a ILoveCandy' "$CONF"

# multilib: the 32-bit repository. Needed for Steam, Wine, and a few
# proprietary dev tools. The default file has the two lines commented;
# this strips the leading '#' from that block only.
if ! grep -q '^\[multilib\]' "$CONF"; then
  sudo sed -i '/^#\[multilib\]/,/^#Include = .*mirrorlist/ s/^#//' "$CONF"
fi

# Refresh package databases so the newly-enabled repo is usable.
sudo pacman -Sy
