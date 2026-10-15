import QtQuick
import qs.common
import qs.widgets

// Battery card for a connected headset/earbuds: name, one big level, a
// bar tinted by charge. BlueZ publishes a single Battery1 value per
// device, so this shows that one number — no invented left/right/case.
//
// Per-bud + case levels are vendor-specific (Apple/Samsung/Airoha GATT or
// AT commands), not something BlueZ or Quickshell surface. If a pair of
// earbuds turns out to expose them, this is the one place to add the
// L / R / Case cells: give `parts` {left, right, case} (0..1, -1 unknown)
// and render a cell per known value.
Rectangle {
    id: root
    property var device
    readonly property real level: device ? (device.battery > 1 ? device.battery / 100 : device.battery) : 0
    readonly property color tone: level < 0.2 ? Theme.err : level < 0.5 ? Theme.warn : Theme.ok

    height: 64
    radius: 14
    color: Theme.alpha(Theme.surfaceHi, 0.6)
    border.width: 1
    border.color: Theme.alpha(Theme.border, 0.7)

    Txt { x: 14; y: 10; text: Icons.headphones; font.pixelSize: 22; color: Theme.info; anchors.verticalCenter: undefined }
    Txt { x: 48; y: 10; text: root.device ? root.device.name : ""; elide: Text.ElideRight; width: parent.width - 130
          anchors.verticalCenter: undefined }
    Txt { anchors.right: parent.right; anchors.rightMargin: 14; y: 6; anchors.verticalCenter: undefined
          text: `${Math.round(root.level * 100)}%`; color: root.tone; font.pixelSize: Theme.textSize + 6; font.bold: true }
    Rectangle {
        x: 48; y: 38; width: parent.width - 62; height: 8; radius: 4
        color: Theme.alpha(Theme.border, 0.6)
        Rectangle {
            width: parent.width * root.level; height: parent.height; radius: 4
            color: root.tone
            Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        }
    }
}
