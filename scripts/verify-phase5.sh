#!/usr/bin/env bash
#
# verify-phase5.sh — assert that Phase 5 (Hyprland) is fully applied.
#
# Read-only: makes no changes, so it is safe to run any time. Exit
# criterion for Phase 5, same pass/fail/warn pattern as the earlier
# verify-phase*.sh scripts.
#
# Some checks only make sense inside a live Hyprland session (running
# processes, hyprctl) — those are gated on $IN_SESSION and degrade to a
# single warning rather than a wall of failures when run from a TTY or
# over SSH.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh for why the
# postfix form causes a false failure on each counter's first increment.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

chk_pkg() {
  pacman -Qq "$1" &>/dev/null && ok "package $1" || no "package $1 MISSING"
}

# Assert $1 (a path under $HOME) resolves into this repo. Not an `-L`
# check on $path itself — see verify-phase2.sh for why (stow
# tree-folding). Doubles as the check for bin/bin/theme's runtime
# active-theme.* symlinks below, which resolve into the repo the same
# way even though they're gitignored, not stowed.
chk_link() {
  local path=$1
  if [[ -e $path || -L $path ]]; then
    local target
    target=$(realpath -e "$path" 2>/dev/null) || { no "$path is a broken symlink"; return; }
    [[ $target == "$DOTFILES"/* ]] && ok "linked: $path" \
                                    || no "$path exists but resolves outside this repo ($target) — stray file?"
  else
    no "$path missing"
  fi
}

# Assert a systemd --user unit is enabled and active in one go — every
# Phase 5 unit check needs both, unlike Phase 1's socket-activated
# services where "disabled but active" is correct.
chk_user_unit() {
  local state
  state=$(systemctl --user is-enabled "$1" 2>&1)
  [[ $state == enabled* ]] && ok "unit $1 enabled" || no "unit $1 not enabled ($state)"
  systemctl --user is-active --quiet "$1" && ok "unit $1 active" \
                                           || no "unit $1 not active ($(systemctl --user is-active "$1" 2>&1))"
}

# Live session detection: hyprctl only answers from inside the session
# it belongs to, so this is the cheapest reliable signal that the
# process-list/hyprctl-dependent checks below can actually run.
IN_SESSION=0
command -v hyprctl &>/dev/null && hyprctl version &>/dev/null && IN_SESSION=1

# ---------------------------------------------------------------------------
hdr "Packages — compositor & session"
# ---------------------------------------------------------------------------
for p in hyprland xdg-desktop-portal-hyprland qt5-wayland qt6-wayland \
         hyprlock hypridle hyprpaper hyprpolkitagent qqc2-desktop-style; do
  chk_pkg "$p"
done

# ---------------------------------------------------------------------------
hdr "Packages — bar, launcher, notifications, clipboard, screenshots"
# ---------------------------------------------------------------------------
for p in waybar rofi blueman network-manager-applet swaync cliphist \
         grim slurp swappy; do
  chk_pkg "$p"
done

# ---------------------------------------------------------------------------
hdr "Packages — theming & quick-access"
# ---------------------------------------------------------------------------
for p in papirus-icon-theme qt6ct qt5ct tokyonight-gtk-theme-git \
         bibata-cursor-theme-bin ttf-press-start-2p wlogout rofimoji matugen; do
  chk_pkg "$p"
done

# ---------------------------------------------------------------------------
hdr "GDM session entry"
# ---------------------------------------------------------------------------
[[ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] \
  && ok "hyprland-uwsm.desktop registered" \
  || no "hyprland-uwsm.desktop missing — reinstall hyprland?"

# ---------------------------------------------------------------------------
hdr "Stow links — static config"
# ---------------------------------------------------------------------------
for f in hyprland.conf autostart.conf keybinds.conf look.conf input.conf \
         monitors.conf windowrules.conf hyprlock.conf hypridle.conf hyprpaper.conf; do
  chk_link "$HOME/.config/hypr/$f"
done
chk_link "$HOME/.config/waybar/config.jsonc"
chk_link "$HOME/.config/waybar/style.css"
chk_link "$HOME/.config/rofi/config.rasi"
chk_link "$HOME/.config/swaync/style.css"
chk_link "$HOME/.config/swaync/config.json"
chk_link "$HOME/.config/wlogout/layout"
chk_link "$HOME/.config/wlogout/style.css"
chk_link "$HOME/.config/qt6ct/qt6ct.conf"
chk_link "$HOME/.config/qt5ct/qt5ct.conf"
chk_link "$HOME/.config/uwsm/env"
chk_link "$HOME/.config/uwsm/env-hyprland"
chk_link "$HOME/bin/theme"
chk_link "$HOME/bin/wallpaper"
chk_link "$HOME/bin/screenshot"
chk_link "$HOME/.local/share/wallpapers/tokyonight-mountains.png"
chk_link "$HOME/.local/share/wallpapers/.current"

# ---------------------------------------------------------------------------
hdr "Whole-desktop theme switcher (bin/bin/theme)"
# ---------------------------------------------------------------------------
# active-theme.* are runtime state (gitignored, repointed by bin/bin/theme
# on every switch) rather than stow output, but they resolve into the
# repo the same way, so chk_link still applies.
chk_link "$HOME/.config/kitty/active-theme.conf"
chk_link "$HOME/.config/waybar/active-theme.css"
chk_link "$HOME/.config/rofi/active-theme.rasi"
chk_link "$HOME/.config/hypr/active-theme.conf"
chk_link "$HOME/.config/swaync/active-theme.css"
chk_link "$HOME/.config/wlogout/active-theme.css"
chk_link "$HOME/.config/qt6ct/colors/active-theme.conf"
chk_link "$HOME/.config/qt5ct/colors/active-theme.conf"
chk_link "$HOME/.config/uwsm/env-theme"

# ---------------------------------------------------------------------------
hdr "Wallpaper-driven theme (matugen)"
# ---------------------------------------------------------------------------
# matugen/ is generation input (bin/bin/theme reads it via `matugen
# --config`), not a stow package — not a symlink into $HOME, so a plain
# -f check, not chk_link. Not invoking `bin/bin/theme wallpaper` itself
# here: that has real side effects (restarts waybar, reloads Hyprland,
# repoints active-theme.* symlinks), which breaks this script's own
# read-only contract.
[[ -f $DOTFILES/matugen/config.toml ]] && ok "matugen/config.toml present" \
                                        || no "matugen/config.toml missing"
for t in kitty.conf waybar.css rofi.rasi hyprland.conf swaync.css \
         wlogout.css qt-colors.conf; do
  [[ -f $DOTFILES/matugen/templates/$t.tpl ]] && ok "template: $t.tpl" \
                                               || no "template missing: $t.tpl"
done

# Which theme is active, by resolving one of the symlinks above back to
# its themes/<name>/ parent dir — kitty's is picked arbitrarily, every
# theme defines it (see bin/bin/theme's own header on partial themes).
ACTIVE_THEME=""
if [[ -L $HOME/.config/kitty/active-theme.conf ]]; then
  target=$(realpath -e "$HOME/.config/kitty/active-theme.conf" 2>/dev/null) || true
  [[ -n ${target:-} ]] && ACTIVE_THEME=$(basename "$(dirname "$target")")
fi
if [[ -n $ACTIVE_THEME ]]; then
  ok "active theme: $ACTIVE_THEME"
else
  no "no active theme set — run: bin/bin/theme tokyonight"
fi

# ---------------------------------------------------------------------------
hdr "GTK / icon / cursor theme (gsettings, from the active theme's meta.sh)"
# ---------------------------------------------------------------------------
if [[ -n $ACTIVE_THEME && -f $DOTFILES/themes/$ACTIVE_THEME/meta.sh ]]; then
  # shellcheck source=/dev/null
  source "$DOTFILES/themes/$ACTIVE_THEME/meta.sh"
  actual_gtk=$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")
  actual_icon=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
  actual_cursor=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
  actual_size=$(gsettings get org.gnome.desktop.interface cursor-size)
  [[ $actual_gtk    == "${GTK_THEME_NAME:-$actual_gtk}"       ]] && ok "gtk-theme: $actual_gtk"    || no "gtk-theme is $actual_gtk, expected $GTK_THEME_NAME"
  [[ $actual_icon   == "${ICON_THEME_NAME:-$actual_icon}"     ]] && ok "icon-theme: $actual_icon"   || no "icon-theme is $actual_icon, expected $ICON_THEME_NAME"
  [[ $actual_cursor == "${CURSOR_THEME_NAME:-$actual_cursor}" ]] && ok "cursor-theme: $actual_cursor" || no "cursor-theme is $actual_cursor, expected $CURSOR_THEME_NAME"
  [[ $actual_size   == "${CURSOR_SIZE:-$actual_size}"         ]] && ok "cursor-size: $actual_size"  || no "cursor-size is $actual_size, expected $CURSOR_SIZE"
elif [[ -n $ACTIVE_THEME ]]; then
  wa "theme '$ACTIVE_THEME' has no meta.sh — GTK/icon/cursor not managed by it (fine if intentionally partial)"
else
  wa "no active theme — skipping GTK/icon/cursor comparison"
fi

# ---------------------------------------------------------------------------
hdr "Hyprland's live environment (session-start-scoped, needs relogin to update)"
# ---------------------------------------------------------------------------
# The actual regression guard for the $mod+W "command not found:
# wallpaper" bug: uwsm app resolves commands against Hyprland's own
# *inherited* process environment, which is fixed at Hyprland's own
# startup and can't be patched live — only a full session relogin
# updates it, even after uwsm/.config/uwsm/env itself is fixed on disk.
HPID=$(pgrep -x Hyprland | head -1)
if [[ -n $HPID ]]; then
  henv=$(tr '\0' '\n' < "/proc/$HPID/environ" 2>/dev/null)
  grep -q "^PATH=.*$HOME/bin" <<<"$henv" \
    && ok "Hyprland's PATH includes ~/bin" \
    || no "Hyprland's PATH is stale (no ~/bin) — log out and back in"
  grep -q "^QT_QPA_PLATFORMTHEME=qt6ct$" <<<"$henv" \
    && ok "Hyprland's QT_QPA_PLATFORMTHEME=qt6ct" \
    || no "QT_QPA_PLATFORMTHEME missing/stale in Hyprland's environment — log out and back in"
  grep -q "^XCURSOR_THEME=" <<<"$henv" \
    && ok "Hyprland's XCURSOR_THEME is set" \
    || no "XCURSOR_THEME missing in Hyprland's environment — log out and back in"
else
  wa "Hyprland not running — skipping live-environment checks"
fi

# ---------------------------------------------------------------------------
hdr "systemd --user services"
# ---------------------------------------------------------------------------
chk_user_unit hyprpolkitagent.service

if pacman -Qq dunst &>/dev/null; then
  state=$(systemctl --user is-enabled dunst.service 2>/dev/null || true)
  [[ $state == masked ]] && ok "dunst.service masked (swaync owns notifications)" \
                          || no "dunst.service not masked ($state) — races swaync for org.freedesktop.Notifications"
else
  ok "dunst not installed, nothing to mask"
fi

systemctl --user list-unit-files 'xdg-desktop-portal-hyprland.service' --no-legend 2>/dev/null | grep -q . \
  && ok "xdg-desktop-portal-hyprland unit registered" \
  || no "xdg-desktop-portal-hyprland unit not found"

# ---------------------------------------------------------------------------
hdr "Autostart processes (exec-once in hypr/autostart.conf, live session only)"
# ---------------------------------------------------------------------------
if (( IN_SESSION )); then
  pgrep -x waybar    &>/dev/null && ok "waybar running"    || no "waybar not running"
  pgrep -x swaync     &>/dev/null && ok "swaync running"    || no "swaync not running"
  pgrep -x hyprpaper &>/dev/null && ok "hyprpaper running" || no "hyprpaper not running"
  pgrep -x hypridle  &>/dev/null && ok "hypridle running"  || no "hypridle not running"

  n=$(pgrep -cf 'wl-paste --type (text|image) --watch cliphist store' || true)
  (( n >= 2 )) && ok "cliphist watchers running ($n)" \
               || no "cliphist watchers: expected 2 (text+image), found ${n:-0}"

  # Tray applets: not exec-once (systemd-xdg-autostart-generator starts
  # these from their own .desktop files — see autostart.conf's comment
  # on why an exec-once here would just race that), but still worth
  # confirming they're actually up.
  pgrep -f nm-applet       &>/dev/null && ok "nm-applet running"       || wa "nm-applet not running"
  pgrep -f blueman-applet  &>/dev/null && ok "blueman-applet running" || wa "blueman-applet not running"

  if command -v swaync-client &>/dev/null; then
    swaync-client --reload-css &>/dev/null && ok "swaync-client reaches the daemon" \
                                            || no "swaync-client can't reach swaync"
  fi
else
  wa "not running inside a live Hyprland session — skipping autostart process checks"
fi

# ---------------------------------------------------------------------------
hdr "Cleanup"
# ---------------------------------------------------------------------------
# dolphin got pulled in alongside nautilus while deciding which file
# manager $mod+E should open (nautilus won) — not required by anything,
# safe to prune whenever.
pacman -Qq dolphin &>/dev/null && wa "dolphin installed but unused (nautilus is the tracked \$mod+E target)" \
                                || ok "no stray dolphin install"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 5 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 5 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
