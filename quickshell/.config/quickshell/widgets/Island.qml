import QtQuick
import qs.common

// One floating bar island: rounded, translucent (Hyprland blurs what's
// behind it — layerrule in hypr/windowrules.conf), sized to its content.
// Width animates, so when content changes (the dev island expanding for an
// event, a workspace gaining a window) the island morphs rather than
// jumping — the Prism "dynamic island" feel, done with one Behavior.
Rectangle {
    id: root
    default property alias content: row.data
    property alias spacing: row.spacing
    property int hpad: Theme.pad
    property color tint: Theme.surface

    implicitWidth: row.implicitWidth + hpad * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radius
    color: Theme.alpha(tint, Theme.islandOpacity)
    border.width: 1
    border.color: Theme.alpha(Theme.border, 0.55)

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
    }
}
