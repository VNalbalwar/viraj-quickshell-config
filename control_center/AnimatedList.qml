import QtQuick
import "../theme"

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
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.slide; easing.type: Motion.settle }
            NumberAnimation { property: "scale"; from: 0.82; to: 1; duration: Motion.slide; easing.type: Motion.pop; easing.overshoot: Motion.overshoot }
        }
    }

    populate: Transition {
        SequentialAnimation {
            PauseAnimation { duration: ViewTransition.index * 45 }
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.slide; easing.type: Motion.settle }
                NumberAnimation { property: "y"; from: ViewTransition.destination.y + 14; to: ViewTransition.destination.y; duration: Motion.slide; easing.type: Motion.settle }
            }
        }
    }

    remove: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.base; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; to: 0.85; duration: Motion.base; easing.type: Easing.InCubic }
        }
    }

    displaced: Transition {
        NumberAnimation { properties: "x,y"; duration: Motion.slide; easing.type: Motion.settle }
        NumberAnimation { property: "opacity"; to: 1; duration: 1 }
        NumberAnimation { property: "scale"; to: 1; duration: 1 }
    }
}
