// sddm/theme/Main.qml — the login screen, styled as the lock screen's
// Trainer Card (hypr/hyprlock.conf): blurred wallpaper, two-tone clock, a
// card with avatar + greeting + password pill. Colours come from
// theme.conf (written by bin/bin/sddm-sync from the active desktop theme),
// so a theme switch followed by `sddm-sync` restyles this too.
//
// Keys: Enter logs in · F1 / click the user name cycles users ·
//       F2 / click the session name cycles sessions · Esc clears the field.
// Versioned imports on purpose: SDDM's greeter loads themes with an engine that
// rejects versionless ones ("Library import requires a version") and silently
// falls back to its built-in theme.
import QtQuick 2.15
import QtQuick.Effects 6.5

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: cfg("bg", "#16161e")

    // theme.conf lookup with a default, so a missing key never leaves
    // an invalid (transparent) colour.
    function cfg(key, fallback) {
        const v = config[key];
        return (v === undefined || v === "") ? fallback : v;
    }
    readonly property color cFg: cfg("fg", "#c0caf5")
    readonly property color cMuted: cfg("muted", "#565f89")
    readonly property color cAccent: cfg("accent", "#7aa2f7")
    readonly property color cAccent2: cfg("accent2", "#bb9af7")
    readonly property color cSurface: cfg("surface", "#1a1b26")
    readonly property color cErr: cfg("err", "#f7768e")
    readonly property color cOk: cfg("ok", "#9ece6a")
    readonly property string face: cfg("font", "JetBrainsMono Nerd Font")

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property bool failed: false

    // QAbstractItemModel roles: SDDM's UserModel/SessionModel number theirs
    // from Qt.UserRole (0x100) in the order name, realName, icon / name.
    function userField(role) {
        return userModel.data(userModel.index(userIndex, 0), 0x100 + role);
    }
    function sessionName() {
        return sessionModel.data(sessionModel.index(sessionIndex, 0), 0x104) || "session";
    }
    readonly property string loginName: userField(1) || ""
    readonly property string displayName: userField(2) || loginName
    readonly property string iconPath: userField(3) || ""

    function nextUser() { if (userModel.count > 1) userIndex = (userIndex + 1) % userModel.count; }
    function nextSession() { if (sessionModel.count > 1) sessionIndex = (sessionIndex + 1) % sessionModel.count; }

    function greeting() {
        const h = new Date().getHours();
        return h < 5 ? "Still up" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    }

    function tryLogin() {
        if (busy || pass.text.length === 0) return;
        busy = true; failed = false;
        sddm.login(loginName, pass.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.failed = true;
            pass.text = "";
            shake.restart();
            pass.forceActiveFocus();
        }
        function onLoginSucceeded() { root.failed = false; }
    }

    // --- Background: wallpaper, blurred and dimmed like the lock screen ---
    Image {
        id: wall
        anchors.fill: parent
        source: cfg("background", "background.jpg")
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.35
        saturation: -0.1
    }
    // Vignette so the card and the corners read on any wallpaper.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#66000000" }
            GradientStop { position: 0.5; color: "#00000000" }
            GradientStop { position: 1.0; color: "#99000000" }
        }
    }

    // --- Clock: hours in the accent, minutes in the foreground ---
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.10
        spacing: 6
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: parent.parent.width * 0.012
            Text {
                text: Qt.formatTime(root.now, "HH")
                color: root.cAccent
                font { family: root.face; pixelSize: root.height * 0.17; weight: Font.ExtraBold }
            }
            Text {
                text: Qt.formatTime(root.now, "mm")
                color: root.cFg
                font { family: root.face; pixelSize: root.height * 0.17; weight: Font.ExtraBold }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, d MMMM").toUpperCase().split("").join(" ")
            color: root.cMuted
            font { family: root.face; pixelSize: root.height * 0.02; weight: Font.Medium }
        }
    }

    // --- The Trainer Card ---
    Rectangle {
        id: card
        width: Math.min(560, root.width - 48)
        height: 150
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.52
        radius: 22
        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.82)
        border.width: 1
        border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.35)

        // Avatar: the account's own icon if it has one, else a Pokéball.
        Rectangle {
            id: avatar
            width: 96; height: 96; radius: 48
            anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
            color: root.cSurface
            border.width: 3
            border.color: root.failed ? root.cErr : root.cAccent
            Behavior on border.color { ColorAnimation { duration: 200 } }
            clip: true
            Image {
                id: avatarImg
                anchors.fill: parent; anchors.margins: 3
                source: root.iconPath !== "" ? "file://" + root.iconPath : ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
            Image {
                anchors.fill: parent; anchors.margins: 6
                source: "pokeball.svg"
                visible: avatarImg.status !== Image.Ready
                sourceSize: Qt.size(192, 192)
            }
        }

        Column {
            anchors { left: avatar.right; leftMargin: 22; right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                text: "@" + root.loginName
                color: root.cFg
                font { family: root.face; pixelSize: 24; weight: Font.Bold }
                MouseArea { anchors.fill: parent; onClicked: root.nextUser(); cursorShape: userModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
            Text {
                text: root.failed ? "Wrong password — try again" : root.greeting() + ", trainer"
                color: root.failed ? root.cErr : root.cMuted
                font { family: root.face; pixelSize: 14 }
            }
            // Password pill.
            Rectangle {
                id: pill
                width: parent.width; height: 42; radius: 21
                color: Qt.rgba(0, 0, 0, 0.35)
                border.width: 2
                border.color: root.failed ? root.cErr : pass.activeFocus ? root.cAccent : root.cMuted
                Behavior on border.color { ColorAnimation { duration: 150 } }
                SequentialAnimation on x {
                    id: shake
                    running: false
                    NumberAnimation { to: -10; duration: 50 }
                    NumberAnimation { to: 10; duration: 80 }
                    NumberAnimation { to: -6; duration: 60 }
                    NumberAnimation { to: 0; duration: 50 }
                }
                TextInput {
                    id: pass
                    anchors { fill: parent; leftMargin: 18; rightMargin: 46 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.cFg
                    selectionColor: root.cAccent
                    font { family: root.face; pixelSize: 16 }
                    enabled: !root.busy
                    focus: true
                    clip: true
                    onAccepted: root.tryLogin()
                    Keys.onEscapePressed: text = ""
                    Keys.onPressed: (e) => { if (root.failed && e.text !== "") root.failed = false; }
                    Text {
                        visible: pass.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.busy ? "Logging in…" : "Password"
                        color: root.cMuted
                        font: pass.font
                    }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    text: root.busy ? "…" : "→"
                    color: pass.text.length > 0 ? root.cAccent : root.cMuted
                    font { family: root.face; pixelSize: 20; weight: Font.Bold }
                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.tryLogin() }
                }
            }
        }
    }

    // --- Corners: session (left), keyboard layout + power (right) ---
    Row {
        anchors { left: parent.left; bottom: parent.bottom; margins: 32 }
        spacing: 10
        Text {
            text: "  " + root.sessionName()
            color: root.cMuted
            font { family: root.face; pixelSize: 14 }
            MouseArea { anchors.fill: parent; onClicked: root.nextSession(); cursorShape: Qt.PointingHandCursor }
        }
        Text {
            visible: sessionModel.count > 1
            text: "(F2)"
            color: Qt.rgba(root.cMuted.r, root.cMuted.g, root.cMuted.b, 0.6)
            font { family: root.face; pixelSize: 12 }
        }
    }

    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 32 }
        spacing: 22
        Text {
            visible: keyboard.layouts.length > 1
            text: "  " + (keyboard.layouts[keyboard.currentLayout] ? keyboard.layouts[keyboard.currentLayout].shortName : "")
            color: root.cMuted
            font { family: root.face; pixelSize: 14 }
        }
        Text {
            visible: keyboard.capsLock
            text: "CAPS"
            color: root.cOk
            font { family: root.face; pixelSize: 14; weight: Font.Bold }
        }
        Text {
            visible: sddm.canSuspend
            text: ""
            color: suspendMa.containsMouse ? root.cAccent : root.cMuted
            font { family: root.face; pixelSize: 18 }
            MouseArea { id: suspendMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: sddm.suspend() }
        }
        Text {
            visible: sddm.canReboot
            text: ""
            color: rebootMa.containsMouse ? root.cAccent2 : root.cMuted
            font { family: root.face; pixelSize: 18 }
            MouseArea { id: rebootMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: sddm.reboot() }
        }
        Text {
            visible: sddm.canPowerOff
            text: ""
            color: offMa.containsMouse ? root.cErr : root.cMuted
            font { family: root.face; pixelSize: 18 }
            MouseArea { id: offMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: sddm.powerOff() }
        }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_F1) nextUser();
        else if (e.key === Qt.Key_F2) nextSession();
    }

    Component.onCompleted: pass.forceActiveFocus()
}
