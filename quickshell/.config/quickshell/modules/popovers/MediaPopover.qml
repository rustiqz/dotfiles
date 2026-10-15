import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services
import qs.widgets

// Media popover — the bar's music chip. Whatever MPRIS player is playing
// (Spotify, a browser tab, mpv…): artwork, title/artist/album, a seekable
// progress bar, transport, shuffle/repeat and the player's own volume.
//
// Player choice lives in services/Media.qml. With more than one player a
// row of chips at the top pins one; the choice sticks until that player
// goes away. Nothing playing gets a quiet empty state, not a blank card.
//
// Keys: Space play/pause · n/p next/previous · ←/→ seek 5s · ↑/↓ volume ·
// s shuffle · r repeat · o raise the player's window
Popover {
    id: pop
    name: "media"
    cardWidth: 480

    readonly property var p: Media.current
    readonly property bool has: p !== null
    readonly property bool seekable: has && p.length > 0 && p.canSeek && p.positionSupported
    readonly property real frac: has && p.length > 0 ? Math.max(0, Math.min(1, p.position / p.length)) : 0

    // MPRIS never pushes `position` as it advances — it has to be asked.
    // Once a second while open and playing is plenty for a progress bar.
    Timer { interval: 1000; running: pop.open && pop.has && pop.p.isPlaying; repeat: true
            onTriggered: pop.p.positionChanged() }
    onOpened: if (has) p.positionChanged()

    function seekBy(sec) { if (seekable) p.position = Math.max(0, Math.min(p.length, p.position + sec)) }
    function nudgeVolume(d) { if (has && p.volumeSupported) p.volume = Math.max(0, Math.min(1, p.volume + d)) }
    function cycleLoop() {
        if (!has || !p.loopSupported) return
        p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
    }

    onKey: (e) => {
        if (!has) return
        if (e.key === Qt.Key_Space) p.togglePlaying()
        else if (e.key === Qt.Key_N) p.next()
        else if (e.key === Qt.Key_P) p.previous()
        else if (e.key === Qt.Key_Right) seekBy(5)
        else if (e.key === Qt.Key_Left) seekBy(-5)
        else if (e.key === Qt.Key_Up) nudgeVolume(0.05)
        else if (e.key === Qt.Key_Down) nudgeVolume(-0.05)
        else if (e.key === Qt.Key_S && p.shuffleSupported) p.shuffle = !p.shuffle
        else if (e.key === Qt.Key_R) cycleLoop()
        else if (e.key === Qt.Key_O && p.canRaise) { p.raise(); Pops.close() }
        else return
        e.accepted = true
    }

    // A round icon button; `on` tints it (shuffle/repeat engaged).
    component Btn: Rectangle {
        id: b
        property string icon
        property bool on: false
        property bool enabledBtn: true
        property int size: 40
        property int glyph: Theme.iconSize + 4
        signal clicked()
        width: size; height: size; radius: size / 2
        opacity: enabledBtn ? 1 : 0.35
        color: on ? Theme.alpha(Theme.accent, 0.25) : bm.containsMouse && enabledBtn ? Theme.alpha(Theme.surfaceHi, 0.95) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Txt { anchors.centerIn: parent; text: b.icon; color: b.on ? Theme.accent : Theme.fg; font.pixelSize: b.glyph }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (b.enabledBtn) b.clicked() }
    }

    Column {
        width: parent.width
        spacing: 16

        // ---- nothing playing -------------------------------------------------------
        Column {
            visible: !pop.has
            width: parent.width
            spacing: 6
            topPadding: 18; bottomPadding: 18
            Txt { anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter
                  text: Icons.music; color: Theme.muted; font.pixelSize: 38 }
            Txt { anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter
                  text: "Nothing playing"; font.bold: true; font.pixelSize: Theme.textSize + 3 }
            Txt { anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter
                  text: "Start a player — Super+M opens Spotify"; color: Theme.muted; font.pixelSize: Theme.smallSize + 1 }
        }

        // ---- artwork + track ----------------------------------------------------------
        Row {
            visible: pop.has
            width: parent.width
            spacing: 18

            ClippingRectangle {
                id: art
                width: 150; height: 150; radius: 16
                color: Theme.alpha(Theme.accent, 0.18)
                Image {
                    id: artImg
                    anchors.fill: parent
                    source: pop.has ? pop.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Txt { anchors.centerIn: parent; visible: !artImg.visible; text: Icons.music; color: Theme.accent; font.pixelSize: 44 }
            }

            Item {
                width: parent.width - art.width - parent.spacing
                height: art.height

                // Player(s): chips to pin one when there are several.
                Row {
                    id: who
                    spacing: 6
                    Repeater {
                        model: Media.players
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool cur: pop.p === modelData
                            width: wl.implicitWidth + 16; height: 20; radius: 10
                            color: cur ? Theme.alpha(Theme.accent, 0.22) : wm.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.9) : Theme.alpha(Theme.surfaceHi, 0.5)
                            visible: Media.players.length > 1 || cur
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Txt { id: wl; anchors.centerIn: parent; text: modelData.identity; font.pixelSize: Theme.smallSize
                                  color: cur ? Theme.accent : Theme.subtle; font.bold: cur }
                            MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: Media.pinned = modelData.dbusName }
                        }
                    }
                }
                // Raise the player's own window.
                Rectangle {
                    visible: pop.has && pop.p.canRaise
                    anchors.right: parent.right; y: -3
                    width: 26; height: 26; radius: 8
                    color: rm.containsMouse ? Theme.alpha(Theme.accent, 0.28) : "transparent"
                    Txt { anchors.centerIn: parent; text: Icons.open; color: Theme.subtle; font.pixelSize: Theme.iconSize }
                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { pop.p.raise(); Pops.close() } }
                }

                Column {
                    anchors.top: who.bottom; anchors.topMargin: 12
                    width: parent.width
                    spacing: 4
                    Txt { anchors.verticalCenter: undefined; width: parent.width
                          text: pop.has ? (pop.p.trackTitle || pop.p.identity) : ""
                          font.bold: true; font.pixelSize: Theme.textSize + 6
                          wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    Txt { anchors.verticalCenter: undefined; width: parent.width
                          visible: text !== ""; text: pop.has ? pop.p.trackArtist : ""
                          color: Theme.subtle; font.pixelSize: Theme.textSize + 1; elide: Text.ElideRight }
                    Txt { anchors.verticalCenter: undefined; width: parent.width
                          visible: text !== ""; text: pop.has ? pop.p.trackAlbum : ""
                          color: Theme.muted; font.pixelSize: Theme.smallSize + 1; elide: Text.ElideRight }
                }
            }
        }

        // ---- progress --------------------------------------------------------------------
        Column {
            visible: pop.has && pop.p.length > 0
            width: parent.width
            spacing: 4

            Item {
                width: parent.width; height: 14
                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Theme.alpha(Theme.border, 0.6)
                    Rectangle {
                        width: parent.width * pop.frac; height: parent.height; radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.accent2 }
                        }
                    }
                    // Knob: only while hovering or dragging, and only if seeking works.
                    Rectangle {
                        visible: pop.seekable && (sm.containsMouse || sm.pressed)
                        x: Math.max(0, Math.min(track.width - width, track.width * pop.frac - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12; radius: 6; color: Theme.fg
                    }
                }
                MouseArea {
                    id: sm
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: pop.seekable
                    cursorShape: pop.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    function seek(x) { pop.p.position = Math.max(0, Math.min(1, x / width)) * pop.p.length }
                    onPressed: (m) => seek(m.x)
                    onPositionChanged: (m) => { if (pressed) seek(m.x) }
                }
            }
            Item {
                width: parent.width; height: 14
                Txt { text: Media.fmt(pop.has ? pop.p.position : 0); color: Theme.muted; font.pixelSize: Theme.smallSize }
                Txt { anchors.right: parent.right; text: Media.fmt(pop.has ? pop.p.length : 0); color: Theme.muted; font.pixelSize: Theme.smallSize }
            }
        }

        // ---- transport ---------------------------------------------------------------------
        Row {
            visible: pop.has
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Btn { icon: Icons.shuffle; on: pop.has && pop.p.shuffleSupported && pop.p.shuffle
                  enabledBtn: pop.has && pop.p.shuffleSupported; size: 36; glyph: Theme.iconSize + 2
                  onClicked: pop.p.shuffle = !pop.p.shuffle }
            Btn { icon: Icons.prev; enabledBtn: pop.has && pop.p.canGoPrevious; onClicked: pop.p.previous() }
            Rectangle {
                width: 52; height: 52; radius: 26
                color: pm.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Txt { anchors.centerIn: parent; text: pop.has && pop.p.isPlaying ? Icons.pause : Icons.play
                      color: Theme.bg; font.pixelSize: Theme.iconSize + 8 }
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: pop.p.togglePlaying() }
            }
            Btn { icon: Icons.next; enabledBtn: pop.has && pop.p.canGoNext; onClicked: pop.p.next() }
            Btn { icon: pop.has && pop.p.loopState === MprisLoopState.Track ? Icons.repeatOnce : Icons.repeat
                  on: pop.has && pop.p.loopSupported && pop.p.loopState !== MprisLoopState.None
                  enabledBtn: pop.has && pop.p.loopSupported; size: 36; glyph: Theme.iconSize + 2
                  onClicked: pop.cycleLoop() }
        }

        // ---- volume ----------------------------------------------------------------------------
        Slider {
            visible: pop.has && pop.p.volumeSupported
            width: parent.width
            value: pop.has ? pop.p.volume : 0
            icon: Icons.vol[value < 0.34 ? 0 : value < 0.67 ? 1 : 2]
            onMoved: (v) => { pop.p.volume = v }
        }

        Txt {
            anchors.verticalCenter: undefined
            visible: pop.has
            text: "space play   n next   p prev   ←→ seek   ↑↓ volume   s shuffle   r repeat"
            color: Theme.muted; font.pixelSize: Theme.smallSize
        }
    }
}
