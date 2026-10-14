#!/usr/bin/env bash
#
# Configure reflector, which ranks Arch mirrors by sync-age and download
# speed and rewrites /etc/pacman.d/mirrorlist. A stale or distant mirror
# list is the usual cause of slow installs and "file not found" errors
# during -Syu (mirror lagging behind the repo state).
#
# A systemd timer refreshes the list twice a week — see the drop-ins
# below for why the stock weekly timer alone was not enough.

set -euo pipefail

# reflector reads its flags from this file when run via the systemd unit.
# This file is the single source of truth for the flags: the one-off run
# at the bottom of this hook goes through the same unit, instead of
# repeating them on a command line that could drift from this copy.
sudo tee /etc/xdg/reflector/reflector.conf >/dev/null <<'EOF'
# Mirrors geographically close to the machine — lower latency.
--country India,Singapore

# Only mirrors that synced within the last 12 hours.
--age 12

# https only. Most mirrors here serve both protocols from the same host,
# so allowing http let one host take two of the ten slots — exactly what
# happened: sg.mirrors.cicku.me sat at #1 (https) and #2 (http), and when
# that one host stalled, pacman's first two attempts both hit it.
--protocol https

# Rank by measured download rate and keep the fastest 10.
--sort rate
--latest 20
--number 10

# Destination file.
--save /etc/pacman.d/mirrorlist
EOF

# --- Retry after resume ------------------------------------------------------
# The stock unit has After=network-online.target, but that only helps at
# *boot*. On a laptop, a weekly run that comes due during suspend fires
# the moment the machine wakes (the timer is Persistent=true) — and
# network-online.target is still considered reached from before the
# suspend, so nothing waits for Wi-Fi to reconnect. Every scheduled run
# from 2026-09-07 to 2026-10-05 (five in a row) failed exactly this way:
# each started 1–2s after "System returned from sleep operation
# 'suspend'" and died on "Temporary failure in name resolution". A
# failed oneshot is not retried, so the mirrorlist silently froze at
# 2026-08-31.
#
# Two layers, either of which alone would have saved those runs:
#   ExecStartPre nm-online  waits (up to 90s) for NetworkManager to report
#                           a real connection before reflector starts.
#                           The "-" prefix means a timeout doesn't fail the
#                           unit by itself — reflector still gets its try.
#   Restart=on-failure      if reflector fails anyway (captive portal, DNS
#                           hiccup), retry every 2 min, at most 5 times in
#                           30 min — then give up until the next timer run
#                           rather than hammering a dead network.
sudo mkdir -p /etc/systemd/system/reflector.service.d
sudo tee /etc/systemd/system/reflector.service.d/retry.conf >/dev/null <<'EOF'
# Managed by dotfiles hooks/11-mirrors.sh — see that file for why.
[Unit]
StartLimitIntervalSec=30min
StartLimitBurst=5

[Service]
ExecStartPre=-/usr/bin/nm-online -q -t 90
Restart=on-failure
RestartSec=2min
EOF

# --- Twice weekly ----------------------------------------------------------
# Mirror speed and sync health shift over days, not hours, so more often
# than this just costs ~30s of probing for no better ranking. Twice weekly
# halves the worst-case staleness of the stock weekly timer. The empty
# OnCalendar= line clears the stock `weekly` first — without it, systemd
# would *add* these schedules on top. Persistent/RandomizedDelaySec stay
# as shipped.
sudo mkdir -p /etc/systemd/system/reflector.timer.d
sudo tee /etc/systemd/system/reflector.timer.d/schedule.conf >/dev/null <<'EOF'
# Managed by dotfiles hooks/11-mirrors.sh — see that file for why.
[Timer]
OnCalendar=
OnCalendar=Mon,Thu *-*-* 10:00:00
EOF

sudo systemctl daemon-reload

# enable --now starts the timer immediately as well.
sudo systemctl enable --now reflector.timer

# Run once now so the current session benefits immediately, rather than
# waiting for the timer's first fire. Through the unit (not a bare
# `reflector ...`), so the conf file above and the retry drop-in are what
# actually get exercised — and a failure shows up in `journalctl -u
# reflector`, same place as the scheduled runs.
echo "Ranking mirrors (this takes ~30s)..."
sudo systemctl start reflector.service

echo "Mirrors ranked; refresh scheduled $(systemctl show reflector.timer -p NextElapseUSecRealtime --value | cut -d' ' -f1-3)."
