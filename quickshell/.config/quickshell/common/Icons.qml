pragma Singleton
import Quickshell

// Nerd Font glyphs used across the shell, by name. Every codepoint was
// looked up in nerd-fonts' own glyphnames.json (v3.4.0) by its official
// name — the key is noted beside each — never typed from memory or pasted:
// private-use-area characters don't survive most copy/paste paths, the
// same lesson as waybar/config.jsonc's header. Escapes, not literals.
Singleton {
    readonly property string arch: "\u{f303}"            // linux-archlinux
    readonly property string robot: "\u{f06a9}"          // md-robot
    readonly property string docker: "\u{f0868}"         // md-docker
    readonly property string branch: "\u{f062c}"         // md-source_branch
    readonly property string folder: "\u{f0256}"         // md-folder_outline
    readonly property string app: "\u{f0614}"            // md-application_outline
    readonly property string ciFail: "\u{f0159}"         // md-close_circle
    readonly property string ciPass: "\u{f05e0}"         // md-check_circle
    readonly property string ciRun: "\u{f04e6}"          // md-sync
    readonly property string alert: "\u{f0028}"          // md-alert_circle
    readonly property string hand: "\u{f0e47}"           // md-hand_back_right (needs input)
    readonly property string check: "\u{f012c}"          // md-check
    readonly property string close: "\u{f0156}"          // md-close
    readonly property string up: "\u{f005d}"             // md-arrow_up
    readonly property string down: "\u{f0045}"           // md-arrow_down
    readonly property string dot: "\u{f09de}"            // md-circle_medium
    readonly property string term: "\u{f018d}"        // md-console
    readonly property string cpu: "\u{f0ee0}"            // md-cpu_64_bit
    readonly property string mem: "\u{f035b}"            // md-memory
    readonly property string ethernet: "\u{f0200}"       // md-ethernet
    readonly property string wifiOff: "\u{f092e}"        // md-wifi_strength_off_outline
    readonly property var wifi: ["\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]  // md-wifi_strength_1..4
    readonly property string volOff: "\u{f0581}"         // md-volume_off
    readonly property var vol: ["\u{f057f}", "\u{f0580}", "\u{f057e}"]  // md-volume_low/medium/high
    readonly property string mic: "\u{f036c}"           // md-microphone
    readonly property string bt: "\u{f00af}"             // md-bluetooth
    readonly property string btOn: "\u{f00b1}"           // md-bluetooth_connect
    readonly property string btOff: "\u{f00b2}"          // md-bluetooth_off
    readonly property string bell: "\u{f009c}"           // md-bell_outline
    readonly property string bellBadge: "\u{f0178}"      // md-bell_badge_outline
    readonly property string bellDnd: "\u{f0a93}"        // md-bell_sleep_outline
    readonly property string power: "\u{f0425}"          // md-power
    readonly property string brightness: "\u{f00df}"     // md-brightness_6
    readonly property string charging: "\u{f0084}"       // md-battery_charging
    readonly property string timer: "\u{f051f}"          // md-timer_sand
}
