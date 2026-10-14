//@ pragma UseQApplication
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

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }
}
