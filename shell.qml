// shell.qml — root van de Quickshell-desktop (fase 2).
//
// Starten: qs -p /home/simon/projecten/quickshell
//
// Fase 2 levert een skelet met één bar per scherm, een thema-singleton dat
// ~/.config/bspwm/settings.json volgt, workspaces (nog statisch) en een klok.
// De BSPWM-koppeling volgt in fase 3.

import QtQuick
import Quickshell
import Quickshell.Io
import "src/components"

ShellRoot {
    id: root

    // Met IPC te schakelen (qs ipc call bar toggle).
    property bool barVisible: true

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {
                required property ShellScreen modelData
                screen: modelData
                shown: root.barVisible
            }
        }
    }

    IpcHandler {
        target: "bar"

        // Herlaadt de QML zonder het proces te herstarten.
        function reload(): void {
            Quickshell.reload(false)
        }

        // Verbergt of toont de bar op alle schermen.
        function toggle(): void {
            root.barVisible = !root.barVisible
        }
    }
}
