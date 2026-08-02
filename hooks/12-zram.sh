# ~/dotfiles/hooks/12-zram.sh
#
# Configures zram-generator: a compressed block device in RAM used as swap.
# Faster than disk swap by a wide margin, and avoids writing swap to SSD.

set -euo pipefail

# zram-size: half of physical RAM, capped at 8G. The cap matters because
#            zram pages still consume RAM (compressed ~2-3x), so an
#            oversized device can be counterproductive.
# zstd:      best compression-ratio-to-speed tradeoff available here.
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

# Higher swappiness is correct for zram — swapping to RAM is cheap, so
# the kernel should prefer it over evicting the page cache. The disk-era
# default of 60 is tuned for slow swap.
sudo tee /etc/sysctl.d/99-vm-zram.conf >/dev/null <<'EOF'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
