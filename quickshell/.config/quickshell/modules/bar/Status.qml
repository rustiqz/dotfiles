import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import qs.common
import qs.services
import qs.widgets

// Right island: load, connectivity, audio, battery, notifications, clock,
// tray, power. Icons first, numbers only where the number *is* the
// information (CPU/RAM/battery) — everything else says its state through
// the glyph and colour, with the detail one click away.
//
// Click targets reuse what already exists rather than reinventing it:
// network/bluetooth/audio open their managers (nm-connection-editor,
// blueman, pavucontrol), the bell toggles swaync's panel, power opens
// wlogout. Phase 10's hub replaces the first three with inline controls.
Island {
    id: root
    spacing: 2
    hpad: 6

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    function run(cmd) { Quickshell.execDetached(["uwsm", "app", "--", ...cmd]) }

    // --- load -------------------------------------------------------------------
    // Colour climbs muted → warn → err with load, so a busy machine is
    // visible without reading the number.
    function loadColor(v) { return v > 0.85 ? Theme.err : v > 0.6 ? Theme.warn : Theme.subtle }
    Hover {
        hpad: 6
        onClicked: root.run(["kitty", "--title", "btop", "-e", "btop"])
        Txt { text: Icons.cpu; color: root.loadColor(Sys.cpu); font.pixelSize: Theme.iconSize }
        Txt { text: `${Math.round(Sys.cpu * 100)}%`; color: root.loadColor(Sys.cpu); font.pixelSize: Theme.smallSize + 1
              width: 28 /* fixed: digits changing width would jitter the island */ }
        Txt { text: Icons.mem; color: root.loadColor(Sys.mem); font.pixelSize: Theme.iconSize }
        Txt { text: `${Math.round(Sys.mem * 100)}%`; color: root.loadColor(Sys.mem); font.pixelSize: Theme.smallSize + 1
              width: 28 }
    }

    Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Theme.alpha(Theme.border, 0.8) }

    // --- network ------------------------------------------------------------------
    Hover {
        readonly property var devs: Networking.devices.values
        readonly property var wired: devs.find(d => d.type === DeviceType.Wired && d.connected)
        readonly property var wifi: devs.find(d => d.type === DeviceType.Wifi)
        readonly property var net: wifi ? wifi.networks.values.find(n => n.connected) : null
        hpad: 6
        onClicked: root.run(["nm-connection-editor"])
        Txt {
            text: parent.parent.wired ? Icons.ethernet
                : parent.parent.net ? Icons.wifi[Math.min(3, Math.floor(parent.parent.net.signalStrength * 4))]
                : Icons.wifiOff
            color: parent.parent.wired || parent.parent.net ? Theme.fg : Theme.muted
            font.pixelSize: Theme.iconSize
        }
    }

    // --- bluetooth ------------------------------------------------------------------
    Hover {
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)
        visible: adapter !== null
        hpad: 6
        onClicked: root.run(["blueman-manager"])
        onRightClicked: if (adapter) adapter.enabled = !adapter.enabled
        Txt {
            text: !parent.parent.adapter || !parent.parent.adapter.enabled ? Icons.btOff
                : parent.parent.connected ? Icons.btOn : Icons.bt
            color: parent.parent.connected ? Theme.info
                 : parent.parent.adapter && parent.parent.adapter.enabled ? Theme.fg : Theme.muted
            font.pixelSize: Theme.iconSize
        }
    }

    // --- audio ------------------------------------------------------------------------
    // Scroll adjusts, click mutes, right-click opens the mixer. The DevIsland
    // flashes the level on any change, so there's no number here.
    Hover {
        readonly property var audio: root.sink && root.sink.audio ? root.sink.audio : null
        hpad: 6
        onClicked: if (audio) audio.muted = !audio.muted
        onRightClicked: root.run(["pavucontrol"])
        onScrolled: (d) => { if (audio) audio.volume = Math.max(0, Math.min(1, audio.volume + d * 0.05)) }
        Txt {
            text: !parent.parent.audio || parent.parent.audio.muted ? Icons.volOff
                : Icons.vol[parent.parent.audio.volume < 0.34 ? 0 : parent.parent.audio.volume < 0.67 ? 1 : 2]
            color: !parent.parent.audio || parent.parent.audio.muted ? Theme.muted : Theme.fg
            font.pixelSize: Theme.iconSize
        }
    }

    // --- battery capsule ---------------------------------------------------------------
    // A drawn battery rather than a glyph, so the fill level is literal:
    // the inner bar is the charge, tinted by state.
    Item {
        readonly property var bat: UPower.displayDevice
        readonly property real pct: bat && bat.ready ? bat.percentage : 0   // 0..1
        readonly property bool charging: bat && bat.state === UPowerDeviceState.Charging
        visible: bat && bat.isLaptopBattery
        implicitWidth: capsule.width + (charging ? 26 : 10)
        implicitHeight: Theme.barHeight
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: capsule
            anchors.centerIn: parent
            width: 38; height: 16; radius: 5
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.subtle, 0.6)
            Rectangle {
                x: 2; y: 2
                height: parent.height - 4
                width: (parent.width - 4) * Math.max(0.04, parent.parent.pct)
                radius: 3
                color: parent.parent.charging ? Theme.ok
                     : parent.parent.pct < 0.15 ? Theme.err
                     : parent.parent.pct < 0.3 ? Theme.warn
                     : Theme.alpha(Theme.accent, 0.55)
                Behavior on width { NumberAnimation { duration: Theme.animSlow } }
            }
            // Over the fill once it reaches the label (~past 40%), the text
            // switches to the dark background colour — white-on-green was
            // unreadable in the first screenshot.
            Txt {
                anchors.centerIn: parent
                text: Math.round(parent.parent.pct * 100)
                font.pixelSize: Theme.smallSize
                font.bold: true
                color: parent.parent.pct > 0.4 ? Theme.bg : Theme.fg
            }
            Rectangle {   // the nub
                x: parent.width + 1; y: 5; width: 2; height: 6; radius: 1
                color: Theme.alpha(Theme.subtle, 0.6)
            }
        }
        Txt {   // charging bolt beside the capsule, not crammed inside it
            visible: parent.charging
            anchors.left: capsule.right
            anchors.leftMargin: 4
            text: Icons.charging
            color: Theme.ok
            font.pixelSize: Theme.iconSize
        }
    }

    // --- notifications ---------------------------------------------------------------------
    Hover {
        hpad: 6
        onClicked: Notifs.toggleCenter()
        onRightClicked: Notifs.toggleDnd()
        Txt {
            text: Notifs.dnd ? Icons.bellDnd : Notifs.count > 0 ? Icons.bellBadge : Icons.bell
            color: Notifs.dnd ? Theme.muted : Notifs.count > 0 ? Theme.accent : Theme.fg
            font.pixelSize: Theme.iconSize
        }
        Txt {
            visible: Notifs.count > 0 && !Notifs.dnd
            text: Notifs.count
            color: Theme.accent
            font.pixelSize: Theme.smallSize + 1
        }
    }

    // --- clock ---------------------------------------------------------------------------------
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Hover {
        hpad: 8
        spacing: 7
        Txt {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.bold: true
            font.pixelSize: Theme.textSize + 1
        }
        Txt {
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Theme.subtle
            font.pixelSize: Theme.smallSize + 1
        }
    }

    // --- tray ------------------------------------------------------------------------------------
    // nm-applet and blueman still autostart (their /etc/xdg/autostart
    // entries — hypr/autostart.conf), but their tray icons only duplicate
    // the network/bluetooth glyphs above, which open the same managers.
    // Hidden by SNI Id, read off the bus with busctl, not guessed.
    readonly property var trayHidden: ["nm-applet", "blueman"]
    Repeater {
        model: SystemTray.items
        delegate: Hover {
            id: trayItem
            required property var modelData
            visible: !root.trayHidden.includes(modelData.id)
            hpad: 5
            onClicked: modelData.onlyMenu ? openMenu() : modelData.activate()
            onRightClicked: openMenu()
            onMiddleClicked: modelData.secondaryActivate()
            function openMenu() {
                if (!modelData.hasMenu) return
                const p = trayItem.mapToItem(null, 0, trayItem.height + 6)
                modelData.display(QsWindow.window, p.x, p.y)
            }
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 15
                source: trayItem.modelData.icon
            }
        }
    }

    // --- power ------------------------------------------------------------------------------------
    Hover {
        hpad: 7
        onClicked: root.run(["wlogout", "-b", "5"])
        Txt { text: Icons.power; color: Theme.err; font.pixelSize: Theme.iconSize }
    }
}
