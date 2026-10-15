import QtQuick
import Quickshell
import qs.common
import qs.services
import qs.widgets
import qs.modules.notifications

// Notification centre — the bell's click and $mod+N. History comes from
// services/Notifs.qml (this shell is the notification daemon now), shown
// newest-first and grouped by app so a chatty app is one block, not a
// wall. Each card is the same one the toasts use.
//
//   × on a card dismisses it · click a card runs its default action
//   Clear all empties everything · the switch is Do Not Disturb
//   d toggles DND · c clears all · Esc closes
Popover {
    id: pop
    name: "notifications"
    cardWidth: 400

    // [{app, items:[notification…newest first]}], groups ordered by their newest item.
    readonly property var groups: {
        const byApp = {}, order = []
        for (const n of [...Notifs.history].reverse()) {
            const k = n.appName || "Other"
            if (!byApp[k]) { byApp[k] = { app: k, items: [] }; order.push(byApp[k]) }
            byApp[k].items.push(n)
        }
        return order
    }

    function ago(d) {
        const s = Math.max(0, Math.round((Date.now() - d.getTime()) / 1000))
        return s < 60 ? "now" : s < 3600 ? `${Math.floor(s / 60)}m` : s < 86400 ? `${Math.floor(s / 3600)}h` : `${Math.floor(s / 86400)}d`
    }

    onKey: (e) => {
        if (e.text === "d") Notifs.toggleDnd()
        else if (e.text === "c") Notifs.clearAll()
        else return
        e.accepted = true
    }

    Column {
        width: parent.width
        spacing: 10

        Item {
            width: parent.width; height: 26
            Txt { text: "Notifications"; font.bold: true; font.pixelSize: Theme.textSize + 2 }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Hover {
                    visible: Notifs.count > 0
                    hpad: 8; onClicked: Notifs.clearAll()
                    Txt { text: "Clear all"; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                }
                Txt { text: "DND"; color: Theme.muted; font.pixelSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
                Toggle { anchors.verticalCenter: parent.verticalCenter; checked: Notifs.dnd; onToggled: Notifs.toggleDnd() }
            }
        }

        Txt {
            anchors.verticalCenter: undefined
            visible: Notifs.count === 0
            width: parent.width; height: 70; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: Notifs.dnd ? "Do Not Disturb is on — nothing new" : "You're all caught up"; color: Theme.muted
        }

        Flickable {
            id: flick
            visible: Notifs.count > 0
            width: parent.width
            height: Math.min(list.height, 460)
            contentHeight: list.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: flick.width
                spacing: 6
                Repeater {
                    model: pop.groups
                    delegate: Column {
                        required property var modelData
                        width: list.width
                        spacing: 6
                        Txt { anchors.verticalCenter: undefined; text: `${modelData.app.toUpperCase()}  ·  ${modelData.items.length}`
                              color: Theme.muted; font.pixelSize: Theme.smallSize; font.letterSpacing: 1.5; topPadding: 4 }
                        Repeater {
                            model: modelData.items
                            delegate: NotificationCard {
                                required property var modelData
                                notif: modelData
                                compact: true
                                width: list.width
                                onDismissed: Notifs.dismiss(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
