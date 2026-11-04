import QtQuick
import "../theme"

// 34px circular icon button (back, refresh, power...). `spinOnClick` spins the icon once.
Rectangle {
    id: btn

    property string icon
    property bool spinOnClick: false
    signal clicked()

    width: 34
    height: 34
    radius: 17
    color: btnHover.hovered ? Colors.alpha(Colors.colFg, 0.13) : Colors.alpha(Colors.colFg, 0.05)
    scale: btnMouse.pressed ? 0.88 : (btnHover.hovered ? 1.08 : 1.0)
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    NumberAnimation {
        id: spin
        target: btnIcon
        property: "rotation"
        from: 0
        to: 360
        duration: 520
        easing.type: Easing.OutCubic
    }

    Text {
        id: btnIcon
        anchors.centerIn: parent
        text: btn.icon
        color: Colors.fg
        font { family: Ui.iconFont; pixelSize: 17 }
    }
    HoverHandler { id: btnHover }
    MouseArea {
        id: btnMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (btn.spinOnClick) spin.restart()
            btn.clicked()
        }
    }
}
