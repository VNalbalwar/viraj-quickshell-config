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
    // what is shown, in reading order: sender / subject, the message, then the small stuff
    readonly property var fmt: content !== null ? NotificationFormat.format(content) : null
    // a browser's own "Settings" button on every web notification is just noise
    readonly property var shownActions: content === null ? [] : content.actions.filter(function(a) {
        return a.identifier !== "default" && !(fmt && fmt.plain && /^settings$/i.test(a.text))
    })
    readonly property bool hasActions: n !== null && shownActions.length > 0
    readonly property int wantedHeight: 112 + (hasActions ? 44 : 0)
    readonly property int wantedWidth: 600

    // keep the last notification's content while the island is collapsing
    property var shownN: null
    onNChanged: if (n !== null) shownN = n

    readonly property var content: n !== null ? n : shownN

    visible: opacity > 0.01
    opacity: (n !== null && active) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    // a verified icon source, or "" (-> the bell glyph) - never somebody else's fallback logo
    function iconSource(notification) { return Icons.forNotification(notification) }


    // card background tap: run the default action and jump to the source window
    scale: bannerMouse.pressed ? 0.975 : 1.0
    Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2 } }

    MouseArea {
        id: bannerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // only real movement over the banner pauses it (a pointer merely resting where it appeared doesn't)
        onPositionChanged: NotificationState.hovering = true
        onExited: NotificationState.hovering = false
        onClicked: NotificationState.activate()
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
                anchors { fill: parent; margins: (!iconImage.siteLogo && banner.content && banner.content.image !== "") ? 0 : 7 }
                // a known site's own logo (WhatsApp, Outlook...) beats the generic picture the browser sends
                readonly property bool siteLogo: banner.fmt !== null && banner.fmt.icon !== ""
                source: siteLogo ? banner.fmt.icon : banner.iconSource(banner.content)
                fillMode: !siteLogo && banner.content && banner.content.image !== "" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
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

    // text: small label (app / site · chat), then the sender or subject, then the message
    Column {
        anchors { left: iconBox.right; leftMargin: 16; right: closeButton.left; rightMargin: 12; top: iconBox.top; topMargin: -2 }
        spacing: 3

        Text {
            width: parent.width
            text: banner.fmt ? banner.fmt.label : ""
            color: Colors.grey2
            elide: Text.ElideRight
            font { pixelSize: 10; weight: Font.Medium; capitalization: Font.AllUppercase; letterSpacing: 0.6 }
        }

        Text {
            width: parent.width
            text: banner.fmt ? banner.fmt.title : ""
            color: Colors.fg
            elide: Text.ElideRight
            maximumLineCount: 1
            font { pixelSize: 15; weight: Font.DemiBold }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: banner.fmt ? banner.fmt.body : ""
            textFormat: banner.fmt && banner.fmt.plain ? Text.PlainText : Text.StyledText
            color: Colors.fg
            opacity: 0.8
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            lineHeight: 1.1
            font.pixelSize: 13
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
        anchors { left: iconBox.right; leftMargin: 16; bottom: parent.bottom; bottomMargin: 22 }
        spacing: 8

        Repeater {
            model: banner.shownActions

            delegate: Rectangle {
                required property var modelData

                visible: true
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

    // time-left bar along the bottom edge (not for critical, which stays).
    // Its width is a fraction of a track that always matches the banner's CURRENT width, so it can never
    // overflow while the island is still growing / shrinking (a fixed start width used to).
    Item {
        id: timeTrack
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 34; rightMargin: 34; bottomMargin: 9 }
        height: 3
        clip: true
        visible: banner.n !== null && NotificationState.bannerDuration > 0

        // exactly what the clock has left (1 -> 0)
        readonly property real remaining: NotificationState.bannerDuration > 0 ? NotificationState.bannerRemaining / NotificationState.bannerDuration : 1

        Rectangle {
            width: Math.max(0, Math.min(1, timeTrack.remaining)) * parent.width
            height: parent.height
            radius: 1.5
            color: Colors.alpha(Colors.colBlue, 0.55)
        }

    }
}
