import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// The bar: one transparent layer-shell strip per monitor holding three
// floating islands. The strip itself is invisible — only the islands
// paint — and reserves exactly the bar's height as an exclusive zone, so
// tiled windows start just below the islands with the same 12px gap they
// have from every other screen edge (hypr/look.conf gaps_out).
//
// Namespace "quickshell-bar" is what hypr/windowrules.conf's layerrules
// match to blur behind the islands; ignore_alpha keeps the fully
// transparent gaps between them unblurred.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight + Theme.gap / 2
    exclusiveZone: implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    Workspaces {
        anchors.left: parent.left
        anchors.leftMargin: Theme.gap
        anchors.bottom: parent.bottom
    }

    DevIsland {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Status {
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        anchors.bottom: parent.bottom
    }
}
