pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services

// The notification daemon — Quickshell owns org.freedesktop.Notifications
// now (swaync used to). That is what makes a themed history panel
// possible: swaync keeps its history to itself, this keeps it here.
//
//   history   every notification not yet dismissed (the server's tracked
//             list), newest last — the notification-centre popover's rows
//   toasts    the subset currently on screen as popups (modules/
//             notifications/Toasts.qml); each leaves after its timeout but
//             stays in history until dismissed
//   dnd       Do Not Disturb: arrivals go to history silently, no toast
//
// Same surface as before (count, dnd, toggleDnd) so the bar bell and the
// hub's Silence toggle didn't change. Rollback to swaync: restore
// `exec-once = uwsm app -- swaync` in hypr/autostart.conf and `$mod+N`'s
// swaync-client bind; quickshell then fails to claim the bus name (logged)
// and stays out of the way.
Singleton {
    id: root

    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length
    property bool dnd: false
    property var toasts: []              // Notification objects currently shown
    property var stamps: ({})            // id -> arrival Date (the protocol carries none)

    function toggleDnd() { dnd = !dnd }
    function stampOf(n) { return stamps[n.id] || new Date() }

    function dismiss(n) { hide(n); n.dismiss() }
    function clearAll() {
        toasts = []
        for (const n of [...history]) n.dismiss()
    }
    function hide(n) { toasts = toasts.filter(t => t !== n) }

    // Seconds a toast stays up: the sender's own request if it gave one,
    // else 6s (critical: until dismissed).
    function toastMs(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0
        return n.expireTimeout > 0 ? n.expireTimeout * 1000 : 6000
    }

    NotificationServer {
        id: server
        keepOnReload: true               // a live qs reload must not drop pending notifications
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: (n) => {
            n.tracked = true
            root.stamps[n.id] = new Date()
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.toasts = [...root.toasts, n]
        }
    }

    // `qs ipc call notifs toggle` — the $mod+N bind; `dnd` for scripts.
    IpcHandler {
        target: "notifs"
        function toggle(): void { Pops.toggle("notifications", (Quickshell.screens[0] ? Quickshell.screens[0].width : 1920) - 180) }
        function dnd(): void { root.toggleDnd() }
        function clear(): void { root.clearAll() }
    }
}
