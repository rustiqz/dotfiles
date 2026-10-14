import QtQuick
import qs.common

// A clickable chip: rounded hover highlight behind arbitrary content, with
// left/right/middle click and scroll handlers. Every interactive thing on
// the bar is one of these, so hover feedback is uniform.
Rectangle {
    id: root
    default property alias content: row.data
    property alias spacing: row.spacing
    property alias hovered: mouse.containsMouse
    property int hpad: 6
    property bool active: false          // e.g. focused workspace
    property color activeColor: Theme.surfaceHi
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth + hpad * 2
    implicitHeight: Theme.barHeight - 10
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    radius: height / 2
    color: active ? activeColor
         : mouse.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.7)
         : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
            if (m.button === Qt.RightButton) root.rightClicked()
            else if (m.button === Qt.MiddleButton) root.middleClicked()
            else root.clicked()
        }
        onWheel: (w) => root.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
