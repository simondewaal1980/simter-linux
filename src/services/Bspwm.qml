pragma Singleton

// Bspwm.qml — live BSPWM-status voor de bar.
//
// Eén abonnement op `bspc subscribe report` levert elke wijziging als één
// regel; ReportParser.js zet die om naar monitors, desktops, layout en de
// status van de gefocuste node. `bspc wm -g` levert de beginstatus.
//
// Verdwijnt bspwm (of de socket, bijvoorbeeld na `bspc wm -r`), dan probeert
// de service elke vijf seconden opnieuw verbinding te maken. In de tussentijd
// blijft de bar bruikbaar: Workspaces toont dan een terugvalrij van 1–9.

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/ReportParser.js" as ReportParser

Singleton {
    id: root

    // --- Status -----------------------------------------------------------

    property bool available: false
    property string lastError: ""

    property var monitors: []
    property var desktops: []

    property string focusedMonitor: ""
    property string focusedDesktop: ""
    property string layout: "tiled"

    property string activeNodeState: ""
    property var activeNodeFlags: ReportParser.emptyFlags()

    readonly property bool hasActiveNode: root.activeNodeState !== ""
    readonly property bool monocle: root.layout === "monocle"

    readonly property var focusedMonitorData: {
        for (var i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].name === root.focusedMonitor)
                return root.monitors[i]
        }
        return root.monitors.length > 0 ? root.monitors[0] : null
    }

    // --- Rapportverwerking ------------------------------------------------

    function applyReport(report) {
        var parsed = ReportParser.parseReport(report)
        if (parsed.monitors.length === 0)
            return

        root.monitors = parsed.monitors
        root.desktops = parsed.desktops
        root.focusedMonitor = parsed.focusedMonitor
        root.focusedDesktop = parsed.focusedDesktop
        root.layout = parsed.layout
        root.activeNodeState = parsed.activeNodeState
        root.activeNodeFlags = parsed.activeNodeFlags
        root.available = true
        root.lastError = ""
        retryTimer.stop()
    }

    function markUnavailable(message) {
        root.available = false
        root.lastError = message
        if (!retryTimer.running)
            retryTimer.start()
    }

    // --- Helpers voor de bar ---------------------------------------------

    function desktopsForMonitor(monitorName) {
        for (var i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].name === monitorName)
                return root.monitors[i].desktops
        }

        var focused = root.focusedMonitorData
        if (focused !== null)
            return focused.desktops
        return []
    }

    function layoutForMonitor(monitorName) {
        for (var i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].name === monitorName)
                return root.monitors[i].layout
        }
        return root.layout
    }

    // --- Commando's -------------------------------------------------------

    function runBspc(args) {
        try {
            commandProcess.exec(args)
        } catch (error) {
            root.markUnavailable("bspwm niet actief")
        }
    }

    // Klik op een workspace: bij voorkeur de n-de desktop van die monitor
    // (`monitor:^n`), zodat ook hernoemde of dubbel voorkomende namen werken.
    function focusDesktop(name, monitorName, index) {
        if (monitorName && monitorName.length > 0 && index !== undefined && index >= 0) {
            root.runBspc(["bspc", "desktop", "-f", monitorName + ":^" + (index + 1)])
            return
        }
        if (!name || name.length === 0)
            return
        root.runBspc(["bspc", "desktop", "-f", name])
    }

    function focusNext() {
        if (!root.available)
            return
        root.runBspc(["bspc", "desktop", "-f", "next"])
    }

    function focusPrev() {
        if (!root.available)
            return
        root.runBspc(["bspc", "desktop", "-f", "prev"])
    }

    function toggleLayout() {
        if (!root.available)
            return
        root.runBspc(["bspc", "desktop", "-l", "next"])
    }

    // --- Processen --------------------------------------------------------

    // Korte commando's (desktopfocus, layout) via één herbruikbaar proces.
    Process {
        id: commandProcess

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "bspc-commando mislukt (" + exitCode + ")"
        }
    }

    // Beginstatus: bspc wm -g levert precies één rapportregel.
    Process {
        id: probeProcess
        command: ["bspc", "wm", "-g"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyReport(text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.markUnavailable("bspwm niet actief")
        }
    }

    // Live updates: één regel per wijziging.
    Process {
        id: subscribeProcess
        command: ["bspc", "subscribe", "report"]

        stdout: SplitParser {
            onRead: (line) => root.applyReport(line)
        }

        onExited: (exitCode) => {
            root.markUnavailable("bspwm niet actief")
        }
    }

    Timer {
        id: retryTimer
        interval: 5000
        repeat: true
        running: false

        onTriggered: {
            if (!root.available) {
                if (!probeProcess.running)
                    probeProcess.running = true
                if (!subscribeProcess.running)
                    subscribeProcess.running = true
            }
        }
    }

    Component.onCompleted: {
        probeProcess.running = true
        subscribeProcess.running = true
    }
}
