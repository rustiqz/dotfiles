-- ~/dotfiles/hypr/.config/hypr/hyprland.lua
--
-- Entry point. Hyprland 0.55+ prefers this file over hyprland.conf when it
-- exists (checked once at startup), and the hyprlang `.conf` format is
-- slated for removal in 0.57 — which is what the "you are using .conf"
-- popup on every start was warning about. Same split as before: one module
-- per concern, pulled in with require().
--
-- hyprlock, hypridle and hyprpaper are separate programs that still read
-- their own hyprlang .conf files; those stay as they are.
--
-- Reference: https://wiki.hypr.land/Configuring/Start/

-- Resolve modules next to this file regardless of the launch directory.
local dir = os.getenv("HOME") .. "/.config/hypr/"
package.path = dir .. "?.lua;" .. package.path

require("monitors")
require("input")
require("look")        -- reads colours via theme.lua
require("keybinds")
require("windowrules")
require("autostart")
