#!/usr/bin/env bash
#
# verify-phase11.sh — assert that Phase 11 (Pokédex launcher) is applied:
# reachable (IPC, $mod+D, bar button), maps centred with its click-outside
# scrim, every mode's data source resolves (desktop entries + icon theme,
# devstat projects, rofimoji's emoji data, qalc), and rofi drun is retired
# while rofi stays for the small pickers.
#
# Opens and closes the launcher a few times (~1s each). No app is
# launched and no launch stats are written.
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

trap 'timeout 3 qs ipc call launcher openWith "" &>/dev/null; timeout 3 qs ipc call launcher toggle &>/dev/null' EXIT
layer() { hyprctl layers -j 2>/dev/null | jq -c --arg n "$1" '[.[].levels | to_entries[] | .key as $l | .value[] | select(.namespace == $n) | {l: ($l|tonumber), x, y, w, h}][0] // empty'; }

# ---------------------------------------------------------------------------
hdr "Reachable"
# ---------------------------------------------------------------------------
ipc=$(timeout 5 qs ipc show 2>/dev/null)
for f in toggle openWith; do
  grep -A3 'target launcher' <<<"$ipc" | grep -q "function $f" && ok "IPC launcher.$f" || no "IPC launcher.$f missing"
done
arg=$(hyprctl binds -j | jq -r '[.[] | select(.description == "App launcher")][0].arg')
[[ $arg == "qs ipc call launcher toggle" ]] && ok "\$mod+D → launcher" || no "\$mod+D runs '$arg'"
grep -q '"launcher", "toggle"' "$QS/modules/bar/Workspaces.qml" && ok "bar's launcher button opens it" || no "bar button doesn't open the launcher"
grep -q 'rofi -show drun' "$DOTFILES/hypr/.config/hypr/keybinds.conf" && no "rofi drun still bound" || ok "rofi drun no longer bound"
pacman -Qq rofi &>/dev/null && ok "rofi still installed (clipboard/ssh/theme pickers)" || no "rofi missing — the pickers need it"

# ---------------------------------------------------------------------------
hdr "Opens centred, with its scrim"
# ---------------------------------------------------------------------------
[[ -z $(layer quickshell-launcher) ]] && ok "hidden until opened" || no "launcher mapped before opening"
timeout 3 qs ipc call launcher openWith "" &>/dev/null; sleep 0.8
L=$(layer quickshell-launcher); S=$(layer quickshell-launcher-scrim)
mon=$(hyprctl monitors -j | jq -c '[.[] | select(.focused)][0] | {w: (.width / .scale | floor), h: (.height / .scale | floor)}')
if [[ -n $L ]]; then
  ok "layer 'quickshell-launcher' mapped ($(jq -r '"\(.w)x\(.h)"' <<<"$L"))"
  cx=$(jq -n --argjson l "$L" --argjson m "$mon" '(($l.x + $l.w / 2) - $m.w / 2) | fabs < 4')
  [[ $cx == true ]] && ok "centred horizontally" || wa "not centred: $L on $mon"
else
  no "launcher layer not mapped after opening"
fi
[[ -n $S && $(jq '.w' <<<"$S") -ge $(jq '.w' <<<"$mon") ]] && ok "scrim covers the monitor" || no "scrim missing/not full-screen: $S"
[[ -n $L && -n $S ]] && (( $(jq .l <<<"$L") > $(jq .l <<<"$S") )) && ok "launcher above its scrim" || no "launcher not above its scrim"
timeout 3 qs ipc call launcher toggle &>/dev/null; sleep 0.8
[[ -z $(layer quickshell-launcher) && -z $(layer quickshell-launcher-scrim) ]] && ok "toggle closes both layers" || no "launcher or scrim still mapped after close"

# Each prefix mode opens without errors in the log.
for q in "/" ">echo hi" "@" "=1+1" ":rocket" "?"; do
  timeout 3 qs ipc call launcher openWith "$q" &>/dev/null; sleep 0.5
  timeout 3 qs ipc call launcher toggle &>/dev/null; sleep 0.3
done
ok "cycled every mode (/ > @ = : ?)"

# ---------------------------------------------------------------------------
hdr "Data sources"
# ---------------------------------------------------------------------------
grep -q '^//@ pragma IconTheme Papirus-Dark' "$QS/shell.qml" && ok "icon theme pragma set (Papirus-Dark, matches GTK)" || no "no IconTheme pragma — icons fall back to hicolor"
n=$(find /usr/share/applications ~/.local/share/applications -name '*.desktop' 2>/dev/null | wc -l)
(( n > 0 )) && ok "$n desktop entries on disk (apps mode)" || no "no desktop entries found"
p=$("$HOME/bin/devstat" projects | jq length)
(( p > 0 )) && ok "devstat projects → $p (projects mode)" || no "devstat finds no projects"
e=$(cat /usr/lib/python3*/site-packages/picker/data/emojis_*.csv 2>/dev/null | wc -l)
(( e > 1000 )) && ok "rofimoji emoji data: $e entries (emoji mode)" || no "rofimoji emoji data not found (glob /usr/lib/python3*/site-packages/picker/data)"
if command -v qalc &>/dev/null; then
  r=$(qalc -t "2^10 * 3" 2>/dev/null)
  [[ $r == 3072 ]] && ok "qalc works (2^10 * 3 = $r)" || no "qalc returned '$r'"
else
  wa "qalc not installed — '=' mode shows an install hint (sudo pacman -S libqalculate)"
fi
grep -qx 'libqalculate' "$DOTFILES/packages/pacman.txt" && ok "libqalculate in the manifest" || no "libqalculate not in packages/pacman.txt"

# ---------------------------------------------------------------------------
hdr "Shell health"
# ---------------------------------------------------------------------------
bad=$(timeout 5 qs log 2>/dev/null | grep -E 'WARN|ERROR' | grep -v 'qalc' | head -3)
[[ -z $bad ]] && ok "qs log: no warnings or errors" || no "qs log: $bad"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 11 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 11 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
