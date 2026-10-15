import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.common
import qs.services
import qs.widgets

// Centre island — the developer's glance surface. Two faces:
//
// At rest:  project · branch ●dirty ↑↓  |  agents  |  containers  |  CI
//   project/branch come from the focused terminal or editor (devstat
//   focus); each indicator only appears when it has something to say, so
//   a quiet machine is a quiet island.
//
// Flash:    for a few seconds after an event — CI turning red/green, an
//   agent needing input or finishing, a long command ending, a volume or
//   brightness change — the island morphs (width animates, faces
//   cross-fade) into a card describing it, then settles back. Clicking a
//   flash acts on it (open the failing run, jump to the agent).
//   This is also the OSD: there's no separate volume/brightness popup.
Island {
    id: root
    hpad: 12

    // --- flash state -------------------------------------------------------------
    property var flash: null     // {icon, color, title, detail, level (0..1 or -1), action}
    readonly property bool flashing: flash !== null

    function show(f, ms) {
        flash = f
        flashTimer.interval = ms || 4500
        flashTimer.restart()
    }
    Timer { id: flashTimer; onTriggered: root.flash = null }

    function focusAgent(project, status) {
        const s = DevStat.sessions.find(x => (!project || x.project === project) && (!status || x.status === status))
                  || DevStat.sessions.find(x => x.status === "needs-input")
                  || DevStat.sessions[0]
        if (!s) return
        if (s.window) Hyprland.dispatch(`focuswindow address:${s.window}`)
        if (s.tmux) Quickshell.execDetached(["tmux", "switch-client", "-t", s.tmux])
    }

    Connections {
        target: DevStat
        function onEvent(ev) {
            const name = s => String(s || "").split("/").pop()
            const took = n => n >= 60 ? `${Math.floor(n / 60)}m ${n % 60}s` : `${n}s`
            switch (ev.kind) {
            case "ci-failed":
                root.show({ icon: Icons.ciFail, color: Theme.err, title: `CI failed · ${name(ev.repo)}`,
                            detail: ev.workflow || "", level: -1,
                            action: () => ev.url && Quickshell.execDetached(["xdg-open", ev.url]) }, 8000)
                break
            case "ci-fixed":
                root.show({ icon: Icons.ciPass, color: Theme.ok, title: `CI green · ${name(ev.repo)}`, detail: "", level: -1 })
                break
            case "agent-needs-input":
                root.show({ icon: Icons.hand, color: Theme.warn, title: `Agent needs input · ${ev.project}`,
                            detail: ev.message || "", level: -1,
                            action: () => root.focusAgent(ev.project, "needs-input") }, 8000)
                break
            case "limit-warning":
                root.show({ icon: Icons.alert, color: ev.level >= 95 ? Theme.err : Theme.warn,
                            title: `Session limit ${ev.level}%`,
                            detail: ev.resets_at ? `resets ${Qt.formatTime(new Date(ev.resets_at * 1000), "HH:mm")}` : "",
                            level: Math.min(1, ev.used / 100),
                            action: () => Quickshell.execDetached(["qs", "ipc", "call", "hub", "openSection", "a"]) }, 8000)
                break
            case "agent-done":
                root.show({ icon: Icons.robot, color: Theme.ok, title: `Agent finished · ${ev.project}`,
                            detail: ev.seconds ? `after ${took(ev.seconds)}` : "", level: -1,
                            action: () => root.focusAgent(ev.project) })
                break
            case "cmd-done":
                root.show({ icon: ev.status === 0 ? Icons.check : Icons.close,
                            color: ev.status === 0 ? Theme.ok : Theme.err,
                            title: (ev.status === 0 ? "Done · " : `Exit ${ev.status} · `) + ev.cmd,
                            detail: [ev.project, took(ev.seconds)].filter(Boolean).join(" · "), level: -1 })
                break
            }
        }
    }

    // --- OSD sources -------------------------------------------------------------
    // Volume: straight from PipeWire, so it shows whatever changed it (keys,
    // pavucontrol, a headset button). The tracker binds the sink so its
    // audio properties are live; `ready` gates out the initial bind, which
    // would otherwise flash an OSD at startup.
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    property bool _audioReady: false
    Timer { interval: 1500; running: true; onTriggered: root._audioReady = true }
    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumeChanged() { root.volumeFlash() }
        function onMutedChanged() { root.volumeFlash() }
    }
    function volumeFlash() {
        if (!_audioReady || !sink || !sink.audio) return
        const v = sink.audio.volume, m = sink.audio.muted
        show({ icon: m ? Icons.volOff : Icons.vol[v < 0.34 ? 0 : v < 0.67 ? 1 : 2],
               color: m ? Theme.muted : Theme.accent, title: m ? "Muted" : `${Math.round(v * 100)}%`,
               detail: "", level: m ? 0 : Math.min(v, 1) }, 1500)
    }

    // Brightness has no change signal to watch (sysfs backlight doesn't
    // emit inotify events), so the keybind pokes this after brightnessctl:
    //   qs ipc call bar brightness     (hypr/keybinds.conf)
    IpcHandler {
        target: "bar"
        function brightness(): void { brightProc.running = true }
        // Generic hook for scripts: qs ipc call bar flash <title> <detail>
        function flash(title: string, detail: string): void {
            root.show({ icon: Icons.term, color: Theme.info, title, detail, level: -1 })
        }
    }
    Process {
        id: brightProc
        command: ["brightnessctl", "-m"]   // name,class,current,percent%,max
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text.split(",")[3])
                if (!isNaN(pct))
                    root.show({ icon: Icons.brightness, color: Theme.warn, title: `${pct}%`, detail: "",
                                level: pct / 100 }, 1500)
            }
        }
    }

    // --- faces ---------------------------------------------------------------------
    // Both faces live in the island's row; only one is visible at a time.
    // The island's width Behavior does the morph.
    Item {
        implicitWidth: root.flashing ? flashFace.implicitWidth : restFace.implicitWidth
        implicitHeight: Theme.barHeight
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: restFace
            anchors.centerIn: parent
            spacing: 10
            opacity: root.flashing ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            readonly property var f: DevStat.focus
            readonly property var git: f && f.git ? f.git : null

            // project · branch ●n ↑a↓b — or the focused window's class
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                Txt {
                    text: restFace.f && restFace.f.project ? Icons.branch : Icons.app
                    color: restFace.f && restFace.f.project ? Theme.accent : Theme.muted
                    font.pixelSize: Theme.iconSize
                }
                Txt {
                    text: restFace.f && restFace.f.project ? restFace.f.project
                          : (restFace.f && restFace.f.window ? restFace.f.window.class : "desktop")
                    font.bold: !!(restFace.f && restFace.f.project)
                    color: restFace.f && restFace.f.project ? Theme.fg : Theme.subtle
                }
                Txt {
                    visible: !!restFace.git && !!restFace.git.branch
                    text: restFace.git ? restFace.git.branch : ""
                    color: Theme.subtle
                    elide: Text.ElideMiddle
                    width: Math.min(implicitWidth, 180)
                }
                Txt {
                    visible: !!restFace.git && restFace.git.dirty > 0
                    text: restFace.git ? `${Icons.dot}${restFace.git.dirty}` : ""
                    color: Theme.warn
                    font.pixelSize: Theme.smallSize + 1
                }
                Txt {
                    visible: !!restFace.git && (restFace.git.ahead > 0 || restFace.git.behind > 0)
                    text: restFace.git ? (restFace.git.ahead ? `${Icons.up}${restFace.git.ahead}` : "")
                                       + (restFace.git.behind ? `${Icons.down}${restFace.git.behind}` : "") : ""
                    color: Theme.info
                    font.pixelSize: Theme.smallSize + 1
                }
            }

            // Agents: spinner while any is working, pulsing hand when one
            // waits on you. Click jumps to the one that needs you most.
            Hover {
                visible: DevStat.sessions.length > 0
                hpad: 5
                onClicked: root.focusAgent()
                Txt {
                    id: agentIcon
                    text: DevStat.agentsWaiting ? Icons.hand : Icons.robot
                    color: DevStat.agentsWaiting ? Theme.warn : DevStat.agentsWorking ? Theme.accent : Theme.muted
                    font.pixelSize: Theme.iconSize
                    SequentialAnimation on opacity {
                        running: DevStat.agentsWaiting > 0
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) agentIcon.opacity = 1
                        NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
                Txt {
                    visible: DevStat.agentsWorking > 0 && !DevStat.agentsWaiting
                    text: Icons.ciRun
                    color: Theme.accent
                    font.pixelSize: Theme.smallSize + 1
                    RotationAnimator on rotation {
                        running: parent.visible; loops: Animation.Infinite
                        from: 0; to: 360; duration: 1400
                    }
                }
                Txt {
                    visible: DevStat.sessions.length > 1
                    text: DevStat.sessions.length
                    color: Theme.subtle
                    font.pixelSize: Theme.smallSize + 1
                }
            }

            // Claude's 5-hour session usage (from the status-line snapshot),
            // coloured like the status line itself: green, yellow from 60%,
            // red from 85%. Click → the hub's Party, which has both windows.
            Hover {
                readonly property real u: DevStat.claudeSession
                visible: u >= 0
                hpad: 5
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "hub", "openSection", "a"])
                Txt { text: "5h"; color: Theme.muted; font.pixelSize: Theme.smallSize }
                Txt {
                    text: `${Math.round(parent.parent.u)}%`
                    color: parent.parent.u >= 85 ? Theme.err : parent.parent.u >= 60 ? Theme.warn : Theme.ok
                    font.pixelSize: Theme.smallSize + 1
                    font.bold: true
                }
            }

            // Containers: count running; warn tint when a compose project is
            // degraded (unhealthy or partially up). Click → lazydocker.
            Hover {
                readonly property bool degraded: DevStat.services.projects
                                                 && DevStat.services.projects.some(p => p.state === "degraded")
                visible: DevStat.containersRunning > 0
                hpad: 5
                onClicked: Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--title", "lazydocker", "-e", "lazydocker"])
                Txt { text: Icons.docker; color: parent.parent.degraded ? Theme.warn : Theme.info; font.pixelSize: Theme.iconSize }
                Txt { text: DevStat.containersRunning; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
            }

            // CI: red with count when a repo's default branch is failing,
            // spinning while runs are in flight, a quiet check otherwise.
            // Click opens the first failing run.
            Hover {
                visible: DevStat.ci && DevStat.ci.available
                hpad: 5
                onClicked: {
                    const r = DevStat.reposFailing[0]
                    const w = r && (r.workflows || []).find(w => ["failure", "timed_out", "startup_failure"].includes(w.conclusion) && !w.managed)
                    Quickshell.execDetached(["xdg-open", w ? w.url : "https://github.com/notifications"])
                }
                Txt {
                    text: DevStat.reposFailing.length ? Icons.ciFail : DevStat.ciRunning ? Icons.ciRun : Icons.ciPass
                    color: DevStat.reposFailing.length ? Theme.err : DevStat.ciRunning ? Theme.info : Theme.ok
                    opacity: DevStat.ci && DevStat.ci.stale ? 0.5 : 1
                    font.pixelSize: Theme.iconSize
                    RotationAnimator on rotation {
                        running: DevStat.ciRunning && !DevStat.reposFailing.length
                        loops: Animation.Infinite; from: 0; to: 360; duration: 1400
                        onRunningChanged: if (!running) parent.rotation = 0
                    }
                }
                Txt {
                    visible: DevStat.reposFailing.length > 0
                    text: DevStat.reposFailing.length
                    color: Theme.err
                    font.pixelSize: Theme.smallSize + 1
                }
            }
        }

        Row {
            id: flashFace
            anchors.centerIn: parent
            spacing: 8
            opacity: root.flashing ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animMed } }

            Txt {
                text: root.flash ? root.flash.icon : ""
                color: root.flash ? root.flash.color : Theme.fg
                font.pixelSize: Theme.iconSize + 2
            }
            Txt {
                text: root.flash ? root.flash.title : ""
                font.bold: true
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 320)
            }
            Txt {
                visible: text !== ""
                text: root.flash ? root.flash.detail : ""
                color: Theme.subtle
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 260)
            }
            // Level bar for OSD flashes (volume/brightness).
            Rectangle {
                visible: root.flash && root.flash.level >= 0
                width: 120; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.alpha(Theme.surfaceHi, 0.9)
                Rectangle {
                    width: parent.width * (root.flash && root.flash.level >= 0 ? root.flash.level : 0)
                    height: parent.height; radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.flash ? root.flash.color : Theme.accent }
                        GradientStop { position: 1; color: Theme.accent2 }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: root.flashing
            cursorShape: root.flash && root.flash.action ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (root.flash && root.flash.action) root.flash.action()
                root.flash = null
            }
        }
    }
}
