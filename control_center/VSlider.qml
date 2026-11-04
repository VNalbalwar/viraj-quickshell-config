import Quickshell.Widgets
import QtQuick
import "../theme"

// Tall rounded slider (iOS-style): drag or scroll to change, tap the icon.
ClippingRectangle {
    id: slider

    property int value: 0
    property string icon
    property bool dim: false

    signal moved(int percent)
    signal iconClicked()

    width: 86
    height: Ui.gridHeight
    radius: 24
    color: Colors.alpha(Colors.colFg, sliderHover.hovered ? 0.085 : 0.055)
    Behavior on color { ColorAnimation { duration: 120 } }

    HoverHandler { id: sliderHover }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * Math.max(0, Math.min(100, slider.value)) / 100
        color: Colors.alpha(Colors.colBlue, slider.dim ? 0.16 : 0.42)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on height { enabled: !dragArea.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
        text: slider.value + "%"
        color: Colors.fg
        opacity: 0.7
        font { pixelSize: 12; weight: Font.DemiBold }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
        text: slider.icon
        color: Colors.fg
        scale: iconZone.pressed ? 0.8 : 1.0
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        font { family: Ui.iconFont; pixelSize: 24 }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function pick(y) {
            var v = (1 - y / slider.height) * 100
            slider.moved(Math.max(0, Math.min(100, Math.round(v))))
        }

        onPressed: function(mouse) { ControlState.adjusting = true; pick(mouse.y) }
        onPositionChanged: function(mouse) { if (pressed) pick(mouse.y) }
        onReleased: ControlState.adjusting = false
        onCanceled: ControlState.adjusting = false
        // proportional: a mouse notch (120) = 5%, a trackpad's tiny deltas add up smoothly
        // (the fractional remainder is kept so slow scrolling still moves the slider)
        property real wheelRemainder: 0
        onWheel: function(wheel) {
            wheelRemainder += wheel.angleDelta.y / 24
            var whole = wheelRemainder > 0 ? Math.floor(wheelRemainder) : Math.ceil(wheelRemainder)
            if (whole === 0) return
            wheelRemainder -= whole
            slider.moved(Math.max(0, Math.min(100, slider.value + whole)))
        }
    }

    MouseArea {
        id: iconZone
        z: 1
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 56
        cursorShape: Qt.PointingHandCursor
        onClicked: slider.iconClicked()
    }
}
