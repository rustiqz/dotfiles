import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// The launcher ($mod+D), styled as a Pokédex: a red device with the big
// blue lens and status LEDs, a "screen" on the left showing the selected
// entry as a dex page, and the numbered list on the right.
//
// Modes by first character of the query — the launcher is the one place
// to start anything, developer things first:
//   (none)  apps         ranked by match, then by how often you launch them
//   /       projects     opens the project's tmux session (bin/bin/work)
//   >       run          shell command; Shift+Enter runs it in a terminal
//   @       windows      jump to any open window
//   =       calculator   qalc; Enter copies the result
//   :       emoji        Enter copies
//   ?       help
//
// ↑/↓ or Ctrl+J/K move, Enter launches, Tab cycles modes, Esc or a click
// outside closes. Replaces rofi's drun; rofi stays for the small pickers
// (clipboard, SSH hosts, theme).
//
// "Caught": every launch is counted in Quickshell.statePath("launcher.json"),
// which feeds ranking (frecency) and the Pokéball on entries you've used.
Scope {
    id: scope

    Scrim {
        screen: dex.screen
        visible: dex.visible
        shown: dex.open
        WlrLayershell.namespace: "quickshell-launcher-scrim"
        onDismissed: dex.open = false
    }

    PanelWindow {
        id: dex

        property bool open: false
        property int cursor: 0
        property var lastPointer: null      // see the row MouseArea

        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]
        // No anchors → the compositor centres the surface.
        implicitWidth: 940
        implicitHeight: 580
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: open || closing.running

        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: {
            if (!open) return
            cursor = 0
            lastPointer = null
            projectsProc.running = true
            search.forceActiveFocus()
        }

        IpcHandler {
            target: "launcher"
            function toggle(): void {
                if (!dex.open) search.text = ""
                dex.open = !dex.open
            }
            // e.g. `qs ipc call launcher openWith /` straight into projects.
            function openWith(prefix: string): void { search.text = prefix; dex.open = true }
        }

        // --- launch stats ("caught") -----------------------------------------------
        property var stats: ({})
        FileView {
            id: statsFile
            path: Quickshell.statePath("launcher.json")
            printErrors: false     // absent on first run — that's fine
            onLoaded: { try { dex.stats = JSON.parse(text()) } catch (e) { dex.stats = {} } }
        }
        function record(key) {
            const s = Object.assign({}, stats)
            const prev = s[key] || { n: 0, last: 0 }
            s[key] = { n: prev.n + 1, last: Math.floor(Date.now() / 1000) }
            stats = s
            statsFile.setText(JSON.stringify(s))
        }
        // Frecency: launch count, halved for every two weeks unused.
        function frecency(key) {
            const s = stats[key]
            if (!s) return 0
            const weeks = (Date.now() / 1000 - s.last) / (14 * 86400)
            return s.n * Math.pow(0.5, Math.max(0, weeks))
        }
        function ago(epoch) {
            if (!epoch) return ""
            const d = Math.floor((Date.now() / 1000 - epoch) / 86400)
            return d === 0 ? "today" : d === 1 ? "yesterday" : `${d} days ago`
        }

        // --- query / mode ------------------------------------------------------------
        readonly property string query: search.text
        readonly property var modes: [
            { p: "", name: "Apps", glyph: Icons.app },
            { p: "/", name: "Projects", glyph: Icons.folder },
            { p: ">", name: "Run", glyph: Icons.term },
            { p: "@", name: "Windows", glyph: Icons.windows },
            { p: "=", name: "Calc", glyph: Icons.calc },
            { p: ":", name: "Emoji", glyph: Icons.emoji },
            { p: "+", name: "Agents", glyph: Icons.robot },
            { p: "?", name: "Help", glyph: Icons.help },
        ]
        readonly property var mode: modes.find(m => m.p && query.startsWith(m.p)) || modes[0]
        readonly property string term: (mode.p ? query.slice(1) : query).trim().toLowerCase()
        onQueryChanged: cursor = 0

        function launch(row, alt) {
            if (!row || !row.run) return
            row.run(alt)
            if (row.key) record(row.key)
            open = false
        }

        // Match score: 0 = no match. Name prefix > word prefix > substring >
        // match only in the secondary text (generic name, keywords, comment).
        function score(name, extra, t) {
            if (!t) return 1
            const n = name.toLowerCase()
            if (n.startsWith(t)) return 100
            if (n.split(/[\s\-_.]+/).some(w => w.startsWith(t))) return 70
            if (n.includes(t)) return 50
            if (extra.toLowerCase().includes(t)) return 20
            return 0
        }

        // --- apps ------------------------------------------------------------------------
        readonly property var apps: {
            const list = DesktopEntries.applications.values.filter(e => !e.noDisplay)
            list.sort((a, b) => a.name.localeCompare(b.name))
            // Dex number = alphabetical position: stable between launches,
            // so an app keeps "its" number.
            return list.map((e, i) => ({ e, no: i + 1 }))
        }
        readonly property var appRows: {
            const t = term
            const rows = []
            for (const { e, no } of apps) {
                const kw = [e.genericName, e.comment,
                            Array.isArray(e.keywords) ? e.keywords.join(" ") : e.keywords].join(" ")
                const s = score(e.name, kw, t)
                if (!s) continue
                const st = stats["app:" + e.id]
                rows.push({
                    key: "app:" + e.id, no, title: e.name,
                    icon: Quickshell.iconPath(e.icon, "application-x-executable"),
                    subtitle: e.genericName || e.comment || "",
                    desc: e.comment || e.genericName || "",
                    types: Dex.typesFor(e.categories),
                    caught: !!st, count: st ? st.n : 0, last: st ? st.last : 0,
                    rank: s * 10 + frecency("app:" + e.id),
                    // Launched through uwsm by desktop-entry id — its own
                    // scoped unit, same as every keybind-launched app.
                    run: () => Quickshell.execDetached(["uwsm", "app", "--", `${e.id}.desktop`]),
                })
            }
            rows.sort((a, b) => b.rank - a.rank || a.title.localeCompare(b.title))
            return rows
        }

        // --- projects ------------------------------------------------------------------
        property var projects: []
        Process {
            id: projectsProc
            command: [DevStat.bin, "projects"]
            stdout: StdioCollector {
                onStreamFinished: { try { dex.projects = JSON.parse(text) } catch (e) {} }
            }
        }
        readonly property var projectRows: {
            const t = term
            return projects.map((p, i) => ({ p, no: i + 1 }))
                .filter(({ p }) => score(p.name, p.path, t))
                .map(({ p, no }) => {
                    const st = stats["proj:" + p.name]
                    const badges = []
                    if (p.git) badges.push({ name: "git", color: Dex.types.steel.color })
                    if (p.justfile) badges.push({ name: "just", color: Dex.types.electric.color })
                    if (p.layout) badges.push({ name: "layout", color: Dex.types.grass.color })
                    return {
                        key: "proj:" + p.name, no, title: p.name, glyph: Icons.folder,
                        subtitle: p.path.replace(Quickshell.env("HOME"), "~"),
                        desc: `Opens the ${p.name} tmux session (work).`,
                        types: badges, caught: !!st, count: st ? st.n : 0, last: st ? st.last : 0,
                        rank: score(p.name, "", t) * 10 + frecency("proj:" + p.name),
                        run: () => Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--title", p.name,
                                                            "-e", Quickshell.env("HOME") + "/bin/work", p.path]),
                    }
                })
                .sort((a, b) => b.rank - a.rank)
        }

        // --- run ---------------------------------------------------------------------------
        readonly property var runRows: {
            const cmd = query.slice(1).trim()
            if (!cmd) return [{ glyph: Icons.term, title: "Type a command", subtitle: "Enter runs it detached · Shift+Enter in a terminal",
                                desc: "Runs through sh -c, scoped by uwsm.", types: [] }]
            return [{
                glyph: Icons.term, title: cmd, no: 0,
                subtitle: "Enter: run detached  ·  Shift+Enter: run in a terminal",
                desc: "Detached runs are scoped by uwsm; terminal runs keep the window open after exit.",
                types: [Dex.types.fighting],
                run: (alt) => Quickshell.execDetached(alt
                    ? ["uwsm", "app", "--", "kitty", "--hold", "-e", "sh", "-c", cmd]
                    : ["uwsm", "app", "--", "sh", "-c", cmd]),
            }]
        }

        // --- windows -----------------------------------------------------------------------
        readonly property var windowRows: {
            const t = term
            return Hyprland.toplevels.values
                .filter(w => w.lastIpcObject && score(w.title, String(w.lastIpcObject.class || ""), t))
                .map((w, i) => {
                    const cls = String(w.lastIpcObject.class || "")
                    const entry = DesktopEntries.heuristicLookup(cls)
                    return {
                        no: i + 1, title: w.title || cls,
                        icon: Quickshell.iconPath(entry && entry.icon ? entry.icon : cls.toLowerCase(), "application-x-executable"),
                        subtitle: `${entry ? entry.name : cls} · workspace ${w.workspace ? w.workspace.name : "?"}`,
                        desc: cls, types: entry ? Dex.typesFor(entry.categories) : [],
                        run: () => Hyprland.dispatch(`focuswindow address:0x${String(w.address).replace(/^0x/, "")}`),
                    }
                })
        }

        // --- calculator ----------------------------------------------------------------------
        property string calcResult: ""
        property bool qalcMissing: false
        Timer {
            id: calcDebounce
            interval: 120
            onTriggered: {
                const expr = dex.query.slice(1).trim()
                // Missing qalc: the install hint is already showing — don't
                // spawn a doomed process per keystroke (each one logged a
                // "Process failed to start" warning).
                if (!expr || dex.qalcMissing) { dex.calcResult = ""; return }
                calcProc.command = ["qalc", "-t", expr]
                calcProc.running = true
            }
        }
        Connections {
            target: dex
            function onQueryChanged() { if (dex.mode.p === "=") calcDebounce.restart() }
        }
        Process {
            id: calcProc
            stdout: StdioCollector { onStreamFinished: dex.calcResult = text.trim() }
        }
        // Checked by asking the shell, not by calcProc's exit code: a
        // missing binary never starts, so there's no exit to read — the
        // first version showed a bare "…" forever instead of the hint.
        Process {
            id: qalcCheck
            running: true
            command: ["sh", "-c", "command -v qalc >/dev/null"]
            onExited: (code) => dex.qalcMissing = code !== 0
        }
        Connections {
            target: dex
            function onOpenChanged() { if (dex.open) qalcCheck.running = true }
        }
        readonly property var calcRows: {
            if (qalcMissing) return [{ glyph: Icons.alert, title: "qalc not installed",
                                       subtitle: "sudo pacman -S libqalculate", desc: "", types: [] }]
            const expr = query.slice(1).trim()
            if (!expr) return [{ glyph: Icons.calc, title: "Type an expression", subtitle: "2^10 · 15% of 340 · 5 GiB to MB · now + 3 days",
                                 desc: "Powered by qalc: units, currencies, dates.", types: [] }]
            const r = calcResult
            return [{ glyph: Icons.calc, title: r || "…", subtitle: expr, no: 0,
                      desc: "Enter copies the result.", types: [Dex.types.water],
                      run: () => r && Quickshell.execDetached(["wl-copy", r]) }]
        }

        // --- emoji ------------------------------------------------------------------------------
        // rofimoji's own data (already installed for the $mod+. picker),
        // found by glob — its path embeds the Python version.
        property var emojis: []
        Process {
            id: emojiProc
            command: ["sh", "-c", "cat /usr/lib/python3*/site-packages/picker/data/emojis_*.csv 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = []
                    for (const line of text.split("\n")) {
                        const m = line.match(/^(\S+)\s+(.*?)(?:\s+<small>\((.*)\)<\/small>)?$/)
                        if (m) out.push({ ch: m[1], name: m[2], kw: m[3] || "" })
                    }
                    dex.emojis = out
                }
            }
        }
        readonly property var emojiRows: {
            if (mode.p !== ":") return []
            if (emojis.length === 0) { if (!emojiProc.running) emojiProc.running = true; return [] }
            const t = term
            return emojis.map(e => ({ e, s: score(e.name, e.kw, t) }))
                .filter(x => x.s).sort((a, b) => b.s - a.s).slice(0, 80)
                .map(x => x.e).map((e, i) => ({
                no: i + 1, emoji: e.ch, title: e.name, subtitle: e.kw, desc: "Enter copies it.",
                types: [Dex.types.fairy], run: () => Quickshell.execDetached(["wl-copy", e.ch]),
            }))
        }

        // --- agents (+) --------------------------------------------------------------
        // Start a new agent session in a project: Enter = Claude, Shift+Enter =
        // Codex, via bin/bin/agent-start (own kitty window, interactive shell so
        // mise's codex resolves). The focused project sorts first; each row says
        // how many agents are already working there.
        readonly property var agentRows: {
            const t = term
            const focusProj = DevStat.focus && DevStat.focus.project
            const busy = name => DevStat.sessions.filter(x => x.project === name).length
            return projects.map((p, i) => ({ p, no: i + 1 }))
                .filter(({ p }) => score(p.name, p.path, t))
                .map(({ p, no }) => {
                    const n = busy(p.name)
                    return {
                        key: "agent:" + p.name, no, title: p.name, glyph: Icons.robot,
                        subtitle: `Enter: Claude  ·  Shift+Enter: Codex${n ? `  ·  ${n} already here` : ""}`,
                        desc: `New agent session in ${p.path.replace(Quickshell.env("HOME"), "~")}, in its own terminal.`,
                        types: [Dex.types.psychic], caught: false,
                        rank: (p.name === focusProj ? 1000 : 0) + score(p.name, "", t) * 10 + frecency("agent:" + p.name),
                        run: (alt) => Quickshell.execDetached([Quickshell.env("HOME") + "/bin/agent-start",
                                                               alt ? "codex" : "claude", p.path]),
                    }
                })
                .sort((a, b) => b.rank - a.rank)
        }

        readonly property var helpRows: modes.filter(m => m.p).map(m => ({
            glyph: m.glyph, title: `${m.p}  ${m.name}`, types: [],
            subtitle: ({ "/": "open a project's tmux session", ">": "run a shell command",
                         "@": "jump to an open window", "=": "calculator (qalc)",
                         ":": "copy an emoji", "+": "start an agent in a project", "?": "this list" })[m.p],
            run: () => { search.text = m.p; dex.open = true },
        }))

        readonly property var rows: ({
            "": appRows, "/": projectRows, ">": runRows, "@": windowRows,
            "=": calcRows, ":": emojiRows, "+": agentRows, "?": helpRows,
        })[mode.p] || []
        readonly property var selected: rows[Math.min(cursor, rows.length - 1)] || null

        // --- device ---------------------------------------------------------------------------
        // The body is the theme's own surface, like every other panel in
        // the shell; the Pokédex identity lives in the details instead —
        // lens, the three LEDs, a red seam under the header, the red dots
        // over the screen, Pokéballs. The first version painted the whole
        // device in Theme.err, which under TokyoNight is #f7768e: a pink
        // slab that fought the rest of the theme (user feedback).
        readonly property color shell: Theme.surface
        readonly property color shellDark: Theme.bg
        readonly property color trim: Theme.border        // bezels, outlines
        readonly property color red: Theme.err            // identity accents only

        Rectangle {
            id: body
            anchors.fill: parent
            radius: 26
            gradient: Gradient {
                GradientStop { position: 0; color: dex.shell }
                GradientStop { position: 1; color: dex.shellDark }
            }
            border.width: 1
            border.color: Theme.alpha(dex.trim, 0.9)

            // Open/close: a quick scale-up from 94%, like the device popping open.
            scale: dex.open ? 1 : 0.94
            opacity: dex.open ? 1 : 0
            Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { id: closing; duration: Theme.animFast } }

            // --- top strip: lens + LEDs + title -------------------------------------
            Row {
                id: topStrip
                x: 22; y: 16
                spacing: 12
                Rectangle {   // the big lens
                    width: 58; height: 58; radius: 29
                    color: Theme.surfaceHi
                    border.width: 2; border.color: Theme.alpha(Theme.fg, 0.55)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 44; height: 44; radius: 22
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(Theme.info, 1.3) }
                            GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.4) }
                        }
                        // Glows brighter while you type — the dex "listening".
                        SequentialAnimation on opacity {
                            running: dex.open; loops: Animation.Infinite
                            NumberAnimation { to: 0.75; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                        }
                        Rectangle {   // gloss
                            x: 9; y: 7; width: 13; height: 9; radius: 5
                            color: Qt.rgba(1, 1, 1, 0.55)
                            rotation: -25
                        }
                    }
                }
                Repeater {
                    model: [dex.red, Theme.warn, Theme.ok]
                    delegate: Rectangle {
                        required property color modelData
                        y: 6
                        width: 14; height: 14; radius: 7
                        color: modelData
                        border.width: 1; border.color: Qt.darker(modelData, 1.6)
                    }
                }
                Column {
                    y: 4
                    leftPadding: 10
                    Text { text: "DEVDEX"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 20; font.bold: true; font.letterSpacing: 3 }
                    Text { text: `${dex.mode.name.toUpperCase()} MODE · ${dex.rows.length} ${dex.mode.p === "" ? "SEEN" : "FOUND"}`
                           color: Theme.subtle; font.family: Theme.font; font.pixelSize: 10; font.letterSpacing: 1.5 }
                }
            }

            // The red seam: the device's hinge line, fading out at both
            // ends — the one large stroke of Pokédex red.
            Rectangle {
                x: 22; y: 82
                width: parent.width - 44; height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.15; color: dex.red }
                    GradientStop { position: 0.85; color: dex.red }
                    GradientStop { position: 1; color: "transparent" }
                }
                opacity: 0.85
            }

            // --- left: the dex screen ---------------------------------------------------
            Rectangle {
                id: bezel
                x: 22; y: 92
                width: 340; height: parent.height - y - 64
                radius: 14
                color: Theme.surfaceHi
                border.width: 1; border.color: Theme.alpha(dex.trim, 0.9)

                Row {   // the two little red dots above the screen
                    x: (parent.width - width) / 2; y: 8; spacing: 10
                    Repeater { model: 2; delegate: Rectangle { width: 7; height: 7; radius: 4; color: dex.red } }
                }

                Rectangle {
                    id: screenRect
                    x: 14; y: 22
                    width: parent.width - 28; height: parent.height - 36
                    radius: 8
                    color: Theme.bg
                    clip: true

                    // faint grid, like an LCD
                    Canvas {
                        anchors.fill: parent
                        opacity: 0.07
                        onPaint: {
                            const c = getContext("2d")
                            c.strokeStyle = Theme.fg
                            c.lineWidth = 1
                            for (let x = 0; x < width; x += 14) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, height); c.stroke() }
                            for (let y = 0; y < height; y += 14) { c.beginPath(); c.moveTo(0, y); c.lineTo(width, y); c.stroke() }
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        visible: dex.selected !== null

                        Item {
                            width: parent.width; height: 120
                            // icon, glyph or emoji — whichever the row has
                            Item {
                                id: art
                                anchors.centerIn: parent
                                width: 104; height: 104
                                IconImage {
                                    anchors.fill: parent
                                    visible: !!(dex.selected && dex.selected.icon)
                                    source: dex.selected && dex.selected.icon ? dex.selected.icon : ""
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !!(dex.selected && !dex.selected.icon)
                                    text: dex.selected ? (dex.selected.emoji || dex.selected.glyph || "") : ""
                                    color: Theme.accent
                                    font.family: dex.selected && dex.selected.emoji ? "Noto Color Emoji" : Theme.font
                                    font.pixelSize: 76
                                }
                                // A small pop whenever the selection changes.
                                SequentialAnimation {
                                    id: pop
                                    NumberAnimation { target: art; property: "scale"; from: 0.82; to: 1.06; duration: 140; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: art; property: "scale"; to: 1; duration: 120 }
                                }
                                Connections {
                                    target: dex
                                    function onSelectedChanged() { pop.restart() }
                                }
                            }
                        }

                        Row {
                            spacing: 8
                            Text { text: dex.selected && dex.selected.no ? Dex.no(dex.selected.no) : ""
                                   color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; font.bold: true
                                   anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                visible: !!(dex.selected && dex.selected.caught)
                                text: Icons.pokeball; color: Theme.err; font.family: Theme.font; font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            width: parent.width
                            text: dex.selected ? dex.selected.title : ""
                            color: Theme.fg; font.family: Theme.font; font.pixelSize: 19; font.bold: true
                            elide: Text.ElideRight
                        }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: dex.selected ? dex.selected.types : []
                                delegate: Rectangle {
                                    required property var modelData
                                    implicitWidth: tlabel.implicitWidth + 16; implicitHeight: 20; radius: 10
                                    color: modelData.color
                                    Text { id: tlabel; anchors.centerIn: parent; text: modelData.name.toUpperCase()
                                           color: "#1a1a1a"; font.family: Theme.font; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            text: dex.selected ? (dex.selected.desc || dex.selected.subtitle || "") : ""
                            color: Theme.subtle; font.family: Theme.font; font.pixelSize: 11
                            wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
                        }
                        Text {
                            visible: !!(dex.selected && dex.selected.key)
                            text: dex.selected && dex.selected.caught
                                  ? `Caught · launched ${dex.selected.count}× · last ${dex.ago(dex.selected.last)}`
                                  : "Not caught yet"
                            color: dex.selected && dex.selected.caught ? Theme.ok : Theme.muted
                            font.family: Theme.font; font.pixelSize: 11
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: dex.selected === null
                        text: "No entries match"
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                    }
                }
            }

            // --- right: search display + list ------------------------------------------
            Rectangle {
                id: searchBox
                anchors.left: bezel.right; anchors.leftMargin: 18
                anchors.right: parent.right; anchors.rightMargin: 22
                y: 26
                height: 44
                radius: 12
                color: Theme.bg
                border.width: 1; border.color: Theme.alpha(Theme.accent, 0.6)

                Text {
                    id: modeGlyph
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    text: dex.mode.p ? dex.mode.glyph : Icons.search
                    color: Theme.accent; font.family: Theme.font; font.pixelSize: 18
                }
                TextInput {
                    id: search
                    anchors.left: modeGlyph.right; anchors.leftMargin: 10
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    selectionColor: Theme.alpha(Theme.accent, 0.4)
                    font.family: Theme.font; font.pixelSize: 15
                    clip: true
                    focus: true

                    Text {
                        visible: search.text === ""
                        text: "Search apps · / projects · + agents · > run · @ windows · = calc · : emoji"
                        color: Theme.muted; font: search.font
                        elide: Text.ElideRight; width: parent.width
                    }

                    Keys.onPressed: (e) => {
                        const ctrl = e.modifiers & Qt.ControlModifier
                        if (e.key === Qt.Key_Escape) { dex.open = false; e.accepted = true }
                        else if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)) {
                            dex.cursor = Math.min(dex.rows.length - 1, dex.cursor + 1); e.accepted = true
                        } else if (e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)) {
                            dex.cursor = Math.max(0, dex.cursor - 1); e.accepted = true
                        } else if (e.key === Qt.Key_PageDown) {
                            dex.cursor = Math.min(dex.rows.length - 1, dex.cursor + 8); e.accepted = true
                        } else if (e.key === Qt.Key_PageUp) {
                            dex.cursor = Math.max(0, dex.cursor - 8); e.accepted = true
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            dex.launch(dex.selected, !!(e.modifiers & Qt.ShiftModifier)); e.accepted = true
                        } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                            const list = dex.modes.filter(m => m.p !== "?")   // every mode but help
                            const i = list.findIndex(m => m.p === dex.mode.p)
                            const d = e.key === Qt.Key_Backtab ? -1 : 1
                            text = list[(i + d + list.length) % list.length].p
                            e.accepted = true
                        }
                    }
                }
            }

            ListView {
                id: list
                anchors.left: searchBox.left; anchors.right: searchBox.right
                anchors.top: searchBox.bottom; anchors.topMargin: 12
                anchors.bottom: parent.bottom; anchors.bottomMargin: 64
                clip: true
                spacing: 3
                model: dex.rows
                currentIndex: dex.cursor
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === dex.cursor
                    width: list.width
                    height: 46
                    radius: 10
                    color: sel ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.surfaceHi, 0.45)
                    border.width: sel ? 2 : 0
                    border.color: Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {   // game-menu cursor
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        text: Icons.cursor; color: Theme.accent
                        font.family: Theme.font; font.pixelSize: 16
                        opacity: row.sel ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }
                    Text {
                        id: num
                        x: 26; anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        text: row.modelData.no ? String(row.modelData.no).padStart(3, "0") : ""
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; font.bold: true
                    }
                    Item {
                        id: rowIcon
                        x: 64; anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26
                        IconImage { anchors.fill: parent; visible: !!row.modelData.icon; source: row.modelData.icon || "" }
                        Text {
                            anchors.centerIn: parent
                            visible: !row.modelData.icon
                            text: row.modelData.emoji || row.modelData.glyph || ""
                            color: Theme.accent
                            font.family: row.modelData.emoji ? "Noto Color Emoji" : Theme.font
                            font.pixelSize: 18
                        }
                    }
                    Column {
                        anchors.left: rowIcon.right; anchors.leftMargin: 12
                        anchors.right: trail.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Text { width: parent.width; text: row.modelData.title || ""; color: Theme.fg
                               font.family: Theme.font; font.pixelSize: 13; font.bold: row.sel; elide: Text.ElideRight }
                        Text { width: parent.width; visible: text !== ""; text: row.modelData.subtitle || ""
                               color: Theme.subtle; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight }
                    }
                    Row {
                        id: trail
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {   // type dots
                            model: row.modelData.types || []
                            delegate: Rectangle {
                                required property var modelData
                                width: 9; height: 9; radius: 5; color: modelData.color
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            visible: !!row.modelData.caught
                            text: Icons.pokeball; color: Theme.err
                            font.family: Theme.font; font.pixelSize: 13
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Follow the pointer only when it really moves.
                        // Hover events also fire when rows move *under* a
                        // still pointer (opening, typing a filter), which
                        // stole the cursor — first via onEntered (opened on
                        // row 002), then via position events (help mode
                        // opened on row 5). Comparing global coordinates
                        // filters both out.
                        onPositionChanged: (m) => {
                            const p = mapToGlobal(m.x, m.y)
                            const last = dex.lastPointer
                            dex.lastPointer = p
                            if (last && Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 2)
                                dex.cursor = row.index
                        }
                        onClicked: dex.launch(row.modelData, false)
                    }
                }
            }

            // --- bottom: D-pad + hints ------------------------------------------------------
            Item {   // decorative D-pad
                x: 26; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                width: 36; height: 36
                Rectangle { anchors.centerIn: parent; width: 12; height: 36; radius: 3; color: Theme.surfaceHi }
                Rectangle { anchors.centerIn: parent; width: 36; height: 12; radius: 3; color: Theme.surfaceHi }
            }
            Row {
                anchors.left: bezel.right; anchors.leftMargin: 18
                anchors.bottom: parent.bottom; anchors.bottomMargin: 22
                spacing: 6
                Repeater {
                    model: [["↑↓", "select"], ["↵", dex.mode.p === ">" ? "run · ⇧↵ term" : dex.mode.p === "+" ? "claude · ⇧↵ codex"
                                                    : dex.mode.p === "=" || dex.mode.p === ":" ? "copy" : "launch"],
                            ["tab", "mode"], ["?", "help"], ["esc", "close"]]
                    delegate: Row {
                        required property var modelData
                        spacing: 4
                        Keycap { key: modelData[0] }
                        Text { text: modelData[1]; color: Theme.subtle; font.family: Theme.font; font.pixelSize: 10
                               anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
