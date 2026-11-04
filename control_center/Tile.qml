import Quickshell.Widgets
import QtQuick
import "../theme"

// Toggle tile: squish + ripple on press, icon pop on click, optional ">" chip
// that opens a detail page.
ClippingRectangle {
    id: tile

    property string icon
    property string label
    property string sub
    property bool on: false
    property bool picked: false
    property bool hasDetail: false

    signal triggered()
    signal detailRequested()
    signal entered()

    width: Ui.tileW
    height: Ui.tileH
    radius: 22
    color: on
        ? Colors.alpha(Colors.colBlue, tileHover.hovered ? 0.44 : 0.34)
        : Colors.alpha(Colors.colFg, tileHover.hovered ? 0.10 : 0.055)
    scale: tileMouse.pressed ? 0.93 : (tileHover.hovered ? 1.045 : 1.0)
    border.width: picked ? 2 : 0
    border.color: Colors.alpha(Colors.colFg, 0.45)

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    HoverHandler {
        id: tileHover
        onHoveredChanged: if (hovered) tile.entered()
    }

    Ripple { id: tileRipple }

    SequentialAnimation {
        id: iconPop
        NumberAnimation { target: tileIcon; property: "scale"; to: 1.35; duration: 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: tileIcon; property: "scale"; to: 1.0; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }

    Text {
        id: tileIcon
        anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 9 }
        text: tile.icon
        color: Colors.fg
        font { family: Ui.iconFont; pixelSize: 21 }
    }

    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 8; bottomMargin: 9 }
        spacing: 0

        Text {
            width: parent.width
            text: tile.label
            color: Colors.fg
            elide: Text.ElideRight
            font { pixelSize: 12; weight: Font.DemiBold }
        }
        Text {
            width: parent.width
            text: tile.sub
            color: Colors.fg
            opacity: 0.55
            elide: Text.ElideRight
            font { pixelSize: 10 }
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { tileRipple.start(mouse.x, mouse.y) }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton && tile.hasDetail) {
                tile.detailRequested()
            } else {
                iconPop.restart()
                tile.triggered()
            }
        }
    }

    // chevron chip: opens the detail page (above the tile's own mouse area)
    Rectangle {
        visible: tile.hasDetail
        anchors { right: parent.right; top: parent.top; rightMargin: 9; topMargin: 8 }
        width: 24
        height: 24
        radius: 12
        color: chevHover.hovered ? Colors.alpha(Colors.colFg, 0.24) : Colors.alpha(Colors.colFg, 0.10)
        scale: chevMouse.pressed ? 0.85 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: "󰅂"
            color: Colors.fg
            font { family: Ui.iconFont; pixelSize: 14 }
        }
        HoverHandler { id: chevHover }
        MouseArea {
            id: chevMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.detailRequested()
        }
    }
}
