import QtQuick
import "../theme"

// Tiny always-visible indicator in the collapsed notch: one dot per existing
// workspace, the current one stretched into a pill.
Row {
    id: dots

    property bool shown: true

    readonly property int count: WorkspaceState.list.length

    spacing: 4
    opacity: (shown && count > 1) ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 220 } }

    Repeater {
        model: WorkspaceState.list

        delegate: Rectangle {
            required property var modelData
            readonly property bool current: modelData.id === WorkspaceState.focusedId

            width: current ? 16 : 6
            height: 6
            radius: 3
            color: current ? Colors.fg : Colors.alpha(Colors.colFg, 0.3)

            Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
