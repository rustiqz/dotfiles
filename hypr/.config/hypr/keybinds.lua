-- ~/dotfiles/hypr/.config/hypr/keybinds.lua
--
-- Every bind carries a `description`. `hyprctl binds -j` reports it, and
-- the Quickshell cheatsheet ($mod+/) renders it — so the sheet can never
-- drift from the real binds. Adding a bind = adding it here, with a
-- description; nothing else to update.
--
-- Options: `locked` = also works on the lock screen (volume/brightness
-- without unlocking); `repeating` = repeats while held; `mouse` = a drag
-- bind.
--
-- $mod is SUPER (Windows key): chosen over Alt so nothing here collides
-- with in-app Alt-combos (Alt+Tab, Alt+F4, ...) that muscle memory expects
-- to reach the application, not the compositor.

local mod      = "SUPER"
local terminal = "kitty"

-- bind(keys, dispatcher, description[, extra options])
local function bind(keys, dsp, desc, opts)
  opts = opts or {}
  opts.description = desc
  hl.bind(keys, dsp, opts)
end

-- Shorthand for the very common "run a command" bind.
local function exec(keys, cmd, desc, opts)
  bind(keys, hl.dsp.exec_cmd(cmd), desc, opts)
end

-- --- Launching ------------------------------------------------------------
-- `uwsm app --` launches each as its own scoped systemd unit rather than an
-- untracked child of Hyprland (see autostart.lua).
exec(mod .. " + Return", "uwsm app -- " .. terminal, "Terminal")

-- The Pokédex launcher (quickshell modules/launcher/Launcher.qml): apps,
-- plus / projects, > run, @ windows, = calc, : emoji. rofi itself stays
-- for the small pickers (clipboard, SSH, theme, emoji).
exec(mod .. " + D", "qs ipc call launcher toggle", "App launcher")

bind(mod .. " + Q", hl.dsp.window.close(), "Close window")
-- End the session through uwsm so its systemd units stop cleanly (the
-- Hyprland docs advise against the bare exit dispatcher under uwsm).
exec(mod .. " + SHIFT + E", "uwsm stop", "Exit Hyprland")

-- Dedicated launchers for apps opened often enough that going through the
-- launcher each time is friction.
exec(mod .. " + B", "uwsm app -- firefox",  "Firefox")
exec(mod .. " + E", "uwsm app -- nautilus", "Files (nautilus)")

-- Yazi — terminal file manager in a kitty window. A different tool for a
-- different moment than nautilus, not a replacement.
exec(mod .. " + Y", "uwsm app -- kitty --title yazi -e yazi", "Files (yazi)")

-- Power menu (quickshell modules/power/PowerMenu.qml): lock / suspend / log
-- out / reboot / shut down, keyboard-driven (l s e r p); reboot and shut
-- down need a second press. wlogout stays installed as the fallback:
-- `uwsm app -- wlogout -b 5`.
exec(mod .. " + P", "qs ipc call power toggle", "Power menu")

-- Emoji/unicode picker (Windows-convention Win+.).
exec(mod .. " + period", "uwsm app -- rofimoji", "Emoji picker")

-- SSH picker (bin/bin/ssh-connect) — rofi over ~/.ssh/config Host entries.
exec(mod .. " + S", "uwsm app -- ssh-connect", "SSH hosts")

-- k9s — cluster. C, not K: `$mod + K` is already focus-up, and two binds
-- differing only in case would compete for one physical key.
-- Launched with `kitty -e` and no login shell, so nothing from .zshrc
-- exists — which is why ~/.kube/config is a real symlink (see
-- hooks/54-do-config.sh) rather than a KUBECONFIG env var.
exec(mod .. " + C", 'uwsm app -- kitty --title "k9s" -e k9s', "Kubernetes (k9s)")

-- Spotify — just launches it; the bar and hub show/control playback.
exec(mod .. " + M", "uwsm app -- spotify", "Spotify")

