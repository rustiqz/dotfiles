import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services

// A card that drops from a bar icon: the shared shell for the Wi-Fi,
// Bluetooth (and later audio/battery/...) popovers. Same recipe as the
// power menu — Scrim underneath for click-outside, card on the Overlay
// layer with OnDemand keyboard focus (never Exclusive, see Scrim.qml).
//
// Usage:
//   Popover { name: "wifi"; cardWidth: 340
//             onKey: (e) => { ... }          // keys not eaten by a child
//             Column { ... } }               // content, any Item
//
// Placement: horizontally centred under Pops.anchorX (the clicked icon),
// clamped to the screen so an icon near the edge can't push the card off.
// Height follows the content.
Scope {
    id: root
    property string name
    property int cardWidth: 340
    property int pad: 14
    default property alias content: body.data
    readonly property bool open: Pops.current === name
    signal key(var event)
    signal opened()

    Scrim {
        screen: card.screen
        visible: root.open || fade.running
        shown: root.open
        dim: 0.12
        WlrLayershell.namespace: "quickshell-popover-scrim"
        onDismissed: Pops.close()
    }

    PanelWindow {
        id: card
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        anchors { top: true; left: true }
        margins {
            top: Theme.barHeight + Theme.gap / 2 + 4
            left: Math.max(Theme.gap, Math.min(Pops.anchorX - root.cardWidth / 2,
                                               (screen ? screen.width : 1920) - root.cardWidth - Theme.gap))
        }
        implicitWidth: root.cardWidth
        implicitHeight: body.implicitHeight + root.pad * 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: root.open || fade.running
        WlrLayershell.namespace: "quickshell-popover"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onVisibleChanged: if (visible && root.open) { keys.forceActiveFocus(); root.opened() }
        Connections { target: root; function onOpenChanged() { if (root.open) { keys.forceActiveFocus(); root.opened() } } }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius + 4
            color: Theme.alpha(Theme.surface, 0.97)
            border.width: 1
            border.color: Theme.alpha(Theme.border, 0.9)
            clip: true
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { id: fade; duration: Theme.animMed } }
            Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            // Children with active focus (a password field) see keys first;
            // anything they leave unaccepted lands here.
            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Escape) { Pops.close(); e.accepted = true; return }
                    root.key(e)
                }

                Item {
                    id: body
                    x: root.pad; y: root.pad
                    width: root.cardWidth - root.pad * 2
                    implicitHeight: childrenRect.height
                }
            }
        }
    }
}
