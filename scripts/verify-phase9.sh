#!/usr/bin/env bash
#
# verify-phase9.sh — assert that Phase 9 (Quickshell bar) is applied:
# package + stow link, the bar running *instead of* waybar, a clean log,
# the blur layerrule actually matching, theming (contract + a live switch
# the running bar must report back), and the dev island's IPC.
#
# Mostly read-only. The theme check briefly repoints the bar's
# active-theme.json symlink at a scratch palette and back (the bar
# cross-fades for ~1s); the original target is restored on exit even if
# a check fails.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$DOTFILES/quickshell/.config/quickshell"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

TMP=$(mktemp -d)
LINK="$QS/active-theme.json"
ORIG=$(readlink "$LINK" 2>/dev/null || true)
restore() {
  [[ -n $ORIG ]] && ln -sfn "$ORIG" "$LINK" && timeout 3 qs ipc call theme reload &>/dev/null
  rm -rf "$TMP"
}
trap restore EXIT

# ---------------------------------------------------------------------------
hdr "Package + link"
# ---------------------------------------------------------------------------
pacman -Qq quickshell &>/dev/null && ok "package quickshell" || no "package quickshell MISSING"
target=$(realpath -e "$HOME/.config/quickshell/shell.qml" 2>/dev/null)
[[ $target == "$DOTFILES"/* ]] && ok "~/.config/quickshell resolves into the repo" \
                               || no "~/.config/quickshell/shell.qml missing or outside the repo"

# ---------------------------------------------------------------------------
hdr "Bar replaces waybar"
# ---------------------------------------------------------------------------
AUTO="$DOTFILES/hypr/.config/hypr/autostart.conf"
grep -q '^exec-once = uwsm app -- qs$' "$AUTO" && ok "autostart launches qs via uwsm" || no "autostart has no 'uwsm app -- qs'"
grep -q '^exec-once = uwsm app -- waybar' "$AUTO" && no "autostart still launches waybar" || ok "autostart no longer launches waybar"
pgrep -x qs &>/dev/null && ok "qs running" || no "qs not running"
pgrep -x waybar &>/dev/null && no "waybar still running alongside the bar" || ok "waybar not running"
scope=$(systemctl --user list-units 'app-Hyprland-qs-*' --no-legend 2>/dev/null)
[[ -n $scope ]] && ok "qs runs as its own uwsm scope" || wa "qs not under a uwsm scope (started by hand?)"
pacman -Qq waybar &>/dev/null && ok "waybar still installed (one-line rollback)" || wa "waybar uninstalled — rollback is no longer one line"

# ---------------------------------------------------------------------------
hdr "Log + layer"
# ---------------------------------------------------------------------------
log=$(timeout 5 qs log 2>/dev/null)
if [[ -z $log ]]; then
  wa "couldn't read the running instance's log (qs log)"
else
  bad=$(grep -E 'WARN|ERROR' <<<"$log" | grep -v 'Reloading configuration' | head -3)
  [[ -z $bad ]] && ok "qs log: no warnings or errors" || no "qs log has problems: $bad"
fi
layers=$(hyprctl layers -j 2>/dev/null | jq -r '.[].levels[][] | .namespace' 2>/dev/null)
grep -qx quickshell-bar <<<"$layers" && ok "layer 'quickshell-bar' mapped" || no "no 'quickshell-bar' layer"
rules=$(grep -c 'match:namespace ^(quickshell-bar' "$DOTFILES/hypr/.config/hypr/windowrules.conf")
(( rules >= 2 )) && ok "blur + ignore_alpha layerrules target quickshell-bar" || no "layerrules don't cover quickshell-bar"

# ---------------------------------------------------------------------------
hdr "Theming"
# ---------------------------------------------------------------------------
ROLES="bg surface surfaceHi fg subtle muted border accent accent2 info ok warn err"
for f in "$DOTFILES"/themes/*/quickshell.json; do
  [[ -f $f ]] || continue
  missing=$(for k in $ROLES; do jq -e --arg k "$k" 'has($k)' "$f" >/dev/null || echo "$k"; done | tr '\n' ' ')
  [[ -z $missing ]] && ok "$(basename "$(dirname "$f")")/quickshell.json fills every role" \
                    || no "$(basename "$(dirname "$f")")/quickshell.json missing: $missing"
done
TPL="$DOTFILES/matugen/templates/quickshell.json.tpl"
missing=$(for k in $ROLES; do grep -q "\"$k\":" "$TPL" || echo "$k"; done | tr '\n' ' ')
[[ -z $missing ]] && ok "matugen template fills every role" || no "matugen template missing: $missing"
grep -q 'templates.quickshell' "$DOTFILES/matugen/config.toml" && ok "matugen config renders the template" || no "matugen/config.toml has no quickshell entry"
grep -q 'qs ipc call theme reload' "$DOTFILES/bin/bin/theme" && ok "bin/bin/theme pokes the bar after linking" || no "bin/bin/theme doesn't call 'qs ipc call theme reload'"

# Live switch: the running bar must report the new palette by name.
if pgrep -x qs &>/dev/null; then
  jq '.name = "verify-phase9"' "$DOTFILES/themes/tokyonight/quickshell.json" >"$TMP/t.json"
  ln -sfn "$TMP/t.json" "$LINK"
  timeout 3 qs ipc call theme reload &>/dev/null
  sleep 0.5
  got=$(timeout 3 qs ipc call theme name 2>/dev/null)
  [[ $got == verify-phase9 ]] && ok "live switch: running bar applied the new palette" \
                              || no "live switch: bar reports '$got', expected verify-phase9"
  restore; trap - EXIT
  sleep 0.5
  back=$(timeout 3 qs ipc call theme name 2>/dev/null)
  want=$(jq -r .name "$(realpath "$LINK")" 2>/dev/null)
  [[ $back == "$want" ]] && ok "switched back: bar reports '$back'" || no "after restore bar reports '$back', expected '$want'"
fi

# ---------------------------------------------------------------------------
hdr "Dev island"
# ---------------------------------------------------------------------------
ipc=$(timeout 5 qs ipc show 2>/dev/null)
grep -q 'target bar' <<<"$ipc" && grep -q 'function brightness' <<<"$ipc" \
  && ok "IPC target 'bar' (brightness, flash)" || no "IPC target 'bar' missing"
timeout 3 qs ipc call bar flash "verify-phase9" "dev island IPC" &>/dev/null \
  && ok "flash call accepted" || no "qs ipc call bar flash failed"
binds=$(grep -c 'brightnessctl set 5%[+-] && qs ipc call bar brightness' "$DOTFILES/hypr/.config/hypr/keybinds.conf")
(( binds == 2 )) && ok "brightness keys poke the island OSD" || no "brightness binds don't call the bar ($binds/2)"
out=$(Hyprland --verify-config -c "$DOTFILES/hypr/.config/hypr/hyprland.conf" 2>&1)
grep -q 'config ok' <<<"$out" && ok "Hyprland config verifies" || no "Hyprland config errors"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 9 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 9 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
