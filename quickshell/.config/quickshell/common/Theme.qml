pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colours, fonts and shared metrics for every surface in the shell.
//
// Colours come from active-theme.json — a symlink bin/bin/theme repoints
// at themes/<name>/quickshell.json (or the matugen-generated
// themes/wallpaper/quickshell.json). The FileView watches it, so a theme
// switch lands here without restarting anything, and every colour
// property animates to its new value: the whole bar cross-fades instead
// of snapping. Keys are *roles* (surface, accent, err...), not hues, so a
// theme only has to fill the same contract.
//
// Fallbacks are TokyoNight, so the bar still renders sensibly if the
// symlink is missing (fresh clone before `theme` has ever run).
Singleton {
    id: root

    // --- palette -------------------------------------------------------------
    property color bg: "#16161e"          // deepest layer (behind islands)
    property color surface: "#1a1b26"     // island fill
    property color surfaceHi: "#292e42"   // chips, hover, active pills
    property color fg: "#c0caf5"
    property color subtle: "#a9b1d6"      // secondary text
    property color muted: "#565f89"       // inactive / tertiary
    property color border: "#3b4261"
    property color accent: "#7aa2f7"
    property color accent2: "#bb9af7"     // gradient partner of accent
    property color info: "#7dcfff"
    property color ok: "#9ece6a"
    property color warn: "#e0af68"
    property color err: "#f7768e"
    property real islandOpacity: 0.86
    property string name: "fallback"

    readonly property int fadeMs: 600
    Behavior on surface { ColorAnimation { duration: root.fadeMs } }
    Behavior on surfaceHi { ColorAnimation { duration: root.fadeMs } }
    Behavior on bg { ColorAnimation { duration: root.fadeMs } }
    Behavior on fg { ColorAnimation { duration: root.fadeMs } }
    Behavior on subtle { ColorAnimation { duration: root.fadeMs } }
    Behavior on muted { ColorAnimation { duration: root.fadeMs } }
    Behavior on border { ColorAnimation { duration: root.fadeMs } }
    Behavior on accent { ColorAnimation { duration: root.fadeMs } }
    Behavior on accent2 { ColorAnimation { duration: root.fadeMs } }
    Behavior on info { ColorAnimation { duration: root.fadeMs } }
    Behavior on ok { ColorAnimation { duration: root.fadeMs } }
    Behavior on warn { ColorAnimation { duration: root.fadeMs } }
    Behavior on err { ColorAnimation { duration: root.fadeMs } }

    // --- type ------------------------------------------------------------------
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int textSize: 12
    readonly property int smallSize: 10
    readonly property int iconSize: 14

    // --- metrics -----------------------------------------------------------------
    // Match hypr/look.conf: same 14px radius as windows, island margin = the
    // 12px gaps_out, so bar islands line up with the window edges below.
    readonly property int radius: 14
    readonly property int gap: 12
    readonly property int barHeight: 34
    readonly property int pad: 10

    // Motion: Material 3 standard easing, same family as look.conf's curves.
    readonly property int animFast: 160
    readonly property int animMed: 280
    readonly property int animSlow: 420

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // bin/bin/theme calls `qs ipc call theme reload` after repointing the
    // symlink. The file watch alone isn't enough: `ln -sf` replaces the
    // *link*, while the watch follows the file it pointed at — so a theme
    // switch changed nothing until this was added (caught by repointing
    // to a test palette and screenshotting the bar, which stayed blue).
    IpcHandler {
        target: "theme"
        function reload(): void { themeFile.reload() }
        // Which theme the *running* bar has applied — what
        // scripts/verify-phase9.sh asserts after a switch, instead of
        // trusting that the symlink moved.
        function name(): string { return root.name }
    }

    FileView {
        id: themeFile
        path: Quickshell.shellDir + "/active-theme.json"
        // Still useful for editing a theme file in place (tuning colours
        // with the bar open): saves re-apply immediately.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let t
            try { t = JSON.parse(text()) } catch (e) {
                console.warn("Theme: active-theme.json is not valid JSON:", e)
                return
            }
            for (const k of ["bg", "surface", "surfaceHi", "fg", "subtle", "muted", "border",
                             "accent", "accent2", "info", "ok", "warn", "err"]) {
                if (typeof t[k] === "string") root[k] = t[k]
            }
            if (typeof t.islandOpacity === "number") root.islandOpacity = t.islandOpacity
            if (typeof t.name === "string") root.name = t.name
        }
    }
}
