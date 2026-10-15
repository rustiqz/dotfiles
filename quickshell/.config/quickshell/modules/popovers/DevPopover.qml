import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.widgets

// Dev popover — the dev island's click. The island is a glance (project,
// branch, a few counts); this is the "tell me everything" card, built
// from devstat's JSON and nothing else:
//
//   header    project, branch, dirty/ahead/behind, this branch's PR, and a
//             nudge when commits are pushed-ahead with no PR
//   agents    every Claude/Codex session, neediest first, with how long
//             it has been in its state. Click jumps to its window/pane.
//   usage     plan windows (5h + week) with reset countdowns
//   CI        one row per repo, failing first, naming what failed
//   PRs       open PRs with check + review state
//   runtime   compose projects that are up or degraded, listening ports
//
// Sections with nothing to say hide themselves, so a quiet machine gets a
// short card. Keys: Enter jumps to the agent that needs you, c opens the
// failing CI run, p opens this branch's PR, h opens the hub.
Popover {
    id: pop
    name: "dev"
    cardWidth: 880

    // Ticks once a second while open so "working 4m" counts up live.
    property real now: Date.now() / 1000
    onOpened: now = Date.now() / 1000
    Timer { interval: 1000; running: pop.open; repeat: true; onTriggered: pop.now = Date.now() / 1000 }

    // --- derived state ------------------------------------------------------
    readonly property var f: DevStat.focus
    readonly property var git: f && f.git ? f.git : null
    readonly property string project: f && f.project ? f.project : ""
    readonly property var repos: DevStat.ci && DevStat.ci.repos ? DevStat.ci.repos : []
    // devstat keys repos by GitHub slug; the focused project is a directory
    // name. Compare the slug's repo half, case-insensitively.
    readonly property var repo: project ? repos.find(r => r.slug.split("/").pop().toLowerCase() === project.toLowerCase()) : null
    readonly property var branchPr: repo && git && repo.prs ? repo.prs.find(p => p.branch === git.branch) : null

    readonly property var agents: DevStat.sessions.slice().sort((a, b) => rank(a.status) - rank(b.status)).slice(0, 3)
    function rank(s) { return s === "needs-input" ? 0 : s === "working" ? 1 : s === "running" ? 2 : 3 }

    readonly property var ciRows: repos.filter(r => r.state !== "none" || (r.workflows && r.workflows.length))
                                       .slice().sort((a, b) => ciRank(a.state) - ciRank(b.state)).slice(0, 3)
    function ciRank(s) { return s === "failing" ? 0 : s === "running" ? 1 : 2 }

    // Flattened PR list, the focused repo's first so "your" PR leads.
    readonly property var prRows: {
        const out = []
        for (const r of repos)
            for (const p of (r.prs || []))
                out.push({ repo: r.slug.split("/").pop(), pr: p, mine: r === repo })
        out.sort((a, b) => (b.mine - a.mine) || (b.pr.checks_failing > 0) - (a.pr.checks_failing > 0))
        return out.slice(0, 3)
    }

    readonly property var composeRows: (DevStat.services && DevStat.services.projects ? DevStat.services.projects : [])
                                       .filter(p => p.running > 0 || p.state !== "down")
    // Everything "running" in one flat list for the bottom strip: orchestra
    // delegations in flight, dev watchers, compose projects (stopped ones
    // too — the start button is the point). Each entry is a ready-made row.
    readonly property var runRows: {
        pop.now   // re-evaluate so "up 4m" counts
        const out = []
        const orq = DevStat.agents && DevStat.agents.orchestra
        for (const p of (orq && orq.projects) || []) {
            const act = (p.active || []).length, blk = (p.blocked || []).length
            if (!act && !blk) continue
            out.push({ icon: Icons.orchestra, iconColor: blk ? Theme.warn : Theme.accent, title: `orchestra · ${p.name}`,
                       sub: `${act} working · ${blk} blocked · ${p.done_count} done`,
                       badge: blk ? "blocked" : "working", badgeColor: blk ? Theme.warn : Theme.accent })
        }
        for (const w of DevStat.watchers || [])
            out.push({ icon: Icons.watch, iconColor: Theme.accent, title: `${w.kind} · ${w.project || "?"}`,
                       sub: `up ${dur(pop.now - w.started)} · ${w.cmd}`, badge: "watching", badgeColor: Theme.ok })
        const sv = DevStat.services
        const lazydocker = () => term("lazydocker", ["lazydocker"])
        const tone = { up: Theme.ok, degraded: Theme.warn, down: Theme.muted }
        const projs = (sv && sv.available ? sv.projects : []).filter(p => p.dir !== null || p.running > 0)
                      .slice().sort((a, b) => (a.state === "down") - (b.state === "down")).slice(0, 4)
        for (const p of projs) {
            const inDir = p.dir !== null
            const logs = inDir ? () => term(`logs · ${p.name}`, ["sh", "-c", `cd '${p.dir}' && docker compose logs -f --tail 200`]) : lazydocker
            out.push({
                icon: Icons.docker, iconColor: p.state === "up" ? Theme.info : p.state === "degraded" ? Theme.warn : Theme.muted,
                title: p.name,
                sub: p.unhealthy && p.unhealthy.length ? `unhealthy: ${p.unhealthy.join(", ")}` : `${p.running}/${p.total} containers`,
                badge: p.state, badgeColor: tone[p.state] || Theme.muted,
                click: logs,
                actions: inDir ? [ p.state === "down" ? { icon: Icons.start, fn: () => act("up", p.dir) }
                                                      : { icon: Icons.stop, fn: () => act("down", p.dir) },
                                   { icon: Icons.logs, fn: logs } ] : []
            })
        }
        return out
    }
    readonly property var portRows: (DevStat.ports || []).slice(0, 6)
    readonly property bool hasUsage: (DevStat.usage.claude && DevStat.usage.claude.available)
                                     || (DevStat.usage.codex && DevStat.usage.codex.available)

    // --- helpers --------------------------------------------------------------
    function dur(sec) {
        sec = Math.max(0, Math.floor(sec))
        if (sec < 60) return `${sec}s`
        const m = Math.floor(sec / 60)
        if (m < 60) return `${m}m`
        const h = Math.floor(m / 60)
        if (h < 24) return `${h}h ${m % 60}m`
        return `${Math.floor(h / 24)}d ${h % 24}h`
    }
    function open_(url) { Quickshell.execDetached(["xdg-open", url]); Pops.close() }
    function jump(s) {
        if (s.window) Hyprland.dispatch(`focuswindow address:${s.window}`)
        if (s.tmux) Quickshell.execDetached(["tmux", "switch-client", "-t", s.tmux])
        Pops.close()
    }
    function term(title, cmd) {
        Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--title", title, "-e", ...cmd])
        Pops.close()
    }
    function act(verb, dir) { Quickshell.execDetached([DevStat.bin, "act", verb, dir]); Pops.close() }
    function ciLog(r, w) { term(`ci · ${r.slug.split("/").pop()}`, ["sh", "-c", `gh run view ${w.id} -R ${r.slug} --log-failed | less -R`]) }
    function failedRun(r) {
        const bad = (r.workflows || []).filter(w => ["failure", "timed_out", "startup_failure"].includes(w.conclusion))
        return bad.find(w => !w.managed) || bad[0] || null
    }
    function agentColor(st) {
        return st === "needs-input" ? Theme.warn : st === "working" ? Theme.accent : st === "running" ? Theme.info : Theme.muted
    }
    function agentBadge(s) {
        if (s.status === "needs-input") return s.since ? `waiting ${dur(pop.now - s.since)}` : "waiting"
        if (s.status === "working") return s.since ? `working ${dur(pop.now - s.since)}` : "working"
        if (s.status === "idle") return s.since ? `idle ${dur(pop.now - s.since)}` : "idle"
        return "running"
    }
    function prBadge(p) {
        if (p.checks_failing > 0) return { t: `${Icons.ciFail} ${p.checks_failing}`, c: Theme.err }
        if (p.checks_pending > 0) return { t: `${Icons.ciRun} ${p.checks_pending}`, c: Theme.info }
        if (p.draft) return { t: "draft", c: Theme.muted }
        if (p.review === "APPROVED") return { t: "approved", c: Theme.ok }
        if (p.review === "CHANGES_REQUESTED") return { t: "changes", c: Theme.warn }
        return { t: Icons.ciPass, c: Theme.ok }
    }
    function usageTone(u) { return u >= 85 ? Theme.err : u >= 60 ? Theme.warn : Theme.ok }

    onKey: (e) => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (pop.agents.length) pop.jump(pop.agents[0])
        } else if (e.key === Qt.Key_C) {
            const r = pop.ciRows.find(r => r.state === "failing")
            const w = r && pop.failedRun(r)
            if (w) pop.open_(w.url)
        } else if (e.key === Qt.Key_P) {
            const p = pop.branchPr || (pop.prRows.length ? pop.prRows[0].pr : null)
            if (p) pop.open_(p.url)
        } else if (e.key === Qt.Key_L) {
            const r = pop.ciRows.find(r => r.state === "failing")
            const w = r && pop.failedRun(r)
            if (w) pop.ciLog(r, w)
        } else if (e.key === Qt.Key_H) {
            Pops.close()
            Quickshell.execDetached(["qs", "ipc", "call", "hub", "openSection", "a"])
        } else return
        e.accepted = true
    }

    // --- building blocks ----------------------------------------------------------
    component Label: Txt {
        anchors.verticalCenter: undefined
        color: Theme.muted
        font.pixelSize: Theme.smallSize
        font.letterSpacing: 1.5
    }

    // Small rounded tag: "waiting 2m", "approved", "✗ 3".
    component Pill: Rectangle {
        property string text
        property color tone: Theme.subtle
        width: pt.implicitWidth + 14; height: 20; radius: 10
        color: Theme.alpha(tone, 0.18)
        Txt { id: pt; anchors.centerIn: parent; text: parent.text; color: parent.tone
              font.pixelSize: Theme.smallSize; font.bold: true }
    }

    // One clickable two-line row: glyph, title/sub, optional trailing pill.
    component ListRow: Rectangle {
        id: lr
        property string icon
        property color iconColor: Theme.subtle
        property string title
        property string sub
        property string badge
        property color badgeColor: Theme.subtle
        property var actions: []          // [{icon, fn}] small buttons at the right edge
        signal clicked()
        width: parent.width
        height: sub !== "" ? 46 : 34
        radius: 10
        color: ma.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.95) : Theme.alpha(Theme.surfaceHi, 0.45)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Txt { id: ic; x: 10; text: lr.icon; color: lr.iconColor; font.pixelSize: Theme.iconSize + 3 }
        Column {
            anchors.left: ic.right; anchors.leftMargin: 10
            anchors.right: lr.badge !== "" ? tag.left : acts.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Txt { anchors.verticalCenter: undefined; width: parent.width; text: lr.title
                  elide: Text.ElideRight; font.bold: true }
            Txt { anchors.verticalCenter: undefined; width: parent.width; text: lr.sub; visible: lr.sub !== ""
                  elide: Text.ElideRight; color: Theme.muted; font.pixelSize: Theme.smallSize }
        }
        Pill {
            id: tag
            visible: lr.badge !== ""
            anchors.right: acts.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            text: lr.badge; tone: lr.badgeColor
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: lr.clicked() }
        // Declared after the row's MouseArea so the buttons win the click.
        Row {
            id: acts
            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: lr.actions
                delegate: Rectangle {
                    required property var modelData
                    width: 26; height: 26; radius: 8
                    color: am.containsMouse ? Theme.alpha(Theme.accent, 0.28) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Txt { anchors.centerIn: parent; text: modelData.icon; color: am.containsMouse ? Theme.fg : Theme.subtle
                          font.pixelSize: Theme.iconSize + 1 }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.fn() }
                }
            }
        }
    }

    // A plan-usage meter: label + percent, bar, reset countdown.
    component Meter: Column {
        property string label
        property var win          // {used, resets_at, reset}
        readonly property bool fresh: !win || win.reset
        readonly property real used: fresh ? 0 : win.used
        spacing: 4
        Item {
            width: parent.width; height: 14
            Txt { text: parent.parent.label; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
            Txt { anchors.right: parent.right; text: parent.parent.fresh ? "reset" : `${Math.round(parent.parent.used)}%`
                  color: pop.usageTone(parent.parent.used); font.bold: true; font.pixelSize: Theme.smallSize + 1 }
        }
        Rectangle {
            width: parent.width; height: 6; radius: 3; color: Theme.alpha(Theme.border, 0.6)
            Rectangle {
                width: parent.width * Math.max(0.02, Math.min(1, parent.parent.used / 100)); height: parent.height; radius: 3
                color: pop.usageTone(parent.parent.used)
                Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            }
        }
        Txt {
            anchors.verticalCenter: undefined
            visible: !!parent.win && !parent.fresh && parent.win.resets_at > 0
            text: parent.win ? `resets in ${pop.dur(parent.win.resets_at - pop.now)}` : ""
            color: Theme.muted; font.pixelSize: Theme.smallSize
        }
    }

    // --- the card ------------------------------------------------------------------
    Column {
        width: parent.width
        spacing: 12

        // Two columns: what's happening (left) and what's out there (right).
        Row {
            width: parent.width
            spacing: 22
            readonly property real colW: (width - spacing) / 2

            Column {
                width: parent.colW
                spacing: 12

        // ---- header ----------------------------------------------------------------
        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width; height: 26
                Txt {
                    text: pop.project || (pop.f && pop.f.window ? pop.f.window.class : "Desktop")
                    font.pixelSize: Theme.textSize + 6; font.bold: true
                    elide: Text.ElideRight; width: parent.width - (prPill.visible ? prPill.width + 8 : 0)
                }
                Pill {
                    id: prPill
                    visible: !!pop.branchPr
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: pop.branchPr ? `${Icons.pr} #${pop.branchPr.number}  ${pop.prBadge(pop.branchPr).t}` : ""
                    tone: pop.branchPr ? pop.prBadge(pop.branchPr).c : Theme.subtle
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: pop.open_(pop.branchPr.url) }
                }
            }

            Row {
                visible: !!pop.git && !!pop.git.branch
                spacing: 12
                Row {
                    spacing: 5
                    Txt { text: Icons.branch; color: Theme.accent; font.pixelSize: Theme.iconSize }
                    Txt { text: pop.git ? pop.git.branch : ""; color: Theme.subtle
                          elide: Text.ElideMiddle; width: Math.min(implicitWidth, 210) }
                }
                Txt { visible: !!pop.git && pop.git.dirty > 0; text: pop.git ? `${Icons.dot}${pop.git.dirty} changed` : ""
                      color: Theme.warn; font.pixelSize: Theme.smallSize + 1 }
                Txt { visible: !!pop.git && pop.git.ahead > 0; text: pop.git ? `${Icons.up}${pop.git.ahead}` : ""
                      color: Theme.info; font.pixelSize: Theme.smallSize + 1 }
                Txt { visible: !!pop.git && pop.git.behind > 0; text: pop.git ? `${Icons.down}${pop.git.behind}` : ""
                      color: Theme.info; font.pixelSize: Theme.smallSize + 1 }
            }

            // Commits that exist only locally and nothing to review them.
            Txt {
                anchors.verticalCenter: undefined
                visible: !!pop.git && pop.git.ahead > 0 && !!pop.repo && !pop.branchPr
                         && pop.git.branch !== pop.repo["default"]
                text: pop.git ? `${pop.git.ahead} unpushed commit${pop.git.ahead > 1 ? "s" : ""} · no open PR` : ""
                color: Theme.warn; font.pixelSize: Theme.smallSize + 1
            }
        }

        // ---- agents ----------------------------------------------------------------
        Column {
            width: parent.width
            spacing: 6
            visible: pop.agents.length > 0
            Label { text: "AGENTS" }
            Repeater {
                model: pop.agents
                delegate: ListRow {
                    required property var modelData
                    icon: modelData.status === "needs-input" ? Icons.hand
                        : modelData.kind === "codex" ? Icons.term : Icons.robot
                    iconColor: pop.agentColor(modelData.status)
                    title: modelData.project || modelData.cwd.split("/").pop()
                    sub: modelData.status === "needs-input" && modelData.message ? modelData.message
                         : `${modelData.kind}${modelData.workspace ? " · workspace " + modelData.workspace : ""}`
                    badge: pop.agentBadge(modelData)
                    badgeColor: pop.agentColor(modelData.status)
                    onClicked: pop.jump(modelData)
                }
            }
        }

        // ---- usage -----------------------------------------------------------------
        Column {
            width: parent.width
            spacing: 8
            visible: pop.hasUsage
            Label { text: "PLAN USAGE" }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 14
                rowSpacing: 10
                readonly property real cw: (width - columnSpacing) / 2
                Meter { width: parent.cw; label: "Claude · 5h";   win: DevStat.usage.claude.session
                        visible: !!DevStat.usage.claude && DevStat.usage.claude.available }
                Meter { width: parent.cw; label: "Claude · week"; win: DevStat.usage.claude.week
                        visible: !!DevStat.usage.claude && DevStat.usage.claude.available }
                Meter { width: parent.cw; label: "Codex · 5h";    win: DevStat.usage.codex.session
                        visible: !!DevStat.usage.codex && DevStat.usage.codex.available }
                Meter { width: parent.cw; label: "Codex · week";  win: DevStat.usage.codex.week
                        visible: !!DevStat.usage.codex && DevStat.usage.codex.available }
            }
        }

            }

            Column {
                width: parent.colW
                spacing: 12

        // ---- CI --------------------------------------------------------------------
        Column {
            width: parent.width
            spacing: 6
            visible: pop.ciRows.length > 0
            Label { text: "CI" }
            Repeater {
                model: pop.ciRows
                delegate: ListRow {
                    required property var modelData
                    readonly property var bad: pop.failedRun(modelData)
                    readonly property bool failing: modelData.state === "failing"
                    readonly property bool running: modelData.state === "running" || (modelData.running && modelData.running.length > 0)
                    icon: failing ? Icons.ciFail : running ? Icons.ciRun : Icons.ciPass
                    iconColor: failing ? Theme.err : running ? Theme.info : Theme.ok
                    title: modelData.slug.split("/").pop()
                    sub: failing && bad ? `${bad.name} failed · ${bad.title}`
                         : running && modelData.running.length ? `${modelData.running[0].name || "run"} in progress`
                         : "default branch passing"
                    badge: modelData.prs && modelData.prs.length ? `${modelData.prs.length} PR` : ""
                    actions: failing && bad ? [{ icon: Icons.logs, fn: () => pop.ciLog(modelData, bad) }] : []
                    onClicked: pop.open_(bad ? bad.url : `https://github.com/${modelData.slug}/actions`)
                }
            }
        }

        // ---- pull requests -----------------------------------------------------------
        Column {
            width: parent.width
            spacing: 6
            visible: pop.prRows.length > 0
            Label { text: "PULL REQUESTS" }
            Repeater {
                model: pop.prRows
                delegate: ListRow {
                    required property var modelData
                    readonly property var b: pop.prBadge(modelData.pr)
                    icon: Icons.pr
                    iconColor: modelData.pr.draft ? Theme.muted : modelData.pr.checks_failing > 0 ? Theme.err : Theme.accent2
                    title: `#${modelData.pr.number}  ${modelData.pr.title}`
                    sub: `${modelData.repo} · ${modelData.pr.branch}`
                    badge: b.t
                    badgeColor: b.c
                    onClicked: pop.open_(modelData.pr.url)
                }
            }
        }

            }
        }

        // ---- running: orchestra, watchers, services, ports ----------------------------
        Column {
            width: parent.width
            spacing: 6
            visible: pop.runRows.length > 0 || pop.portRows.length > 0
            Label { text: "RUNNING" }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 22
                rowSpacing: 6
                readonly property real cw: (width - columnSpacing) / 2
                Repeater {
                    model: pop.runRows
                    delegate: ListRow {
                        required property var modelData
                        width: parent.cw
                        icon: modelData.icon
                        iconColor: modelData.iconColor
                        title: modelData.title
                        sub: modelData.sub
                        badge: modelData.badge
                        badgeColor: modelData.badgeColor
                        actions: modelData.actions || []
                        onClicked: if (modelData.click) modelData.click()
                    }
                }
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: pop.portRows
                    delegate: Rectangle {
                        required property var modelData
                        width: chip.implicitWidth + 18; height: 26; radius: 13
                        color: pma.containsMouse ? Theme.alpha(Theme.accent, 0.25) : Theme.alpha(Theme.surfaceHi, 0.7)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Txt {
                            id: chip
                            anchors.centerIn: parent
                            text: `${Icons.web} :${modelData.port}  ${modelData.process}`
                            color: Theme.subtle; font.pixelSize: Theme.smallSize + 1
                        }
                        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: pop.open_(modelData.url) }
                    }
                }
            }
        }

        // ---- footer --------------------------------------------------------------------
        Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.border, 0.6) }
        Item {
            width: parent.width; height: 18
            Txt { text: "↵ jump   c CI   l failed log   p PR   h hub"; color: Theme.muted; font.pixelSize: Theme.smallSize }
            Txt {
                anchors.right: parent.right
                text: DevStat.ci && DevStat.ci.stale ? "CI data stale" : ""
                color: Theme.warn; font.pixelSize: Theme.smallSize
            }
        }
    }
}
