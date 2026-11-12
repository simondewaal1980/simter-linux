// VolumeWidget.qml — volumewidget voor de bar (fase 9).
//
// Primair via Quickshell.Services.Pipewire: `Pipewire.defaultAudioSink`.
// Deze machine draait PulseAudio zonder PipeWire-daemon; daarom valt de widget
// terug op `pactl` (pulseaudio-utils). Zodra PipeWire wel beschikbaar is,
// schakelt hij automatisch naar de Pipewire-API en stopt het pollen.
//
// Linksklik = dempen/aanzetten, scrollen = ±5%. Het percentage staat ernaast;
// bij dempen wordt het icoon gedempt en toont de tekst "stil".

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../theme"

Item {
    id: root

    // --- Pipewire ---------------------------------------------------------

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool pipewireReady: Pipewire.ready
        && root.sink !== null && root.sink.audio !== null

    // Houdt de standaardsink vast zolang de widget bestaat.
    PwObjectTracker {
        objects: root.sink !== null ? [root.sink] : []
    }

    // --- PulseAudio-fallback ---------------------------------------------

    property int fallbackVolume: -1
    property bool fallbackMuted: false

    readonly property int volumePercent: root.pipewireReady
        ? Math.round((root.sink.audio.volume || 0) * 100)
        : root.fallbackVolume
    readonly property bool muted: root.pipewireReady
        ? root.sink.audio.muted === true
        : root.fallbackMuted
    readonly property bool available: root.pipewireReady
        || root.fallbackVolume >= 0

    readonly property string icon: {
        if (root.muted)
            return "\uf026" // volume-xmark
        if (root.volumePercent < 34)
            return "\uf027" // volume-low
        if (root.volumePercent < 67)
            return "\uf027"
        return "\uf028" // volume-high
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.widgetHeight
    visible: root.available

    function refreshFallback() {
        if (root.pipewireReady)
            return
        if (!volumeProcess.running)
            volumeProcess.running = true
        if (!muteProcess.running)
            muteProcess.running = true
    }

    function fallbackCommand(args) {
        if (fallbackCommandProcess.running)
            return
        fallbackCommandProcess.command = args
        fallbackCommandProcess.running = true
    }

    function toggleMute() {
        if (root.pipewireReady) {
            root.sink.audio.muted = !root.sink.audio.muted
            return
        }
        root.fallbackCommand(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
        fallbackRefreshTimer.restart()
    }

    function changeVolume(delta) {
        if (root.pipewireReady) {
            const next = Math.max(0, Math.min(1,
                (root.sink.audio.volume || 0) + delta * 0.05))
            root.sink.audio.volume = next
            return
        }
        const step = delta > 0 ? "+5%" : "-5%"
        root.fallbackCommand(["pactl", "set-sink-volume", "@DEFAULT_SINK@", step])
        fallbackRefreshTimer.restart()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.muted ? Theme.overlay0 : Theme.barMuted
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "stil" : root.volumePercent + "%"
            color: root.muted ? Theme.overlay0 : Theme.barMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleMute()
    }

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y > 0)
                root.changeVolume(1)
            else if (event.angleDelta.y < 0)
                root.changeVolume(-1)
        }
    }

    // --- Processen --------------------------------------------------------

    Timer {
        id: pollTimer
        interval: 1500
        repeat: true
        running: !root.pipewireReady
        onTriggered: root.refreshFallback()
    }

    Timer {
        id: fallbackRefreshTimer
        interval: 120
        repeat: false
        running: false
        onTriggered: root.refreshFallback()
    }

    Process {
        id: volumeProcess
        command: ["pactl", "get-sink-volume", "@DEFAULT_SINK@"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const match = text.match(/([0-9]+)%/)
                if (match)
                    root.fallbackVolume = parseInt(match[1], 10)
            }
        }
    }

    Process {
        id: muteProcess
        command: ["pactl", "get-sink-mute", "@DEFAULT_SINK@"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const match = text.match(/Mute:\s*(yes|no)/i)
                if (match)
                    root.fallbackMuted = match[1].toLowerCase() === "yes"
            }
        }
    }

    Process {
        id: fallbackCommandProcess

        onExited: root.fallbackRefreshTimer.restart()
    }

    Component.onCompleted: root.refreshFallback()
}
