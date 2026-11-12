// MprisWidget.qml — compacte MPRIS-speler in de bar (optioneel, fase 9).
//
// Toont de eerste speler met een nummer. Linksklik = play/pause, scrollen =
// volgende/vorige track. Zonder speler is de widget volledig onzichtbaar.

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    readonly property var players: Mpris.players.values

    readonly property var player: {
        for (var i = 0; i < root.players.length; i++) {
            const candidate = root.players[i]
            if (candidate && candidate.trackTitle
                    && candidate.trackTitle.length > 0)
                return candidate
        }
        return root.players.length > 0 ? root.players[0] : null
    }

    readonly property string title: root.player
        && root.player.trackTitle ? root.player.trackTitle : ""
    readonly property bool playing: root.player
        && root.player.isPlaying === true

    implicitWidth: content.implicitWidth
    implicitHeight: Theme.widgetHeight
    visible: root.player !== null && root.title.length > 0

    function togglePlaying() {
        if (root.player && root.player.canTogglePlaying)
            root.player.togglePlaying()
    }

    function next() {
        if (root.player && root.player.canGoNext)
            root.player.next()
    }

    function previous() {
        if (root.player && root.player.canGoPrevious)
            root.player.previous()
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.scaled(5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.playing ? "\uf04c" : "\uf04b" // pause / play
            color: Theme.accentMuted
            font.family: Theme.iconFamily
            font.pixelSize: Theme.fontSmall
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Theme.scaled(180), implicitWidth)
            text: root.title
            color: Theme.barMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePlaying()
    }

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y > 0)
                root.next()
            else if (event.angleDelta.y < 0)
                root.previous()
        }
    }
}
