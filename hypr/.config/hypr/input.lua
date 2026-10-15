-- ~/dotfiles/hypr/.config/hypr/input.lua
--
-- Keyboard and touchpad. Values mirror the machine's former GNOME settings
-- so switching sessions doesn't change how typing/scrolling feels.
hl.config({
  input = {
    kb_layout = "us",

    -- Repeat behaviour for held keys — defaults, listed so they're one
    -- place to tune.
    repeat_rate  = 25,
    repeat_delay = 600,

    touchpad = {
      natural_scroll = true,   -- content follows finger direction
      tap_to_click   = true,   -- tap = click
    },
  },
})

-- 3-finger horizontal swipe switches workspaces. (The old on/off
-- `workspace_swipe` option was removed in the 0.51 gesture rework in favour
-- of explicit gesture binds.)
hl.gesture({
  fingers   = 3,
  direction = "horizontal",
  action    = "workspace",
})
