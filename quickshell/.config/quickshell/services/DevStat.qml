pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The bar's view of bin/bin/devstat. All the actual gathering — git state,
// docker, agent sessions, CI — happens in that script; this only polls it
// and exposes the JSON as properties, so the bar never shells out to git
// or docker itself and everything it shows is reproducible from a
// terminal with `devstat <section> --pretty`.
//
// Cadence is per section, by how fast it changes and what it costs:
//   focus           on every Hyprland focus change, plus a 3s backstop
//                   (git branch/dirty can change without a focus change)
//   agents/services every 4s
//   ci              every 30s — reads devstat's cache; devstat-ci.timer
//                   does the actual GitHub fetches every 3 min
// Events (CI red, agent done, long command finished) are pushed, not
// polled: a `tail -F` on events.jsonl turns each new line into a signal.
Singleton {
    id: root

    readonly property string bin: Quickshell.env("HOME") + "/bin/devstat"
    readonly property string eventsFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                         + "/devstat/events.jsonl"

    property var focus: null
    property var agents: ({ sessions: [], orchestra: null })
    property var services: ({ available: false, running: 0, projects: [] })
    // Agent plan limits (devstat usage): claude from the status-line
    // snapshot, codex from its session logs. -1 = unknown.
    property var usage: ({ claude: { available: false }, codex: { available: false } })
    readonly property real claudeSession: usage && usage.claude && usage.claude.available && usage.claude.session
                                          ? usage.claude.session.used : -1
    property var ci: ({ available: false, repos: [] })
    property var ports: []
    property var watchers: []

    // The dev hub sets this while open. ports/watchers are only shown
    // there, so they're only polled then — no point scanning /proc and
    // ss every few seconds for a panel nobody is looking at.
    property bool hubOpen: false
    // The dev popover (modules/popovers/DevPopover.qml) shows them too.
    readonly property bool wantHub: hubOpen || Pops.current === "dev"
    onWantHubChanged: if (wantHub) refreshAll()

    function refreshAll() {
        refreshFocus()
        if (!liveProc.running) liveProc.running = true
        if (!ciProc.running) ciProc.running = true
        if (!hubProc.running) hubProc.running = true
    }

    // --- derived ---------------------------------------------------------------
    readonly property var sessions: agents && agents.sessions ? agents.sessions : []
    readonly property int agentsWorking: sessions.filter(s => s.status === "working").length
    readonly property int agentsWaiting: sessions.filter(s => s.status === "needs-input").length
    readonly property int containersRunning: services && services.available ? services.running : 0
    readonly property var reposFailing: (ci && ci.repos ? ci.repos : []).filter(r => r.state === "failing")
    readonly property bool ciRunning: (ci && ci.repos ? ci.repos : []).some(r => r.state === "running"
                                                                              || (r.running && r.running.length))

    signal event(var ev)

    function refreshFocus() { if (!focusProc.running) focusProc.running = true }

    // --- pollers ---------------------------------------------------------------------
    component Poll: Process {
        id: p
        property var target: function (data) {}
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return
                try { p.target(JSON.parse(text)) }
                catch (e) { console.warn("DevStat:", p.command.join(" "), "→ bad JSON:", e) }
            }
        }
    }

    Poll {
        id: focusProc
        command: [root.bin, "focus"]
        target: d => root.focus = d
    }
    Poll {
        id: liveProc
        command: [root.bin, "agents", "services", "usage"]
        target: d => { root.agents = d.agents; root.services = d.services; root.usage = d.usage }
    }
    Poll {
        id: ciProc
        command: [root.bin, "ci"]
        target: d => root.ci = d
    }

    Poll {
        id: hubProc
        command: [root.bin, "ports", "watchers"]
        target: d => { root.ports = d.ports; root.watchers = d.watchers }
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refreshFocus()
    }
    Timer {
        interval: 3000; running: root.wantHub; repeat: true
        onTriggered: if (!hubProc.running) hubProc.running = true
    }
    Timer {
        interval: 4000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (!liveProc.running) liveProc.running = true
    }
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (!ciProc.running) ciProc.running = true
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root.refreshFocus() }
        function onFocusedWorkspaceChanged() { root.refreshFocus() }
    }

    // --- events ------------------------------------------------------------------------
    // -n0: only lines written from now on (history isn't news). -F: keep
    // following across the file being trimmed/recreated by devstat.
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$(dirname "$1")" && touch "$1" && exec tail -n0 -F "$1"',
                  "sh", root.eventsFile]
        stdout: SplitParser {
            onRead: (line) => {
                let ev
                try { ev = JSON.parse(line) } catch (e) { return }
                root.event(ev)
                // Event-relevant state changed; don't wait for the next poll.
                if (ev.kind.startsWith("ci-")) ciProc.running = true
                else if (!liveProc.running) liveProc.running = true
            }
        }
    }
}
