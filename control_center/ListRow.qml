import Quickshell.Widgets
import QtQuick
import "../theme"

// One row of a detail-page list: icon, title/subtitle, trailing tag.
ClippingRectangle {
    id: row

    property string icon
    property string title
    property string subtitle
    property string tag
    property bool on: false
    property bool picked: false

    signal clicked()
    signal rightClicked()
    signal entered()

    height: 48
    radius: 16
    color: on
        ? Colors.alpha(Colors.colBlue, rowHover.hovered ? 0.40 : 0.30)
        : Colors.alpha(Colors.colFg, rowHover.hovered ? 0.10 : 0.055)
    scale: rowMouse.pressed ? 0.975 : 1.0
    border.width: picked ? 2 : 0
    border.color: Colors.alpha(Colors.colFg, 0.45)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2 } }

    HoverHandler {
        id: rowHover
        onHoveredChanged: if (hovered) row.entered()
    }

    Ripple { id: rowRipple }

    Text {
        id: rowIcon
        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
        text: row.icon
        color: Colors.fg
        font { family: Ui.iconFont; pixelSize: 21 }
    }

    Column {
        anchors { left: rowIcon.right; leftMargin: 14; right: rowTag.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 0

        Text {
            width: parent.width
            text: row.title
            color: Colors.fg
            elide: Text.ElideRight
            font { pixelSize: 13; weight: Font.DemiBold }
        }
        Text {
            width: parent.width
            text: row.subtitle
            color: Colors.fg
            opacity: 0.5
            elide: Text.ElideRight
            font { pixelSize: 10 }
            visible: text !== ""
        }
    }

    Text {
        id: rowTag
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        text: row.tag
        color: Colors.fg
        opacity: 0.7
        font { family: Ui.iconFont; pixelSize: 12; weight: Font.DemiBold }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { rowRipple.start(mouse.x, mouse.y) }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) row.rightClicked()
            else row.clicked()
        }
    }
}
