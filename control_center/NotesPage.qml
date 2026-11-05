import QtQuick
import "../theme"

// To-dos (left) and a scratch note (right). Enter adds / ticks, Delete removes.
Page {
    id: page
    name: "notes"
    count: NotesState.todos.count

    onActivateRequested: if (listIndex < NotesState.todos.count) NotesState.toggle(listIndex)
    onDeleteRequested: if (listIndex < NotesState.todos.count) NotesState.remove(listIndex)

    onShownChanged: {
        if (shown) { input.text = ""; Qt.callLater(function() { input.forceActiveFocus() }) }
        else if (parent) parent.forceActiveFocus()
    }

    readonly property real colW: (width - Ui.sideMargin * 2 - 16) / 2

    // to-dos
    Rectangle {
        id: inputBox
        x: Ui.sideMargin
        y: Ui.bodyTop - 4
        width: page.colW
        height: 42
        radius: 15
        color: Colors.alpha(Colors.colFg, 0.06)

        Text {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: "+"
            color: Colors.fg
            opacity: 0.5
            font { pixelSize: 18; weight: Font.DemiBold }
        }
        TextInput {
            id: input
            anchors { left: parent.left; right: parent.right; leftMargin: 40; rightMargin: 14; verticalCenter: parent.verticalCenter }
            color: Colors.fg
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {     // add it - and don't let Enter also tick a row
                    NotesState.add(text); text = ""; event.accepted = true; return
                }
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Escape) page.handleKey(event, true)
                else if (event.key === Qt.Key_Delete && text === "") page.handleKey(event, true)
            }
            Text { visible: input.text === "" ; text: "Add a to-do…"; color: Colors.fg; opacity: 0.35; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    AnimatedList {
        id: list
        x: Ui.sideMargin
        y: Ui.bodyTop + 50
        width: page.colW
        height: page.height - y - Ui.bottomMargin
        pick: page.listIndex
        model: NotesState.todos

        delegate: ListRow {
            required property string text
            required property bool done
            required property int index
            width: list.width
            height: 42
            icon: done ? "󰄲" : "󰄱"
            title: text
            subtitle: ""
            tag: ""
            on: done
            picked: index === page.listIndex
            opacity: done ? 0.55 : 1
            onEntered: page.listIndex = index
            onClicked: NotesState.toggle(index)
            onRightClicked: NotesState.remove(index)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "Nothing to do"
            color: Colors.fg
            opacity: 0.4
            font.pixelSize: 13
        }
    }

    // scratch note
    Rectangle {
        x: Ui.sideMargin + page.colW + 16
        y: Ui.bodyTop - 4
        width: page.colW
        height: page.height - y - Ui.bottomMargin
        radius: 18
        color: Colors.alpha(Colors.colFg, 0.05)

        Flickable {
            anchors { fill: parent; margins: 14 }
            contentHeight: note.paintedHeight + 8
            clip: true
            TextEdit {
                id: note
                width: parent.width
                text: NotesState.note
                color: Colors.fg
                font.pixelSize: 13
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                onTextChanged: if (activeFocus) NotesState.setNote(text)
                Text { visible: note.text === "" && !note.activeFocus; text: "Scratch note - click and type"; color: Colors.fg; opacity: 0.35; font.pixelSize: 13 }
            }
        }
    }
}
