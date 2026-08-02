# ~/dotfiles/hooks/11-mirrors.sh
#
# Configures reflector to keep /etc/pacman.d/mirrorlist fresh.
# Writes the config, then runs it once so the current session benefits;
# the systemd timer (enabled in 20-services.sh) handles it thereafter.

set -euo pipefail

# --country: adjust per machine if you relocate. India + Singapore gives
#            decent coverage from Bengaluru.
# --age 12:  only mirrors synced in the last 12 hours (avoids stale ones)
# --protocol https: encrypted transport
# --latest 20 --sort rate: probe the 20 most recently synced, keep fastest
sudo tee /etc/xdg/reflector/reflector.conf >/dev/null <<'EOF'
--save /etc/pacman.d/mirrorlist
--country India,Singapore
--protocol https
--age 12
--latest 20
--sort rate
EOF

echo "Running reflector (this takes ~30s)..."
sudo reflector @/etc/xdg/reflector/reflector.conf
