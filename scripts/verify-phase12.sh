#!/usr/bin/env bash
#
# verify-phase12.sh — assert that Phase 12 (cards + polish) is applied:
# the cheatsheet, power menu and wallpaper picker are reachable and map
# as modal popups with a blurred scrim; the wallpaper script's direct-set
# path is safe; hyprlock's config is portable and every command it runs
# works; swaync floats under the bar with the shared radius.
#
# Opens and closes each popup once. Never locks the screen, never runs a
# power action, never changes the wallpaper.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

# The running bar's log, minus one known-benign line: at startup Qt tries
# to register an app ID with xdg-desktop-portal, but uwsm's scope already
# gave the process one, so the portal declines ("Connection already
# associated with an application ID"). Logged once per cold start, by Qt,
# not by this config — filtered by its exact text so any other warning
# still fails the check.
qslog() { timeout 5 qs log 2>/dev/null | grep -vE 'Failed to register with host portal|QWaylandTextInputv3::(en|dis)ableSurface'; }

mapped() { hyprctl layers -j 2>/dev/null | jq -r '.[].levels[][] | .namespace' | grep -qx "$1"; }

# ---------------------------------------------------------------------------
hdr "Popups: reachable, modal, blurred"
# ---------------------------------------------------------------------------
RULES="$DOTFILES/hypr/.config/hypr/windowrules.lua"
binds=$(hyprctl binds -j)
# target | namespace | bind description
for row in "cheatsheet|quickshell-cheatsheet|Keybind cheatsheet" \
           "power|quickshell-power|Power menu" \
           "wallpapers|quickshell-wallpapers|Wallpaper picker"; do
  IFS='|' read -r target ns desc <<<"$row"
  n=$(jq --arg d "$desc" '[.[] | select(.description == $d)] | length' <<<"$binds")
  grep -qF "\"qs ipc call $target toggle\", \"$desc\"" "$DOTFILES/hypr/.config/hypr/keybinds.lua" && [[ $n == 1 ]] \
    && ok "'$desc' bind → qs ipc call $target toggle" || no "'$desc' bind isn't 'qs ipc call $target toggle' (live binds: $n)"
  if mapped "$ns"; then no "$ns mapped before opening"; continue; fi
  timeout 3 qs ipc call "$target" toggle &>/dev/null; sleep 0.9
  mapped "$ns" && mapped "$ns-scrim" && ok "$target opens with its scrim" || no "$target: layer or scrim not mapped"
  timeout 3 qs ipc call "$target" toggle &>/dev/null; sleep 0.9
  mapped "$ns" || mapped "$ns-scrim" && no "$target: still mapped after close" || ok "$target closes cleanly"
  grep -qE "namespace = .*${target}" "$RULES" && ok "$target backdrop blurred" || no "no blur layerrule covering $target's scrim"
done
grep -q '"power", "toggle"' "$DOTFILES/quickshell/.config/quickshell/modules/bar/Status.qml" \
  && ok "bar power glyph opens the power menu" || no "bar power glyph doesn't open the power menu"

# ---------------------------------------------------------------------------
hdr "Wallpaper script"
# ---------------------------------------------------------------------------
out=$("$HOME/bin/wallpaper" ../../etc/passwd 2>&1); rc=$?
[[ $rc -ne 0 && $out == *"no such file"* ]] && ok "direct-set rejects paths outside the wallpaper dir" || no "wallpaper ../../etc/passwd → rc=$rc '$out'"
cur=$(readlink -f "$HOME/.local/share/wallpapers/.current" 2>/dev/null)
[[ -f $cur ]] && ok "current wallpaper resolves ($(basename "$cur"))" || no ".current doesn't resolve to a file"

# ---------------------------------------------------------------------------
hdr "Lock screen (config only — never locks)"
# ---------------------------------------------------------------------------
LOCK="$DOTFILES/hypr/.config/hypr/hyprlock.conf"
grep -qF "$HOME" "$LOCK" && no "hyprlock.conf contains $HOME" || ok "no home path baked into hyprlock.conf"
grep -q '@\$USER' "$LOCK" && ok "user label is \$USER (any account)" || no "user label isn't \$USER"
grep -q 'fingerprint' "$LOCK" && ok "fingerprint auth block kept" || no "fingerprint block missing"
# hyprlang reads {{ }} as arithmetic: the first restyle's inline playerctl
# format was a config error that rendered as "Sample Text". Formats with
# braces belong in bin/bin/lockinfo.
grep -q '{{' "$LOCK" && no "hyprlock.conf contains {{ }} — hyprlang parses it as an expression" \
                     || ok "no {{ }} in hyprlock.conf (moved into lockinfo)"
for sub in battery music uptime greeting caught avatar; do
  "$HOME/bin/lockinfo" "$sub" >/dev/null 2>&1 && ok "lockinfo $sub exits cleanly" || no "lockinfo $sub failed"
done
av=$("$HOME/bin/lockinfo" avatar)
[[ -s $av ]] && ok "avatar resolves to an image ($(basename "$av"))" || no "lockinfo avatar → '$av' (missing/empty)"
n=0; bad=0
while IFS= read -r cmd; do
  n=$((n+1))
  timeout 5 sh -c "$cmd" >/dev/null 2>&1; rc=$?
  # `[ -n "$x" ] && echo` legitimately exits 1 when there's nothing to show.
  (( rc > 1 )) && { bad=$((bad+1)); no "cmd label fails (rc=$rc): ${cmd:0:70}"; }
done < <(grep -oP 'text = cmd\[update:\d+\] \K.*' "$LOCK")
# An if, not `a && ok || b && no`: that chains left to right, so a passing
# `ok` still fell through to the trailing `&& no` (it did, first run).
if (( n == 0 )); then no "no cmd[] labels found"
elif (( bad == 0 )); then ok "all $n cmd[] labels run cleanly"
fi

# ---------------------------------------------------------------------------
hdr "Notifications (swaync)"
# ---------------------------------------------------------------------------
for f in "$DOTFILES"/themes/*/swaync-config.json "$DOTFILES/swaync/.config/swaync/config.json"; do
  [[ -e $f ]] || continue   # the active-theme link is absent under themes without swaync config (e.g. wallpaper)
  m=$(jq -r '"\(.["control-center-margin-top"])/\(.["control-center-margin-right"])/\(.["control-center-margin-bottom"])"' "$f")
  [[ $m == 6/12/12 ]] && ok "$(realpath --relative-to="$DOTFILES" "$f"): floats under the bar ($m)" \
                     || no "$(realpath --relative-to="$DOTFILES" "$f"): margins $m, expected 6/12/12"
done
grep -q -- '--border-radius: 14px' "$DOTFILES/swaync/.config/swaync/style.css" && ok "radius 14px (matches look.conf)" || no "swaync radius isn't 14px"
pidof swaync &>/dev/null && ok "swaync running" || wa "swaync not running"

# ---------------------------------------------------------------------------
hdr "Shell health"
# ---------------------------------------------------------------------------
bad=$(qslog | grep -E 'WARN|ERROR' | head -3)
[[ -z $bad ]] && ok "qs log: no warnings or errors" || no "qs log: $bad"
out=$(Hyprland --verify-config -c "$DOTFILES/hypr/.config/hypr/hyprland.lua" 2>&1)
grep -q 'config ok' <<<"$out" && ok "Hyprland config verifies" || no "Hyprland config errors"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 12 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 12 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
