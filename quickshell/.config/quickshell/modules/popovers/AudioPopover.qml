import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.common
import qs.services
import qs.widgets

// Audio popover — replaces "right-click opens pavucontrol". PipeWire
// through Quickshell.Services.Pipewire, so it's live: a stream starting
// in another app appears here as it happens.
//
//   Output / Input   volume slider (icon mutes) + a device list; clicking
//                    a device makes it the default
//   Apps             one slider per playing stream
//
// The bar icon keeps scroll-to-adjust and click-to-mute; opening this is
// the middle-click. Nothing here is hardcoded to a device or app name.
Popover {
    id: pop
    name: "audio"
    cardWidth: 360

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values
    // Hardware sinks/sources only (no streams, no unnamed monitors).
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream
                                                     && !(n.name || "").endsWith(".monitor"))
    readonly property var streams: nodes.filter(n => n.audio && n.isSink && n.isStream)

    // Volume/mute on a node are only readable while it's tracked.
    PwObjectTracker { objects: [...pop.sinks, ...pop.sources, ...pop.streams] }

    function label(n) { return n.nickname || n.description || n.name }
    function appName(n) {
        const p = n.properties || {}
        return p["application.name"] || n.description || n.name
    }
    function setVol(n, v) { if (n.audio) { n.audio.muted = false; n.audio.volume = v } }
    function volIcon(n) {
        return !n.audio || n.audio.muted ? Icons.volOff : Icons.vol[n.audio.volume < 0.34 ? 0 : n.audio.volume < 0.67 ? 1 : 2]
    }

    component DeviceList: Column {
        id: dl
        property var devices: []
        property var current: null
        property bool isSource: false
        width: parent.width
        spacing: 2
        Repeater {
            model: dl.devices
            delegate: Rectangle {
                required property var modelData
                readonly property bool isDefault: dl.current !== null && modelData.id === dl.current.id
                width: dl.width; height: 32; radius: 10
                color: ma.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.9) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Txt { x: 10; text: isDefault ? Icons.check : ""; width: 14; color: Theme.accent; font.pixelSize: Theme.iconSize }
                Txt { x: 30; text: pop.label(modelData); elide: Text.ElideRight; width: parent.width - 44
                      color: isDefault ? Theme.accent : Theme.fg }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true
                    onClicked: dl.isSource ? Pipewire.preferredDefaultAudioSource = modelData
                                           : Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 8

        Txt { anchors.verticalCenter: undefined; text: "Audio"; font.bold: true; font.pixelSize: Theme.textSize + 2 }

        // --- output ---------------------------------------------------------
        Txt { anchors.verticalCenter: undefined; text: "OUTPUT"; color: Theme.muted; font.pixelSize: Theme.smallSize; font.letterSpacing: 1.5 }
        Slider {
            width: parent.width
            visible: pop.sink !== null && pop.sink.audio !== null
            value: pop.sink && pop.sink.audio ? pop.sink.audio.volume : 0
            dim: pop.sink && pop.sink.audio ? pop.sink.audio.muted : false
            icon: pop.sink ? pop.volIcon(pop.sink) : ""
            onMoved: (v) => pop.setVol(pop.sink, v)
            onIconClicked: if (pop.sink && pop.sink.audio) pop.sink.audio.muted = !pop.sink.audio.muted
        }
        DeviceList { devices: pop.sinks; current: pop.sink }

        // --- input ----------------------------------------------------------
        Txt { anchors.verticalCenter: undefined; text: "INPUT"; color: Theme.muted; font.pixelSize: Theme.smallSize; font.letterSpacing: 1.5; topPadding: 6
              visible: pop.sources.length > 0 }
        Slider {
            width: parent.width
            visible: pop.source !== null && pop.source.audio !== null
            fill: Theme.accent2
            value: pop.source && pop.source.audio ? pop.source.audio.volume : 0
            dim: pop.source && pop.source.audio ? pop.source.audio.muted : false
            icon: Icons.mic
            onMoved: (v) => pop.setVol(pop.source, v)
            onIconClicked: if (pop.source && pop.source.audio) pop.source.audio.muted = !pop.source.audio.muted
        }
        DeviceList { devices: pop.sources; current: pop.source; isSource: true }

        // --- apps -----------------------------------------------------------
        Txt { anchors.verticalCenter: undefined; text: "APPS"; color: Theme.muted; font.pixelSize: Theme.smallSize; font.letterSpacing: 1.5; topPadding: 6
              visible: pop.streams.length > 0 }
        Repeater {
            model: pop.streams
            delegate: Item {
                required property var modelData
                width: parent.width; height: 44
                Txt { anchors.verticalCenter: undefined; text: pop.appName(modelData); elide: Text.ElideRight; width: parent.width
                      color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                Slider {
                    y: 16; width: parent.width; implicitHeight: 26
                    value: modelData.audio ? modelData.audio.volume : 0
                    dim: modelData.audio ? modelData.audio.muted : false
                    onMoved: (v) => pop.setVol(modelData, v)
                    onIconClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                }
            }
        }
        Txt { anchors.verticalCenter: undefined; visible: pop.streams.length === 0
              width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 4
              text: "Nothing is playing"; color: Theme.muted; font.pixelSize: Theme.smallSize + 1 }
    }
}
