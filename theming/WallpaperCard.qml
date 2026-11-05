import Quickshell.Widgets
import QtQuick
import "../theme"

// One wallpaper preview. Uses the small cached thumbnail, never the full-size picture.
Item {
    id: card

    property string path
    property string thumb
    property bool ready: false
    property bool selected: false
    property bool current: false

    signal chosen()

    HoverHandler { id: hover }

    scale: hover.hovered ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.settle } }

    ClippingRectangle {
        anchors.fill: parent
        radius: 14
        color: Colors.alpha(Colors.colFg, 0.06)

        Image {
            anchors.fill: parent
            source: card.ready ? "file://" + card.thumb : ""
            sourceSize.width: 480
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.base } }
        }
    }

    // the one in use right now
    Rectangle {
        visible: card.current
        anchors { left: parent.left; top: parent.top; leftMargin: 8; topMargin: 8 }
        width: 8
        height: 8
        radius: 4
        color: Colors.colBlue
        border { width: 1.5; color: Colors.colBg }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "transparent"
        antialiasing: true
        border.width: card.selected ? 3 : (hover.hovered ? 2 : 0)
        border.color: card.selected ? Colors.colBlue : Colors.alpha(Colors.colFg, 0.55)
        Behavior on border.width { NumberAnimation { duration: Motion.quick } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.chosen()
    }
}
