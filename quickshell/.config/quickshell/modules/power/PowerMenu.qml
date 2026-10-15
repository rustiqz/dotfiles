import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.widgets

// Power menu ($mod+P, the bar's power glyph) — after surface-dots'
// "Cassini" menu: a small card, the session actions as a plain list on
// the left, the current wallpaper on the right, "@user · up 2h 14m" on
// top. Replaced wlogout (kept installed and themed as the fallback, same
// as waybar).
//
// Keys: j/k ↑/↓ move, Enter acts, or the action's letter directly
// (l s e r p). Reboot and shut down ask for a second press — a stray
// Enter in the wrong window shouldn't power the machine off.
//
// Every value is read at runtime: $USER, uptime, the wallpaper symlink.
// Nothing here knows which machine or account it's on.
Scope {
    id: scope

    Scrim {
        screen: menu.screen
        visible: menu.visible
        shown: menu.open
        dim: 0.4
        WlrLayershell.namespace: "quickshell-power-scrim"
        onDismissed: menu.open = false
    }

    PanelWindow {
        id: menu
        property bool open: false
        property int cursor: 0
        property int armed: -1          // index awaiting confirmation
        property string uptime: ""

        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        implicitWidth: 640
        implicitHeight: 330
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: open || fade.running
        WlrLayershell.namespace: "quickshell-power"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: if (open) { cursor = 0; armed = -1; uptimeProc.running = true; keys.forceActiveFocus() }

        IpcHandler {
            target: "power"
            function toggle(): void { menu.open = !menu.open }
        }

        Process {
            id: uptimeProc
            command: ["uptime", "-p"]
            stdout: StdioCollector { onStreamFinished: menu.uptime = text.trim() }
        }

        readonly property var actions: [
            { key: "l", name: "Lock", danger: false, cmd: ["loginctl", "lock-session"] },
            { key: "s", name: "Suspend", danger: false, cmd: ["systemctl", "suspend"] },
            // uwsm stop: ends the session cleanly (units stopped in order)
            // — same command wlogout's layout used.
            { key: "e", name: "Log out", danger: false, cmd: ["uwsm", "stop"] },
            { key: "r", name: "Reboot", danger: true, cmd: ["systemctl", "reboot"] },
            { key: "p", name: "Shut down", danger: true, cmd: ["systemctl", "poweroff"] },
        ]

        function run(i) {
            const a = actions[i]
            if (!a) return
            if (a.danger && armed !== i) { armed = i; cursor = i; return }   // first press arms
            open = false
            // After the menu is gone, so it isn't in the lock screen /
            // shutdown screenshot and the scrim isn't left behind.
            Qt.callLater(() => Quickshell.execDetached(a.cmd))
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.radius + 4
            color: Theme.alpha(Theme.surface, 0.97)
            border.width: 1
            border.color: Theme.alpha(Theme.border, 0.9)
            clip: true
            opacity: menu.open ? 1 : 0
            scale: menu.open ? 1 : 0.96
            Behavior on opacity { NumberAnimation { id: fade; duration: Theme.animMed } }
            Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: (e) => {
                    const k = e.text.toLowerCase()
                    if (e.key === Qt.Key_Escape) menu.open = false
                    else if (e.key === Qt.Key_Down || k === "j") { menu.cursor = (menu.cursor + 1) % menu.actions.length; menu.armed = -1 }
                    else if (e.key === Qt.Key_Up || k === "k") { menu.cursor = (menu.cursor + menu.actions.length - 1) % menu.actions.length; menu.armed = -1 }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) menu.run(menu.cursor)
                    else {
                        const i = menu.actions.findIndex(a => a.key === k)
                        if (i >= 0) menu.run(i)
                    }
                    e.accepted = true
                }
            }

            // --- left: identity + actions ---------------------------------------------
            Column {
                x: 28; y: 26
                width: 250
                spacing: 4

                Txt {
                    anchors.verticalCenter: undefined
                    text: "@" + (Quickshell.env("USER") || "user")
                    font.pixelSize: 26
                    font.bold: true
                }
                Txt {
                    anchors.verticalCenter: undefined
                    text: menu.uptime || " "
                    color: Theme.subtle
                    font.italic: true
                    font.pixelSize: Theme.smallSize + 2
                    bottomPadding: 14
                }

                Repeater {
                    model: menu.actions
                    delegate: Rectangle {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool sel: index === menu.cursor
                        readonly property bool isArmed: index === menu.armed
                        width: 230; height: 34
                        radius: 10
                        color: isArmed ? Theme.alpha(Theme.err, 0.9)
                             : sel ? Theme.alpha(Theme.accent, 0.9)
                             : mouse.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.8) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Txt {
                            x: 12
                            text: item.isArmed ? `${item.modelData.name}? Press again` : item.modelData.name
                            font.pixelSize: 17
                            color: item.sel || item.isArmed ? Theme.bg
                                 : item.modelData.danger ? Theme.err : Theme.fg
                        }
                        Keycap {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            key: item.modelData.key
                            visible: !item.isArmed
                            // Not lit on the selected row: an accent cap on the
                            // accent highlight vanished in the first screenshot.
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menu.run(item.index)
                        }
                    }
                }
            }

            // --- right: the current wallpaper ------------------------------------------
            ClippingRectangle {
                anchors.right: parent.right
                anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 300
                topRightRadius: card.radius; bottomRightRadius: card.radius
                color: Theme.bg
                Image {
                    anchors.fill: parent
                    // The same symlink hyprpaper and hyprlock read, so this is
                    // always whatever is on the desktop right now.
                    source: "file://" + Quickshell.env("HOME") + "/.local/share/wallpapers/.current"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 600
                    cache: false
                }
                Rectangle {   // soft edge into the list side
                    width: 40; height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.alpha(Theme.surface, 0.97) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }
    }
}
