import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.common
import qs.services
import qs.widgets

// Battery popover — the bar capsule's click. What the capsule can't say:
// time left, how fast it's draining, how worn the cell is, and the power
// profile in words. Everything is UPower's (Quickshell.Services.UPower),
// live, no polling of ours.
//
// "Devices" lists every other battery UPower knows about — earbuds,
// mouse, keyboard — so a connected headset's charge shows here too.
Popover {
    id: pop
    name: "battery"
    cardWidth: 340

    readonly property var bat: UPower.displayDevice
    readonly property real pct: bat && bat.ready ? bat.percentage : 0
    readonly property bool charging: bat && bat.state === UPowerDeviceState.Charging
    readonly property bool full: bat && bat.state === UPowerDeviceState.FullyCharged
    readonly property color tone: charging || full ? Theme.ok : pct < 0.15 ? Theme.err : pct < 0.3 ? Theme.warn : Theme.accent
    readonly property var others: UPower.devices.values.filter(d => !d.isLaptopBattery && d.isPresent && d.percentage > 0
                                                                    && d.model && d.type !== UPowerDeviceType.LinePower)

    // Health = full-charge capacity vs design capacity. UPower's own
    // healthPercentage is unsupported on some laptops (here), but the same
    // two numbers are in sysfs, in whatever unit that driver uses (µAh or
    // µWh — the ratio is unit-free). Read once per open, not polled.
    property real healthRatio: 0
    function readHealth(full, design) {
        const f = parseFloat(full), d = parseFloat(design)
        healthRatio = f > 0 && d > 0 ? f / d : 0
    }
    onOpened: { fullFile.reload(); designFile.reload() }
    FileView { id: fullFile;   path: "/sys/class/power_supply/BAT0/charge_full";        onLoaded: pop.readHealth(text(), designFile.text()) }
    FileView { id: designFile; path: "/sys/class/power_supply/BAT0/charge_full_design"; onLoaded: pop.readHealth(fullFile.text(), text()) }

    function dur(sec) {
        if (!sec || sec <= 0) return ""
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return h > 0 ? `${h}h ${m}m` : `${m}m`
    }
    readonly property string status: !bat ? ""
        : full ? "Fully charged"
        : charging ? (bat.timeToFull > 0 ? `Charging · ${dur(bat.timeToFull)} to full` : "Charging")
        : (bat.timeToEmpty > 0 ? `On battery · ${dur(bat.timeToEmpty)} left` : "On battery")

    component Stat: Column {
        property string label
        property string value
        width: parent ? parent.width / 3 : 80
        spacing: 2
        Txt { anchors.verticalCenter: undefined; text: parent.value; font.bold: true; font.pixelSize: Theme.textSize + 1
              width: parent.width; horizontalAlignment: Text.AlignHCenter }
        Txt { anchors.verticalCenter: undefined; text: parent.label; color: Theme.muted; font.pixelSize: Theme.smallSize
              width: parent.width; horizontalAlignment: Text.AlignHCenter }
    }

    Column {
        width: parent.width
        spacing: 12

        Txt { anchors.verticalCenter: undefined; text: "Battery"; font.bold: true; font.pixelSize: Theme.textSize + 2 }

        // --- level ----------------------------------------------------------
        Item {
            width: parent.width; height: 70
            Txt { anchors.verticalCenter: undefined; text: `${Math.round(pop.pct * 100)}%`
                  font.pixelSize: 34; font.bold: true; color: pop.tone }
            Txt { anchors.verticalCenter: undefined; y: 46; text: pop.status; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
            Txt { anchors.verticalCenter: undefined; anchors.right: parent.right; y: 8
                  text: pop.charging ? Icons.charging : ""; color: Theme.ok; font.pixelSize: 26 }
        }
        Rectangle {
            width: parent.width; height: 8; radius: 4
            color: Theme.alpha(Theme.border, 0.6)
            Rectangle {
                width: parent.width * Math.max(0.02, pop.pct); height: parent.height; radius: 4; color: pop.tone
                Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            }
        }

        // --- numbers --------------------------------------------------------
        Row {
            width: parent.width
            Stat { label: pop.charging ? "charge rate" : "draw"
                   value: pop.bat && pop.bat.changeRate !== undefined ? `${Math.abs(pop.bat.changeRate).toFixed(1)} W` : "—" }
            Stat { label: "energy"
                   value: pop.bat ? `${pop.bat.energy.toFixed(1)} / ${pop.bat.energyCapacity.toFixed(0)} Wh` : "—" }
            Stat { label: "health"
                   value: pop.bat && pop.bat.healthSupported ? `${Math.round(pop.bat.healthPercentage)}%`
                        : pop.healthRatio > 0 ? `${Math.round(pop.healthRatio * 100)}%` : "—" }
        }

        // --- power profile --------------------------------------------------
        Txt { anchors.verticalCenter: undefined; text: "POWER PROFILE"; color: Theme.muted
              font.pixelSize: Theme.smallSize; font.letterSpacing: 1.5 }
        Row {
            width: parent.width
            spacing: 6
            Repeater {
                model: PowerProf.order
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool cur: PowerProf.profile === modelData
                    width: (parent.width - (PowerProf.order.length - 1) * 6) / PowerProf.order.length
                    height: 54; radius: 12
                    color: cur ? Theme.alpha(PowerProf.color(modelData), 0.22) : ma.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.9) : Theme.alpha(Theme.surfaceHi, 0.5)
                    border.width: 1
                    border.color: cur ? PowerProf.color(modelData) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Txt { anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter
                              text: PowerProf.icon(modelData); font.pixelSize: Theme.iconSize + 4
                              color: cur ? PowerProf.color(modelData) : Theme.subtle }
                        Txt { anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter
                              text: PowerProf.label(modelData); font.pixelSize: Theme.smallSize
                              color: cur ? Theme.fg : Theme.subtle }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: PowerProf.set(modelData) }
                }
            }
        }
        Txt { anchors.verticalCenter: undefined; visible: PowerProf.degraded !== ""
              width: parent.width; wrapMode: Text.Wrap; color: Theme.warn; font.pixelSize: Theme.smallSize
              text: `Held back: ${PowerProf.degraded}` }

        // --- other batteries --------------------------------------------------
        Txt { anchors.verticalCenter: undefined; visible: pop.others.length > 0; text: "DEVICES"; color: Theme.muted
              font.pixelSize: Theme.smallSize; font.letterSpacing: 1.5 }
        Repeater {
            model: pop.others
            delegate: Item {
                required property var modelData
                width: parent.width; height: 26
                Txt { x: 2; text: modelData.model; elide: Text.ElideRight; width: parent.width - 120 }
                Rectangle {
                    anchors.right: pct.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    width: 60; height: 6; radius: 3; color: Theme.alpha(Theme.border, 0.6)
                    Rectangle { width: parent.width * modelData.percentage; height: parent.height; radius: 3
                                color: modelData.percentage < 0.2 ? Theme.err : Theme.ok }
                }
                Txt { id: pct; anchors.right: parent.right; width: 36; horizontalAlignment: Text.AlignRight
                      text: `${Math.round(modelData.percentage * 100)}%`; color: Theme.subtle; font.pixelSize: Theme.smallSize + 1 }
            }
        }
    }
}
