#!/usr/bin/env bash
#
# verify-popovers.sh — assert the bar popovers and the Quickshell
# notification daemon work: every popover opens and maps as a layer, closes
# again, Quickshell (not swaync) owns org.freedesktop.Notifications, a
# test notification arrives in the history, and nothing was logged.
#
# Sends one test notification and dismisses it. Changes no setting.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

mapped() { hyprctl layers -j 2>/dev/null | jq -r '.[].levels[][] | .namespace' | grep -qx "$1"; }
# Filter the one benign startup line — see verify-phase12.sh.
# `qs log` keeps history across live reloads, so only look at what was
# logged since the last successful load — earlier lines may be already fixed.
qslog() { timeout 5 qs log 2>/dev/null | grep -vE 'Failed to register with host portal|QWaylandTextInputv3::(en|dis)ableSurface' | awk '/Configuration Loaded/{n=0; next} {l[n++]=$0} END{for(i=0;i<n;i++) print l[i]}'; }

hdr "Popovers open and close"
ipc=$(qs ipc show 2>&1)
for t in popover notifs; do
  [[ $ipc == *"target $t"* ]] && ok "ipc target '$t' registered" || no "ipc target '$t' missing"
done
for name in wifi bluetooth audio battery system calendar notifications dev media; do
  qs ipc call popover toggle "$name" 1500 >/dev/null 2>&1
  sleep 0.8
  mapped quickshell-popover && ok "$name: card mapped" || no "$name: card did not map"
  qs ipc call popover close >/dev/null 2>&1
  sleep 0.6
  mapped quickshell-popover && no "$name: card still mapped after close" || ok "$name: closed"
done

hdr "Dev island focus"
# devstat's focus section follows kitty's *active tab* over a socket that
# kitty.conf opens; without it the island names the newest process in any tab.
grep -q '^listen_on unix:@kitty-{kitty_pid}' kitty/.config/kitty/kitty.conf \
  && grep -q '^allow_remote_control socket-only' kitty/.config/kitty/kitty.conf \
  && ok "kitty.conf opens the per-process control socket" || no "kitty.conf lacks listen_on/allow_remote_control"
python3 -c "import ast;ast.parse(open('bin/bin/devstat').read())" 2>/dev/null \
  && ok "devstat parses" || no "devstat has a syntax error"

hdr "Notification daemon"
owner=$(busctl --user status org.freedesktop.Notifications 2>/dev/null | awk -F= '/^Comm=/{print $2}')
[[ $owner == qs ]] && ok "qs owns org.freedesktop.Notifications" || no "owner is '${owner:-nobody}', not qs (swaync running? pgrep -x swaync)"
notify-send -a verify-popovers "verify" "test notification" >/dev/null 2>&1
sleep 0.8
mapped quickshell-toasts && ok "toast window mapped" || no "no toast for a test notification"
qs ipc call notifs clear >/dev/null 2>&1

hdr "Log is clean"
bad=$(qslog | grep -E 'ERROR|WARN' | tail -5)
[[ -z $bad ]] && ok "no warnings or errors in qs log" || { no "qs log has warnings/errors:"; echo "$bad"; }

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
