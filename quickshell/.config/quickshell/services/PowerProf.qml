pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.common

// power-profiles-daemon's active profile, shared by the bar icon and the
// hub's selector so they can't disagree. Quickshell's UPower module talks
// to the daemon over D-Bus and keeps `profile` live, so a change made
// elsewhere (powerprofilesctl, GNOME's panel) shows up here without a poll.
//
// Not every machine has a performance profile (it depends on the CPU
// driver), so the list and the cycle both skip it when
// hasPerformanceProfile is false rather than offering a dead choice.
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    // Set when the daemon is holding the machine back (thermal/battery);
    // empty string means not degraded.
    readonly property string degraded: PowerProfiles.degradationReason ? String(PowerProfiles.degradationReason) : ""

    // Slowest to fastest — the order the hub lays them out and the bar cycles.
    readonly property var order: hasPerformance
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    function label(p) {
        return p === PowerProfile.PowerSaver ? "Saver"
             : p === PowerProfile.Performance ? "Performance" : "Balanced"
    }
    function icon(p) {
        return p === PowerProfile.PowerSaver ? Icons.profSaver
             : p === PowerProfile.Performance ? Icons.profPerf : Icons.profBalanced
    }
    function color(p) {
        return p === PowerProfile.PowerSaver ? Theme.ok
             : p === PowerProfile.Performance ? Theme.warn : Theme.subtle
    }

    function set(p) { PowerProfiles.profile = p }

    // dir = +1 toward performance, -1 toward saver; wraps around.
    function cycle(dir) {
        const i = order.indexOf(profile)
        set(order[(i + dir + order.length) % order.length])
    }
}
