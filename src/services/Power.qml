pragma Singleton

// Power.qml — sessieacties voor het powermenu in de bar.
//
// Alle acties starten losgekoppeld van de shell (Quickshell.execDetached),
// zodat afmelden, opschorten en afsluiten niet stranden wanneer deze
// Quickshell-instantie stopt. Vergrendelen delegeert naar
// scripts/lock-session.sh, zodat de locker-detectie en de melding bij een
// ontbrekende locker op één plek blijven.
//
// De standaardpaden volgen de deployment uit de README
// (~/projecten/quickshell). Met QS_LOCK_SCRIPT is het lockscript te
// overschrijven, bijvoorbeeld in een testomgeving.

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string lockScript: {
        const override = Quickshell.env("QS_LOCK_SCRIPT")
        if (override && override.length > 0)
            return override
        return Quickshell.env("HOME") + "/projecten/quickshell/scripts/lock-session.sh"
    }

    // Laatste actie, alleen voor diagnostiek via `qs ipc call power status`.
    property string lastAction: ""

    function run(command) {
        Quickshell.execDetached(command)
    }

    function lock() {
        root.lastAction = "Vergrendelen"
        root.run([root.lockScript])
    }

    function logout() {
        root.lastAction = "Afmelden"
        root.run(["bspc", "quit"])
    }

    function sleep() {
        root.lastAction = "Slapen"
        root.run(["systemctl", "suspend"])
    }

    function shutdown() {
        root.lastAction = "Afsluiten"
        root.run(["systemctl", "poweroff"])
    }
}
