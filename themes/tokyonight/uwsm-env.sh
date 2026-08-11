# themes/tokyonight/uwsm-env.sh
#
# Symlinked as ~/.config/uwsm/env-theme (bin/bin/theme repoints it) and
# sourced from the permanent uwsm/.config/uwsm/env (tracked, not
# swapped per-theme — see that file for why PATH and other non-theme
# vars had to be split out from this one).
#
# Per UWSM's own docs: "use ~/.config/uwsm/env for theming, xcursor,
# Nvidia and toolkit variables" (~/.config/uwsm/env-hyprland is for
# HYPR*/AQ_* variables specifically, and hyprland.conf's own `env =`
# should be avoided for anything else under UWSM).
export XCURSOR_THEME=Bibata-Modern-Ice
export XCURSOR_SIZE=24

# The actual bridge: without this, Qt apps (hyprpolkitagent included —
# this is what was leaving its auth dialog looking plain/unstyled
# earlier in Phase 5) have no platform theme plugin at all and fall
# back to Qt's own bare defaults, ignoring qt6ct/qt5ct entirely no
# matter how qt6ct.conf/qt5ct.conf are configured.
export QT_QPA_PLATFORMTHEME=qt6ct
