import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.common
import qs.services
import qs.widgets

// Notification popups: a stack of themed cards under the bar, top right.
// The window is only as big as the stack and click-through everywhere
// else (mask), so it never blocks what's underneath. Click a card to run
// its default action and dismiss it; the × dismisses; action buttons run
// the sender's actions. A toast times out of view but stays in the
// notification centre until dismissed (services/Notifs.qml).
//
// Namespace "quickshell-toasts": hypr/windowrules.conf blurs it like the
// bar and the other popups.
Scope {
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: Theme.barHeight + Theme.gap / 2 + 4; right: Theme.gap }
        implicitWidth: 380
        implicitHeight: Math.max(1, stack.height)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: Notifs.toasts.length > 0
        mask: Region { item: stack }
        WlrLayershell.namespace: "quickshell-toasts"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Column {
            id: stack
            width: parent.width
            spacing: 8
            Repeater {
                model: Notifs.toasts
                delegate: NotificationCard {
                    required property var modelData
                    notif: modelData
                    width: stack.width
                    timeoutMs: Notifs.toastMs(modelData)
                    onExpired: Notifs.hide(modelData)
                    onDismissed: Notifs.dismiss(modelData)
                }
            }
        }
    }
}
