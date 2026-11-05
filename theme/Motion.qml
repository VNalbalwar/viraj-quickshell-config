pragma Singleton
import Quickshell
import QtQuick

// One set of timings and springs for the whole shell, so everything moves like it belongs together.
//   quick   colour / hover changes          fast    presses, scale pops, small fades
//   base    fades, panel content            slide   things that travel (panels, pages, lists)
//   island  the notch growing / shrinking
//   pop     the springy overshoot used for presses and entrances (Easing.OutBack at `overshoot`)
//   settle  the gentle landing everything else uses (Easing.OutCubic)
Singleton {
    readonly property int quick: 120
    readonly property int fast: 160
    readonly property int base: 240
    readonly property int slide: 340
    readonly property int island: 500

    readonly property real overshoot: 2.0

    readonly property int settle: Easing.OutCubic
    readonly property int pop: Easing.OutBack
    readonly property int ease: Easing.InOutSine

    // the notch's own spring-like curve (slight overshoot, then rest)
    readonly property var islandCurve: [0.38, 1.21, 0.22, 1, 1, 1]
}
