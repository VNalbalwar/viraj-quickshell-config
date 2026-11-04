import QtQuick
import "../theme"

Page {
    id: page
    name: "bluetooth"
    count: ControlState.btModel.count

    onActivateRequested: {
        if (listIndex < ControlState.btModel.count)
            ControlState.activateBluetoothDevice(ControlState.btByAddress[ControlState.btModel.get(listIndex).address])
    }

    AnimatedList {
        id: list
        anchors { fill: parent; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop; bottomMargin: Ui.bottomMargin }
        pick: page.listIndex
        model: ControlState.btModel

        delegate: ListRow {
            required property string address
            required property int index

            readonly property var dev: ControlState.btByAddress[address]

            width: list.width
            icon: dev && dev.connected ? "󰂱" : "󰂯"
            title: dev ? (dev.name || dev.deviceName) : ""
            subtitle: dev ? (dev.connected ? "Connected" : (dev.paired ? "Paired" : "Available")) : ""
            tag: dev && dev.batteryAvailable ? Math.round(dev.battery * 100) + "%" : ""
            on: dev ? dev.connected : false
            picked: index === page.listIndex

            onEntered: page.listIndex = index
            onClicked: ControlState.activateBluetoothDevice(dev)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: !ControlState.bluetoothEnabled ? "Bluetooth is off" : "Searching for devices…"
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
