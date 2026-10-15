-- ~/dotfiles/hypr/.config/hypr/windowrules.lua
--
-- Per-application overrides (window_rule) and per-layer effects
-- (layer_rule: the bar, launcher, hub — layer-shell surfaces, not windows).
-- Each rule is one table: `match` selects, every other key is an effect.
-- Regexes are the same ones the old windowrule/layerrule lines used.
--
-- Reference: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- --- Small utility windows float, centred, at a sane size ---------------
-- "Settings dialogs", not workspaces-worth of app: tiling them just shoves
-- whatever you were working on aside for a 10-second tweak.
hl.window_rule({
  name  = "utility-windows",
  match = { class = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol|blueman-manager|\\.blueman-manager-wrapped|nm-connection-editor|qt5ct|qt6ct|nwg-look|xdg-desktop-portal-gtk|org\\.gnome\\.Calculator)$" },
  float  = true,
  size   = "60% 60%",
  center = true,
})

-- File pickers / save dialogs (portal or app-native). Matched on title
-- because every toolkit reuses the parent app's class for these.
hl.window_rule({
  name  = "file-dialogs",
  match = { title = "^(Open File|Open Folder|Save As|Save File|File Upload|Choose Files|Select a File)(.*)$" },
  float  = true,
  center = true,
})

-- Firefox picture-in-picture: float, pin (every workspace), park in the
-- bottom-right corner, keep its aspect ratio.
hl.window_rule({
  name  = "firefox-pip",
  match = { title = "^(Picture-in-Picture)$" },
  float             = true,
  pin               = true,
  keep_aspect_ratio = true,
  size              = "25% 25%",
  move              = "74% 72%",
})

-- Dropdown terminal (special workspace "scratch", $mod+Z in keybinds.lua).
-- The title is set by that workspace's on_created_empty command, which is
-- how it's told apart from every other kitty window.
hl.window_rule({
  name  = "scratchpad",
  match = { title = "^(scratchpad)$" },
  float  = true,
  size   = "70% 60%",
  center = true,
})

-- Video players and browsers decide their own opacity — the global
-- inactive_opacity (look.lua) dimming a paused film looks like a bug.
hl.window_rule({
  name  = "opaque-media",
  match = { class = "^(mpv|firefox|org\\.mozilla\\.firefox|spotify|Spotify)$" },
  opacity = "1.0 override 1.0 override",
})

-- Fullscreen apps (games, video) shouldn't let hypridle lock the screen.
hl.window_rule({
  name  = "idle-inhibit-fullscreen",
  match = { class = ".*" },
  idle_inhibit = "fullscreen",
})

-- --- Layer surfaces: blur behind the shell's own pieces ------------------
-- Matched on the layer-shell namespace each one registers. `ignore_alpha`
-- stops blur bleeding through the fully transparent gaps between the bar's
-- floating islands — without it the whole strip, gaps included, gets a
-- frosted rectangle behind it.
hl.layer_rule({
  name  = "bar",
  match = { namespace = "^(quickshell-bar|waybar)$" },
  blur = true, ignore_alpha = 0.2,
})

-- Dev hub drawer (quickshell modules/hub/Hub.qml). Without blur the
-- windows' text showed straight through the 93%-opaque panel.
hl.layer_rule({
  name  = "hub",
  match = { namespace = "^(quickshell-hub)$" },
  blur = true, ignore_alpha = 0.2,
})

-- Centred popups (wallpaper cards, launcher, cheatsheet, power menu): blur
-- the whole backdrop through their click-outside scrim so the popup reads
-- as modal. ignore_alpha sits below the scrims' dim (0.18 to 0.45) so the
-- blur always applies. The hub's scrim is deliberately left out — a side
-- drawer you glance at, not a modal.
hl.layer_rule({
  name  = "modal-scrims",
  match = { namespace = "^(quickshell-(wallpapers|launcher|cheatsheet|power|clipboard)-scrim)$" },
  blur = true, ignore_alpha = 0.05,
})

hl.layer_rule({
  name  = "rofi",
  match = { namespace = "^(rofi)$" },
  blur = true, ignore_alpha = 0.2,
  dim_around = true,   -- focus the launcher
})

hl.layer_rule({
  name  = "swaync",
  match = { namespace = "^(swaync-control-center|swaync-notification-window)$" },
  blur = true, ignore_alpha = 0.2,
})

hl.layer_rule({
  name  = "wlogout",
  match = { namespace = "^(logout_dialog)$" },
  blur = true,
})
