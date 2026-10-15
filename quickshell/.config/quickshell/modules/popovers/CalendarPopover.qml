import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services
import qs.widgets

// Calendar popover — the bar clock's click. A month grid (Monday first,
// ISO week numbers), today ringed in the accent, plus the full date and
// uptime. No events: nothing here talks to an account.
//
//   ←/→ or h/l   previous / next month · ↑/↓ or k/j  year · t today
Popover {
    id: pop
    name: "calendar"
    cardWidth: 320

    property var today: new Date()
    property int vy: today.getFullYear()
    property int vm: today.getMonth()      // 0..11
    property string uptime: ""

    onOpened: { today = new Date(); vy = today.getFullYear(); vm = today.getMonth(); uptimeFile.reload() }
    FileView {
        id: uptimeFile; path: "/proc/uptime"; blockLoading: true
        onLoaded: {
            const s = Math.floor(parseFloat(text().split(" ")[0]))
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
            pop.uptime = d > 0 ? `${d}d ${h}h ${m}m` : h > 0 ? `${h}h ${m}m` : `${m}m`
        }
    }

    function shift(n) {
        const t = vm + n
        vy += Math.floor(t / 12); vm = ((t % 12) + 12) % 12
    }
    function isoWeek(d) {   // ISO 8601: week containing the Thursday
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7)
    }
    // 6 rows × 7 columns starting on the Monday on/before the 1st.
    readonly property var cells: {
        const first = new Date(vy, vm, 1)
        const start = new Date(vy, vm, 1 - ((first.getDay() + 6) % 7))
        return Array.from({ length: 42 }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
    }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }

    onKey: (e) => {
        if (e.key === Qt.Key_Left || e.text === "h") shift(-1)
        else if (e.key === Qt.Key_Right || e.text === "l") shift(1)
        else if (e.key === Qt.Key_Up || e.text === "k") vy--
        else if (e.key === Qt.Key_Down || e.text === "j") vy++
        else if (e.text === "t") { vy = today.getFullYear(); vm = today.getMonth() }
        else return
        e.accepted = true
    }

    Column {
        width: parent.width
        spacing: 10

        // --- today ----------------------------------------------------------
        Txt { anchors.verticalCenter: undefined; text: Qt.formatDateTime(pop.today, "dddd")
              font.pixelSize: Theme.textSize + 6; font.bold: true }
        Txt { anchors.verticalCenter: undefined; text: `${Qt.formatDateTime(pop.today, "d MMMM yyyy")}  ·  up ${pop.uptime}`
              color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }

        // --- month header ---------------------------------------------------
        Item {
            width: parent.width; height: 28
            Hover { hpad: 8; onClicked: pop.shift(-1); Txt { text: "‹"; font.pixelSize: Theme.textSize + 4 } }
            Hover {
                anchors.horizontalCenter: parent.horizontalCenter; hpad: 10
                onClicked: { pop.vy = pop.today.getFullYear(); pop.vm = pop.today.getMonth() }
                Txt { text: Qt.formatDate(new Date(pop.vy, pop.vm, 1), "MMMM yyyy"); font.bold: true }
            }
            Hover { anchors.right: parent.right; hpad: 8; onClicked: pop.shift(1); Txt { text: "›"; font.pixelSize: Theme.textSize + 4 } }
        }

        // --- grid -----------------------------------------------------------
        Grid {
            width: parent.width
            columns: 8
            readonly property real cw: width / 8
            Repeater {   // weekday header: blank over the week-number column, then Mon..Sun
                model: ["", "M", "T", "W", "T", "F", "S", "S"]
                delegate: Txt { anchors.verticalCenter: undefined; required property string modelData
                                text: modelData; width: parent.cw; height: 22; horizontalAlignment: Text.AlignHCenter
                                color: Theme.muted; font.pixelSize: Theme.smallSize }
            }
            Repeater {
                model: 48   // 6 × (week number + 7 days)
                delegate: Item {
                    required property int index
                    readonly property int row: Math.floor(index / 8)
                    readonly property int col: index % 8
                    readonly property var date: col > 0 ? pop.cells[row * 7 + col - 1] : pop.cells[row * 7]
                    readonly property bool isToday: col > 0 && pop.sameDay(date, pop.today)
                    readonly property bool inMonth: col > 0 && date.getMonth() === pop.vm
                    width: parent.cw; height: 32
                    Rectangle {
                        anchors.centerIn: parent; width: 28; height: 28; radius: 14
                        visible: parent.isToday
                        color: Theme.accent
                    }
                    Txt {
                        anchors.centerIn: parent; anchors.verticalCenter: undefined
                        text: parent.col === 0 ? pop.isoWeek(parent.date) : parent.date.getDate()
                        font.pixelSize: parent.col === 0 ? Theme.smallSize : Theme.textSize
                        font.bold: parent.isToday
                        color: parent.col === 0 ? Theme.muted
                             : parent.isToday ? Theme.bg
                             : !parent.inMonth ? Theme.muted
                             : parent.col >= 6 ? Theme.accent2 : Theme.fg
                        opacity: parent.col > 0 && !parent.inMonth ? 0.5 : 1
                    }
                }
            }
        }

        Txt { anchors.verticalCenter: undefined; width: parent.width; horizontalAlignment: Text.AlignHCenter
              text: "←/→ month · ↑/↓ year · t today"; color: Theme.muted; font.pixelSize: Theme.smallSize }
    }
}
