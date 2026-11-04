import QtQuick
import "../theme"

// Shown inside the notch when you switch workspace / layout: one chip per
// existing workspace, the current one stretched and highlighted, then the layout.
Item {
    id: popup

    property bool active: false

    readonly property int chipH: 30
    readonly property int chipW: 32
    readonly property int activeW: 74
    readonly property int count: WorkspaceState.list.length
    readonly property int wantedWidth: Math.max(220, 48 + (count > 0 ? (count - 1) * (chipW + 8) + activeW : 0) + 16 + layoutText.implicitWidth + 24)
    readonly property int wantedHeight: 56

    visible: opacity > 0.01
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Row {
        anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
        spacing: 8

        Repeater {
            model: WorkspaceState.list

            delegate: Rectangle {
                id: chip
                required property var modelData

                readonly property bool current: modelData.id === WorkspaceState.focusedId

                width: current ? popup.activeW : popup.chipW
                height: popup.chipH
                radius: height / 2
                color: current ? Colors.alpha(Colors.colBlue, 0.42)
                    : (chipMouse.containsMouse ? Colors.alpha(Colors.colFg, 0.16) : Colors.alpha(Colors.colFg, 0.07))
                scale: chipMouse.pressed ? 0.9 : 1.0

                Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                Text {
                    anchors.centerIn: parent
                    text: chip.modelData.name
                    color: Colors.fg
                    opacity: chip.current ? 1 : 0.6
                    font { pixelSize: 13; weight: Font.DemiBold }
                }

                // little pip if the workspace is asking for attention
                Rectangle {
                    visible: chip.modelData.urgent && !chip.current
                    anchors { right: parent.right; top: parent.top; rightMargin: 2; topMargin: 2 }
                    width: 8
                    height: 8
                    radius: 4
                    color: "#ff6b6b"
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WorkspaceState.switchTo(chip.modelData.id)
                }
            }
        }
    }

    Text {
        id: layoutText
        anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
        text: WorkspaceState.layoutLabel
        color: Colors.fg
        opacity: 0.55
        font { pixelSize: 11; weight: Font.Medium; capitalization: Font.AllUppercase; letterSpacing: 0.8 }
    }
}
