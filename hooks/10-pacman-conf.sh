#!/usr/bin/env bash
#
# Tune /etc/pacman.conf: colour output, parallel downloads, multilib repo.
#
# This edits a system file in place rather than shipping a full pacman.conf,
# because pacman.conf carries machine-relevant defaults that vary by install
# and get updated as .pacnew files. Surgical edits survive those updates;
# a wholesale replacement would fight them.
#
# Idempotent: every change is guarded or written as a regex that matches
# both the commented default and the already-applied value.

set -euo pipefail
CONF=/etc/pacman.conf

# Colourised output. The default line is "#Color"; the \?  makes the
# leading # optional so re-runs match the already-uncommented line.
sudo sed -i 's/^#\?Color$/Color/' "$CONF"

# Download 10 packages concurrently instead of 1. Biggest single speedup
# for large installs. .* on the right matches whatever value is there.
sudo sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' "$CONF"

# Pac-Man animation in the progress bar. Purely cosmetic, requires
# ILoveCandy to appear in the [options] section — inserted right after
# ParallelDownloads, which is guaranteed to be in that section.
if ! grep -q '^ILoveCandy' "$CONF"; then
  sudo sed -i '/^ParallelDownloads/a ILoveCandy' "$CONF"
fi

# multilib: 32-bit packages. Needed for Steam, Wine, some proprietary
# toolchains, and 32-bit build targets. The default file has the repo
# header and its Include line both commented; this uncomments the pair.
if ! grep -q '^\[multilib\]' "$CONF"; then
  sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$CONF"
  # New repo enabled → refresh the package databases so pacman knows
  # what's in it. -yy forces refresh even if the DB looks current.
  sudo pacman -Syy --noconfirm
fi

echo "pacman.conf tuned."
