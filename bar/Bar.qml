import Quickshell
import QtQuick
import "../theme"

PanelWindow{
    property var screen
    
    anchors {
        top: true;
        left: true;
        right: true;
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitHeight: 160

    mask: Region {item: island}

    Rectangle{
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        clip: true

        property bool expanded: hover.hovered

        implicitWidth: expanded ? 340: 150
        implicitHeight: expanded ? 120: 34
        radius: Math.min(height / 2, 26)
        color: Colors.colBg

        Behavior on implicitWidth { NumberAnimation { duration: 500; easing.type: Easing.Bezier; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1 ] } }
        Behavior on implicitHeight { NumberAnimation { duration: 500; easing.type: Easing.Bezier; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1 ] } }

        HoverHandler { id: hover}

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text{
            anchors.centerIn: parent
            opacity: island.expanded ? 0 : 1
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Colors.colFg
            font { pixelSize: 14; weight: 600 }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Column{
            anchors.centerIn: parent
            spacing: 2
            opacity: island.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.Bezier; easing.bezierCurve: [0.34, 0.8, 0.34, 1, 1, 1 ] } }

            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "hh:mm"); color: Colors.colFg; font { pixelSize: 26; weight: 600 } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "dddd, MMMM d"); color: Colors.colBrightBlack; font.pixelSize: 13}
        }
    }
}
