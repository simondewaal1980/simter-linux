// shell.qml — root van de Quickshell-desktop (fase 3).
//
// Starten: qs -p /home/simon/projecten/quickshell
//
// Eén bar per scherm met live workspaces (Bspwm-service), layoutindicator,
// venstertitel en klok. De BSPWM-status komt uit `bspc subscribe report`.

import QtQuick
import Quickshell
import Quickshell.Io
import "src/components"
import "src/services"

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

    // Diagnostiek: qs ipc call bspwm status
    IpcHandler {
        target: "bspwm"

        function status(): string {
            return JSON.stringify({
                available: Bspwm.available,
                error: Bspwm.lastError,
                focusedMonitor: Bspwm.focusedMonitor,
                focusedDesktop: Bspwm.focusedDesktop,
                layout: Bspwm.layout,
                activeNodeState: Bspwm.activeNodeState,
                activeNodeFlags: Bspwm.activeNodeFlags,
                desktops: Bspwm.desktops
            })
        }
    }
}
