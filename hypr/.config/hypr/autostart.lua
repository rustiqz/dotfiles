-- ~/dotfiles/hypr/.config/hypr/autostart.lua
--
-- Runs once when Hyprland starts a session (the "hyprland.start" event —
-- not on config reload, like the old `exec-once`). Everything goes through
-- `uwsm app --` so each process is its own scoped systemd unit (proper
-- cgroup, clean shutdown on `uwsm stop`) instead of an untracked child of
-- Hyprland.
--
-- Deliberately NOT started here (units/D-Bus activation already do it, and
-- a second launch just races the real one): the xdg portals (D-Bus
-- activated under UWSM), nm-applet/blueman-applet (systemd's xdg-autostart
-- generator), hyprpolkitagent (WantedBy=graphical-session.target, enabled
-- in hooks/72-hyprpolkitagent.sh), and the notification daemon — Quickshell
-- owns org.freedesktop.Notifications (services/Notifs.qml). swaync stays
-- installed as the rollback: add `uwsm app -- swaync` here and restore its
-- bind in keybinds.lua; never run both. The dev hub is part of the `qs`
-- process below, hidden until toggled.

hl.on("hyprland.start", function()
  -- The bar, launcher, hub, notifications, lock-screen widgets: Quickshell
  -- (quickshell/.config/quickshell/). Rolling back to waybar is swapping
  -- this for `uwsm app -- waybar`.
  hl.exec_cmd("uwsm app -- qs")

  -- Clipboard history: two watchers, not one — per cliphist's FAQ a single
  -- `wl-paste --watch` only sees one MIME type reliably, so text and images
  -- each get their own.
  hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
  hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")

  -- Wallpaper daemon; reads hyprpaper.conf, which points at the .current
  -- symlink hooks/71-wallpaper.sh creates.
  hl.exec_cmd("uwsm app -- hyprpaper")

  -- Idle daemon: dim, lock, screen off, suspend (hypridle.conf). Its
  -- lock_cmd is hyprlock, so this one line covers both.
  hl.exec_cmd("uwsm app -- hypridle")
end)
