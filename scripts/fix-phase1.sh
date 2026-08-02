#!/usr/bin/env bash
set -euo pipefail

echo "1) makepkg: disable debug package builds"
sudo sed -i 's/^OPTIONS=(\(.*\) debug \(.*\))/OPTIONS=(\1 !debug \2)/' /etc/makepkg.conf
grep '^OPTIONS' /etc/makepkg.conf

echo "2) enabling reflector.timer and paccache.timer"
sudo systemctl enable --now reflector.timer paccache.timer

echo "3) installing fonts"
sudo pacman -S --needed ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk

echo "done"
