import QtQuick
import "../theme"
import "../notifications"

// Notification history (everything the notch's notification daemon received).
Page {
    id: page
    name: "notifications"
    count: NotificationState.history.count

    onShownChanged: if (shown) NotificationState.markRead()

    onDeleteRequested: NotificationState.removeFromHistory(listIndex)
    onActivateRequested: {
        if (listIndex >= count) return
        var e = NotificationState.history.get(listIndex)
        var file = NotificationState.capturePath(e.app, e.body, e.icon)
        if (file !== "") NotificationState.reveal(file)
        else NotificationState.focusSource(e.app, e.entry)
        NotificationState.removeFromHistory(listIndex)
        ControlState.hide()
    }

    RoundButton {
        anchors { right: parent.right; rightMargin: Ui.sideMargin; top: parent.top; topMargin: 16 }
        icon: "󰆴"
        onClicked: NotificationState.clearHistory()
    }

    AnimatedList {
        id: list
        anchors { fill: parent; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop; bottomMargin: Ui.bottomMargin }
        pick: page.listIndex
        model: NotificationState.history

        delegate: ListRow {
            required property string nid
            required property string app
            required property string summary
            required property string body
            required property string entry
            required property string icon
            required property real time
            required property int urgency
            required property int index

            width: list.width
            icon: urgency === 2 ? "󰂞" : "󰂚"
            // same cleanup as the banner: sender / subject first, the message, the site as a label
            readonly property var fmt: NotificationFormat.format({ appName: app, summary: summary, body: body })
            title: fmt.title !== "" ? fmt.title : app
            subtitle: fmt.label + (fmt.body !== "" ? "  ·  " + fmt.body.replace(/\s+/g, " ") : "")
            tag: NotificationState.ago(time)
            on: urgency === 2
            picked: index === page.listIndex

            onEntered: page.listIndex = index
            onClicked: {
                var file = NotificationState.capturePath(app, body, icon)
                if (file !== "") NotificationState.reveal(file)
                else NotificationState.focusSource(app, entry)
                NotificationState.removeFromHistory(index)
                ControlState.hide()
            }
            onRightClicked: NotificationState.removeFromHistory(index)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "No notifications"
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
