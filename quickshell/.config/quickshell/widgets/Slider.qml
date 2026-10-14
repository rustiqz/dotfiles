import QtQuick
import qs.common

// A fat pill slider (Prism's control-drawer style): the fill *is* the
// value, with the icon and percentage drawn over it. Drag, click, or
// scroll. `moved(v)` fires on user input only, never on external value
// changes, so it can drive a setter without feedback loops.
Rectangle {
    id: root
    property real value: 0          // 0..1
    property string icon: ""
    property color fill: Theme.accent
    property bool dim: false        // e.g. muted: fill greys out
    signal moved(real v)
    signal iconClicked()

    implicitHeight: 34
    radius: 12
    color: Theme.alpha(Theme.surfaceHi, 0.75)

    Rectangle {
        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
        height: parent.height
        radius: parent.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.dim ? Theme.muted : root.fill }
            GradientStop { position: 1; color: root.dim ? Theme.muted : Theme.alpha(Theme.accent2, 0.85) }
        }
        opacity: root.dim ? 0.5 : 0.9
        Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: (m) => set(m.x)
        onPositionChanged: (m) => { if (pressed) set(m.x) }
        onWheel: (w) => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }

    Txt {
        x: 12
        text: root.icon
        color: root.dim ? Theme.subtle : Theme.bg
        font.pixelSize: Theme.iconSize + 2
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }
    Txt {
        anchors.right: parent.right
        anchors.rightMargin: 12
        text: `${Math.round(root.value * 100)}%`
        color: Theme.fg
        font.pixelSize: Theme.smallSize + 1
        font.bold: true
    }
}
