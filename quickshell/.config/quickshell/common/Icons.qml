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
    // --- dev hub (Phase 10) ---
    readonly property string pr: "\u{f04c2}"             // md-source_pull
    readonly property string web: "\u{f059f}"            // md-web
    readonly property string github: "\u{f02a4}"         // md-github
    readonly property string logs: "\u{f0eaf}"           // md-text_box_search_outline
    readonly property string start: "\u{f040d}"          // md-play_circle_outline
    readonly property string stop: "\u{f0667}"           // md-stop_circle_outline
    readonly property string watch: "\u{f06d0}"          // md-eye_outline
    readonly property string keys: "\u{f097b}"           // md-keyboard_outline
    readonly property string play: "\u{f040a}"           // md-play
    readonly property string pause: "\u{f03e4}"          // md-pause
    readonly property string next: "\u{f04ad}"           // md-skip_next
    readonly property string prev: "\u{f04ae}"           // md-skip_previous
    readonly property string music: "\u{f0387}"          // md-music_note
    readonly property string wifiOn: "\u{f05a9}"         // md-wifi
    readonly property string micOff: "\u{f036d}"         // md-microphone_off
    readonly property string lan: "\u{f0317}"            // md-lan
    readonly property string refresh: "\u{f0450}"        // md-refresh
    readonly property string open: "\u{f03cc}"           // md-open_in_new
    readonly property string hub: "\u{f0a1d}"            // md-view_dashboard_outline
    readonly property string orchestra: "\u{f0b9f}"      // md-folder_star_outline
    readonly property string coffee: "\u{f06ca}"         // md-coffee_outline
    readonly property string profSaver: "\u{f032a}"     // md-leaf
    readonly property string profBalanced: "\u{f05d1}"  // md-scale_balance
    readonly property string profPerf: "\u{f04c5}"      // md-speedometer
    // --- launcher (Phase 11) ---
    readonly property string pokeball: "\u{f041d}"       // md-pokeball
    readonly property string calc: "\u{f15a6}"           // md-calculator_variant_outline
    readonly property string emoji: "\u{f01f5}"          // md-emoticon_happy_outline
    readonly property string help: "\u{f0625}"           // md-help_circle_outline
    readonly property string windows: "\u{f05b2}"        // md-window_restore
    readonly property string search: "\u{f0349}"         // md-magnify
    readonly property string cursor: "\u{f0142}"         // md-chevron_right
}
