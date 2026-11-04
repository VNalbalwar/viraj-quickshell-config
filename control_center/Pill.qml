import QtQuick
import "../theme"

// On/off switch with a springy knob.
Rectangle {
    id: pill

    property bool on: false
    signal toggled()

    width: 48
    height: 28
    radius: 14
    color: on ? Colors.alpha(Colors.colBlue, 0.55) : Colors.alpha(Colors.colFg, 0.12)
    Behavior on color { ColorAnimation { duration: 160 } }

    Rectangle {
        width: pillMouse.pressed ? 26 : 22
        height: 22
        radius: 11
        y: 3
        x: pill.on ? parent.width - width - 3 : 3
        color: Colors.fg
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        Behavior on width { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: pillMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.toggled()
    }
}
