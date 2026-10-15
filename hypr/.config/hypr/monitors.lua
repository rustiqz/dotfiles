-- ~/dotfiles/hypr/.config/hypr/monitors.lua
--
-- Display layout. An empty `output` is the wildcard: every monitor gets its
-- preferred mode, auto-placed, 1x scale (the laptop panel is 1080p — no
-- HiDPI scaling needed). Wildcard so this works unmodified on any
-- single-monitor machine this repo is replayed on; for a named layout,
-- `hyprctl monitors` lists the real output names (eDP-1, DP-1, ...).
hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = 1,
})
