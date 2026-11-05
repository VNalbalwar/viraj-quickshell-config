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
    Behavior on color { ColorAnimation { duration: Motion.fast } }

    Rectangle {
        width: pillMouse.pressed ? 26 : 22
        height: 22
        radius: 11
        y: 3
        x: pill.on ? parent.width - width - 3 : 3
        color: Colors.fg
        Behavior on x { NumberAnimation { duration: Motion.base; easing.type: Motion.pop; easing.overshoot: Motion.overshoot } }
        Behavior on width { NumberAnimation { duration: Motion.quick } }
    }

    MouseArea {
        id: pillMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.toggled()
    }
}
