import QtQuick
import QtQuick.Effects
import "../theme"

// ─────────────────────────────────────────────────────────────────────────────
//  LockContent — the shared lockscreen visual + input handling.
//
//  Used by BOTH:
//    • Lockscreen.qml   (Stage 1: dismissible test overlay)   testMode: true
//    • SessionLock.qml  (Stage 2: real ext-session-lock)      testMode: false
//
//  Keeping one visual means the Stage-1 test exercises the *exact* UI the real
//  lock renders — no drift, no untested lock surface.
//
//  Props:
//    • active   — the lock is showing. Drives the clock, focus + field clear,
//                 and the subtle slide-in.
//    • testMode — show the "TEST MODE" hint and let Esc dismiss (demo only).
//                 The real lock sets this false, so Esc can NOT escape it.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: content

    property bool active: false
    property bool testMode: false

    // Self-contained clock.
    property var now: new Date()

    // Fresh clock + empty, focused field every time the lock appears.
    function _armField() {
        content.now = new Date()
        passwordField.text = ""
        Qt.callLater(function () {
            passwordField.forceActiveFocus()
        })
    }

    onActiveChanged: if (active) _armField()
    Component.onCompleted: if (active) _armField()

    Connections {
        target: LockState
        function onFailed() {
            passwordField.text = ""
            shake.restart()
            Qt.callLater(function () {
                passwordField.forceActiveFocus()
            })
        }
    }

    // Ticks only while the lock is showing.
    Timer {
        interval: 1000
        repeat: true
        running: content.active
        triggeredOnStart: true
        onTriggered: content.now = new Date()
    }

    // 1 ─ Fallback background (shown only if the wallpaper frame is missing).
    Rectangle {
        anchors.fill: parent
        visible: bg.status !== Image.Ready
        color: Colors.colBg
    }

    // 1 ─ Current wallpaper (hidden source; drawn blurred by MultiEffect below).
    Image {
        id: bg
        anchors.fill: parent
        source: "file:///home/viraj/.cache/wallpaper_frame.png"
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        visible: false
    }

    // 1 ─ Frosted-glass blur over the wallpaper.
    MultiEffect {
        anchors.fill: parent
        source: bg
        visible: bg.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 48
    }

    // 2 ─ Calm gradient scrim for legibility (darker toward the bottom).
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Colors.alpha(Colors.colBg, 0.42) }
            GradientStop { position: 1.0; color: Colors.alpha(Colors.colBg, 0.74) }
        }
    }

    // Clicks on empty space just refocus the field.
    MouseArea {
        anchors.fill: parent
        onClicked: passwordField.forceActiveFocus()
    }

    // 3 ─ Centered stack: clock · date · avatar · name · field · status.
    Column {
        id: stack
        anchors.centerIn: parent
        spacing: 0

        transform: Translate {
            y: content.active ? 0 : 14
            Behavior on y {
                NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(content.now, "HH:mm")
            color: Colors.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 96
            font.weight: Font.Light
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 6
            text: Qt.formatDate(content.now, "dddd, d MMMM")
            color: Colors.alpha(Colors.fg, 0.66)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
            font.weight: Font.Medium
        }

        Item { width: 1; height: 52 }

        // Avatar — photo from ~/.face if present, otherwise a monogram.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            height: 72
            radius: 36
            clip: true
            color: Colors.alpha(Colors.fg, 0.08)
            border.width: 1
            border.color: Colors.alpha(Colors.fg, 0.18)

            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: "V"
                color: Colors.alpha(Colors.fg, 0.85)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 30
                font.weight: Font.DemiBold
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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 10
            text: "Viraj"
            color: Colors.alpha(Colors.fg, 0.8)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        Item { width: 1; height: 30 }

        // Signature element — the "notch capsule" password field.
        Rectangle {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 46
            radius: 23
            color: Colors.alpha(Colors.colBg, 0.55)
            border.width: passwordField.activeFocus ? 2 : 1
            border.color: LockState.errorState
                ? Colors.alpha(Colors.colRed, 0.9)
                : (passwordField.activeFocus ? Colors.alpha(Colors.colBlue, 0.9)
                                             : Colors.alpha(Colors.fg, 0.16))

            Behavior on border.color { ColorAnimation { duration: 140 } }

            transform: Translate { id: shakeT; x: 0 }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 45 }
                NumberAnimation { target: shakeT; property: "x"; to: 9;  duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to: 6;  duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to: 0;  duration: 45 }
            }

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                clip: true

                focus: true
                enabled: !LockState.authenticating && !LockState.unlocking
                echoMode: TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0

                color: Colors.fg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                font.letterSpacing: 3

                cursorDelegate: Rectangle {
                    width: 2
                    color: Colors.colBlue
                    visible: passwordField.cursorVisible
                }

                onAccepted: LockState.submit(text)

                // Esc dismisses ONLY the Stage-1 demo. The real lock (testMode
                // false) ignores it — there is no keyboard escape from the lock.
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Escape) {
                        if (content.testMode)
                            LockState.hideDemo()
                        event.accepted = true
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: passwordField.text.length === 0 && !passwordField.activeFocus
                text: "Password"
                color: Colors.alpha(Colors.fg, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }
        }

        // Status / error line — fixed height so the layout never jumps.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 14
            height: 34
            text: LockState.statusText
            color: LockState.errorState ? Colors.alpha(Colors.colRed, 0.95)
                                        : Colors.alpha(Colors.fg, 0.6)
            opacity: LockState.statusText.length > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    // Stage-1 affordance — makes it obvious the demo is the safe test, not a lock.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        visible: content.testMode
        text: "TEST MODE  ·  Esc to dismiss"
        color: Colors.alpha(Colors.fg, 0.35)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 2
    }
}
