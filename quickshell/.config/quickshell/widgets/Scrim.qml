import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// Click-outside-to-close for a popup layer: a full-screen transparent
// layer (Top) that catches every click or scroll not on the popup, which
// must sit a level higher (Overlay). Lightly dims while shown so the
// popup reads as modal; covers the bar too, so clicking the bar dismisses.
//
// Not HyprlandFocusGrab: a popup holding exclusive keyboard focus never
// gets `cleared` from it — not on an outside click, not on a focus change
// (traced in Phase 10; CLAUDE.md, Known gotchas). This needs nothing from
// the compositor.
PanelWindow {
    id: root
    property bool shown: false          // dim level follows this
    property real dim: 0.18
    signal dismissed()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.shown ? root.dim : 0)
        Behavior on color { ColorAnimation { duration: Theme.animMed } }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.dismissed()
        onWheel: root.dismissed()
    }
}
