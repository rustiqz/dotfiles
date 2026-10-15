import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.widgets

// Click-outside-to-close for popups Quickshell doesn't own: the rofi
// pickers (clipboard, SSH, theme, emoji, window search) and wlogout.
//
// rofi 2.0's Wayland backend can't see clicks outside its own window, and
// wlogout doesn't try, so unlike the Quickshell popups they stayed open
// until Escape. Rather than wrapping every caller, this watches Hyprland's
// own layer events: `openlayer>>NAMESPACE` / `closelayer>>NAMESPACE`
// arrive for every layer-shell surface, whoever made it. While one of the
// namespaces below is mapped, the shared Scrim (widgets/Scrim.qml, Top
// layer, under those Overlay surfaces) is shown; a click on it kills the
// owning process. Same dismissal behaviour as every Quickshell popup, no
// changes to the keybinds or to the scripts that call rofi.
Scope {
    id: scope

    // layer namespace -> process name to kill on an outside click
    readonly property var watched: ({ "rofi": "rofi", "logout_dialog": "wlogout" })
    property var mapped: ({})            // namespace -> true while its layer exists
    readonly property var active: Object.keys(mapped).filter(k => mapped[k])

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "openlayer" && ev.name !== "closelayer") return
            const ns = ev.data
            if (!(ns in scope.watched)) return
            const m = Object.assign({}, scope.mapped)
            m[ns] = ev.name === "openlayer"
            scope.mapped = m
        }
    }

    Scrim {
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        visible: scope.active.length > 0
        shown: visible
        WlrLayershell.namespace: "quickshell-external-scrim"
        onDismissed: {
            for (const ns of scope.active)
                Quickshell.execDetached(["pkill", "-x", scope.watched[ns]])
        }
    }
}