-- Dev hub (quickshell modules/hub/Hub.qml) — agents, CI, services, ports,
-- watchers, quick controls, now-playing. Not wrapped in `uwsm app --`:
-- `qs ipc call` is a one-shot client, not an app to scope.
exec(mod .. " + Space", "qs ipc call hub toggle", "Dev hub")
exec(mod .. " + grave", "qs ipc call hub toggle", "Dev hub")

-- --- Window state -----------------------------------------------------------
bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mod .. " + F", hl.dsp.window.fullscreen(),                 "Fullscreen")

-- --- Focus / move / resize: vim-style hjkl (h=left j=down k=up l=right) ----
-- Matches Neovim muscle memory instead of reaching for the arrow cluster.
local dirs = {
  { key = "h", dir = "left",  name = "left",  resize = { x = -40, y = 0 },  rname = "Shrink width"  },
  { key = "j", dir = "down",  name = "down",  resize = { x = 0,   y = 40 }, rname = "Grow height"   },
  { key = "k", dir = "up",    name = "up",    resize = { x = 0,   y = -40 }, rname = "Shrink height" },
  { key = "l", dir = "right", name = "right", resize = { x = 40,  y = 0 },  rname = "Grow width"    },
}
for _, d in ipairs(dirs) do
  bind(mod .. " + " .. d.key,                 hl.dsp.focus({ direction = d.dir }),         "Focus " .. d.name)
  bind(mod .. " + SHIFT + " .. d.key,         hl.dsp.window.move({ direction = d.dir }),   "Move window " .. d.name)
  bind(mod .. " + CTRL + " .. d.key,
       hl.dsp.window.resize({ x = d.resize.x, y = d.resize.y, relative = true }),
       d.rname, { repeating = true })
end

-- Window cycling (alt-tab equivalent) on the current workspace; SHIFT
-- reverses, same convention as Tab/Shift+Tab everywhere else.
bind(mod .. " + Tab",         hl.dsp.window.cycle_next(),                "Next window")
bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), "Previous window")

-- --- Workspaces: 1-9, then 0 for 10 ------------------------------------------
for i = 1, 10 do
  local key = i % 10
  bind(mod .. " + " .. key,           hl.dsp.focus({ workspace = i }),       "Workspace " .. i)
  bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }), "Move to workspace " .. i)
end

-- Mouse wheel over the desktop with $mod held flips workspaces — pairs with
-- the 3-finger swipe gesture in input.lua.
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")

-- --- Mouse: SUPER + drag to move/resize without needing the border -----------
bind(mod .. " + mouse:272", hl.dsp.window.drag(),   "Drag window",   { mouse = true })  -- left button
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })  -- right button

-- --- Laptop hardware keys ----------------------------------------------------
-- Brightness: sysfs backlight emits no change event the bar could watch, so
-- the binds poke the dev island OSD over Quickshell IPC after setting the
-- level. Volume the bar picks up from PipeWire on its own. `repeating` so
-- holding the key ramps smoothly.
local hw = { locked = true, repeating = true }
exec("XF86MonBrightnessUp",   "brightnessctl set 5%+ && qs ipc call bar brightness", "Brightness up",   hw)
exec("XF86MonBrightnessDown", "brightnessctl set 5%- && qs ipc call bar brightness", "Brightness down", hw)

