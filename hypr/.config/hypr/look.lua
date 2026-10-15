-- ~/dotfiles/hypr/.config/hypr/look.lua
--
-- Visual styling: gaps, borders, rounding, blur, animations. No hardcoded
-- colours — they come from theme.lua (which reads the active-theme.conf
-- symlink bin/bin/theme repoints).
--
-- Design direction ("floating glass"): every surface is a soft,
-- heavily-rounded card floating off the wallpaper, never a slab glued to
-- a screen edge:
--   - one shared corner radius (14px) across windows, bar, drawer, rofi
--   - gaps wide enough that the wallpaper frames every window
--   - a two-colour gradient on the focused border instead of a flat line
--   - a large, low-opacity shadow (depth) rather than a tight dark one

local theme = require("theme")

hl.config({
  general = {
    gaps_in     = 6,    -- between adjacent windows
    gaps_out    = 12,   -- between windows and the screen edge (matches the bar's island margin)
    border_size = 2,

    -- Gradient: theme accent fading into its secondary hue at 45deg.
    -- The `borderangle` animation below rotates it slowly, so focus is
    -- obvious at a glance without a thicker border.
    col = {
      active_border   = { colors = { theme.border_active, theme.border_gradient }, angle = 45 },
      inactive_border = theme.border_inactive,
    },

    resize_on_border = true,   -- grab a border with the mouse, not just mod+drag
    layout           = "dwindle",
  },

  decoration = {
    rounding       = 14,
    rounding_power = 2.4,   -- >2 = squircle-ish corners instead of circular arcs

    active_opacity   = 1.0,
    inactive_opacity = 0.96,   -- unfocused windows recede very slightly
    dim_inactive     = false,

    -- Blur behind anything translucent (kitty's background_opacity, the
    -- bar islands, rofi, the dev hub — layers opt in via layer_rule in
    -- windowrules.lua). 3 passes at size 6 looks frosted rather than
    -- smeared on a Gen9.5 iGPU; higher costs frame time for no visible gain.
    blur = {
      enabled           = true,
      size              = 6,
      passes            = 3,
      new_optimizations = true,
      xray              = false,   -- blur what's actually behind, not just wallpaper
      noise             = 0.02,    -- a hint of grain stops gradients banding
      contrast          = 1.0,
      brightness        = 0.9,
      vibrancy          = 0.2,     -- keeps wallpaper colour alive through the blur
      popups            = true,    -- right-click menus get the same frosted look
    },

    shadow = {
      enabled        = true,
      range          = 24,
      render_power   = 3,                  -- softer falloff than the default 2
      offset         = "0 6",              -- light from above — shadow sits below
      color          = theme.shadow_color,
      color_inactive = "rgba(00000033)",
    },
  },

  animations = { enabled = true },

  dwindle = {
    preserve_split = true,   -- a split's direction survives window closes
  },

  misc = {
    disable_hyprland_logo         = true,    -- the default wallpaper flashes before hyprpaper paints
    disable_splash_rendering      = true,
    animate_manual_resizes        = true,
    animate_mouse_windowdragging  = false,   -- dragging tracks the cursor 1:1
    focus_on_activate             = true,    -- clicking a link focuses the browser
  },
})

-- Animations: Material 3 easing curves, so things decelerate into place
-- instead of sliding linearly. `overshot` gives workspace switches a tiny
-- settle-bounce; windows pop in from 80%.
hl.curve("md3_standard", { type = "bezier", points = { { 0.2, 0.0 },  { 0, 1.0 } } })
hl.curve("md3_decel",    { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("overshot",     { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("linear",       { type = "bezier", points = { { 0, 0 },      { 1, 1 } } })

hl.animation({ leaf = "windows",          enabled = true, speed = 3,  bezier = "md3_decel",    style = "popin 80%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3,  bezier = "md3_standard", style = "popin 80%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 3,  bezier = "md3_decel" })
hl.animation({ leaf = "border",           enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle",      enabled = true, speed = 80, bezier = "linear",       style = "loop" })  -- the slow gradient shimmer
hl.animation({ leaf = "fade",             enabled = true, speed = 3,  bezier = "md3_decel" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 3,  bezier = "md3_decel",    style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2,  bezier = "md3_standard", style = "fade" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4,  bezier = "overshot",     style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3,  bezier = "md3_decel",    style = "slidevert" })
