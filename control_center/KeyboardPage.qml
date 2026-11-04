import QtQuick
import "../theme"

// Keyboard backlight: four zone swatches, a colour palette, hardware effects
// and brightness. Needs the patched driver + predator-sense helper.
Page {
    id: page
    name: "keyboard"

    onShownChanged: if (shown) KeyboardState.refresh()

    // not available yet: say what to do instead of showing dead controls
    Column {
        anchors.centerIn: parent
        visible: !KeyboardState.available
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Keyboard lighting isn't available yet"
            color: Colors.fg
            font { pixelSize: 15; weight: Font.DemiBold }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Run extras/predator/install.sh once - it adds your model to the driver"
            color: Colors.fg
            opacity: 0.55
            font.pixelSize: 12
        }
    }

    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop - 4 }
        spacing: 10
        visible: KeyboardState.available
        opacity: KeyboardState.helper ? 1 : 0.5

        // zones (+ "all")
        Row {
            spacing: 8

            Repeater {
                model: 5

                delegate: Rectangle {
                    required property int index
                    readonly property int zone: index - 1            // -1 = all
                    readonly property bool selected: KeyboardState.selectedZone === zone

                    width: (page.width - 2 * Ui.sideMargin - 4 * 8) / 5
                    height: 54
                    radius: 16
                    color: zone < 0 ? Colors.alpha(Colors.colFg, 0.07) : "#" + KeyboardState.zones[zone]
                    border.width: selected ? 3 : 1
                    border.color: selected ? Colors.fg : Colors.alpha(Colors.colFg, 0.18)
                    scale: zoneMouse.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text: zone < 0 ? "All" : "Zone " + (zone + 1)
                        color: zone < 0 ? Colors.fg : "#000000"
                        opacity: zone < 0 ? 0.85 : 0.55
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }

                    MouseArea {
                        id: zoneMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeyboardState.selectedZone = zone
                    }
                }
            }
        }

        // palette
        Row {
            spacing: 8

            Repeater {
                model: KeyboardState.palette

                delegate: Rectangle {
                    required property string modelData

                    width: 30
                    height: 30
                    radius: 15
                    color: "#" + modelData
                    scale: swatchMouse.pressed ? 0.85 : (swatchMouse.containsMouse ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeyboardState.setColor(modelData)
                    }
                }
            }

            // theme colours, so the keyboard can match the wallpaper palette
            Repeater {
                model: [Colors.colBrightBlue, Colors.colBrightPurple, Colors.colBrightCyan]

                delegate: Rectangle {
                    required property color modelData

                    width: 30
                    height: 30
                    radius: 15
                    color: modelData
                    border { width: 2; color: Colors.alpha(Colors.colFg, 0.5) }
                    scale: themeMouse.pressed ? 0.85 : (themeMouse.containsMouse ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                    MouseArea {
                        id: themeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeyboardState.setColor(KeyboardState.hex(parent.color))
                    }
                }
            }
        }

        // effects
        Row {
            spacing: 6

            Repeater {
                model: KeyboardState.effects

                delegate: Rectangle {
                    required property var modelData

                    width: (page.width - 2 * Ui.sideMargin - 7 * 6) / 8
                    height: 32
                    radius: 12
                    color: KeyboardState.effect === modelData.mode
                        ? Colors.alpha(Colors.colBlue, 0.4)
                        : Colors.alpha(Colors.colFg, effMouse.containsMouse ? 0.10 : 0.055)
                    scale: effMouse.pressed ? 0.92 : 1.0
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: Colors.fg
                        font { pixelSize: 11; weight: Font.DemiBold }
                    }

                    MouseArea {
                        id: effMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeyboardState.setEffect(modelData.mode)
                    }
                }
            }
        }

        // brightness
        Rectangle {
            width: parent.width
            height: 30
            radius: 15
            color: Colors.alpha(Colors.colFg, 0.06)
            clip: true

            Rectangle {
                width: parent.width * KeyboardState.brightness / 100
                height: parent.height
                radius: 15
                color: Colors.alpha(Colors.colBlue, 0.42)
            }

            Text {
                anchors.centerIn: parent
                text: "Brightness  " + KeyboardState.brightness + "%"
                color: Colors.fg
                opacity: 0.8
                font { pixelSize: 11; weight: Font.DemiBold }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: function(m) { KeyboardState.setBrightness(m.x / width * 100) }
                onPositionChanged: function(m) { if (pressed) KeyboardState.setBrightness(m.x / width * 100) }
                onWheel: function(w) { KeyboardState.setBrightness(KeyboardState.brightness + (w.angleDelta.y > 0 ? 5 : -5)) }
            }
        }
    }
}
