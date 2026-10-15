pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Which MPRIS player the shell means by "the player". The bar's media chip
// and the media popover both read this, so they can't disagree.
//
// Rule: the one the user pinned in the popover if it still exists, else
// whichever is playing, else the first. A browser tab with a paused video
// therefore never hides the song that is actually playing, and a paused
// Spotify is still reachable once nothing else is.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property string pinned: ""      // dbusName chosen in the popover; "" = automatic
    readonly property var current: players.find(p => p.dbusName === pinned)
                                   || players.find(p => p.isPlaying) || players[0] || null
    readonly property bool playing: current !== null && current.isPlaying

    // 3:07, or 1:02:03 past the hour. Negative/NaN → "--:--".
    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) return "--:--"
        sec = Math.floor(sec)
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60
        const two = n => (n < 10 ? "0" : "") + n
        return h > 0 ? `${h}:${two(m)}:${two(s)}` : `${m}:${two(s)}`
    }
}
