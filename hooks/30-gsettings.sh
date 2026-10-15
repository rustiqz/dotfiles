# ~/dotfiles/hooks/30-gsettings.sh
#
# Desktop-level settings that live in dconf rather than a config file.
# These apply under GNOME *and* Hyprland (GTK apps read the same values
# via xdg-desktop-portal / gsettings), so setting them once covers both.
#
# Idempotent: gsettings set is a no-op when the value already matches.

set -euo pipefail

# Dark theme preference — respected by GTK4/libadwaita apps.
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# GTK3 theme name. Install the package in packages/aur.txt first.
# gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark'

# Cursor theme and size — Hyprland also needs these exported as
# XCURSOR_THEME/XCURSOR_SIZE in the Hyprland config for consistent cursors
# across Wayland-native and XWayland apps.
# gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
# gsettings set org.gnome.desktop.interface cursor-size 24
