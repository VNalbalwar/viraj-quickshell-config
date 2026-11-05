import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower
import "../theme"

// ─────────────────────────────────────────────────────────────────────────────
//  LockContent — the lockscreen visual + input handling, shared by
//    • Lockscreen.qml   (dismissible test overlay)   testMode: true
//    • SessionLock.qml  (the real ext-session-lock)  testMode: false
//  Everything is drawn in the live theme colors, so it follows the wallpaper / theme switcher.
//
//  Look: the wallpaper, blurred, slowly drifting · a big clock that settles in · an avatar with a
//  ring that breathes while it checks the password · a notch-style capsule that grows open, shows
//  your typing as popping dots, shakes on a wrong password and turns green on success.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: content

    property bool active: false
    property bool testMode: false
    property var now: new Date()

    // entrance progress of each element (staggered, see `intro`)
    property real tClock: 0
    property real tDate: 0
    property real tAvatar: 0
    property real tField: 0
    property real tFoot: 0

    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property bool busy: LockState.authenticating
    readonly property bool ok: LockState.unlocking
    readonly property real battery: UPower.displayDevice && UPower.displayDevice.ready ? UPower.displayDevice.percentage * 100 : -1

    function greeting() {
        var h = content.now.getHours()
        return h < 5 ? "Still up" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 22 ? "Good evening" : "Good night"
    }

    function _armField() {
        content.now = new Date()
        passwordField.text = ""
        tClock = 0; tDate = 0; tAvatar = 0; tField = 0; tFoot = 0
        intro.restart()
        Qt.callLater(function () { passwordField.forceActiveFocus() })
    }

    onActiveChanged: if (active) _armField()
    Component.onCompleted: if (active) _armField()

    Connections {
        target: LockState
        function onFailed() {
            passwordField.text = ""
            shake.restart()
            flash.restart()
            Qt.callLater(function () { passwordField.forceActiveFocus() })
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: content.active
        triggeredOnStart: true
        onTriggered: content.now = new Date()
    }

    // staggered entrance: clock → date → avatar → field → footer
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            NumberAnimation { target: content; property: "tClock"; to: 1; duration: 750; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 110 }
            NumberAnimation { target: content; property: "tDate"; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 230 }
            NumberAnimation { target: content; property: "tAvatar"; to: 1; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 360 }
            NumberAnimation { target: content; property: "tField"; to: 1; duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 600 }
            NumberAnimation { target: content; property: "tFoot"; to: 1; duration: 600; easing.type: Easing.OutCubic }
        }
    }

    // ── background ───────────────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Colors.colBg
    }

    Image {
        id: bg
        anchors.fill: parent
        source: "file:///home/viraj/.cache/wallpaper_frame.png"
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        visible: false
    }

    MultiEffect {
        id: blurred
        anchors.fill: parent
        source: bg
        visible: bg.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 56
        saturation: 0.15
        transformOrigin: Item.Center

        // a very slow drift so the lock never feels frozen
        SequentialAnimation on scale {
            running: content.active
            loops: Animation.Infinite
            NumberAnimation { from: 1.04; to: 1.12; duration: 45000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.12; to: 1.04; duration: 45000; easing.type: Easing.InOutSine }
        }
    }

    // theme-colored wash + vignette: legible, and tinted by whichever theme is active
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Colors.alpha(Colors.colBg, 0.50) }
            GradientStop { position: 0.55; color: Colors.alpha(Colors.colBg, 0.62) }
            GradientStop { position: 1.0; color: Colors.alpha(Colors.colBg, 0.86) }
        }
    }
    Rectangle {
        anchors.fill: parent
        opacity: 0.16 * content.tClock
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Colors.colBlue }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: Colors.colPurple }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: passwordField.forceActiveFocus()
    }

    // ── the stack ────────────────────────────────────────────────────────────────────────────────
    Column {
        id: stack
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 0
        scale: content.ok ? 1.05 : 1
        opacity: content.ok ? 0.0 : 1
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 320 } }

        // clock
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: content.tClock
            spacing: 0
            transform: Translate { y: (1 - content.tClock) * 26 }

            Text {
                text: Qt.formatTime(content.now, "HH")
                color: Colors.fg
                font { family: content.mono; pixelSize: 128; weight: Font.Light }
            }
            Text {
                id: colon
                text: ":"
                color: Colors.colBlue
                topPadding: -6
                font { family: content.mono; pixelSize: 128; weight: Font.Light }
                SequentialAnimation on opacity {
                    running: content.active
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.25; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Text {
                text: Qt.formatTime(content.now, "mm")
                color: Colors.fg
                font { family: content.mono; pixelSize: 128; weight: Font.Light }
            }
        }

        // date
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(content.now, "dddd, d MMMM")
            color: Colors.alpha(Colors.fg, 0.7)
            opacity: content.tDate
            font { family: content.mono; pixelSize: 19; weight: Font.Medium; letterSpacing: 1 }
            transform: Translate { y: (1 - content.tDate) * 18 }
        }

        Item { width: 1; height: 54 }

        // avatar + breathing ring
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92
            height: 92
            opacity: content.tAvatar
            scale: 0.6 + 0.4 * content.tAvatar

            Rectangle {
                id: ring
                anchors.fill: parent
                radius: 46
                color: "transparent"
                border.width: 2
                border.color: content.ok ? Colors.colGreen : (LockState.errorState ? Colors.colRed : Colors.colBlue)
                Behavior on border.color { ColorAnimation { duration: 200 } }
                opacity: 0.9
                SequentialAnimation on scale {
                    running: content.active && content.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 1.14; duration: 520; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.14; to: 1; duration: 520; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 78
                height: 78
                radius: 39
                clip: true
                color: Colors.alpha(Colors.fg, 0.10)

                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: "V"
                    color: Colors.alpha(Colors.fg, 0.9)
                    font { family: content.mono; pixelSize: 34; weight: Font.DemiBold }
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: "file:///home/viraj/.face"
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 14
            text: content.greeting() + ", Viraj"
            color: Colors.alpha(Colors.fg, 0.85)
            opacity: content.tAvatar
            font { family: content.mono; pixelSize: 16; weight: Font.Medium }
        }

        Item { width: 1; height: 26 }

        // the capsule: grows open from a small pill, like the notch
        Rectangle {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64 + 276 * content.tField
            height: 54
            radius: 27
            opacity: content.tField
            color: Colors.alpha(Colors.colBg, 0.62)
            border.width: passwordField.activeFocus ? 2 : 1
            border.color: content.ok ? Colors.colGreen
                : (LockState.errorState ? Colors.alpha(Colors.colRed, 0.95)
                : (passwordField.activeFocus ? Colors.alpha(Colors.colBlue, 0.95) : Colors.alpha(Colors.fg, 0.18)))
            Behavior on border.color { ColorAnimation { duration: 160 } }

            transform: Translate { id: shakeT; x: 0 }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 45 }
                NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45 }
            }

            // red flash on a wrong password
            Rectangle {
                id: flashLayer
                anchors.fill: parent
                radius: parent.radius
                color: Colors.colRed
                opacity: 0
                SequentialAnimation on opacity {
                    id: flash
                    running: false
                    NumberAnimation { to: 0.35; duration: 80 }
                    NumberAnimation { to: 0; duration: 420; easing.type: Easing.OutCubic }
                }
            }

            // hidden real input; we draw our own dots
            TextInput {
                id: passwordField
                anchors.fill: parent
                opacity: 0
                focus: true
                enabled: !LockState.authenticating && !LockState.unlocking
                echoMode: TextInput.Password
                onAccepted: LockState.submit(text)
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Escape) {
                        if (content.testMode) LockState.hideDemo()
                        event.accepted = true
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 9
                visible: !content.ok
                Repeater {
                    model: Math.min(passwordField.text.length, 18)
                    Rectangle {
                        width: 11
                        height: 11
                        radius: 6
                        color: Colors.fg
                        scale: 0
                        Component.onCompleted: scale = 1
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: passwordField.text.length === 0 && !content.ok && content.tField > 0.6
                text: content.busy ? "Checking…" : "Enter password"
                color: Colors.alpha(Colors.fg, 0.45)
                font { family: content.mono; pixelSize: 14 }
            }

            Text {
                anchors.centerIn: parent
                visible: content.ok
                text: "✓  Welcome back"
                color: Colors.colGreen
                font { family: content.mono; pixelSize: 15; weight: Font.DemiBold }
            }
        }

        // status / error line — fixed height so nothing jumps
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 16
            height: 40
            text: LockState.errorState ? LockState.statusText : ""
            color: Colors.alpha(Colors.colRed, 0.95)
            opacity: text.length > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            font { family: content.mono; pixelSize: 13; weight: Font.Medium }
        }
    }

    // ── footer: battery, hint ────────────────────────────────────────────────────────────────────
    Row {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 36; bottomMargin: 30 }
        spacing: 10
        opacity: content.tFoot * (content.battery >= 0 ? 1 : 0)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 18
            radius: 6
            color: "transparent"
            border { width: 1.5; color: Colors.alpha(Colors.fg, 0.6) }
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 3 }
                width: Math.max(2, (parent.width - 6) * Math.min(content.battery, 100) / 100)
                radius: 3
                color: content.battery < 20 ? Colors.colBrightRed : Colors.colBrightGreen
            }
        }
        Text {
            visible: !UPower.onBattery
            anchors.verticalCenter: parent.verticalCenter
            text: "󱐋"
            color: Colors.colBrightGreen
            font { family: content.mono; pixelSize: 15 }
        }
        Text {
            text: Math.round(content.battery) + "%" + (UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging ? "  charging" : "")
            color: Colors.alpha(Colors.fg, 0.7)
            font { family: content.mono; pixelSize: 13 }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
        opacity: content.tFoot
        text: content.testMode ? "TEST MODE  ·  Esc to dismiss" : "Enter to unlock"
        color: Colors.alpha(Colors.fg, 0.4)
        font { family: content.mono; pixelSize: 11; weight: Font.Medium; letterSpacing: 2 }
    }
}
