#!/usr/bin/env bash
#
# preview-lock.sh — screenshot the lock screen without it ever touching
# authentication.
#
# Why this exists: previewing by starting the real hyprlock and ending it
# with SIGUSR1 aborts its PAM conversation, and PAM records every aborted
# conversation as a FAILED LOGIN. pam_faillock's defaults (deny=3,
# unlock_time=600) then lock the account: three previews on 2026-10-14
# locked password login (and sudo) out for ten minutes, while the
# screen had just idle-locked for real. So a preview loads the real
# config and turns PAM off on top of it — no PAM conversation, nothing to
# fail. Fingerprint stays ON: hyprlock aborts at startup if every auth
# method is disabled ("At least one authentication method must be
# enabled!", found from a core dump on the first try), and its
# fingerprint path talks to fprintd over D-Bus, not through PAM, so it
# can't record a failed login either. --grace 30 means any keypress or
# mouse move also unlocks it, should SIGUSR1 ever not work.
#
# Refuses to run while a real lock is up (only one session lock can exist,
# and you wouldn't want to stack on top of it anyway).
#
# Usage: scripts/preview-lock.sh [out.png]     (default: ./lock-preview.png)

set -uo pipefail

out=${1:-lock-preview.png}

if pgrep -x hyprlock >/dev/null; then
  echo "preview-lock: a hyprlock is already running (a real lock?) — not stacking on it" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/preview.conf" <<EOF
source = $HOME/.config/hypr/hyprlock.conf
auth {
  pam {
    enabled = false
  }
}
EOF

hyprlock -c "$tmp/preview.conf" --grace 30 --no-fade-in >"$tmp/log" 2>&1 &
pid=$!
sleep 3
grim "$out"
kill -USR1 "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
rc=$?

# A crash before locking means the screenshot is just the desktop — that
# must fail, not report a preview (the first version said "wrote …" over
# a core dump).
if (( rc != 0 )) || grep -q 'At least one authentication method' "$tmp/log"; then
  echo "preview-lock: hyprlock exited $rc — no preview taken:" >&2
  grep -iE 'error|abort|at least one' "$tmp/log" >&2
  exit 1
fi

if grep -q 'pam_authenticate' "$tmp/log"; then
  echo "preview-lock: PAM ran — the auth override didn't apply; NOT safe to repeat" >&2
  exit 1
fi
grep -iE 'config error' "$tmp/log" >&2 && exit 1
echo "preview-lock: wrote $out (PAM disabled, no login attempt recorded)"
