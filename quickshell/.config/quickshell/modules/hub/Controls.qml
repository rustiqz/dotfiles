import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Top of the dev hub: the everyday controls, kept to one compact block —
// sliders for output/brightness/mic, a row of toggles, and a now-playing
// card when something is playing. Everything here also has a key or a bar
// glyph; this is the "do it without hunting" surface, not the only one.
Column {
    id: root
    spacing: 8

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }

    // --- brightness (no live source — read when shown and after each set) ---
    property real brightness: 0
    Process {
        id: brightGet
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text.split(",")[3])
                if (!isNaN(pct)) root.brightness = pct / 100
            }
        }
    }
    function refresh() { brightGet.running = true }
    function setBrightness(v) {
        root.brightness = v
        // Floor at 1%: 0 turns the panel fully off, which reads as a crash.
        Quickshell.execDetached(["brightnessctl", "-q", "set", `${Math.max(1, Math.round(v * 100))}%`])
    }

    Slider {
        width: parent.width
        icon: !root.sink || !root.sink.audio || root.sink.audio.muted ? Icons.volOff : Icons.vol[2]
        value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
        dim: !root.sink || !root.sink.audio || root.sink.audio.muted
        onMoved: (v) => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v } }
        onIconClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
    }
    Slider {
        width: parent.width
        icon: Icons.brightness
        fill: Theme.warn
        value: root.brightness
        onMoved: (v) => root.setBrightness(v)
    }
    Slider {
        width: parent.width
        icon: !root.source || !root.source.audio || root.source.audio.muted ? Icons.micOff : Icons.mic
        fill: Theme.info
        value: root.source && root.source.audio ? root.source.audio.volume : 0
        dim: !root.source || !root.source.audio || root.source.audio.muted
        onMoved: (v) => { if (root.source && root.source.audio) { root.source.audio.muted = false; root.source.audio.volume = v } }
        onIconClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
    }

    Process {
        id: caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=dev hub", "--why=Caffeine toggle", "sleep", "infinity"]
    }

    // --- toggles --------------------------------------------------------------------
    component Toggle: Rectangle {
        id: t
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color onColor: Theme.accent
        signal toggled()
        width: (root.width - 3 * 6) / 4
        height: 54
        radius: 12
        color: on ? Theme.alpha(onColor, 0.22) : Theme.alpha(Theme.surfaceHi, 0.6)
        border.width: 1
        border.color: on ? Theme.alpha(onColor, 0.6) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: t.icon
                color: t.on ? t.onColor : Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.iconSize + 4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: t.label
                color: t.on ? Theme.fg : Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
                font.bold: true
                width: Math.min(implicitWidth, t.width - 8)
                elide: Text.ElideRight
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled() }
    }

    Row {
        spacing: 6
        readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
        readonly property var wifiNet: wifiDev ? wifiDev.networks.values.find(n => n.connected) : null
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property var btDev: Bluetooth.devices.values.find(d => d.connected)

        Toggle {
            icon: Networking.wifiEnabled ? Icons.wifiOn : Icons.wifiOff
            label: parent.wifiNet ? parent.wifiNet.name : "Wi-Fi"
            on: Networking.wifiEnabled
            // nmcli rather than flipping the property: it's the same call
            // waybar's network menu used, so behaviour is unchanged.
            onToggled: Quickshell.execDetached(["nmcli", "radio", "wifi", Networking.wifiEnabled ? "off" : "on"])
        }
        Toggle {
            icon: parent.btDev ? Icons.btOn : parent.adapter && parent.adapter.enabled ? Icons.bt : Icons.btOff
            label: parent.btDev ? parent.btDev.name : "Bluetooth"
            on: !!parent.adapter && parent.adapter.enabled
            onColor: Theme.info
            onToggled: if (parent.adapter) parent.adapter.enabled = !parent.adapter.enabled
        }
        Toggle {
            icon: Notifs.dnd ? Icons.bellDnd : Icons.bell
            label: "Silence"
            on: Notifs.dnd
            onColor: Theme.warn
            onToggled: Notifs.toggleDnd()
        }
        // Caffeine: holds a systemd idle inhibitor while on. hypridle
        // honours those (ignore_systemd_inhibit defaults to false), so no
        // dim/lock/suspend — for a long build or a demo. Lives exactly as
        // long as this process: quitting the shell releases it.
        Toggle {
            icon: Icons.coffee
            label: "Caffeine"
            on: caffeine.running
            onColor: Theme.ok
            onToggled: caffeine.running = !caffeine.running
        }
    }

    // --- power profile ------------------------------------------------------------------
    // Segmented selector for power-profiles-daemon: one segment per
    // profile the hardware offers, the active one filled. Full width
    // because a profile is a choice among named options, not an on/off.
    Row {
        id: profiles
        width: parent.width
        spacing: 6
        Repeater {
            model: PowerProf.order
            delegate: Rectangle {
                id: seg
                required property int modelData
                readonly property bool on: PowerProf.profile === modelData
                readonly property color tint: PowerProf.color(modelData)
                width: (profiles.width - (PowerProf.order.length - 1) * 6) / PowerProf.order.length
                height: 38
                radius: 12
                color: on ? Theme.alpha(Theme.accent, 0.22) : Theme.alpha(Theme.surfaceHi, 0.6)
                border.width: 1
                border.color: on ? Theme.alpha(Theme.accent, 0.6) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PowerProf.icon(seg.modelData)
                        color: seg.on ? Theme.accent : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: Theme.iconSize + 2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PowerProf.label(seg.modelData)
                        color: seg.on ? Theme.fg : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: Theme.smallSize
                        font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProf.set(seg.modelData)
                }
            }
        }
    }

    // --- now playing --------------------------------------------------------------------
    // The playing player if any, else the first that exists. Hidden when
    // there's nothing — no empty "Nothing playing" card taking up room.
    Rectangle {
        readonly property var players: Mpris.players.values
        readonly property var p: players.find(x => x.isPlaying) || players[0] || null
        visible: p !== null
        width: parent.width
        height: 64
        radius: 12
        color: Theme.alpha(Theme.surfaceHi, 0.6)

        ClippingRectangle {
            id: art
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 48; height: 48; radius: 8
            color: Theme.alpha(Theme.accent, 0.2)
            Image {
                anchors.fill: parent
                source: parent.parent.p ? parent.parent.p.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Txt {
                anchors.centerIn: parent
                visible: !parent.children[0].visible
                text: Icons.music; color: Theme.accent; font.pixelSize: 20
            }
        }
        Column {
            anchors.left: art.right; anchors.leftMargin: 10
            anchors.right: transport.left; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Txt {
                anchors.verticalCenter: undefined
                width: parent.width
                text: parent.parent.p ? parent.parent.p.trackTitle || parent.parent.p.identity : ""
                font.bold: true; elide: Text.ElideRight
            }
            Txt {
                anchors.verticalCenter: undefined
                width: parent.width
                text: parent.parent.p ? parent.parent.p.trackArtist : ""
                color: Theme.subtle; font.pixelSize: Theme.smallSize + 1; elide: Text.ElideRight
            }
        }
        Row {
            id: transport
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Hover { onClicked: parent.parent.p.previous(); Txt { text: Icons.prev; font.pixelSize: Theme.iconSize + 2 } }
            Hover {
                active: true
                activeColor: Theme.accent
                hpad: 9
                onClicked: parent.parent.p.togglePlaying()
                Txt { text: parent.parent.parent.p && parent.parent.parent.p.isPlaying ? Icons.pause : Icons.play
                      color: Theme.bg; font.pixelSize: Theme.iconSize + 2 }
            }
            Hover { onClicked: parent.parent.p.next(); Txt { text: Icons.next; font.pixelSize: Theme.iconSize + 2 } }
        }
    }
}
