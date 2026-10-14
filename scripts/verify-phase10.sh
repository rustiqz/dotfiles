#!/usr/bin/env bash
#
# verify-phase10.sh — assert that Phase 10 (dev hub) is applied: the hub
# is reachable (IPC + keybinds), actually maps/unmaps as a layer (with
# its click-outside scrim), is
# blurred, its actions work, and the ags sidebar it replaced is gone
# everywhere (process, autostart, keybind, theme switcher, manifests).
#
# Opens and closes the hub once (visible for ~1s). Everything else is
# read-only; `devstat act` is exercised against a scratch justfile only.
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

TMP=$(mktemp -d)
trap 'timeout 3 qs ipc call hub close &>/dev/null; rm -rf "$TMP"' EXIT
mapped() { hyprctl layers -j 2>/dev/null | jq -r '.[].levels[][] | .namespace' | grep -qx quickshell-hub; }

# ---------------------------------------------------------------------------
hdr "Hub reachable"
# ---------------------------------------------------------------------------
ipc=$(timeout 5 qs ipc show 2>/dev/null)
for f in toggle openSection close; do
  grep -A4 'target hub' <<<"$ipc" | grep -q "function $f" && ok "IPC hub.$f" || no "IPC hub.$f missing"
done
binds=$(hyprctl binds -j 2>/dev/null)
for key in space grave; do
  n=$(jq --arg k "$key" '[.[] | select((.key | ascii_downcase) == $k and .modmask == 64 and .description == "Dev hub")] | length' <<<"$binds")
  [[ $n == 1 ]] && ok "\$mod+$key → Dev hub" || no "\$mod+$key not bound to the hub"
done
toggle=$(jq -r '[.[] | select(.description == "Dev hub")][0].arg' <<<"$binds")
[[ $toggle == "qs ipc call hub toggle" ]] && ok "bind runs '$toggle'" || no "hub bind runs '$toggle'"

# ---------------------------------------------------------------------------
hdr "Hub maps and unmaps"
# ---------------------------------------------------------------------------
mapped && no "hub layer mapped before opening (should start hidden)" || ok "hidden until opened"
timeout 3 qs ipc call hub openSection c &>/dev/null; sleep 0.8
mapped && ok "openSection c → layer 'quickshell-hub' mapped" || no "hub layer not mapped after opening"
kb=$(hyprctl layers -j | jq -r '[.[].levels[][] | select(.namespace == "quickshell-hub")][0] | .keyboardInteractivity // empty' 2>/dev/null)
[[ -z $kb || $kb == 1 ]] && ok "hub takes keyboard focus when open" || wa "hub keyboardInteractivity=$kb (expected exclusive)"
# Click-outside-to-close: a full-screen scrim layer under the hub (which
# sits a level higher) catches every click that isn't on the hub. The
# click itself can't be scripted here (no input simulator installed), so
# assert the geometry and stacking that make it work.
L=$(hyprctl layers -j 2>/dev/null)
scrim=$(jq -c '[.[].levels | to_entries[] | .key as $l | .value[] | select(.namespace == "quickshell-hub-scrim") | {l: ($l|tonumber), w, h}][0]' <<<"$L")
hubl=$(jq '[.[].levels | to_entries[] | .key as $l | .value[] | select(.namespace == "quickshell-hub") | ($l|tonumber)][0]' <<<"$L")
mon=$(hyprctl monitors -j | jq -c '[.[] | select(.focused)][0] | {w: (.width / .scale | floor), h: (.height / .scale | floor)}')
if [[ $(jq -r '"\(.w)x\(.h)"' <<<"$scrim") == $(jq -r '"\(.w)x\(.h)"' <<<"$mon") ]]; then
  ok "scrim covers the whole monitor ($(jq -r '"\(.w)x\(.h)"' <<<"$scrim")) — catches clicks outside the hub"
else
  no "scrim missing or not full-screen: $scrim vs monitor $mon"
