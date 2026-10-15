import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.common
import qs.widgets

// One notification as a card — shared by the toast stack and the
// notification-centre list so a message looks the same in both places.
// `timeoutMs > 0` adds a thin countdown bar and emits expired() when it
// runs out (toasts); 0 means it stays (history, critical).
Rectangle {
    id: root
    property var notif
    property int timeoutMs: 0
    property bool compact: false          // history rows: no entrance animation, no countdown
    signal expired()
    signal dismissed()

    readonly property bool critical: notif && notif.urgency === NotificationUrgency.Critical
    readonly property string iconSrc: {
        if (!notif) return ""
        if (notif.image) return notif.image
        const a = notif.appIcon
        if (!a) return ""
        return a.startsWith("/") ? "file://" + a : Quickshell.iconPath(a, true)
    }
    readonly property var acts: notif ? notif.actions.filter(a => a.identifier !== "default") : []

    implicitHeight: content.implicitHeight + 24
    radius: Theme.radius
    color: Theme.alpha(Theme.surface, 0.97)
    border.width: 1
    border.color: critical ? Theme.err : Theme.alpha(Theme.border, 0.9)
    clip: true

    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: compact ? 0 : Theme.animMed } }

    // Whole-card click = the sender's default action (if any), then dismiss.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const d = root.notif.actions.find(a => a.identifier === "default")
            if (d) d.invoke()
            root.dismissed()
        }
    }

    Row {
        id: content
        x: 12; y: 12
        width: parent.width - 24
        spacing: 10

        Rectangle {
            width: 36; height: 36; radius: 10
            color: Theme.alpha(Theme.surfaceHi, 0.9)
            visible: root.iconSrc !== ""
            Image {
                anchors.centerIn: parent
                width: 26; height: 26
                source: root.iconSrc
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(52, 52)
            }
        }

        Column {
            width: parent.width - (root.iconSrc !== "" ? 46 : 0)
            spacing: 3
            Item {
                width: parent.width; height: 18
                Txt { anchors.verticalCenter: undefined; text: root.notif ? root.notif.appName : ""
                      color: Theme.muted; font.pixelSize: Theme.smallSize; width: parent.width - 24; elide: Text.ElideRight }
                Txt {
                    anchors.verticalCenter: undefined; anchors.right: parent.right
                    text: "×"; font.pixelSize: Theme.textSize + 4; color: closeMa.containsMouse ? Theme.err : Theme.muted
                    MouseArea { id: closeMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: root.dismissed() }
                }
            }
            Txt { anchors.verticalCenter: undefined; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                  text: root.notif ? root.notif.summary : ""; font.bold: true; color: root.critical ? Theme.err : Theme.fg }
            Txt { anchors.verticalCenter: undefined; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: root.compact ? 2 : 4; elide: Text.ElideRight
                  visible: text !== ""; textFormat: Text.StyledText
                  text: root.notif ? root.notif.body : ""; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
            Flow {
                visible: root.acts.length > 0
                width: parent.width; spacing: 6; topPadding: 4
                Repeater {
                    model: root.acts
                    delegate: Rectangle {
                        required property var modelData
                        height: 24; width: lbl.implicitWidth + 20; radius: 8
                        color: bma.containsMouse ? Theme.accent : Theme.surfaceHi
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Txt { id: lbl; anchors.centerIn: parent; anchors.verticalCenter: undefined; text: modelData.text
                              font.pixelSize: Theme.smallSize + 1; color: bma.containsMouse ? Theme.bg : Theme.fg }
                        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { modelData.invoke(); root.dismissed() } }
                    }
                }
            }
        }
    }

    // Countdown: a thin accent line draining along the bottom edge.
    Rectangle {
        visible: root.timeoutMs > 0
        anchors.bottom: parent.bottom
        height: 2; color: Theme.accent; opacity: 0.7
        width: parent.width
        NumberAnimation on width { running: root.timeoutMs > 0; from: root.width; to: 0; duration: root.timeoutMs }
    }
    Timer { running: root.timeoutMs > 0; interval: root.timeoutMs > 0 ? root.timeoutMs : 1; onTriggered: root.expired() }
}
