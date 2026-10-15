import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.common
import qs.services
import qs.widgets

// Bluetooth popover — replaces blueman-manager as the bar icon's click.
// Quickshell.Bluetooth is BlueZ over D-Bus, so state is live: a device
// connecting from its own button shows up here without a poll.
//
//   click a row   connect / disconnect a paired device; pair + trust +
//                 connect a nearby one
//   j/k ↑/↓       move · Enter act · f forget · s scan · Esc close
//
// Connected audio gear gets a battery card on top. BlueZ exposes ONE
// battery figure per device (Battery1), so that is what's shown; per-bud
// and charging-case levels aren't part of BlueZ and would need a
// vendor-specific source (see BudsCard below).
Popover {
    id: pop
    name: "bluetooth"
    cardWidth: 360

    readonly property var adapter: Bluetooth.defaultAdapter
    property int cursor: 0
    property var autoConnect: null   // nearby device we asked to pair; connect once it is
    property int tick: 0

    function pct(d) { return d.battery > 1 ? d.battery / 100 : d.battery }   // BlueZ gives 0..1 here; be tolerant
    function isMac(n) { return /^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(n) }
    function iconFor(d) {
        const i = d.icon || ""
        return i.includes("headset") || i.includes("headphone") ? Icons.headphones
             : i.includes("keyboard") ? Icons.keyboard
             : i.includes("mouse") ? Icons.mouse
             : i.includes("phone") ? Icons.phone
             : i.includes("gaming") || i.includes("joystick") ? Icons.gamepad
             : i.includes("audio") || i.includes("speaker") ? Icons.speaker : Icons.bt
    }

    // Connected first, then other paired devices, then (only while
    // scanning) nearby unpaired ones with a real name.
    readonly property var devs: {
        tick
        const all = Bluetooth.devices.values.filter(d => d.name && !isMac(d.name))
        const paired = all.filter(d => d.paired || d.bonded)
        paired.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
        const nearby = adapter && adapter.discovering ? all.filter(d => !(d.paired || d.bonded)) : []
        return [...paired, ...nearby]
    }
    readonly property var buds: devs.filter(d => d.connected && d.batteryAvailable && (d.icon || "").match(/headset|headphone|audio/))

    onOpened: { cursor = 0 }
    onOpenChanged: if (!open && adapter && adapter.discovering) adapter.discovering = false
    Timer { running: pop.open; interval: 4000; repeat: true; onTriggered: pop.tick++ }

    function activate(d) {
        if (d.connected) d.disconnect()
        else if (d.paired || d.bonded) d.connect()
        else { autoConnect = d; d.pair() }
    }
    Connections {
        target: pop.autoConnect
        function onPairedChanged() {
            const d = pop.autoConnect
            if (d && d.paired) { d.trusted = true; d.connect(); pop.autoConnect = null }
        }
    }
    onKey: (e) => {
        const d = devs[Math.min(cursor, devs.length - 1)]
        if (e.key === Qt.Key_Down || e.text === "j") cursor = Math.min(cursor + 1, devs.length - 1)
        else if (e.key === Qt.Key_Up || e.text === "k") cursor = Math.max(cursor - 1, 0)
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && d) activate(d)
        else if (e.text === "f" && d && (d.paired || d.bonded)) d.forget()
        else if (e.text === "s" && adapter) adapter.discovering = !adapter.discovering
        else return
        e.accepted = true
    }

    Column {
        width: parent.width
        spacing: 10

        // --- header ---------------------------------------------------------
        Item {
            width: parent.width; height: 24
            Txt { text: "Bluetooth"; font.bold: true; font.pixelSize: Theme.textSize + 2 }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Hover {
                    visible: pop.adapter && pop.adapter.enabled
                    hpad: 6
                    active: pop.adapter && pop.adapter.discovering
                    onClicked: pop.adapter.discovering = !pop.adapter.discovering
                    Txt { text: Icons.refresh; font.pixelSize: Theme.iconSize
                          color: pop.adapter && pop.adapter.discovering ? Theme.accent : Theme.subtle
                          RotationAnimator on rotation { running: pop.adapter && pop.adapter.discovering
                                                         from: 0; to: 360; duration: 1400; loops: Animation.Infinite } }
                    Txt { text: pop.adapter && pop.adapter.discovering ? "Scanning" : "Scan"
                          color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                }
                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: pop.adapter ? pop.adapter.enabled : false
                    onToggled: if (pop.adapter) pop.adapter.enabled = !pop.adapter.enabled
                }
            }
        }

        Txt {
            anchors.verticalCenter: undefined
            visible: !pop.adapter || !pop.adapter.enabled
            width: parent.width; height: 48
            horizontalAlignment: Text.AlignHCenter
            text: !pop.adapter ? "No Bluetooth adapter" : "Bluetooth is off"
            color: Theme.muted
        }

        // --- battery cards for connected audio gear -----------------------------
        Repeater {
            model: pop.adapter && pop.adapter.enabled ? pop.buds : []
            delegate: BudsCard { required property var modelData; device: modelData; width: parent.width }
        }

        // --- devices --------------------------------------------------------------
        ListView {
            id: list
            visible: pop.adapter && pop.adapter.enabled
            width: parent.width
            height: Math.min(contentHeight, 280)
            clip: true
            spacing: 2
            model: pop.devs
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === pop.cursor
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                                           || modelData.state === BluetoothDeviceState.Disconnecting
                                           || modelData.pairing
                width: list.width; height: 44
                radius: 12
                color: sel || rowMouse.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.9) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    x: 10; height: parent.height; spacing: 10
                    Txt { text: pop.iconFor(modelData); font.pixelSize: Theme.iconSize + 3
                          color: modelData.connected ? Theme.info : Theme.subtle
                          anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 0
                        Txt { text: modelData.name; elide: Text.ElideRight; width: 200
                              color: modelData.connected ? Theme.info : Theme.fg; anchors.verticalCenter: undefined }
                        Txt { anchors.verticalCenter: undefined; font.pixelSize: Theme.smallSize; color: Theme.muted
                              text: row.busy ? (modelData.pairing ? "Pairing…" : "Connecting…")
                                  : modelData.connected ? "Connected"
                                  : (modelData.paired || modelData.bonded) ? "Paired" : "Nearby — click to pair" }
                    }
                }
                Txt {
                    visible: modelData.connected && modelData.batteryAvailable
                    anchors.right: parent.right; anchors.rightMargin: 12
                    text: `${Math.round(pop.pct(modelData) * 100)}%`
                    color: pop.pct(modelData) < 0.2 ? Theme.err : Theme.subtle
                    font.pixelSize: Theme.smallSize + 1
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: { pop.cursor = index; pop.activate(modelData) }
                }
            }
        }

        Txt {
            anchors.verticalCenter: undefined
            visible: pop.adapter && pop.adapter.enabled && pop.devs.length === 0
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "No paired devices — press s to scan"; color: Theme.muted
        }
        Txt {
            anchors.verticalCenter: undefined
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "↑↓ move · Enter connect · f forget · s scan"
            color: Theme.muted; font.pixelSize: Theme.smallSize
        }
    }
}
