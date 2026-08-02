#!/usr/bin/env bash
#
# Configure reflector, which ranks Arch mirrors by sync-age and download
# speed and rewrites /etc/pacman.d/mirrorlist. A stale or distant mirror
# list is the usual cause of slow installs and "file not found" errors
# during -Syu (mirror lagging behind the repo state).
#
# The systemd timer re-runs this weekly so the list doesn't rot.

set -euo pipefail

# reflector reads its flags from this file when run via the systemd unit.
sudo tee /etc/xdg/reflector/reflector.conf >/dev/null <<'EOF'
# Mirrors geographically close to the machine — lower latency.
--country India,Singapore

# Only mirrors that synced within the last 12 hours.
--age 12

# Both protocols; https preferred where available.
--protocol https,http

# Rank by measured download rate and keep the fastest 10.
--sort rate
--latest 20
--number 10

# Destination file.
--save /etc/pacman.d/mirrorlist
EOF

# Run once now so the current session benefits immediately, rather than
# waiting for the timer's first fire.
echo "Ranking mirrors (this takes ~30s)..."
sudo reflector --country India,Singapore --age 12 --protocol https,http \
  --sort rate --latest 20 --number 10 --save /etc/pacman.d/mirrorlist

# Weekly refresh. enable --now starts the timer immediately as well.
sudo systemctl enable --now reflector.timer

echo "Mirrors ranked and weekly refresh enabled."
