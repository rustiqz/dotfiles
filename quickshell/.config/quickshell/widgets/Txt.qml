import QtQuick
import qs.common

// Text with the shell's font/colour defaults. Also used for Nerd Font
// glyphs: those are written as "\u{f0e7}"-style escapes in the QML, never
// pasted characters — private-use codepoints get mangled in transit (same
// lesson as waybar/config.jsonc's header).
Text {
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.textSize
    verticalAlignment: Text.AlignVCenter
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
}
