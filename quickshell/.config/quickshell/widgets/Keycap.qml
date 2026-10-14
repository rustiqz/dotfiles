import QtQuick
import qs.common

// A key hint: bordered rounded cap with the key's label. Used in the dev
// hub's section tabs and footer, so every keyboard shortcut is visible
// where it applies — the hub is meant to be driven without the mouse.
Rectangle {
    id: root
    property string key: ""
    property bool lit: false   // highlights the key of the current section

    implicitWidth: Math.max(label.implicitWidth + 10, 20)
    implicitHeight: 18
    radius: 5
    color: lit ? Theme.alpha(Theme.accent, 0.25) : Theme.alpha(Theme.surfaceHi, 0.8)
    border.width: 1
    border.color: lit ? Theme.accent : Theme.alpha(Theme.border, 0.9)
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.key
        color: root.lit ? Theme.accent : Theme.subtle
        font.family: Theme.font
        font.pixelSize: Theme.smallSize
        font.bold: true
    }
}
