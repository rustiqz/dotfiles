pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Unread-notification count and Do Not Disturb state, from swaync.
// `swaync-client -swb` is swaync's own waybar feed: it stays running and
// prints one JSON line per change ({"text": "<count>", "alt": "dnd-none"
// ...}), so this is push-driven with no polling.
//
// Guarded on swaync actually running, and restarted if it exits: when the
// daemon isn't up, swaync-client blocks forever waiting for it (the hang
// that once parked bootstrap.sh — CLAUDE.md, clean-machine findings).
Singleton {
    id: root

    property int count: 0
    property bool dnd: false

    function toggleCenter() { Quickshell.execDetached(["swaync-client", "-t", "-sw"]) }
    function toggleDnd() { Quickshell.execDetached(["swaync-client", "-d", "-sw"]) }

    Process {
        id: feed
        command: ["sh", "-c", "pidof swaync >/dev/null && exec swaync-client -swb"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const d = JSON.parse(line)
                    root.count = parseInt(d.text) || 0
                    root.dnd = String(d.alt).startsWith("dnd")
                } catch (e) {}
            }
        }
        onExited: retry.start()
    }
    Timer { id: retry; interval: 5000; onTriggered: feed.running = true }
}
