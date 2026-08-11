# themes/tokyonight/meta.sh
#
# Sourced by bin/bin/theme (not run directly). GTK theme/icon theme/
# cursor theme aren't config fragments like the CSS/rasi/conf files —
# there's no per-theme override file to symlink, just a name to pass to
# gsettings — so this is a plain shell variable file instead.
#
# Themes don't have to define this at all (f1/ doesn't yet) — the
# switcher skips the GTK/icon/cursor step entirely when a theme has no
# meta.sh, leaving whatever's currently set.

GTK_THEME_NAME="Tokyonight-Dark"
ICON_THEME_NAME="Papirus-Dark"

# Bibata-Modern-Ice specifically for its cool blue tint, closer to the
# TokyoNight accent than the other Bibata variants (Amber/Classic).
CURSOR_THEME_NAME="Bibata-Modern-Ice"
CURSOR_SIZE=24
