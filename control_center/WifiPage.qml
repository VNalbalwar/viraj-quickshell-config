import QtQuick
import "../theme"
import "../osd"

Page {
    id: page
    name: "wifi"
    count: ControlState.wifiModel.count

    function iconFor(strength) {
        return strength >= 75 ? "󰤨" : strength >= 50 ? "󰤥" : strength >= 25 ? "󰤢" : "󰤟"
    }

    onActivateRequested: {
        if (listIndex < ControlState.wifiModel.count) {
            var n = ControlState.wifiModel.get(listIndex)
            if (!n.active) ControlState.connectWifi(n.ssid)
        }
    }

    AnimatedList {
        id: list
        anchors { fill: parent; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop; bottomMargin: Ui.bottomMargin }
        pick: page.listIndex
        model: ControlState.wifiModel

        delegate: ListRow {
            required property string ssid
            required property bool active
            required property int strength
            required property bool secure
            required property int index

            width: list.width
            icon: page.iconFor(strength)
            title: ssid
            subtitle: active ? "Connected" : (secure ? "Secured" : "Open")
            tag: ControlState.wifiConnecting === ssid ? "Connecting…" : (secure ? "󰌾" : "")
            on: active
            picked: index === page.listIndex

            onEntered: page.listIndex = index
            onClicked: if (!active) ControlState.connectWifi(ssid)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: !OsdState.wifiEnabled ? "Wi-Fi is off" : (ControlState.wifiScanning ? "Scanning…" : "No networks found")
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
