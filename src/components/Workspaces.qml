// Workspaces.qml — live workspace-indicator voor de bar.
//
// De gegevens komen uit de Bspwm-service (één `bspc subscribe report` voor de
// hele shell). Tot die service een rapport heeft ontvangen — bijvoorbeeld in
// een LXQt-sessie zonder bspwm — toont de component een terugvalrij 1–9, zodat
// de bar ook zonder window manager bruikbaar blijft.
//
// Klikken focust de desktop; scrollen gaat naar de vorige/volgende desktop.
// Rechts van de workspaces staat de layoutindicator (T = tiled, M = monocle);
// die is ook klikbaar om te wisselen. Zonder bspwm verschijnt een foutlabel.

import QtQuick
import "../theme"
import "../services"

Row {
    id: root

    // Naam van de monitor waar deze bar bij hoort (ShellScreen.name).
    property string monitorName: ""

    spacing: Theme.spacingSmall

    readonly property var desktops: {
        if (!Bspwm.available)
            return root.fallbackDesktops()

        var list = Bspwm.desktopsForMonitor(root.monitorName)
        return list.length > 0 ? list : root.fallbackDesktops()
    }

    function fallbackDesktops() {
        var result = []
        for (var i = 0; i < 9; i++) {
            result.push({
                name: String(i + 1),
                monitor: "",
                focused: i === 0,
                occupied: false,
                urgent: false
            })
        }
        return result
    }

    // Scrollen over de workspaces wisselt van desktop.
    WheelHandler {
        enabled: Bspwm.available

        onWheel: (event) => {
            if (event.angleDelta.y > 0)
                Bspwm.focusPrev()
            else if (event.angleDelta.y < 0)
                Bspwm.focusNext()
        }
    }

    Repeater {
        model: root.desktops

        delegate: Rectangle {
            id: item

            required property var modelData
            required property int index

            readonly property bool isFocused: modelData.focused === true
            readonly property bool isOccupied: modelData.occupied === true
            readonly property bool isUrgent: modelData.urgent === true

            width: Theme.workspaceWidth
            height: Theme.widgetHeight
            radius: Theme.radiusSmall

            color: {
                if (isUrgent)
                    return Theme.urgent
                if (isFocused)
                    return Theme.accent
                if (isOccupied)
                    return Theme.surface0
                return hoverArea.containsMouse ? Theme.surface0 : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: item.modelData.name
                color: {
                    if (item.isUrgent || item.isFocused)
                        return Theme.crust
                    return item.isOccupied ? Theme.workspaceOccupied : Theme.workspaceEmpty
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.weight: item.isFocused ? Font.DemiBold : Font.Normal
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (Bspwm.available)
                        Bspwm.focusDesktop(item.modelData.name, item.modelData.monitor, item.index)
                }
            }
        }
    }

    // Layoutindicator: alleen zinvol als bspwm bereikbaar is.
    Rectangle {
        id: layoutBadge

        readonly property bool isMonocle: Bspwm.layoutForMonitor(root.monitorName) === "monocle"

        visible: Bspwm.available
        width: Theme.workspaceWidth
        height: Theme.widgetHeight
        radius: Theme.radiusSmall
        color: layoutHover.containsMouse ? Theme.surface0 : "transparent"

        Text {
            anchors.centerIn: parent
            text: layoutBadge.isMonocle ? "M" : "T"
            color: Theme.accentMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: layoutHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Bspwm.toggleLayout()
        }
    }

    // Foutpad: bspc ontbreekt of er is geen bspwm-sessie.
    Text {
        visible: !Bspwm.available
        text: "bspwm niet actief"
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
    }
}
