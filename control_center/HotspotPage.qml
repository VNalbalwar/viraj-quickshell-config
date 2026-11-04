import QtQuick
import "../theme"
import "../osd"

// Hotspot details: name + password (tap to copy) and who's connected.
Page {
    id: page
    name: "hotspot"
    count: 3

    readonly property var rows: [
        { icon: "󰀃", title: HotspotState.ssid, subtitle: "Network name · tap to copy", tag: "", copy: HotspotState.ssid },
        { icon: "󰌾", title: HotspotState.password, subtitle: "Password · tap to copy", tag: "", copy: HotspotState.password },
        { icon: "󰂯", title: HotspotState.clients + (HotspotState.clients === 1 ? " device connected" : " devices connected"),
          subtitle: HotspotState.active
              ? "Sharing your Wi-Fi on channel " + HotspotState.channel
              : "Off · turn it on with the switch (stays on your channel)",
          tag: "", copy: "" }
    ]

    onActivateRequested: {
        var r = rows[listIndex]
        if (r && r.copy !== "") HotspotState.copy(r.copy)
    }

    onShownChanged: if (shown) HotspotState.refresh()

    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop }
        spacing: 8

        Repeater {
            model: page.rows

            delegate: ListRow {
                required property var modelData
                required property int index

                width: parent.width
                icon: modelData.icon
                title: modelData.title
                subtitle: modelData.subtitle
                tag: modelData.tag
                on: index === 2 && HotspotState.active
                picked: index === page.listIndex

                onEntered: page.listIndex = index
                onClicked: if (modelData.copy !== "") HotspotState.copy(modelData.copy)
            }
        }

        Text {
            width: parent.width
            text: "Runs next to your Wi-Fi on a virtual interface, so you stay connected. Both share one channel."
            color: Colors.fg
            opacity: 0.4
            wrapMode: Text.WordWrap
            font.pixelSize: 10
        }
    }
}
