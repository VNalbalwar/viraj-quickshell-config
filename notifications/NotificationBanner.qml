import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import "../theme"

// The notification banner that lives INSIDE the notch. Bar.qml sizes the island
// to wantedHeight while a banner is showing.
Item {
    id: banner

    // false while another panel (control center, menus) owns the island
    property bool active: true

    readonly property var n: NotificationState.banner
    readonly property bool critical: n !== null && n.urgency === NotificationUrgency.Critical
    readonly property bool hasActions: n !== null && n.actions.length > 0
    readonly property int wantedHeight: 92 + (hasActions ? 46 : 0)
    readonly property int wantedWidth: 600

    // keep the last notification's content while the island is collapsing
    property var shownN: null
    onNChanged: if (n !== null) shownN = n

    readonly property var content: n !== null ? n : shownN

    visible: opacity > 0.01
    opacity: (n !== null && active) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    function iconSource(notification) {
        if (!notification) return ""
        if (notification.image && notification.image !== "") return notification.image
        var icon = notification.appIcon
        if (!icon || icon === "") return ""
        return icon.indexOf("/") === 0 ? "file://" + icon : "image://icon/" + icon
    }

    HoverHandler {
        onHoveredChanged: NotificationState.hovering = hovered
    }

    // card background tap: default action if the app provided one, else dismiss
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var n = banner.n
            if (!n) return
            for (var i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === "default") {
                    NotificationState.invokeAction(n.actions[i])
                    return
                }
            }
            NotificationState.closeBanner(true)
        }
    }

    // app icon / image
    Rectangle {
        id: iconBox
        anchors { left: parent.left; leftMargin: 26; top: parent.top; topMargin: 22 }
        width: 48
        height: 48
        radius: 14
        color: Colors.alpha(banner.critical ? "#ff6b6b" : Colors.colFg, banner.critical ? 0.20 : 0.07)

        ClippingRectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            Image {
                id: iconImage
                anchors { fill: parent; margins: banner.content && banner.content.image !== "" ? 0 : 7 }
                source: banner.iconSource(banner.content)
                fillMode: banner.content && banner.content.image !== "" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                visible: status === Image.Ready
            }
        }

        Text {
            anchors.centerIn: parent
            visible: iconImage.status !== Image.Ready
            text: banner.critical ? "󰂞" : "󰂚"
            color: banner.critical ? "#ff6b6b" : Colors.fg
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 22 }
        }
    }

    // text
    Column {
        anchors { left: iconBox.right; leftMargin: 16; right: closeButton.left; rightMargin: 10; top: iconBox.top }
        spacing: 2

        Text {
            width: parent.width
            text: banner.content ? banner.content.appName : ""
            color: Colors.grey2
            elide: Text.ElideRight
            font { pixelSize: 10; weight: Font.Medium; capitalization: Font.AllUppercase; letterSpacing: 0.6 }
        }

        Text {
            width: parent.width
            text: banner.content ? banner.content.summary : ""
            color: Colors.fg
            elide: Text.ElideRight
            font { pixelSize: 15; weight: Font.DemiBold }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: banner.content ? banner.content.body : ""
            textFormat: Text.StyledText
            color: Colors.fg
            opacity: 0.7
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            font.pixelSize: 12
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
    }

    // close
    Rectangle {
        id: closeButton
        anchors { right: parent.right; rightMargin: 22; top: parent.top; topMargin: 20 }
        width: 26
        height: 26
        radius: 13
        color: closeMouse.containsMouse ? Colors.alpha(Colors.colFg, 0.18) : Colors.alpha(Colors.colFg, 0.07)
        scale: closeMouse.pressed ? 0.85 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: Colors.fg
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationState.closeBanner(true)
        }
    }

    // actions
    Row {
        id: actionRow
        visible: banner.hasActions
        anchors { left: iconBox.right; leftMargin: 16; bottom: parent.bottom; bottomMargin: 16 }
        spacing: 8

        Repeater {
            model: banner.content ? banner.content.actions : []

            delegate: Rectangle {
                required property var modelData

                visible: modelData.identifier !== "default"
                width: visible ? Math.max(72, actionLabel.implicitWidth + 28) : 0
                height: 30
                radius: 15
                color: actionMouse.containsMouse ? Colors.alpha(Colors.colBlue, 0.45) : Colors.alpha(Colors.colBlue, 0.28)
                scale: actionMouse.pressed ? 0.92 : 1.0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: modelData.text
                    color: Colors.fg
                    font { pixelSize: 12; weight: Font.DemiBold }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationState.invokeAction(modelData)
                }
            }
        }
    }

    // time-left bar along the bottom edge (not for critical, which stays)
    Rectangle {
        id: timeBar
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 34; bottomMargin: 8 }
        height: 3
        radius: 1.5
        color: Colors.alpha(Colors.colBlue, 0.55)
        visible: banner.n !== null && NotificationState.bannerDuration > 0

        NumberAnimation {
            id: drain
            target: timeBar
            property: "width"
            from: banner.width - 68
            to: 0
            duration: NotificationState.bannerDuration
            running: banner.n !== null && NotificationState.bannerDuration > 0
            paused: NotificationState.hovering
        }

        Connections {
            target: NotificationState
            function onBannerChanged() { if (NotificationState.banner !== null) drain.restart() }
        }
    }
}
