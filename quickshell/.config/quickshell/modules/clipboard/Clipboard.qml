import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.widgets

// Clipboard history ($mod+Ctrl+V, the bar's clipboard glyph —
// `qs ipc call clipboard toggle`). A centred card: filterable list of
// everything cliphist has stored (the two wl-paste watchers in
// hypr/autostart fill it) on the left, a preview of the selected entry on
// the right — full text for text, the decoded picture for screenshots.
//
// Keys: type to filter · ↑/↓ (Ctrl+J/K) move · Enter copies and closes ·
// Delete removes the entry · Esc or a click outside closes.
//
// cliphist has no timestamps, so order is its own: newest first.
Scope {
    id: scope

    Scrim {
        screen: card.screen
        visible: card.visible
        shown: card.open
        dim: 0.35
        WlrLayershell.namespace: "quickshell-clipboard-scrim"
        onDismissed: card.open = false
    }

    PanelWindow {
        id: card
        property bool open: false
        property var clips: []            // [{id, text}] straight from cliphist, newest first
        property int cursor: 0
        property string imgSrc: ""
        property int imgGen: 0

        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        implicitWidth: Math.min(980, screen ? screen.width - 80 : 980)
        implicitHeight: Math.min(620, screen ? screen.height - 120 : 620)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: open || fade.running
        WlrLayershell.namespace: "quickshell-clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        // OnDemand, never Exclusive: see widgets/Scrim.qml.
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: if (open) { filter.text = ""; cursor = 0; imgSrc = ""; load.running = true; filter.forceActiveFocus() }

        IpcHandler {
            target: "clipboard"
            function toggle(): void { card.open = !card.open }
        }

        // --- data ---------------------------------------------------------------------
        Process {
            id: load
            command: ["cliphist", "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = []
                    for (const line of text.split("\n")) {
                        const m = line.match(/^(\d+)\t(.*)$/)
                        if (m) out.push({ id: m[1], text: m[2] })
                    }
                    card.clips = out
                }
            }
        }

        // What an entry is, for the badge colour and the preview. Images
        // come back from cliphist as one "[[ binary data … ]]" line.
        function kindOf(t) {
            if (t.startsWith("[[ binary data")) return "image"
            if (/^https?:\/\/\S+$/.test(t.trim())) return "link"
            return "text"
        }
        readonly property var kinds: ({
            text:  { label: "TEXT",  color: Dex.types.normal.color },
            link:  { label: "LINK",  color: Dex.types.water.color },
            image: { label: "IMAGE", color: Dex.types.fairy.color },
        })

        readonly property var rows: {
            const t = filter.text.trim().toLowerCase()
            return clips.filter(c => !t || c.text.toLowerCase().includes(t)).slice(0, 300)
                .map(c => ({ id: c.id, text: c.text, kind: kindOf(c.text) }))
        }
        readonly property var selected: rows[Math.min(cursor, rows.length - 1)] || null
        onRowsChanged: cursor = Math.min(cursor, Math.max(0, rows.length - 1))

        // Decode the selected picture to a scratch file the Image can load.
        Process {
            id: imgProc
            onExited: { card.imgGen++; card.imgSrc = "file://" + imgPath + "?" + card.imgGen }
        }
        readonly property string imgPath: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-clipboard-preview"
        onSelectedChanged: {
            if (selected && selected.kind === "image" && /^\d+$/.test(selected.id)) {
                imgSrc = ""
                imgProc.command = ["sh", "-c", "cliphist decode " + selected.id + " > '" + imgPath + "'"]
                imgProc.running = true
            }
        }

        function copy(row) {
            if (!row || !/^\d+$/.test(row.id)) return
            Quickshell.execDetached(["sh", "-c", "cliphist decode " + row.id + " | wl-copy"])
            open = false
        }
        function remove(row) {
            if (!row || !/^\d+$/.test(row.id)) return
            Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' " + row.id + " | cliphist delete"])
            clips = clips.filter(c => c.id !== row.id)
        }

        // --- card -----------------------------------------------------------------------
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius + 6
            color: Theme.alpha(Theme.surface, 0.96)
            border.width: 1
            border.color: Theme.alpha(Theme.border, 0.8)
            opacity: card.open ? 1 : 0
            scale: card.open ? 1 : 0.97
            Behavior on opacity { NumberAnimation { id: fade; duration: Theme.animMed } }
            Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            Item {
                anchors.fill: parent
                anchors.margins: 20

                // header: title + search
                Row {
                    id: header
                    spacing: 10
                    Txt { text: Icons.clipboard; color: Theme.accent; font.pixelSize: 26 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { anchors.verticalCenter: undefined; text: "Clipboard"; font.bold: true; font.pixelSize: 20 }
                        Txt { anchors.verticalCenter: undefined; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1
                              text: card.rows.length + (card.rows.length === 1 ? " entry" : " entries")
                                    + (filter.text ? " match" : "") }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 340; height: 38; radius: 12
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
                        onTextChanged: card.cursor = 0
                        Keys.onEscapePressed: card.open = false
                        Keys.onReturnPressed: card.copy(card.selected)
                        Keys.onEnterPressed: card.copy(card.selected)
                        Keys.onDeletePressed: card.remove(card.selected)
                        Keys.onDownPressed: card.cursor = Math.min(card.cursor + 1, card.rows.length - 1)
                        Keys.onUpPressed: card.cursor = Math.max(card.cursor - 1, 0)
                        Keys.onPressed: e => {
                            if (e.modifiers & Qt.ControlModifier) {
                                if (e.key === Qt.Key_J || e.key === Qt.Key_N) { card.cursor = Math.min(card.cursor + 1, card.rows.length - 1); e.accepted = true }
                                else if (e.key === Qt.Key_K || e.key === Qt.Key_P) { card.cursor = Math.max(card.cursor - 1, 0); e.accepted = true }
                            }
                        }
                        Txt {
                            anchors.verticalCenter: undefined
                            visible: !filter.text; text: "Search clipboard…"; color: Theme.muted; font: filter.font
                        }
                    }
                }

                // list (left)
                ListView {
                    id: list
                    anchors.top: header.bottom; anchors.topMargin: 16
                    anchors.bottom: hints.top; anchors.bottomMargin: 12
                    anchors.left: parent.left
                    width: Math.round(parent.width * 0.46)
                    clip: true
                    spacing: 6
                    model: card.rows
                    currentIndex: card.cursor
                    highlightMoveDuration: 0
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool sel: index === card.cursor
                        readonly property var kind: card.kinds[modelData.kind]
                        width: list.width
                        height: 50
                        radius: 12
                        color: sel ? Theme.alpha(kind.color, 0.16) : Theme.alpha(Theme.surfaceHi, 0.35)
                        border.width: 1
                        border.color: sel ? Theme.alpha(kind.color, 0.7) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        // type stripe
                        Rectangle {
                            x: 0; y: 10; width: 3; height: parent.height - 20; radius: 2
                            color: kind.color
                        }
                        Txt {
                            x: 16; width: parent.width - 100
                            anchors.verticalCenter: parent.verticalCenter
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            text: modelData.kind === "image" ? "Image" : (modelData.text.trim() || "(whitespace)")
                            color: sel ? Theme.fg : Theme.subtle
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: badge.implicitWidth + 14; implicitHeight: 18; radius: 9
                            color: kind.color
                            Text { id: badge; anchors.centerIn: parent; text: kind.label
                                   color: "#1a1a1a"; font.family: Theme.font; font.pixelSize: 9
                                   font.bold: true; font.letterSpacing: 1 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            property real lx: -1
                            property real ly: -1
                            // Follow real pointer movement only: rows
                            // reflowing under a still pointer must not steal
                            // the selection (same lesson as the launcher).
                            onPositionChanged: m => {
                                const g = mapToGlobal(m.x, m.y)
                                if (g.x !== lx || g.y !== ly) { if (lx >= 0) card.cursor = index; lx = g.x; ly = g.y }
                            }
                            onClicked: card.copy(modelData)
                        }
                    }

                    Txt {
                        anchors.centerIn: parent
                        visible: card.rows.length === 0
                        text: filter.text ? "Nothing matches" : "Clipboard is empty"
                        color: Theme.muted
                    }
                }

                // preview (right)
                Rectangle {
                    id: pane
                    anchors.top: header.bottom; anchors.topMargin: 16
                    anchors.bottom: hints.top; anchors.bottomMargin: 12
                    anchors.right: parent.right
                    anchors.left: list.right; anchors.leftMargin: 16
                    radius: Theme.radius
                    color: Theme.alpha(Theme.bg, 0.7)
                    border.width: 1
                    border.color: Theme.alpha(Theme.border, 0.8)

                    readonly property var sel: card.selected

                    Txt {
                        anchors.centerIn: parent
                        visible: !pane.sel
                        text: "Nothing selected"; color: Theme.muted
                    }

                    // text / link
                    Flickable {
                        id: pv
                        anchors.fill: parent; anchors.margins: 14
                        visible: pane.sel && pane.sel.kind !== "image"
                        contentHeight: body.implicitHeight
                        clip: true
                        onVisibleChanged: contentY = 0
                        Text {
                            id: body
                            width: pv.width
                            wrapMode: Text.Wrap
                            text: pane.sel ? pane.sel.text : ""
                            color: pane.sel && pane.sel.kind === "link" ? Dex.types.water.color : Theme.fg
                            font.family: Theme.font; font.pixelSize: 12
                        }
                    }

                    // image
                    Item {
                        anchors.fill: parent; anchors.margins: 14
                        visible: pane.sel && pane.sel.kind === "image"
                        Image {
                            anchors.fill: parent
                            source: card.imgSrc
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: pane.sel ? pane.sel.text.replace(/^\[\[ binary data |\ \]\]$/g, "") : ""
                            color: Theme.subtle; font.pixelSize: Theme.smallSize
                        }
                    }
                }

                // footer: key hints
                Row {
                    id: hints
                    anchors.bottom: parent.bottom
                    spacing: 6
                    Keycap { key: "↵" }       Txt { text: "copy"; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                    Item { width: 8; height: 1 }
                    Keycap { key: "↑↓" }      Txt { text: "move"; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                    Item { width: 8; height: 1 }
                    Keycap { key: "Del" }     Txt { text: "remove"; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                    Item { width: 8; height: 1 }
                    Keycap { key: "Esc" }     Txt { text: "close"; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                }
            }
        }
    }
}
