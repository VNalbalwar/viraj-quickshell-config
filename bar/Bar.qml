import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "../theme"

PanelWindow {
    property var screen

    anchors {
        top: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitHeight: 160

    mask: Region {
        item: island
    }

    readonly property var mediaPlayer: {
        for (var i = 0; i < Mpris.players.values.length