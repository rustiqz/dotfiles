import QtQuick
import qs.common

// Pill switch for popover headers (radio on/off). Pure view: `checked` is
// bound by the caller to real state, and a click only emits `toggled()` —
// the caller flips the actual thing, so the knob can never disagree with it.
Rectangle {
    id: root
    property bool checked: false
    signal toggled()
    implicitWidth: 38; implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.accent : Theme.surfaceHi
    border.width: 1
    border.color: Theme.alpha(Theme.border, 0.8)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Rectangle {
        width: 16; height: 16; radius: 8
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.bg : Theme.subtle
        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}
