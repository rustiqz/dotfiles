import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services
import qs.widgets

// System popover — the bar's CPU/RAM chip, opened. Replaces "click opens
// btop" (kept as middle-click): the numbers worth a glance without a
// terminal. CPU graph, memory/swap/disk bars, temperature, network rate,
// and the heaviest processes with a kill button — on an 8GB machine the
// culprit is usually one process.
//
// CPU/mem/net come from services/Sys.qml (already ticking for the bar);
// processes, disk and temperature are read with one short shell call
// every 3s, only while this card is open.
Popover {
    id: pop
    name: "system"
    cardWidth: 380

    property var procs: []        // [{pid, name, cpu, mem}] top by CPU
    property var memProcs: []     // top by memory
    property real diskUsed: 0
    property real diskTotal: 0
    property real temp: 0         // °C, 0 = unknown
    property bool byMem: false

    function gb(v) { return v.toFixed(1) }
    function rate(b) { return b >= 1048576 ? `${(b / 1048576).toFixed(1)} MB/s` : `${Math.round(b / 1024)} KB/s` }
    function tone(v) { return v > 0.85 ? Theme.err : v > 0.6 ? Theme.warn : Theme.accent }

    // One call, sectioned output: disk, temperature, top-CPU, top-mem.
    // Only this user's processes get a kill button, so `-u $USER`.
    Process {
        id: probe
        command: ["sh", "-c", `
            echo "DISK $(df -B1 --output=used,size / | tail -1)"
            for z in /sys/class/thermal/thermal_zone*; do
              [ "$(cat $z/type 2>/dev/null)" = x86_pkg_temp ] && echo "TEMP $(cat $z/temp)" && break
            done
            ps -u "$USER" -o pid=,pcpu=,pmem=,comm= --sort=-pcpu | grep -vE " (ps|sh|head|grep)$" | head -5 | sed 's/^/CPU /'
            ps -u "$USER" -o pid=,pcpu=,pmem=,comm= --sort=-pmem | grep -vE " (ps|sh|head|grep)$" | head -5 | sed 's/^/MEM /'`]
        stdout: StdioCollector {
            onStreamFinished: {
                const cpu = [], mem = []
                for (const l of text.split("\n")) {
                    const t = l.trim().split(/\s+/)
                    if (t[0] === "DISK") { pop.diskUsed = Number(t[1]); pop.diskTotal = Number(t[2]) }
                    else if (t[0] === "TEMP") pop.temp = Number(t[1]) / 1000
                    else if (t[0] === "CPU" || t[0] === "MEM") {
                        const row = { pid: t[1], cpu: Number(t[2]), mem: Number(t[3]), name: t.slice(4).join(" ") }   // comm last: it can contain spaces
                        if (t[0] === "CPU") cpu.push(row); else mem.push(row)
                    }
                }
                pop.procs = cpu; pop.memProcs = mem
            }
        }
    }
    onOpened: probe.running = true
    Timer { running: pop.open; interval: 3000; repeat: true; onTriggered: if (!probe.running) probe.running = true }

    component Meter: Item {
        property string label
        property real frac: 0
        property string detail
        width: parent ? parent.width : 100; height: 34
        Txt { anchors.verticalCenter: undefined; text: parent.label; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
        Txt { anchors.verticalCenter: undefined; anchors.right: parent.right; text: parent.detail; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
        Rectangle {
            y: 20; width: parent.width; height: 8; radius: 4; color: Theme.alpha(Theme.border, 0.6)
            Rectangle {
                width: parent.width * Math.max(0.01, Math.min(1, parent.parent.frac)); height: parent.height; radius: 4
                color: pop.tone(parent.parent.frac)
                Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 10

        Item {
            width: parent.width; height: 24
            Txt { text: "System"; font.bold: true; font.pixelSize: Theme.textSize + 2 }
            Hover {
                anchors.right: parent.right; hpad: 8
                onClicked: { Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--title", "btop", "-e", "btop"]); Pops.close() }
                Txt { text: "btop"; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
            }
        }

        // --- CPU graph ------------------------------------------------------
        Item {
            width: parent.width; height: 74
            Txt { anchors.verticalCenter: undefined; text: "CPU"; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
            Txt { anchors.verticalCenter: undefined; anchors.right: parent.right
                  text: `${Math.round(Sys.cpu * 100)}%${pop.temp > 0 ? `  ·  ${Math.round(pop.temp)}°C` : ""}`
                  color: pop.tone(Sys.cpu); font.bold: true }
            Row {
                y: 20; width: parent.width; height: 54; spacing: 1
                Repeater {
                    model: 40
                    delegate: Item {
                        required property int index
                        readonly property real v: {
                            const h = Sys.cpuHist, i = h.length - 40 + index
                            return i >= 0 ? h[i] : 0
                        }
                        width: (parent.width - 39) / 40; height: parent.height
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width
                            height: Math.max(2, parent.height * parent.v); radius: 1
                            color: pop.tone(parent.v); opacity: 0.35 + 0.65 * parent.v
                        }
                    }
                }
            }
        }

        Meter { label: "Memory"; frac: Sys.mem; detail: `${pop.gb(Sys.memUsedGb)} / ${pop.gb(Sys.memTotalGb)} GB` }
        Meter { visible: Sys.swapTotalGb > 0; label: "Swap"
                frac: Sys.swapTotalGb > 0 ? Sys.swapUsedGb / Sys.swapTotalGb : 0
                detail: `${pop.gb(Sys.swapUsedGb)} / ${pop.gb(Sys.swapTotalGb)} GB` }
        Meter { label: "Disk /"; frac: pop.diskTotal > 0 ? pop.diskUsed / pop.diskTotal : 0
                detail: `${pop.gb(pop.diskUsed / 1073741824)} / ${pop.gb(pop.diskTotal / 1073741824)} GB` }

        Row {
            width: parent.width
            Txt { text: `${Icons.down} ${pop.rate(Sys.netDown)}`; width: parent.width / 2; color: Theme.info; font.pixelSize: Theme.smallSize + 1 }
            Txt { text: `${Icons.up} ${pop.rate(Sys.netUp)}`; width: parent.width / 2; color: Theme.accent2; font.pixelSize: Theme.smallSize + 1 }
        }

        // --- processes ------------------------------------------------------
        Item {
            width: parent.width; height: 22
            Txt { text: pop.byMem ? "TOP BY MEMORY" : "TOP BY CPU"; color: Theme.muted; font.pixelSize: Theme.smallSize; font.letterSpacing: 1.5 }
            Hover {
                anchors.right: parent.right; hpad: 8
                onClicked: pop.byMem = !pop.byMem
                Txt { text: pop.byMem ? "show CPU" : "show memory"; color: Theme.subtle; font.pixelSize: Theme.smallSize }
            }
        }
        Repeater {
            model: pop.byMem ? pop.memProcs : pop.procs
            delegate: Rectangle {
                required property var modelData
                width: parent.width; height: 30; radius: 10
                color: ma.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.9) : "transparent"
                Txt { x: 10; text: modelData.name; elide: Text.ElideRight; width: 170 }
                Txt { x: 190; text: `${modelData.cpu.toFixed(0)}% cpu`; width: 60; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                Txt { x: 255; text: `${modelData.mem.toFixed(1)}% mem`; width: 70; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
                Txt { anchors.right: parent.right; anchors.rightMargin: 10; text: Icons.close; color: ma.containsMouse ? Theme.err : Theme.muted }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    // SIGTERM, not -9: let the process clean up; one click per process.
                    onClicked: { Quickshell.execDetached(["kill", modelData.pid]); probe.running = true }
                }
            }
        }
        Txt { anchors.verticalCenter: undefined; visible: pop.procs.length === 0; width: parent.width; horizontalAlignment: Text.AlignHCenter; color: Theme.muted; text: "Reading processes…" }
    }
}
