import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.widgets

// Keybind cheatsheet ($mod+/). Read live from `hyprctl binds -j` every
// time it opens — every bind in hypr/keybinds.conf is `bindd`, so the
// description shown here IS the config; the sheet can't drift from the
// real binds (Prism's "generated from your config" idea).
//
// Grouped by what the bind does (dispatcher + command), numeric series
// collapsed ("1–0  Workspace n" instead of ten rows). Type to filter;
// Esc or a click outside closes.
Scope {
    id: scope

    Scrim {
        screen: sheet.screen
        visible: sheet.visible
        shown: sheet.open
        dim: 0.35
        WlrLayershell.namespace: "quickshell-cheatsheet-scrim"
        onDismissed: sheet.open = false
    }

    PanelWindow {
        id: sheet
        property bool open: false
        property var groups: []

        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        implicitWidth: Math.min(1240, screen ? screen.width - 80 : 1240)
        implicitHeight: Math.min(800, screen ? screen.height - 120 : 800)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: open || fade.running
        WlrLayershell.namespace: "quickshell-cheatsheet"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onOpenChanged: if (open) { filter.text = ""; binds.running = true; filter.forceActiveFocus() }

        IpcHandler {
            target: "cheatsheet"
            function toggle(): void { sheet.open = !sheet.open }
        }

        // --- data ------------------------------------------------------------------------
        Process {
            id: binds
            command: ["hyprctl", "binds", "-j"]
            stdout: StdioCollector { onStreamFinished: { try { sheet.groups = sheet.build(JSON.parse(text)) } catch (e) {} } }
        }

        function mods(mask) {
            const out = []
            if (mask & 64) out.push("SUPER")
            if (mask & 4) out.push("CTRL")
            if (mask & 8) out.push("ALT")
            if (mask & 1) out.push("SHIFT")
            return out
        }
        function keyName(k) {
            const map = { Return: "↵", grave: "`", slash: "/", period: ".", space: "Space", Space: "Space",
                          Escape: "Esc", Tab: "Tab", Print: "Print",
                          "mouse:272": "LMB", "mouse:273": "RMB", mouse_down: "Wheel ↓", mouse_up: "Wheel ↑",
                          XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mute",
                          XF86AudioMicMute: "Mic mute", XF86AudioPlay: "Play", XF86AudioNext: "Next",
                          XF86AudioPrev: "Prev", XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright −" }
            return map[k] || (k.length === 1 ? k.toUpperCase() : k)
        }
        function category(b) {
            const a = b.arg || "", d = b.dispatcher
            if (b.key.startsWith("XF86")) return "Media & hardware"
            if (["workspace", "movetoworkspace", "togglespecialworkspace"].includes(d)) return "Workspaces"
            if (["killactive", "togglefloating", "fullscreen", "movefocus", "movewindow",
                 "resizeactive", "cyclenext", "mouse"].includes(d)) return "Windows"
            if (a.includes("screenshot")) return "Capture"
            if (d === "exit" || a.includes("qs ipc") || a.includes("swaync") || a.includes("lock-session")
                || /\b(theme|wallpaper|cliphist|rofimoji|rofi -show window)\b/.test(a)) return "Shell"
            return "Apps"
        }
        readonly property var order: ["Apps", "Shell", "Windows", "Workspaces", "Capture", "Media & hardware"]
        // Each group is a Pokémon type, in the canonical type colour — the
        // same badges as the launcher (common/Dex.qml): Apps Normal, Shell
        // Psychic (controls the desktop), Windows Fighting (move, resize),
        // Workspaces Flying (travel between them), Capture Electric (the
        // flash), Media Water.
        readonly property var groupType: ({ "Apps": "normal", "Shell": "psychic", "Windows": "fighting",
                                            "Workspaces": "flying", "Capture": "electric", "Media & hardware": "water" })
        function build(list) {
            const groups = {}
            const seen = {}
            for (const b of list) {
                // Collapse numeric series: "Workspace 3" + "Workspace 4"... → "Workspace n" on keys 1–0.
                const series = /^(.*?)\s*\b\d+$/.exec(b.description)
                const isNum = series && /^[0-9]$/.test(b.key)
                const desc = isNum ? `${series[1]} n` : b.description
                const id = `${b.modmask}|${desc}`
                if (isNum && seen[id]) continue
                seen[id] = true
                const cat = category(b)
                ;(groups[cat] = groups[cat] || []).push({
                    keys: mods(b.modmask).concat([isNum ? "1–0" : keyName(b.key)]),
                    desc,
                })
            }
            return order.filter(c => groups[c]).map(c => {
                const t = Dex.types[groupType[c]] || Dex.types.normal
                return { name: c, color: t.color, type: t.name, rows: groups[c] }
            })
        }

        readonly property string q: filter.text.toLowerCase()
        readonly property var shown: groups.map(g => ({
            name: g.name, color: g.color, type: g.type,   // type: the badge label (dropping it left blank badges)
            rows: g.rows.filter(r => !q || r.desc.toLowerCase().includes(q) || r.keys.join(" ").toLowerCase().includes(q)),
        })).filter(g => g.rows.length)

        // --- view ------------------------------------------------------------------------
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius + 6
            color: Theme.alpha(Theme.surface, 0.96)
            border.width: 1
            border.color: Theme.alpha(Theme.border, 0.8)
            opacity: sheet.open ? 1 : 0
            scale: sheet.open ? 1 : 0.97
            Behavior on opacity { NumberAnimation { id: fade; duration: Theme.animMed } }
            Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            Item {
                anchors.fill: parent
                anchors.margins: 22

                Row {
                    id: header
                    spacing: 10
                    Txt { text: Icons.keys; color: Theme.accent; font.pixelSize: 26 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { anchors.verticalCenter: undefined; text: "Keybinds"; font.bold: true; font.pixelSize: 20 }
                        Txt { anchors.verticalCenter: undefined; text: "read live from your Hyprland config"
                              color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    width: 300; height: 38; radius: 12
                    color: Theme.bg
                    border.width: 1; border.color: Theme.alpha(Theme.accent, filter.text ? 0.8 : 0.35)
                    Txt { id: mag; x: 12; text: Icons.search; color: Theme.accent; font.pixelSize: 16 }
                    TextInput {
                        id: filter
                        anchors.left: mag.right; anchors.leftMargin: 8
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg; font.family: Theme.font; font.pixelSize: 13
                        clip: true; focus: true
                        Keys.onEscapePressed: sheet.open = false
                        Txt {
                            anchors.verticalCenter: undefined
                            visible: !filter.text; text: "Filter binds…"; color: Theme.muted; font: filter.font
                        }
                    }
                }

                Flickable {
                    id: flick
                    anchors.top: header.bottom; anchors.topMargin: 18
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    contentHeight: cols.height
                    clip: true

                    // Masonry-ish: three columns, each group placed in the
                    // currently shortest column.
                    readonly property int ncol: 3
                    readonly property var placement: {
                        const heights = Array(ncol).fill(0), out = Array(ncol).fill(0).map(() => [])
                        for (const g of sheet.shown) {
                            const c = heights.indexOf(Math.min(...heights))
                            out[c].push(g)
                            heights[c] += 52 + g.rows.length * 30
                        }
                        return out
                    }

                    Row {
                        id: cols
                        width: parent.width
                        spacing: 14
                        Repeater {
                            // flick.placement, not parent.parent: inside a
                            // Flickable that resolves to its contentItem, and
                            // the sheet rendered empty.
                            model: flick.placement
                            delegate: Column {
                                required property var modelData
                                width: (cols.width - 2 * cols.spacing) / 3
                                spacing: 14
                                Repeater {
                                    model: parent.modelData
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: grp.implicitHeight + 24
                                        radius: Theme.radius
                                        color: Theme.alpha(Theme.surfaceHi, 0.45)
                                        border.width: 1
                                        border.color: Theme.alpha(modelData.color, 0.35)
                                        Column {
                                            id: grp
                                            x: 14; y: 12
                                            width: parent.width - 28
                                            spacing: 8
                                            Row {
                                                spacing: 8
                                                Txt { text: modelData.name; color: modelData.color
                                                      font.bold: true; font.pixelSize: 14 }
                                                // Type badge, styled exactly like the launcher's
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    implicitWidth: typeLabel.implicitWidth + 14; implicitHeight: 18; radius: 9
                                                    color: modelData.color
                                                    Text { id: typeLabel; anchors.centerIn: parent; text: (modelData.type || "").toUpperCase()
                                                           color: "#1a1a1a"; font.family: Theme.font; font.pixelSize: 9
                                                           font.bold: true; font.letterSpacing: 1 }
                                                }
                                            }
                                            Repeater {
                                                model: modelData.rows
                                                delegate: Item {
                                                    required property var modelData
                                                    width: grp.width; height: 22
                                                    Row {
                                                        spacing: 4
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Repeater {
                                                            model: modelData.keys
                                                            delegate: Keycap { required property string modelData; key: modelData }
                                                        }
                                                    }
                                                    Txt {
                                                        anchors.right: parent.right
                                                        width: Math.min(implicitWidth, parent.width * 0.55)
                                                        horizontalAlignment: Text.AlignRight
                                                        elide: Text.ElideRight
                                                        text: modelData.desc
                                                        color: Theme.subtle
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
