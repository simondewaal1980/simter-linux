// ActiveWindow.qml — titel van het gefocuste venster (optioneel balelement).
//
// De titel wordt opgehaald met xdotool en ververst bij elke `node_focus`-
// gebeurtenis van bspwm. Een extra poll van vijf seconden vangt titel-
// wijzigingen binnen hetzelfde venster op (bspwm kent geen title-event).
//
// Zonder bspwm of zonder actief venster blijft het element onzichtbaar; de
// rest van de bar blijft gewoon werken.

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

Item {
    id: root

    property string title: ""
    property int maxWidth: Theme.scaled(340)

    visible: root.title.length > 0
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    clip: true

    // De titel hoort bij de gefocuste node van bspwm, niet bij het X-venster
    // dat toevallig de inputfocus heeft (dat blijft op een verborgen venster
    // staan als je naar een lege desktop wisselt). Daarom eerst de node-id
    // opvragen en pas daarna de titel.
    function refresh() {
        if (!Bspwm.available) {
            titleFetch.exec(["xdotool", "getactivewindow", "getwindowname"])
            return
        }
        nodeQuery.exec(["bspc", "query", "-N", "-n", "focused"])
    }

    TextMetrics {
        id: metrics
        font: label.font
        text: root.title
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.scaled(6)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf2d0" // window-maximize
            color: Theme.barMuted
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
            opacity: 0.7
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(metrics.width, root.maxWidth)
            text: root.title
            elide: Text.ElideRight
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
        }
    }

    // Stap 1: welke node is op dit moment gefocust?
    Process {
        id: nodeQuery
        command: ["bspc", "query", "-N", "-n", "focused"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var id = text.trim()
                if (id.length === 0) {
                    root.title = ""
                    return
                }
                titleFetch.exec(["xdotool", "getwindowname", id])
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.title = ""
        }
    }

    // Stap 2: titel van die node (of van het actieve X-venster zonder bspwm).
    Process {
        id: titleFetch
        command: ["xdotool", "getactivewindow", "getwindowname"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.title = text.trim()
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.title = ""
        }
    }

    // Direct verversen zodra de focus naar een ander venster of desktop gaat.
    Process {
        id: focusWatcher
        command: ["bspc", "subscribe", "node_focus"]

        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }

        onExited: (exitCode) => reconnectTimer.start()
    }

    Timer {
        id: reconnectTimer
        interval: 5000
        repeat: false

        onTriggered: {
            if (!focusWatcher.running)
                focusWatcher.running = true
        }
    }

    // Vangt titelwijzigingen op zonder dat de focus verspringt.
    Timer {
        id: pollTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Bspwm

        function onFocusedDesktopChanged() {
            root.refresh()
        }
    }

    Component.onCompleted: {
        focusWatcher.running = true
        root.refresh()
    }
}
