import QtQuick
import "../theme"

// A control-center page. Slides + fades in/out as ControlState.page changes.
// Pages with a list set `count` and react to `activateRequested`.
Item {
    id: page

    property string name
    property int listIndex: 0
    property int count: 0

    readonly property bool shown: ControlState.page === name

    signal activateRequested()
    signal deleteRequested()

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    opacity: shown ? 1 : 0
    x: shown ? 0 : (name === "main" ? -56 : 56)
    visible: opacity > 0.01
    enabled: shown

    Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.settle } }
    Behavior on x { NumberAnimation { duration: Motion.slide; easing.type: Motion.settle } }

    onShownChanged: if (shown) listIndex = 0

    // Shared list keys. `typing` = a text field has focus (so Left/Backspace edit text).
    function handleKey(event, typing) {
        if (event.key === Qt.Key_Up) {
            if (count > 0) listIndex = (listIndex - 1 + count) % count
        } else if (event.key === Qt.Key_Down) {
            if (count > 0) listIndex = (listIndex + 1) % count
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateRequested()
        } else if (!typing && event.key === Qt.Key_Delete) {
            deleteRequested()
        } else if (!typing && (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace)) {
            ControlState.back()
        } else {
            return false
        }
        event.accepted = true
        return true
    }
}
