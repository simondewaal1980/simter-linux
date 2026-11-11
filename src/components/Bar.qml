// Bar.qml — de bovenbalk, één instantie per scherm.
//
// De bar reserveert ruimte via EWMH-struts. In Quickshell 0.3.2 gebeurt dat
// automatisch met ExclusionMode.Auto: bij drie ankers (top/left/right) wordt
// precies de hoogte van het venster gereserveerd.

import QtQuick
import Quickshell
import "../theme"

PanelWindow {
    id: bar

    // Van buitenaf te schakelen via de IPC-handler in shell.qml.
    property bool shown: true

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    exclusionMode: ExclusionMode.Auto
    aboveWindows: true
    focusable: false
    visible: bar.shown

    Rectangle {
        id: background
        anchors.fill: parent
        color: Theme.barBackground

        // Subtiele rand onder de bar, in dezelfde kleur als normale
        // BSPWM-vensterranden.
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.borderNormal
        }

        // Links: workspaces (fase 2 nog statisch; fase 3 koppelt BSPWM).
        Workspaces {
            id: workspaces
            anchors {
                left: parent.left
                leftMargin: Theme.barPadding
                verticalCenter: parent.verticalCenter
            }
        }

        // Midden: tijd en datum.
        Clock {
            anchors.centerIn: parent
        }

        // Rechts: tijdelijke iconen. Volume, netwerk en accu krijgen in latere
        // fasen een echte widget (tray in fase 5, volume/accu in fase 9).
        Row {
            anchors {
                right: parent.right
                rightMargin: Theme.barPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf028" // volume-high
                color: Theme.barMuted
                font.family: Theme.iconFamily
                font.pixelSize: Theme.iconSize
                opacity: 0.55
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf1eb" // wifi
                color: Theme.barMuted
                font.family: Theme.iconFamily
                font.pixelSize: Theme.iconSize
                opacity: 0.55
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf240" // battery-full
                color: Theme.barMuted
                font.family: Theme.iconFamily
                font.pixelSize: Theme.iconSize
                opacity: 0.55
            }
        }
    }
}
