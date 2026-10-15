pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which bar popover (widgets/Popover.qml) is open, and where to hang it.
// One name at a time: opening Wi-Fi while Bluetooth is up swaps them
// rather than stacking two cards. A bar icon calls toggle("wifi", x) with
// its own centre in screen coordinates; each Popover compares `current`
// to its own name, so nothing needs to know which popovers exist.
Singleton {
    id: root
    property string current: ""
    property real anchorX: 0

    function toggle(name, x) {
        if (current === name) { current = ""; return }
        anchorX = x
        current = name
    }
    function close() { current = "" }

    // `qs ipc call popover toggle wifi 1700` — for scripts and testing.
    IpcHandler {
        target: "popover"
        function toggle(name: string, x: int): void { root.toggle(name, x) }
        function close(): void { root.close() }
    }
}
