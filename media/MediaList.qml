import Quickshell.Widgets
import QtQuick
import "../theme"

// "Now playing" list that opens inside the notch: one tall row per sound source, each with a big
// play/pause (or mute) button - easy to hit, unlike the little dots this replaced.
Item {
    id: list

    property bool active: false

    signal closeRequested()
    signal pick(var player)

    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int rowH: 54
    readonly property int visibleRows: Math.min(Math.max(MediaState.count, 1), 4)
    readonly property int wantedWidth: 640
    readonly property int wantedHeight: 66 + visibleRows * (rowH + 6) + 8

    visible: opacity > 0.01
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    // header
    Row {
        anchors { left: parent.left; leftMargin: 26; top: parent.top; topMargin: 21 }
        spacing: 12

        Text {
            text: "Now playing"
            color: Colors.fg
            font { pixelSize: 15; weight: Font.DemiBold }
        }
        Text {
            text: MediaState.playingCount + " of " + MediaState.count + " playing"
            color: Colors.grey2
            font.pixelSize: 12
            topPadding: 3
        }
    }

    Rectangle {
        id: closeButton
        anchors { right: parent.right; rightMargin: 22; top: parent.top; topMargin: 14 }
        width: 32
        height: 32
        radius: 16
        color: closeMouse.containsMouse ? Colors.alpha(Colors.colFg, 0.16) : Colors.alpha(Colors.colFg, 0.07)
        scale: closeMouse.pressed ? 0.88 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2 } }

        Text {
            anchors.centerIn: parent
            text: "󰅃"
            color: Colors.fg
            font { family: list.iconFont; pixelSize: 16 }
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: list.closeRequested()
        }
    }

    ListView {
        id: rows
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 20; rightMargin: 20; topMargin: 58; bottomMargin: 10 }
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: MediaState.rows

        delegate: ClippingRectangle {
            id: row
            required property var modelData
            required property int index

            width: rows.width
            height: list.rowH
            radius: 18
            color: modelData.playing
                ? Colors.alpha(Colors.colBlue, rowHover.hovered ? 0.30 : 0.22)
                : Colors.alpha(Colors.colFg, rowHover.hovered ? 0.10 : 0.055)
            scale: rowMouse.pressed ? 0.985 : 1.0
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 } }

            HoverHandler { id: rowHover }

            // tapping the row itself makes that player the main one (streams have nothing to select)
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                cursorShape: row.modelData.kind === "mpris" ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (row.modelData.kind === "mpris") list.pick(row.modelData.player)
            }

            ClippingRectangle {
                id: art
                anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                width: 40
                height: 40
                radius: 12
                color: Colors.alpha(Colors.colFg, 0.10)

                Image {
                    anchors.fill: parent
                    source: row.modelData.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: row.modelData.art === ""
                    text: row.modelData.kind === "stream" ? "󰕾" : "󰎆"
                    color: Colors.colBrightBlue
                    font { family: list.iconFont; pixelSize: 20 }
                }
            }

            Column {
                anchors { left: art.right; leftMargin: 12; right: actionButton.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 1

                Text {
                    width: parent.width
                    text: row.modelData.title
                    color: Colors.fg
                    elide: Text.ElideRight
                    font { pixelSize: 13; weight: Font.DemiBold }
                }
                Text {
                    width: parent.width
                    text: row.modelData.app + (row.modelData.subtitle !== "" && row.modelData.kind === "mpris" ? "  ·  " + row.modelData.subtitle : "")
                        + (row.modelData.kind === "mpris" ? (row.modelData.playing ? "" : "  ·  paused") : "  ·  " + (row.modelData.muted ? "muted" : "playing"))
                    color: Colors.fg
                    opacity: 0.55
                    elide: Text.ElideRight
                    font.pixelSize: 11
                }
            }

            // the big button: play/pause for players, mute/unmute for streams
            Rectangle {
                id: actionButton
                anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                width: 40
                height: 40
                radius: 20
                color: actionMouse.containsMouse ? Colors.alpha(Colors.colBlue, 0.55) : Colors.alpha(Colors.colBlue, 0.34)
                scale: actionMouse.pressed ? 0.86 : (actionMouse.containsMouse ? 1.06 : 1.0)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                Text {
                    anchors.centerIn: parent
                    text: row.modelData.kind === "mpris"
                        ? (row.modelData.playing ? "󰏤" : "󰐊")
                        : (row.modelData.muted ? "󰖁" : "󰕾")
                    color: Colors.fg
                    font { family: list.iconFont; pixelSize: 20 }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaState.toggle(row.modelData)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: rows.count === 0
            text: "Nothing is playing"
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
