//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
// IconTheme: the same theme GTK uses (gsettings icon-theme). Without it
// Qt looked icons up in bare hicolor, so app icons in the launcher and
// workspace chips silently fell back or failed ("Could not load icon").
// A pragma: applies at startup only, a live reload won't pick it up.
// UseQApplication: tray menus (SystemTrayItem.display) are QMenus, which
// need a QApplication rather than the default QGuiApplication.

// Quickshell entry point (Phase 9+). One bar per monitor; later phases add
// the dev hub (10), launcher (11) and wallpaper cards (12) here.
//
// Live-reloads on save — editing any .qml under this directory reapplies
// without restarting, which is also why config errors show up as a popup
// rather than a crash. Started by hypr/autostart.conf via `uwsm app -- qs`.
import QtQuick
import Quickshell
import qs.modules.bar
import qs.modules.hub
import qs.modules.launcher
import qs.modules.cheatsheet
import qs.modules.power
import qs.modules.clipboard
import qs.modules.wallpaper
import qs.modules.external
import qs.modules.popovers
import qs.modules.notifications

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    // Dev hub — one instance, follows the focused monitor. Toggled with
    // $mod+Space (qs ipc call hub toggle), hidden until then.
    Hub {}

    // Pokédex launcher — $mod+D (qs ipc call launcher toggle).
    Launcher {}

    // Keybind cheatsheet — $mod+/ (qs ipc call cheatsheet toggle).
    Cheatsheet {}

    // Clipboard history — $mod+Ctrl+V and the bar's clipboard glyph (qs ipc call clipboard toggle).
    Clipboard {}

    // Power menu — $mod+P and the bar's power glyph (qs ipc call power toggle).
    PowerMenu {}

    // Wallpaper picker as Pokémon cards — $mod+W (qs ipc call wallpapers toggle).
    Wallpapers {}

    // Bar popovers — hang from the status island's icons (Pops picks which).
    WifiPopover {}
    BluetoothPopover {}
    AudioPopover {}
    BatteryPopover {}
    SystemPopover {}
    CalendarPopover {}
    NotificationPopover {}
    DevPopover {}
    MediaPopover {}

    // Notification popups — Quickshell is the notification daemon (services/Notifs.qml).
    Toasts {}

    // Click-outside-to-close for rofi and wlogout (not ours, so watched via
    // Hyprland layer events) — same behaviour as every popup above.
    ExternalScrim {}
}
