import QtQuick
import "../theme"

// A month you can page through, and the next events from your iCal feed (see agenda.py).
Page {
    id: page
    name: "calendar"

    property int offset: 0                         // months from this one
    readonly property date today: new Date()
    readonly property date viewDate: new Date(today.getFullYear(), today.getMonth() + offset, 1)   // (not `shown`: that is the Page's own open/closed flag)
    readonly property int firstCol: (viewDate.getDay() + 6) % 7                       // Monday first
    readonly property int daysIn: new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0).getDate()

    onShownChanged: if (shown) { offset = 0; CalendarState.refresh() }

    Keys.onPressed: function(event) { }

    function whenText(e) {
        var d = new Date(e.start)
        var day = Qt.formatDate(d, "ddd d MMM")
        var isToday = d.toDateString() === new Date().toDateString()
        var tomorrow = d.toDateString() === new Date(Date.now() + 86400000).toDateString()
        var label = isToday ? "Today" : tomorrow ? "Tomorrow" : day
        return e.allDay ? label : label + " · " + Qt.formatTime(d, "hh:mm")
    }

    // month
    Item {
        id: month
        x: Ui.sideMargin
        y: Ui.bodyTop - 6
        width: 300
        height: page.height - y - Ui.bottomMargin

        Row {
            width: parent.width
            height: 30
            Rectangle {
                width: 30; height: 30; radius: 15
                color: prevHover.hovered ? Colors.alpha(Colors.colFg, 0.12) : "transparent"
                HoverHandler { id: prevHover }
                Text { anchors.centerIn: parent; text: "‹"; color: Colors.fg; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: page.offset-- }
            }
            Text {
                width: parent.width - 60
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(page.viewDate, "MMMM yyyy")
                color: Colors.fg
                font { pixelSize: 14; weight: Font.DemiBold }
            }
            Rectangle {
                width: 30; height: 30; radius: 15
                color: nextHover.hovered ? Colors.alpha(Colors.colFg, 0.12) : "transparent"
                HoverHandler { id: nextHover }
                Text { anchors.centerIn: parent; text: "›"; color: Colors.fg; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: page.offset++ }
            }
        }

        Grid {
            y: 36
            columns: 7
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Text { width: 300 / 7; horizontalAlignment: Text.AlignHCenter; text: modelData; color: Colors.grey2; font { pixelSize: 11; weight: Font.Medium } }
            }
        }

        Grid {
            y: 58
            columns: 7
            Repeater {
                model: 42
                Item {
                    readonly property int day: index - page.firstCol + 1
                    readonly property bool inMonth: day >= 1 && day <= page.daysIn
                    readonly property bool isToday: inMonth && page.offset === 0 && day === page.today.getDate()
                    width: 300 / 7
                    height: 31
                    Rectangle {
                        anchors.centerIn: parent
                        width: 27; height: 27; radius: 14
                        color: isToday ? Colors.colBlue : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.base } }
                        Text {
                            anchors.centerIn: parent
                            text: inMonth ? day : ""
                            color: isToday ? Colors.colBg : Colors.fg
                            opacity: inMonth ? 1 : 0
                            font { pixelSize: 12; weight: isToday ? Font.DemiBold : Font.Normal }
                        }
                    }
                }
            }
        }
    }

    // agenda
    Item {
        x: Ui.sideMargin + 330
        y: Ui.bodyTop - 6
        width: page.width - x - Ui.sideMargin
        height: page.height - y - Ui.bottomMargin

        Text {
            id: agendaTitle
            text: "Next up"
            color: Colors.fg
            font { pixelSize: 14; weight: Font.DemiBold }
        }

        ListView {
            anchors { left: parent.left; right: parent.right; top: agendaTitle.bottom; topMargin: 10; bottom: parent.bottom }
            spacing: 6
            clip: true
            model: CalendarState.events
            visible: CalendarState.configured && CalendarState.events.length > 0
            delegate: Rectangle {
                width: ListView.view.width
                height: 40
                radius: 13
                color: Colors.alpha(Colors.colFg, 0.055)
                Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 22; radius: 2; color: Colors.colBlue }
                Column {
                    anchors { left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    Text { width: parent.width; text: modelData.title; color: Colors.fg; elide: Text.ElideRight; font { pixelSize: 12; weight: Font.DemiBold } }
                    Text { text: page.whenText(modelData); color: Colors.grey2; font.pixelSize: 10 }
                }
            }
        }

        Text {
            anchors { left: parent.left; right: parent.right; top: agendaTitle.bottom; topMargin: 14 }
            visible: !CalendarState.configured || CalendarState.events.length === 0
            wrapMode: Text.WordWrap
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 12
            text: !CalendarState.configured
                ? "To see events here, put your calendar's iCal address in ~/.config/qs-calendar.url\n\nGoogle Calendar: Settings → your calendar → \"Secret address in iCal format\"."
                : "Nothing coming up in the next 45 days."
        }
    }
}
