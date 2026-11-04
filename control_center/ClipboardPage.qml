import QtQuick
import "../theme"

Page {
    id: page
    name: "clipboard"
    count: ClipboardState.model.count

    function entryAt(i) { return i >= 0 && i < ClipboardState.model.count ? ClipboardState.model.get(i) : null }

    onActivateRequested: {
        var e = entryAt(listIndex)
        if (e) {
            ClipboardState.copy(e.id)
            ControlState.hide()
        }
    }
    onDeleteRequested: {
        var e = entryAt(listIndex)
        if (e) ClipboardState.remove(e.id)
    }

    onShownChanged: {
        if (shown) {
            search.text = ""
            ClipboardState.setFilter("")
            ClipboardState.refresh()
            Qt.callLater(function() { search.forceActiveFocus() })
        } else if (parent) {
            parent.forceActiveFocus()
        }
    }

    // search box
    Rectangle {
        id: searchBox
        anchors { left: parent.left; right: wipeButton.left; top: parent.top; leftMargin: Ui.sideMargin; rightMargin: 10; topMargin: Ui.bodyTop - 4 }
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
            onTextChanged: { ClipboardState.setFilter(text); page.listIndex = 0 }
            Keys.onPressed: function(event) { page.handleKey(event, true) }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search clipboard…"
                color: Colors.fg
                opacity: 0.35
                visible: search.text.length === 0
                font.pixelSize: 13
            }
        }
    }

    RoundButton {
        id: wipeButton
        anchors { right: parent.right; rightMargin: Ui.sideMargin; verticalCenter: searchBox.verticalCenter }
        width: 42
        height: 42
        radius: 21
        icon: "󰆴"
        onClicked: ClipboardState.wipe()
    }

    AnimatedList {
        id: list
        anchors { left: parent.left; right: parent.right; top: searchBox.bottom; bottom: parent.bottom; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: 8; bottomMargin: Ui.bottomMargin }
        pick: page.listIndex
        model: ClipboardState.model

        delegate: ListRow {
            required property string id
            required property string preview
            required property bool image
            required property int index

            width: list.width
            height: 44
            icon: image ? "󰋩" : "󰅌"
            title: preview
            subtitle: ""
            tag: image ? "Image" : ""
            picked: index === page.listIndex

            onEntered: page.listIndex = index
            onClicked: { ClipboardState.copy(id); ControlState.hide() }
            onRightClicked: ClipboardState.remove(id)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: ClipboardState.filter !== "" ? "No matches" : "Clipboard history is empty"
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
