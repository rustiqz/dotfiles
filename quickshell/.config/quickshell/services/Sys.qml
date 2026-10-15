pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU and memory load from /proc, every 2s. Read directly with FileView
// (blockLoading: /proc files report size 0, so the read has to be
// synchronous on reload) rather than spawning a process per tick.
Singleton {
    id: root

    property real cpu: 0      // 0..1, whole machine, since previous tick
    property real mem: 0      // 0..1, (total - available) / total
    property real memUsedGb: 0
    property real memTotalGb: 0

    property real swapUsedGb: 0
    property real swapTotalGb: 0
    property var cpuHist: []  // last 40 CPU samples (0..1), for the system popover's graph
    property real netDown: 0  // bytes/s across every non-loopback interface
    property real netUp: 0

    property var _last: null
    property var _net: null

    FileView { id: netdev; path: "/proc/net/dev"; blockLoading: true }

    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            stat.reload()
            // First line: "cpu  user nice system idle iowait irq softirq steal ..."
            const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + f[4]
            const total = f.reduce((a, b) => a + b, 0)
            if (root._last) {
                const dt = total - root._last.total
                root.cpu = dt > 0 ? 1 - (idle - root._last.idle) / dt : 0
            }
            root._last = { idle, total }
            root.cpuHist = [...root.cpuHist.slice(-39), root.cpu]

            // /proc/net/dev: "iface: rx_bytes ... (8 rx cols) tx_bytes ...". Rate = delta / 2s tick.
            netdev.reload()
            let rx = 0, tx = 0
            for (const line of netdev.text().split("\n").slice(2)) {
                const [name, rest] = line.split(":")
                if (!rest || name.trim() === "lo") continue
                const c = rest.trim().split(/\s+/).map(Number)
                rx += c[0]; tx += c[8]
            }
            if (root._net) { root.netDown = Math.max(0, (rx - root._net.rx) / 2); root.netUp = Math.max(0, (tx - root._net.tx) / 2) }
            root._net = { rx, tx }

            meminfo.reload()
            const m = {}
            for (const line of meminfo.text().split("\n")) {
                const p = line.split(/:\s+/)
                if (p.length === 2) m[p[0]] = parseInt(p[1])
            }
            if (m.MemTotal) {
                root.mem = 1 - m.MemAvailable / m.MemTotal
                root.memTotalGb = m.MemTotal / 1048576
                root.memUsedGb = (m.MemTotal - m.MemAvailable) / 1048576
                root.swapTotalGb = (m.SwapTotal || 0) / 1048576
                root.swapUsedGb = ((m.SwapTotal || 0) - (m.SwapFree || 0)) / 1048576
            }
        }
    }
}
