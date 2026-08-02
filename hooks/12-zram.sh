#!/usr/bin/env bash
#
# Set up zram: a compressed block device in RAM used as swap.
#
# Why not a disk swap partition — compressed pages in RAM are roughly an
# order of magnitude faster to fault back in than pages from an SSD, and
# nothing gets written to the drive. The tradeoff is CPU time for
# compression, which zstd makes cheap.
#
# zram-generator creates the device via systemd at boot from this config,
# so there's no fstab entry or manual setup to maintain.

set -euo pipefail

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
# Half of physical RAM, capped at 8G. Compression means the effective
# capacity is roughly 2-3x this figure.
zram-size = min(ram / 2, 8192)

# zstd gives the best ratio-to-speed balance for this workload.
compression-algorithm = zstd

# Higher priority than any disk swap, so the kernel fills zram first.
swap-priority = 100
EOF

# Regenerate units from the config, then bring the device up now.
sudo systemctl daemon-reload
sudo systemctl start /dev/zram0 2>/dev/null || \
  sudo systemctl restart systemd-zram-setup@zram0.service

echo "zram configured. Verify with: swapon --show"
