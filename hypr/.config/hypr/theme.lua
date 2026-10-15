-- ~/dotfiles/hypr/.config/hypr/theme.lua
--
-- Theme colours for the compositor. The single source of truth stays
-- active-theme.conf (a symlink bin/bin/theme repoints, see
-- themes/<name>/hyprland.conf) because hyprlock — which is still
-- hyprlang — sources the same file for its $lock_* variables. Rather than
-- keep two palettes in sync, read the `$name = value` lines out of it here.
-- bin/bin/theme runs `hyprctl reload` after repointing, which re-runs
-- this file, so switching themes still applies live.

local M = {}

local f = io.open(os.getenv("HOME") .. "/.config/hypr/active-theme.conf", "r")
if f then
  for line in f:lines() do
    local name, value = line:match("^%$([%w_]+)%s*=%s*(.-)%s*$")
    if name then M[name] = value end
  end
  f:close()
end

-- Fallbacks so a missing/empty theme file degrades to visible borders
-- instead of a Lua error at startup (TokyoNight's values).
M.border_active   = M.border_active   or "rgb(7aa2f7)"
M.border_gradient = M.border_gradient or "rgb(bb9af7)"
M.border_inactive = M.border_inactive or "rgb(292e42)"
M.shadow_color    = M.shadow_color    or "rgba(000000AB)"

return M
