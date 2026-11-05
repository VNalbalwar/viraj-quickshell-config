import QtQuick
import "../theme"

// Keybind cheatsheet, built from the `desc` of every bind in binds.lua.
Page {
    id: page
    name: "keys"
    count: KeybindState.shown.length

    onShownChanged: {
        if (shown) {
            search.text = ""
            KeybindState.filter = ""
            KeybindState.load()
            Qt.callLater(function() { search.forceActiveFocus() })
        } else if (parent) {
            parent.forceActiveFocus()
        }
    }

    Rectangle {
        id: searchBox
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop - 4 }
        height: 42
        radius: 15
        color: Colors.alpha(Colors.colFg, 0.06)

        Text {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: "󰍉"
            color: Colors.fg
            opacity: 0.5
            font { family: Ui.iconFont; pixelSize: 16 }
        }

        TextInput {
            id: search
            anchors { left: parent.left; right: parent.right; leftMargin: 44; rightMargin: 16; verticalCenter: parent.verticalCenter }
            color: Colors.fg
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            onTextChanged: { KeybindState.filter = text; page.listIndex = 0 }
            Keys.onPressed: function(event) { page.handleKey(event, true) }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search keybinds…"
                color: Colors.fg
                opacity: 0.35
                visible: search.text.length === 0
                font.pixelSize: 13
            }
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: searchBox.bottom; bottom: parent.bottom; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: 8; bottomMargin: Ui.bottomMargin }
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: KeybindState.shown
        currentIndex: page.listIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            required property var modelData
            required property int index

            width: list.width
            height: 40
            radius: 14
            color: Colors.alpha(Colors.colFg, index === page.listIndex ? 0.10 : 0.055)
            Behavior on color { ColorAnimation { duration: Motion.quick } }

            Row {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 5

                Repeater {
                    model: modelData.chips

                    delegate: Rectangle {
                        required property string modelData

                        width: chipText.implicitWidth + 16
                        height: 24
                        radius: 8
                        color: Colors.alpha(Colors.colBlue, 0.28)

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData
                            color: Colors.fg
                            font { pixelSize: 11; weight: Font.DemiBold }
                        }
                    }
                }
            }

            Text {
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: modelData.desc
                color: Colors.fg
                opacity: 0.85
                font.pixelSize: 12
            }

            HoverHandler { onHoveredChanged: if (hovered) page.listIndex = index }
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: KeybindState.filter !== "" ? "No matches" : "No keybinds with a description"
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