fi
(( hubl > $(jq '.l // 99' <<<"$scrim") )) && ok "hub stacked above the scrim (layer $hubl)" || no "hub not above the scrim"
timeout 3 qs ipc call hub close &>/dev/null; sleep 0.8
mapped && no "hub layer still mapped after close" || ok "close → layer unmapped"
hyprctl layers -j | jq -r '.[].levels[][] | .namespace' | grep -qx quickshell-hub-scrim \
  && no "scrim still mapped after close (would eat every click)" || ok "close → scrim unmapped too"
rules=$(grep -c 'match:namespace ^(quickshell-hub)' "$DOTFILES/hypr/.config/hypr/windowrules.conf")
(( rules >= 2 )) && ok "hub layer blurred (blur + ignore_alpha)" || no "no blur layerrules for quickshell-hub"

# ---------------------------------------------------------------------------
hdr "Hub actions (devstat act)"
# ---------------------------------------------------------------------------
mkdir -p "$TMP/proj" && printf 'up:\n    @true\ndown:\n    @true\n' >"$TMP/proj/justfile"
printf '#!/bin/sh\nexit 0\n' >"$TMP/notify-send" && chmod +x "$TMP/notify-send"
XDG_STATE_HOME="$TMP/st" PATH="$TMP:$PATH" "$HOME/bin/devstat" act up "$TMP/proj"; rc=$?
ev=$(cat "$TMP/st/devstat/events.jsonl" 2>/dev/null)
[[ $rc -eq 0 ]] && grep -q '"cmd": "just up"' <<<"$ev" && ok "act up prefers the project's 'just up' and reports a cmd-done event" \
                                                       || no "act up: rc=$rc events='$ev'"
"$HOME/bin/devstat" act sideways "$TMP/proj" &>/dev/null; rc=$?
[[ $rc -eq 2 ]] && ok "act rejects an unknown verb (rc=2)" || no "act sideways → rc=$rc"
for s in ports watchers; do
  "$HOME/bin/devstat" "$s" | jq -e 'type == "array"' >/dev/null && ok "devstat $s → array (hub's p/w sections)" || no "devstat $s not an array"
done

# ---------------------------------------------------------------------------
hdr "ags sidebar retired"
# ---------------------------------------------------------------------------
pgrep -f 'gjs.*ags|ags run' &>/dev/null && no "ags still running" || ok "ags not running"
grep -q 'ags run' "$DOTFILES/hypr/.config/hypr/autostart.conf" && no "autostart still launches ags" || ok "not in autostart"
grep -q 'ags toggle' "$DOTFILES/hypr/.config/hypr/keybinds.conf" && no "a keybind still calls ags" || ok "no ags keybind"
grep -q 'ags.css' "$DOTFILES/bin/bin/theme" && no "theme switcher still links ags.css" || ok "theme switcher no longer links ags"
[[ ! -e $DOTFILES/ags ]] && ok "ags/ stow package removed" || no "ags/ still in the repo (bootstrap would stow it)"
[[ ! -e $HOME/.config/ags ]] && ok "~/.config/ags unlinked" || no "~/.config/ags still exists"
left=$(grep -hE '^(aylurs-gtk-shell|libastal-mpris-git|dart-sass)\b' "$DOTFILES"/packages/*.txt)
[[ -z $left ]] && ok "ags packages dropped from manifests" || no "still in manifests: $left"
pacman -Qq aylurs-gtk-shell &>/dev/null && wa "aylurs-gtk-shell still installed (unused) — optional: paru -Rns aylurs-gtk-shell libastal-mpris-git dart-sass"

# ---------------------------------------------------------------------------
hdr "Shell health"
# ---------------------------------------------------------------------------
log=$(timeout 5 qs log 2>/dev/null)
bad=$(grep -E 'WARN|ERROR' <<<"$log" | head -3)
[[ -z $bad ]] && ok "qs log: no warnings or errors" || no "qs log: $bad"
out=$(Hyprland --verify-config -c "$DOTFILES/hypr/.config/hypr/hyprland.conf" 2>&1)
grep -q 'config ok' <<<"$out" && ok "Hyprland config verifies" || no "Hyprland config errors"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 10 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 10 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