-- Volume via wpctl (WirePlumber's CLI). @DEFAULT_AUDIO_SINK@ follows
-- whatever PipeWire currently considers the default output.
exec("XF86AudioRaiseVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+", "Volume up",   hw)
exec("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "Volume down", hw)
exec("XF86AudioMute",        "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "Mute", { locked = true })

-- Media keys (playerctl drives whichever MPRIS player is active).
exec("XF86AudioPlay",    "playerctl play-pause", "Play / pause",    { locked = true })
exec("XF86AudioNext",    "playerctl next",       "Next track",      { locked = true })
exec("XF86AudioPrev",    "playerctl previous",   "Previous track",  { locked = true })
exec("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "Mute microphone", { locked = true })

-- --- Lock screen + wallpaper picker -------------------------------------------
-- Not $mod+L: hjkl already claims plain/SHIFT/CTRL "l". Same command
-- hypridle's own lock_cmd runs, just triggerable on demand.
exec(mod .. " + Escape", "loginctl lock-session",         "Lock screen")
exec(mod .. " + W",      "qs ipc call wallpapers toggle", "Wallpaper picker")

-- Whole-desktop theme switcher (bin/bin/theme); no-args form pops its own
-- rofi picker over themes/*/.
exec(mod .. " + SHIFT + T", "uwsm app -- theme", "Theme picker")

-- --- Screenshots (bin/bin/screenshot) ------------------------------------------
-- Bare Print / $mod+Print: region — the everyday screenshot, so it gets the
-- plain key. SHIFT selects screen/window; CTRL adds the swappy annotate step.
exec("Print",                         "uwsm app -- screenshot region",          "Screenshot region")
exec(mod .. " + CTRL + Print",        "uwsm app -- screenshot region --edit",   "Screenshot region + edit")
exec(mod .. " + SHIFT + Print",       "uwsm app -- screenshot screen",          "Screenshot screen")
exec(mod .. " + SHIFT + CTRL + Print","uwsm app -- screenshot screen --edit",    "Screenshot screen + edit")
exec(mod .. " + Print",               "uwsm app -- screenshot window",          "Screenshot window")
exec(mod .. " + ALT + Print",         "uwsm app -- screenshot window --edit",   "Screenshot window + edit")

-- --- Clipboard history (cliphist; watchers in autostart.lua) ---------------------
-- $mod+V is toggle-floating, so CTRL is added to keep the "V" mnemonic.
-- `-display-columns 2` hides cliphist's numeric entry ID from the rofi list
-- (it's needed internally to decode the exact original bytes).
-- Quickshell popup (modules/clipboard/); deleting entries also works there (Del),
-- the rofi picker below stays as a fallback.
exec(mod .. " + CTRL + V", "qs ipc call clipboard toggle", "Clipboard history")
exec(mod .. " + CTRL + SHIFT + V",
     "sh -c 'cliphist list | rofi -dmenu -display-columns 2 | cliphist delete'",
     "Delete clipboard entry")

-- --- Shell extras ---------------------------------------------------------------
-- Cheatsheet: every bind above, grouped and searchable — read live from
-- `hyprctl binds -j` (quickshell modules/cheatsheet/Cheatsheet.qml).
exec(mod .. " + slash",         "qs ipc call cheatsheet toggle", "Keybind cheatsheet")
exec(mod .. " + SHIFT + slash", "qs ipc call cheatsheet vim",    "Vim / nvim cheatsheet")

-- Notification centre — same panel as the bar's bell icon (Quickshell is
-- the notification daemon).
exec(mod .. " + N", "qs ipc call notifs toggle", "Notification centre")

-- Open-window search (rofi window mode) — faster than Tab-cycling once
-- windows are spread over several workspaces.
exec(mod .. " + R", "uwsm app -- rofi -show window", "Search open windows")

-- Dropdown terminal on a special workspace: $mod+Z toggles it over
-- whatever you're doing without disturbing the tiled layout. The
-- on_created_empty rule spawns it the first time, so it needs no
-- autostart entry; windowrules.lua floats/centres it by its title.
hl.workspace_rule({
  workspace        = "special:scratch",
  on_created_empty = "uwsm app -- kitty --title scratchpad",
})
bind(mod .. " + Z",         hl.dsp.workspace.toggle_special("scratch"),          "Dropdown terminal")
bind(mod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:scratch" }), "Send window to scratchpad")

-- --- Display mirroring (bin/bin/hdmi-mirror) --------------------------------------
-- monitors.lua keeps its wildcard so the repo stays machine-agnostic, and
-- `auto` means every external output *extends* by default. This toggles
-- the external between mirror and extend at runtime. SHIFT on $mod+M's
-- "M" keeps the mnemonic for "mirror".
exec(mod .. " + SHIFT + M", "uwsm app -- hdmi-mirror", "Toggle display mirroring")
