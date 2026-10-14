import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.widgets

// Left island: Arch launcher button, workspace chips with app icons, and
// the focused window's title.
//
// Workspaces 1–5 always show (muscle memory: the slot for "5" is always in
// the same place), plus any higher-numbered one that currently exists.
// Occupied workspaces show up to three distinct app icons; empty ones
// collapse to a dot. The focused one is an accent-tinted pill, and the
// width change animates (Hover's implicitWidth Behavior), so focus visibly
// slides between chips instead of hopping.
Island {
    id: root
    spacing: 4
    hpad: 6

    readonly property int minShown: 5
    readonly property var wsList: Hyprland.workspaces.values.filter(w => w.id > 0)
    readonly property int maxId: Math.max(minShown, ...wsList.map(w => w.id))
    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // Window classes are in lastIpcObject, which Quickshell only fills on a
    // refresh — re-pull on the events that change which window is where.
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2",
                 "windowtitle", "windowtitlev2"].includes(ev.name))
                Hyprland.refreshToplevels()
        }
    }
    Component.onCompleted: Hyprland.refreshToplevels()

    function wsById(id) { return wsList.find(w => w.id === id) || null }

    function iconFor(cls) {
        if (!cls) return ""
        const entry = DesktopEntries.heuristicLookup(cls)
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : cls.toLowerCase(), "application-x-executable")
    }

    // Launcher button — same Pokédex launcher as $mod+D; right-click opens
    // it straight into projects mode.
    Hover {
        hpad: 8
        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "launcher", "toggle"])
        onRightClicked: Quickshell.execDetached(["qs", "ipc", "call", "launcher", "openWith", "/"])
        Txt { text: Icons.arch; color: Theme.accent; font.pixelSize: Theme.iconSize + 2 }
    }

    Repeater {
        model: root.maxId
        delegate: Hover {
            id: chip
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: root.wsById(wsId)
            readonly property var classes: {
                if (!ws) return []
                const seen = []
                for (const t of ws.toplevels.values) {
                    const c = t.lastIpcObject && t.lastIpcObject.class
                    if (c && !seen.includes(c)) seen.push(c)
                }
                return seen.slice(0, 3)
            }
            readonly property bool focused: wsId === root.focusedId
            readonly property bool occupied: classes.length > 0

            visible: wsId <= root.minShown || ws !== null
            active: focused
            activeColor: Theme.alpha(Theme.accent, 0.22)
            hpad: occupied || focused ? 7 : 4
            spacing: 4
            onClicked: Hyprland.dispatch(`workspace ${wsId}`)
            onScrolled: (d) => Hyprland.dispatch(d > 0 ? "workspace e-1" : "workspace e+1")

            // Number only on the focused chip — the slot position already
            // tells you which one the others are.
            Txt {
                visible: chip.focused
                text: chip.wsId
                color: Theme.accent
                font.bold: true
            }
            Repeater {
                model: chip.classes
                delegate: IconImage {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 15
                    source: root.iconFor(modelData)
                    opacity: chip.focused ? 1 : 0.7
                }
            }
            Rectangle {
                visible: !chip.occupied && !chip.focused
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: Theme.muted
            }
        }
    }

    Rectangle {
        width: 1; height: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.alpha(Theme.border, 0.8)
        visible: title.text !== ""
    }

    Txt {
        id: title
        readonly property var win: Hyprland.activeToplevel
        text: win && win.workspace && win.workspace.id === root.focusedId ? win.title : ""
        color: Theme.subtle
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 260)
        rightPadding: 4
    }
}
