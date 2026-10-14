import QtQuick
import qs.common
import qs.widgets

// One row in a hub section. Every section (agents, CI, services, ports,
// watchers) builds plain JS objects of the same shape and this renders
// them, so sections differ only in *what* they show, not how:
//
//   { icon, iconColor, title, subtitle, chip, chipColor, indent,
//     hp,            // optional 0..1: draws a game-style HP bar (Party)
//     actions: { Enter: fn, u: fn, ... } }
//
// The selected row (keyboard cursor) gets the accent bar on its left edge.
Rectangle {
    id: root
    required property var item
    required property bool selected
    signal activated()

    implicitHeight: col.implicitHeight + 16
    radius: 10
    color: selected ? Theme.alpha(Theme.accent, 0.13)
         : mouse.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.55)
         : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Rectangle {   // selection bar
        width: 3; radius: 2
        height: parent.height - 14
        anchors.verticalCenter: parent.verticalCenter
        x: 2
        color: Theme.accent
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    Txt {
        id: icon
        x: 14 + (root.item.indent || 0) * 18
        anchors.verticalCenter: undefined
        y: 8
        text: root.item.icon || ""
        color: root.item.iconColor || Theme.subtle
        font.pixelSize: Theme.iconSize + 2
    }

    Column {
        id: col
        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: chip.left
        anchors.rightMargin: 8
        y: 8
        spacing: 2
        Txt {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.item.title || ""
            font.bold: true
            elide: Text.ElideRight
        }
        Txt {
            anchors.verticalCenter: undefined
            width: parent.width
            visible: text !== ""
            text: root.item.subtitle || ""
            color: Theme.subtle
            font.pixelSize: Theme.smallSize + 1
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        // HP bar, Pokémon-style: green above half, yellow above a fifth,
        // red below — the colour change is the signal, not the number.
        Row {
            visible: root.item.hp !== undefined
            spacing: 6
            topPadding: 3
            Text {
                text: "HP"
                color: Theme.warn
                font.family: Theme.font; font.pixelSize: 9; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 150; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.alpha(Theme.surfaceHi, 0.9)
                border.width: 1; border.color: Theme.alpha(Theme.border, 0.8)
                Rectangle {
                    readonly property real hp: Math.max(0, Math.min(1, root.item.hp || 0))
                    width: (parent.width - 2) * hp
                    height: parent.height - 2
                    x: 1; y: 1; radius: 2
                    color: hp > 0.5 ? Theme.ok : hp > 0.2 ? Theme.warn : Theme.err
                    Behavior on width { NumberAnimation { duration: Theme.animMed } }
                    Behavior on color { ColorAnimation { duration: Theme.animMed } }
                }
            }
        }
    }

    Rectangle {
        id: chip
        visible: !!root.item.chip
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 8
        implicitWidth: visible ? chipText.implicitWidth + 14 : 0
        implicitHeight: 20
        radius: 10
        color: Theme.alpha(root.item.chipColor || Theme.muted, 0.2)
        Text {
            id: chipText
            anchors.centerIn: parent
            text: root.item.chip || ""
            color: root.item.chipColor || Theme.subtle
            font.family: Theme.font
            font.pixelSize: Theme.smallSize
            font.bold: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.item.actions && root.item.actions.Enter ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
