import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.widgets

// The dev hub: a right-side drawer ($mod+Space) with everything running,
// building or waiting across projects — keyboard-first, after
// surface-dots' "open it, hit a letter, done" workflow.
//
//   a agents   c CI   s services   p ports   w watchers
//   j/k ↑/↓ move · Enter act · section keys act on the row · Esc closes
//
// All data is devstat's (services/DevStat.qml); actions shell out to the
// same tools you'd type (gh, docker compose via `devstat act`, kitty,
// xdg-open). Opening it triggers an immediate refresh of every section.
//
// Replaces the ags sidebar (Docker + now-playing): both live here now,
// alongside everything else.
Scope {
    id: scope

// Click-outside-to-close (widgets/Scrim.qml — why it's a scrim and not
// HyprlandFocusGrab is documented there).
Scrim {
    screen: hub.screen
    visible: hub.visible
    shown: hub.open
    WlrLayershell.namespace: "quickshell-hub-scrim"
    onDismissed: hub.open = false
}

PanelWindow {
    id: hub

    property bool open: false
    property string section: "a"
    property int cursor: 0

    // On whichever monitor has focus right now.
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
            || Quickshell.screens[0]
    anchors { top: true; right: true; bottom: true }
    margins { top: Theme.gap / 2; right: Theme.gap; bottom: Theme.gap }
    implicitWidth: 460
    // Overlay the windows, never shove them: no exclusive zone of its own,
    // but still placed below the bar's zone (Normal respects others').
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    visible: open || slideOut.running

    WlrLayershell.namespace: "quickshell-hub"
    WlrLayershell.layer: WlrLayer.Overlay   // above the scrim (Top)
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        DevStat.hubOpen = open
        if (open) { cursor = 0; controls.refresh(); keys.forceActiveFocus() }
    }

    IpcHandler {
        target: "hub"
        function toggle(): void { hub.open = !hub.open }
        // Not `show` — `qs ipc call hub show x` collides with the `qs ipc
        // show` subcommand and the argument is rejected — and not `goto`, a
        // reserved word: the reload "succeeded" but kept the old handler.
        function openSection(section: string): void { if (section) hub.section = section; hub.open = true }
        function close(): void { hub.open = false }
    }

    // --- actions ---------------------------------------------------------------------
    function term(title, cmd) {
        Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--title", title, "-e", ...cmd])
        open = false
    }
    function url(u) { Quickshell.execDetached(["xdg-open", u]); open = false }
    function focusAgent(s) {
        if (s.window) Hyprland.dispatch(`focuswindow address:${s.window}`)
        if (s.tmux) Quickshell.execDetached(["tmux", "switch-client", "-t", s.tmux])
        open = false
    }
    function ago(epoch) {
        if (!epoch) return ""
        const n = Math.max(0, Math.floor(Date.now() / 1000 - epoch))
        return n < 60 ? `${n}s` : n < 3600 ? `${Math.floor(n / 60)}m` : `${Math.floor(n / 3600)}h ${Math.floor(n % 3600 / 60)}m`
    }
    // Re-evaluates "x ago" labels while open.
    property int tick: 0
    Timer { interval: 10000; running: hub.open; repeat: true; onTriggered: hub.tick++ }

    // --- sections ----------------------------------------------------------------------
    readonly property var sections: [
        { key: "a", name: "Party", hints: [["↵", "jump to"]] },
        { key: "c", name: "CI", hints: [["↵", "open"], ["l", "failed log"], ["o", "actions"]] },
        { key: "s", name: "Services", hints: [["↵", "logs"], ["u", "up"], ["d", "down"], ["z", "lazydocker"]] },
        { key: "p", name: "Ports", hints: [["↵", "open"]] },
        { key: "w", name: "Watchers", hints: [] },
    ]

    // The agents section is your Party: each agent session is a party
    // member with an HP bar. HP is how fresh the current turn is — it
    // drains over 30 minutes of continuous work, so an agent that's been
    // grinding (or stuck) visibly goes yellow, then red: the nudge to
    // check on it. Idle/finished members rest at full HP. Status reads as
    // the game would say it.
    readonly property int hpDrainSecs: 30 * 60
    readonly property var agentItems: {
        hub.tick
        const color = { "needs-input": Theme.warn, working: Theme.accent, idle: Theme.muted, done: Theme.ok }
        const said = { "needs-input": "awaiting command", working: "in battle", idle: "resting",
                       done: "victorious", running: "in the field" }
        const now = Date.now() / 1000
        const out = DevStat.sessions.map(s => ({
            icon: s.status === "needs-input" ? Icons.hand : s.kind === "claude" ? Icons.robot : Icons.term,
            iconColor: color[s.status] || Theme.info,
            title: s.project || (s.cwd ? s.cwd.split("/").pop() : s.kind),
            subtitle: s.message || [`Lv. ${s.kind}`, s.since ? `${said[s.status] || s.status} ${hub.ago(s.since)}` : `out for ${hub.ago(s.started)}`,
                                    s.tmux ? `tmux ${s.tmux}` : s.workspace ? `workspace ${s.workspace}` : ""]
                                   .filter(Boolean).join(" · "),
            hp: s.status === "working" && s.since ? 1 - (now - s.since) / hub.hpDrainSecs
              : s.status === "needs-input" ? 0.35 : 1,
            chip: said[s.status] || "",
            chipColor: color[s.status] || Theme.muted,
            actions: { Enter: () => hub.focusAgent(s) },
        }))
        // Orchestra delegations: only projects with something in flight.
        const orq = DevStat.agents && DevStat.agents.orchestra
        for (const p of (orq && orq.projects) || []) {
            const act = (p.active || []).length, blk = (p.blocked || []).length
            if (!act && !blk) continue
            out.push({ icon: Icons.orchestra, iconColor: blk ? Theme.warn : Theme.accent,
                       title: `orchestra · ${p.name}`,
                       subtitle: `${act} working · ${blk} blocked · ${p.done_count} done`,
                       chip: blk ? "blocked" : "working", chipColor: blk ? Theme.warn : Theme.accent, actions: {} })
        }
        return out
    }

    readonly property var ciItems: {
        const ci = DevStat.ci
        if (!ci || !ci.available)
            return [{ icon: Icons.alert, iconColor: Theme.warn, title: "CI unavailable",
                      subtitle: ci && ci.error ? ci.error : "gh offline or not authenticated", actions: {} }]
        const stateColor = { failing: Theme.err, running: Theme.info, passing: Theme.ok, none: Theme.muted }
        const bad = ["failure", "timed_out", "startup_failure"]
        const out = []
        for (const r of ci.repos) {
            const name = r.slug.split("/").pop()
            const failing = r.workflows.filter(w => bad.includes(w.conclusion) && !w.managed)
            const actionsUrl = `https://github.com/${r.slug}/actions`
            out.push({
                icon: Icons.github, iconColor: stateColor[r.state] || Theme.muted,
                title: name,
                subtitle: failing.length ? `failing: ${failing.map(w => w.name).join(", ")}`
                        : r.running.length ? `running: ${r.running.map(w => w.name).join(", ")}`
                        : r.workflows.length ? "all workflows passing" : "no workflows",
                chip: r.state === "none" ? "" : r.state, chipColor: stateColor[r.state],
                actions: {
                    Enter: () => hub.url(failing.length ? failing[0].url : actionsUrl),
                    o: () => hub.url(actionsUrl),
                    l: failing.length ? () => hub.term(`ci · ${name}`,
                        ["sh", "-c", `gh run view ${failing[0].id} -R ${r.slug} --log-failed | less -R`]) : null,
                },
            })
            for (const pr of r.prs) {
                const chip = pr.checks_failing ? `${pr.checks_failing} failing` : pr.checks_pending ? "checks…" : "checks ok"
                out.push({
                    indent: 1, icon: Icons.pr,
                    iconColor: pr.checks_failing ? Theme.err : pr.draft ? Theme.muted : Theme.accent2,
                    title: `#${pr.number} ${pr.title}`,
                    subtitle: [pr.draft ? "draft" : "", pr.review ? pr.review.toLowerCase().replace(/_/g, " ") : "", pr.branch]
                              .filter(Boolean).join(" · "),
                    chip, chipColor: pr.checks_failing ? Theme.err : pr.checks_pending ? Theme.info : Theme.ok,
                    actions: { Enter: () => hub.url(pr.url) },
                })
            }
        }
        if (ci.stale) out.unshift({ icon: Icons.alert, iconColor: Theme.warn, title: "Showing cached CI",
                                    subtitle: ci.error || "last refresh failed", actions: {} })
        return out
    }

    readonly property var serviceItems: {
        const sv = DevStat.services
        if (!sv || !sv.available)
            return [{ icon: Icons.docker, iconColor: Theme.muted, title: "Docker unavailable",
                      subtitle: sv && sv.error ? sv.error : "", actions: {} }]
        const c = { up: Theme.ok, degraded: Theme.warn, down: Theme.muted }
        return sv.projects.map(p => {
            const lazydocker = () => hub.term("lazydocker", ["lazydocker"])
            const inDir = p.dir !== null
            return {
                icon: Icons.docker, iconColor: c[p.state],
                title: p.name,
                subtitle: p.containers.map(x => `${x.name} ${x.state === "running" ? (x.health === "unhealthy" ? "✗" : "●") : "○"}`).join("  "),
                chip: `${p.running}/${p.total} ${p.state}`, chipColor: c[p.state],
                actions: {
                    Enter: inDir ? () => hub.term(`logs · ${p.name}`,
                        ["sh", "-c", `cd '${p.dir}' && docker compose logs -f --tail 200`]) : lazydocker,
                    u: inDir ? () => { Quickshell.execDetached([DevStat.bin, "act", "up", p.dir]); hub.open = false } : null,
                    d: inDir ? () => { Quickshell.execDetached([DevStat.bin, "act", "down", p.dir]); hub.open = false } : null,
                    z: lazydocker,
                },
            }
        })
    }

    readonly property var portItems: DevStat.ports.map(p => ({
        icon: Icons.web, iconColor: p.source === "docker" ? Theme.info : Theme.ok,
        title: `:${p.port}  ${p.project || ""}`,
        subtitle: p.source === "docker" ? `container · ${p.cmd}` : `${p.process} · ${p.cmd}`,
        chip: p.source === "docker" ? "docker" : "",
        chipColor: Theme.info,
        actions: { Enter: () => hub.url(p.url) },
    }))

    readonly property var watcherItems: {
        hub.tick
        return DevStat.watchers.map(w => ({
            icon: Icons.watch, iconColor: Theme.accent,
            title: `${w.kind} · ${w.project || "?"}`,
            subtitle: `up ${hub.ago(w.started)} · ${w.cmd}`,
            actions: {},
        }))
    }

    readonly property var items: ({ a: agentItems, c: ciItems, s: serviceItems, p: portItems, w: watcherItems })[section] || []
    readonly property var empty: ({ a: "Your party is empty — no agents running", c: "No repos", s: "No compose projects",
                                    p: "No dev servers listening", w: "No watchers running" })[section]
    onSectionChanged: cursor = 0
    onItemsChanged: if (cursor >= items.length) cursor = Math.max(0, items.length - 1)

    function act(key) {
        const it = items[cursor]
        const fn = it && it.actions ? it.actions[key] : null
        if (fn) fn()
    }

    // --- view -------------------------------------------------------------------------------
    Rectangle {
        id: panel
        width: parent.width
        height: parent.height
        radius: Theme.radius + 4
        color: Theme.alpha(Theme.surface, 0.96)
        border.width: 1
        border.color: Theme.alpha(Theme.border, 0.7)

        // Slide in from the right edge; fade with it. A Translate, not x:
        // animating x off `width` was a binding loop (the window sizes from
        // its content), logged on every open — verify-phase10 caught it.
        transform: Translate {
            x: hub.open ? 0 : hub.implicitWidth + Theme.gap
            Behavior on x { NumberAnimation { id: slideOut; duration: Theme.animMed; easing.type: Easing.OutCubic } }
        }
        opacity: hub.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }

        FocusScope {
            id: keys
            anchors.fill: parent
            anchors.margins: 14
            focus: true

            Keys.onPressed: (e) => {
                const k = e.text
                if (e.key === Qt.Key_Escape) hub.open = false
                else if (e.key === Qt.Key_Down || k === "j") hub.cursor = Math.min(hub.items.length - 1, hub.cursor + 1)
                else if (e.key === Qt.Key_Up || k === "k") hub.cursor = Math.max(0, hub.cursor - 1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) hub.act("Enter")
                else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                    const i = hub.sections.findIndex(s => s.key === hub.section)
                    const d = e.key === Qt.Key_Backtab ? -1 : 1
                    hub.section = hub.sections[(i + d + hub.sections.length) % hub.sections.length].key
                }
                else if (k === "r") DevStat.refreshAll()
                else if (hub.sections.some(s => s.key === k)) hub.section = k
                else if (k) hub.act(k)
                e.accepted = true
            }

            Column {
                id: top
                width: parent.width
                spacing: 12

                // Title row
                Row {
                    spacing: 8
                    Txt { text: Icons.hub; color: Theme.accent; font.pixelSize: Theme.iconSize + 4 }
                    Txt { text: "Dev hub"; font.bold: true; font.pixelSize: Theme.textSize + 3 }
                    Txt {
                        text: DevStat.focus && DevStat.focus.project ? `· ${DevStat.focus.project}` : ""
                        color: Theme.subtle
                    }
                }

                Controls { id: controls; width: parent.width }

                // Section tabs: keycap + name + count
                Row {
                    spacing: 4
                    Repeater {
                        model: hub.sections
                        delegate: Hover {
                            required property var modelData
                            readonly property int count: ({ a: hub.agentItems, c: DevStat.reposFailing, s: DevStat.services.projects || [],
                                                            p: DevStat.ports, w: DevStat.watchers })[modelData.key].length
                            active: hub.section === modelData.key
                            activeColor: Theme.alpha(Theme.accent, 0.15)
                            hpad: 7
                            spacing: 5
                            onClicked: hub.section = modelData.key
                            Keycap { key: modelData.key; lit: hub.section === modelData.key }
                            Txt { text: modelData.name; color: hub.section === modelData.key ? Theme.fg : Theme.subtle
                                  font.pixelSize: Theme.smallSize + 1 }
                            Txt {
                                visible: parent.parent.count > 0
                                text: parent.parent.count
                                color: modelData.key === "c" ? Theme.err : Theme.accent
                                font.pixelSize: Theme.smallSize
                                font.bold: true
                            }
                        }
                    }
                }
            }

            ListView {
                id: list
                anchors.top: top.bottom
                anchors.topMargin: 8
                anchors.bottom: footer.top
                anchors.bottomMargin: 8
                width: parent.width
                clip: true
                spacing: 2
                model: hub.items
                currentIndex: hub.cursor
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: HubRow {
                    required property var modelData
                    required property int index
                    width: list.width
                    item: modelData
                    selected: index === hub.cursor
                    onActivated: { hub.cursor = index; hub.act("Enter") }
                }
                Txt {
                    anchors.centerIn: parent
                    anchors.verticalCenter: undefined
                    visible: hub.items.length === 0
                    text: hub.empty
                    color: Theme.muted
                }
            }

            // Footer: key hints for the current section + the universal ones
            Row {
                id: footer
                anchors.bottom: parent.bottom
                spacing: 6
                Repeater {
                    model: (hub.sections.find(s => s.key === hub.section) || { hints: [] }).hints
                           .concat([["j/k", "move"], ["r", "refresh"], ["esc", "close"]])
                    delegate: Row {
                        required property var modelData
                        spacing: 4
                        Keycap { key: modelData[0] }
                        Txt { text: modelData[1]; color: Theme.muted; font.pixelSize: Theme.smallSize }
                    }
                }
            }
        }
    }
}
}
