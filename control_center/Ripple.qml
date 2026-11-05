import QtQuick
import "../theme"

// Expanding tap ripple. Drop it inside a clipped (rounded) card and call
// start(mouse.x, mouse.y) from the card's MouseArea.
Rectangle {
    id: ripple

    property real cx: 0
    property real cy: 0

    function start(x, y) {
        cx = x
        cy = y
        anim.restart()
    }

    x: cx - width / 2
    y: cy - height / 2
    width: 0
    height: width
    radius: width / 2
    color: Colors.alpha(Colors.colFg, 0.20)
    opacity: 0

    ParallelAnimation {
        id: anim
        NumberAnimation { target: ripple; property: "width"; from: 0; to: 260; duration: 460; easing.type: Motion.settle }
        NumberAnimation { target: ripple; property: "opacity"; from: 0.9; to: 0; duration: 460; easing.type: Easing.OutQuad }
    }
}
