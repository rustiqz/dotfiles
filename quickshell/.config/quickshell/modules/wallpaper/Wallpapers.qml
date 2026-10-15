import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.widgets

// Wallpaper picker ($mod+W) as Pokémon cards in a coverflow.
//
// Every card is derived from the image itself, at open time — nothing is
// precomputed or cached per machine:
//   type     hue of the image's most saturated colour (common/Dex.qml),
//            which also tints the card frame — Fire wallpapers get
//            fire-coloured cards
//   HP       from the image's overall lightness
//   attacks  the two strongest palette colours, as the energy cost, with
//            their hex codes; damage scales with saturation
//   palette  the full quantized palette along the bottom
// The palette comes from Quickshell's ColorQuantizer on a downscaled copy,
// so a card renders as fast as its thumbnail loads.
//
// ←/→ or h/l browse, Enter sets the wallpaper (bin/bin/wallpaper, the same
// path the rofi picker uses), Shift+Enter also recolours the desktop from
// it (`theme wallpaper`). Esc or a click outside closes.
Scope {
    id: scope

    Scrim {
        screen: deck.screen
        visible: deck.visible
        shown: deck.open
        dim: 0.45
        WlrLayershell.namespace: "quickshell-wallpapers-scrim"
        onDismissed: deck.open = false
    }

    PanelWindow {
        id: deck
        property bool open: false
        property var files: []          // [{ name, size }]
        property string current: ""     // basename the .current link points at
        readonly property string dir: Quickshell.env("HOME") + "/.local/share/wallpapers"

        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        implicitWidth: screen ? screen.width : 1920
        implicitHeight: 600
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: open || fade.running
        WlrLayershell.namespace: "quickshell-wallpapers"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: if (open) { listProc.running = true; keys.forceActiveFocus() }

        IpcHandler {
            target: "wallpapers"
            function toggle(): void { deck.open = !deck.open }
        }

        // Same filter as bin/bin/wallpaper's rofi picker. -L: the directory
        // is a stowed symlink. Current target read in the same call.
        Process {
            id: listProc
            command: ["sh", "-c", 'cd "$1" && basename "$(readlink -f .current)"; ' +
                      'find -L . -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) ' +
                      '-printf "%f\\t%s\\n" | sort', "sh", deck.dir]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n")
                    deck.current = lines.shift() || ""
                    deck.files = lines.filter(Boolean).map(l => {
                        const [name, size] = l.split("\t")
                        return { name, size: parseInt(size) }
                    })
                    const i = deck.files.findIndex(f => f.name === deck.current)
                    view.currentIndex = Math.max(0, i)
                }
            }
        }

        function apply(name, retheme) {
            open = false
            const wp = Quickshell.env("HOME") + "/bin/wallpaper"
            const th = Quickshell.env("HOME") + "/bin/theme"
            Quickshell.execDetached(retheme
                ? ["sh", "-c", `"$1" "$2" && "$3" wallpaper`, "sh", wp, name, th]
                : [wp, name])
        }

        function pretty(name) {
            return name.replace(/\.[^.]+$/, "").split(/[-_\s]+/)
                       .map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ")
        }
        function mb(bytes) { return bytes > 1048576 ? `${(bytes / 1048576).toFixed(1)} MB` : `${Math.round(bytes / 1024)} KB` }

        Item {
            id: stage
            anchors.fill: parent
            opacity: deck.open ? 1 : 0
            Behavior on opacity { NumberAnimation { id: fade; duration: Theme.animMed } }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: (e) => {
                    const k = e.text
                    if (e.key === Qt.Key_Escape) deck.open = false
                    else if (e.key === Qt.Key_Right || k === "l") view.incrementCurrentIndex()
                    else if (e.key === Qt.Key_Left || k === "h") view.decrementCurrentIndex()
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        const f = deck.files[view.currentIndex]
                        if (f) deck.apply(f.name, !!(e.modifiers & Qt.ShiftModifier))
                    }
                    e.accepted = true
                }
            }

            PathView {
                id: view
                anchors.fill: parent
                anchors.bottomMargin: 50
                model: deck.files
                pathItemCount: Math.min(5, deck.files.length || 1)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: Theme.animSlow
                interactive: true

                readonly property real cy: height / 2
                path: Path {
                    startX: view.width * 0.5 - 900; startY: view.cy
                    PathAttribute { name: "s"; value: 0.66 }
                    PathAttribute { name: "o"; value: 0.35 }
                    PathAttribute { name: "r"; value: 32 }
                    PathAttribute { name: "z"; value: 0 }
                    PathLine { x: view.width * 0.5; y: view.cy }
                    PathAttribute { name: "s"; value: 1 }
                    PathAttribute { name: "o"; value: 1 }
                    PathAttribute { name: "r"; value: 0 }
                    PathAttribute { name: "z"; value: 10 }
                    PathLine { x: view.width * 0.5 + 900; y: view.cy }
                    PathAttribute { name: "s"; value: 0.66 }
                    PathAttribute { name: "o"; value: 0.35 }
                    PathAttribute { name: "r"; value: -32 }
                    PathAttribute { name: "z"; value: 0 }
                }

                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property bool sel: PathView.isCurrentItem
                    width: 320; height: 450
                    scale: PathView.s
                    opacity: PathView.o
                    z: PathView.z
                    transform: Rotation {
                        origin.x: slot.width / 2; origin.y: slot.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: slot.PathView.r
                    }

                    // --- the card's data, from its own pixels -----------------------
                    ColorQuantizer {
                        id: q
                        source: "file://" + deck.dir + "/" + slot.modelData.name
                        depth: 3            // 2^3 = 8 colours
                        rescaleSize: 64     // quantize a 64px copy — fast
                    }
                    readonly property var pal: q.colors || []
                    readonly property string typeKey: Dex.typeOfPalette(pal)
                    readonly property var type: Dex.types[typeKey]
                    readonly property var strong: pal.slice().sort((a, b) => b.hslSaturation - a.hslSaturation)
                    readonly property real light: pal.length ? pal.reduce((a, c) => a + c.hslLightness, 0) / pal.length : 0.5
                    readonly property int hp: Math.round(40 + light * 90) - Math.round(40 + light * 90) % 10
                    function dmg(c) { return c ? 20 + Math.round(c.hslSaturation * 10) * 10 : 20 }
                    readonly property bool equipped: slot.modelData.name === deck.current

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: slot.sel ? deck.apply(slot.modelData.name, false) : view.currentIndex = slot.index
                    }

                    // Frame: type-coloured, like the card's border colour in the TCG.
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(slot.type.color, 1.15) }
                            GradientStop { position: 1; color: Qt.darker(slot.type.color, 1.35) }
                        }
                        border.width: slot.sel ? 3 : 1
                        border.color: slot.sel ? Theme.fg : Qt.darker(slot.type.color, 1.8)

                        // Inner card face
                        Rectangle {
                            id: face
                            anchors.fill: parent
                            anchors.margins: 9
                            radius: 10
                            color: Theme.alpha(Theme.surface, 0.96)

                            // Header: name · HP · energy symbol
                            Item {
                                id: head
                                x: 12; y: 8
                                width: parent.width - 24; height: 30
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - hpRow.width - 8
                                    text: deck.pretty(slot.modelData.name)
                                    color: Theme.fg; font.family: Theme.font; font.pixelSize: 15; font.bold: true
                                    elide: Text.ElideRight
                                }
                                Row {
                                    id: hpRow
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5
                                    Text { text: "HP"; color: Theme.err; font.family: Theme.font; font.pixelSize: 9; font.bold: true
                                           anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: slot.hp; color: Theme.err; font.family: Theme.font; font.pixelSize: 17; font.bold: true }
                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: slot.type.color
                                        border.width: 1; border.color: Qt.darker(slot.type.color, 1.6)
                                    }
                                }
                            }

                            // Art window
                            ClippingRectangle {
                                id: art
                                x: 12; y: head.y + head.height + 4
                                width: parent.width - 24; height: 168
                                radius: 6
                                color: Theme.bg
                                border.width: 2; border.color: Qt.darker(slot.type.color, 1.4)
                                Image {
                                    anchors.fill: parent
                                    source: "file://" + deck.dir + "/" + slot.modelData.name
                                    sourceSize.width: 600
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                // Holo shimmer: a rainbow band sweeping across
                                // the selected card's art.
                                Rectangle {
                                    visible: slot.sel
                                    width: parent.width * 0.6; height: parent.height * 2
                                    y: -parent.height / 2
                                    rotation: 25
                                    opacity: 0.22
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.35; color: "#7dcfff" }
                                        GradientStop { position: 0.5; color: "#ffffff" }
                                        GradientStop { position: 0.65; color: "#bb9af7" }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    NumberAnimation on x {
                                        running: slot.sel; loops: Animation.Infinite
                                        from: -art.width; to: art.width * 1.4; duration: 2600
                                        easing.type: Easing.InOutSine
                                    }
                                }
                            }

                            // Info strip
                            Text {
                                id: info
                                x: 14; y: art.y + art.height + 6
                                text: `No. ${String(slot.index + 1).padStart(3, "0")}  ·  ${slot.type.name} type  ·  ${deck.mb(slot.modelData.size)}`
                                color: Theme.subtle; font.family: Theme.font; font.pixelSize: 10; font.italic: true
                            }

                            // Attacks: the two strongest colours as energy cost
                            Column {
                                id: attacks
                                x: 12; y: info.y + info.height + 10
                                width: parent.width - 24
                                spacing: 8
                                Repeater {
                                    model: 2
                                    delegate: Item {
                                        required property int index
                                        readonly property color c: slot.strong[index] || Theme.muted
                                        width: attacks.width; height: 38
                                        Row {
                                            id: cost
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Repeater {
                                                model: index + 1
                                                delegate: Rectangle {
                                                    width: 16; height: 16; radius: 8
                                                    color: parent.parent.c
                                                    border.width: 1; border.color: Qt.darker(parent.parent.c, 1.7)
                                                }
                                            }
                                        }
                                        Column {
                                            anchors.left: cost.right; anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: (Dex.moves[slot.typeKey] || Dex.moves.normal)[index]
                                                   color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.bold: true }
                                            Text { text: String(parent.parent.c).toUpperCase()
                                                   color: Theme.subtle; font.family: Theme.font; font.pixelSize: 9 }
                                        }
                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: slot.dmg(parent.c)
                                            color: Theme.fg; font.family: Theme.font; font.pixelSize: 18; font.bold: true
                                        }
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width; height: 1
                                            color: Theme.alpha(Theme.border, 0.6)
                                            visible: index === 0
                                        }
                                    }
                                }
                            }

                            // Palette strip + equipped badge
                            Row {
                                x: 12
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                                spacing: 0
                                Repeater {
                                    model: slot.pal
                                    delegate: Rectangle {
                                        required property color modelData
                                        width: (face.width - 24 - (slot.equipped ? 80 : 0)) / Math.max(1, slot.pal.length)
                                        height: 14
                                        color: modelData
                                    }
                                }
                            }
                            Rectangle {
                                visible: slot.equipped
                                anchors.right: parent.right; anchors.rightMargin: 12
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 9
                                width: 72; height: 20; radius: 10
                                color: Theme.alpha(Theme.ok, 0.2)
                                border.width: 1; border.color: Theme.ok
                                Text { anchors.centerIn: parent; text: "★ EQUIPPED"; color: Theme.ok
                                       font.family: Theme.font; font.pixelSize: 9; font.bold: true }
                            }
                        }
                    }
                }
            }

            // Hints
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                spacing: 8
                Repeater {
                    model: [["←→", "browse"], ["↵", "set wallpaper"], ["⇧↵", "set + recolour desktop"], ["esc", "close"]]
                    delegate: Row {
                        required property var modelData
                        spacing: 5
                        Keycap { key: modelData[0] }
                        Text { text: modelData[1]; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11
                               anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
