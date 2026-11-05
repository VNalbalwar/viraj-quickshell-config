import Quickshell.Widgets
import QtQuick
import "../theme"

// One theme: shown in its own colors (background, text, the accent palette) so you see what you get.
// The first card, "Follow wallpaper", shows the current picture instead.
Item {
    id: card

    property var info
    property bool cursor: false
    property bool applied: false
    property string wallpaperThumb: ""

    signal chosen()

    readonly property bool auto: info && info.auto === true

    HoverHandler { id: hover }

    scale: hover.hovered ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    ClippingRectangle {
        anchors.fill: parent
        radius: 14
        color: card.auto ? Colors.alpha(Colors.colFg, 0.08) : (card.info ? card.info.bg : "transparent")

        Image {
            visible: card.auto && source !== ""
            anchors.fill: parent
            source: card.wallpaperThumb !== "" ? "file://" + card.wallpaperThumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.55
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 3

            Text {
                width: parent.width
                text: card.info ? card.info.label : ""
                elide: Text.ElideRight
                color: card.auto ? Colors.fg : (card.info ? card.info.fg : Colors.fg)
                font { pixelSize: 13; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                text: card.auto ? "colors from the picture" : (card.info && card.info.dark ? "dark" : "light")
                elide: Text.ElideRight
                color: card.auto ? Colors.grey2 : (card.info ? card.info.fg : Colors.fg)
                opacity: 0.6
                font.pixelSize: 11
            }
        }

        // the accent colors of this theme (red, green, yellow, blue, magenta, cyan)
        Row {
            visible: !card.auto
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 12 }
            spacing: 6
            Repeater {
                model: card.info && card.info.colors ? card.info.colors.slice(1, 7) : []
                Rectangle { width: 16; height: 16; radius: 8; color: modelData }
            }
        }

        // "follow wallpaper": the live palette instead
        Row {
            visible: card.auto
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 12 }
            spacing: 6
            Repeater {
                model: [Colors.colRed, Colors.colGreen, Colors.colYellow, Colors.colBlue, Colors.colPurple, Colors.colCyan]
                Rectangle { width: 16; height: 16; radius: 8; color: modelData; border { width: 1; color: Colors.alpha(Colors.colBg, 0.6) } }
            }
        }
    }

    // applied badge
    Rectangle {
        visible: card.applied
        anchors { right: parent.right; top: parent.top; rightMargin: 9; topMargin: 9 }
        width: 10
        height: 10
        radius: 5
        color: Colors.colBlue
        border { width: 1.5; color: card.auto ? Colors.colBg : (card.info ? card.info.bg : Colors.colBg) }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "transparent"
        antialiasing: true
        border.width: card.cursor ? 3 : (hover.hovered ? 2 : 1)
        border.color: card.cursor ? Colors.colBlue : Colors.alpha(Colors.colFg, hover.hovered ? 0.55 : 0.14)
        Behavior on border.width { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.chosen()
    }
}
