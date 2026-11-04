import QtQuick

// ListView whose entries pop in (staggered on first open), shrink away when
// removed, and glide to their new spot when the list reorders.
ListView {
    id: list

    property int pick: 0

    spacing: 7
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: pick
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    add: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.82; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    populate: Transition {
        SequentialAnimation {
            PauseAnimation { duration: ViewTransition.index * 45 }
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: ViewTransition.destination.y + 14; to: ViewTransition.destination.y; duration: 340; easing.type: Easing.OutCubic }
            }
        }
    }

    remove: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; to: 0.85; duration: 200; easing.type: Easing.InCubic }
        }
    }

    displaced: Transition {
        NumberAnimation { properties: "x,y"; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { property: "opacity"; to: 1; duration: 1 }
        NumberAnimation { property: "scale"; to: 1; duration: 1 }
    }
}
