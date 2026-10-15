import QtQuick
import Quickshell
import Quickshell.Networking
import qs.common
import qs.services
import qs.widgets

// Wi-Fi popover — replaces nm-connection-editor as the bar icon's click.
// Talks to NetworkManager through Quickshell.Networking, no nmcli parsing.
//
//   click a row   known/open network → connect; connected → disconnect;
//                 secured + new → an inline password field opens
//   j/k ↑/↓       move · Enter act · f forget · r rescan · Esc close
//
// Scanning runs only while the card is open (scannerEnabled), so it costs
// nothing the rest of the time. List order: connected, known, then signal.
Popover {
    id: pop
    name: "wifi"
    cardWidth: 340

    readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    property int cursor: 0
    property var pending: null      // network waiting for a password
    property string error: ""
    property int tick: 0            // bumps re-sort (signal strengths change in place)

    // Distinct SSIDs only; connected first, then known, then strongest.
    readonly property var nets: {
        tick
        if (!dev) return []
        const seen = {}
        const out = []
        for (const n of dev.networks.values) {
            if (!n.name) continue
            const prev = seen[n.name]
            if (prev && prev.signalStrength >= n.signalStrength) continue
            if (prev) out.splice(out.indexOf(prev), 1)
            seen[n.name] = n
            out.push(n)
        }
        out.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
        return out
    }

    onOpened: { cursor = 0; pending = null; error = ""; if (dev) dev.scannerEnabled = true }
    onOpenChanged: if (!open && dev) { dev.scannerEnabled = false; pending = null }
    Timer { running: pop.open; interval: 3000; repeat: true; onTriggered: pop.tick++ }

    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe }
    function activate(n) {
        error = ""
        if (n.connected) n.disconnect()
        else if (n.known || !secured(n)) n.connect()
        else { pending = n; return }
        pending = null
    }
    onKey: (e) => {
        const n = nets[Math.min(cursor, nets.length - 1)]
        if (e.key === Qt.Key_Down || e.text === "j") cursor = Math.min(cursor + 1, nets.length - 1)
        else if (e.key === Qt.Key_Up || e.text === "k") cursor = Math.max(cursor - 1, 0)
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && n) activate(n)
        else if (e.text === "f" && n && n.known) n.forget()
        else if (e.text === "r" && dev) { dev.scannerEnabled = false; dev.scannerEnabled = true }
        else return
        e.accepted = true
    }

    Column {
        width: parent.width
        spacing: 10

        // --- header ---------------------------------------------------------
        Item {
            width: parent.width; height: 24
            Txt { text: "Wi-Fi"; font.bold: true; font.pixelSize: Theme.textSize + 2 }
            Toggle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Txt {
            anchors.verticalCenter: undefined
            visible: !Networking.wifiEnabled || !pop.dev
            width: parent.width; height: 48
            horizontalAlignment: Text.AlignHCenter
            text: !pop.dev ? "No Wi-Fi adapter" : "Wi-Fi is off"
            color: Theme.muted
        }

        // --- networks -------------------------------------------------------
        ListView {
            id: list
            visible: Networking.wifiEnabled && pop.dev !== null
            width: parent.width
            height: Math.min(contentHeight, 320)
            clip: true
            spacing: 2
            model: pop.nets
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === pop.cursor
                readonly property bool asking: pop.pending === modelData
                width: list.width
                height: 40 + (asking ? 44 : 0)
                radius: 12
                color: sel || rowMouse.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.9) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    x: 10; height: 40; spacing: 10
                    Txt {
                        text: Icons.wifi[Math.min(3, Math.floor(modelData.signalStrength * 4))]
                        color: modelData.connected ? Theme.accent : Theme.subtle
                        font.pixelSize: Theme.iconSize + 2
                        anchors.verticalCenter: undefined; y: (40 - height) / 2
                    }
                    Column {
                        y: 4; spacing: 0
                        Txt { text: modelData.name; color: modelData.connected ? Theme.accent : Theme.fg
                              elide: Text.ElideRight; width: 200; anchors.verticalCenter: undefined }
                        Txt {
                            anchors.verticalCenter: undefined
                            font.pixelSize: Theme.smallSize
                            color: Theme.muted
                            text: modelData.state === ConnectionState.Connecting ? "Connecting…"
                                : modelData.connected ? "Connected"
                                : modelData.known ? "Saved" : pop.secured(modelData) ? "Secured" : "Open"
                        }
                    }
                }
                Txt {
                    visible: pop.secured(modelData)
                    text: Icons.lock; color: Theme.muted
                    anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: undefined; y: (40 - height) / 2
                    font.pixelSize: Theme.smallSize + 1
                }
                MouseArea {
                    id: rowMouse
                    width: parent.width; height: 40
                    hoverEnabled: true
                    onClicked: { pop.cursor = index; pop.activate(modelData) }
                }

                // Inline password entry for a new secured network.
                Rectangle {
                    visible: row.asking
                    x: 10; y: 42; width: parent.width - 20; height: 34
                    radius: 10
                    color: Theme.surfaceHi
                    border.width: 1; border.color: Theme.alpha(Theme.accent, 0.7)
                    TextInput {
                        id: pw
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.textSize
                        clip: true
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                        onAccepted: { modelData.connectWithPsk(text); pop.pending = null }
                        Text { visible: !pw.text; text: "Password — Enter to connect"; color: Theme.muted
                               font: pw.font; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Connections {
                    target: row.modelData
                    function onConnectionFailed(reason) {
                        pop.error = `Couldn't connect to ${row.modelData.name}`
                        if (row.modelData.known === false || reason === ConnectionFailReason.NoSecrets) pop.pending = row.modelData
                    }
                }
            }
        }

        Txt {
            anchors.verticalCenter: undefined
            visible: pop.error !== ""
            width: parent.width; text: pop.error; color: Theme.err
            font.pixelSize: Theme.smallSize + 1; wrapMode: Text.Wrap
        }
        Txt {
            anchors.verticalCenter: undefined
            visible: Networking.wifiEnabled && pop.dev !== null && pop.nets.length === 0
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "Scanning…"; color: Theme.muted
        }
        Txt {
            anchors.verticalCenter: undefined
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "↑↓ move · Enter connect · f forget · r rescan"
            color: Theme.muted; font.pixelSize: Theme.smallSize
        }
    }
}
