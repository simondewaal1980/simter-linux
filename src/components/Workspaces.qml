// Workspaces.qml — tijdelijke, statische workspace-indicator voor fase 2.
//
// Fase 3 vervangt de vaste waarden door de Bspwm-service (live report-parser),
// klikken en scrollen. De basisstyling blijft dan hetzelfde.

import QtQuick
import "../theme"

Row {
    id: root

    property int count: 9
    property int currentIndex: 0
    property var occupiedIndices: [1, 3]
    property var urgentIndices: []

    spacing: Theme.spacingSmall

    Repeater {
        model: root.count

        delegate: Rectangle {
            id: item

            required property int index

            readonly property bool isFocused: index === root.currentIndex
            readonly property bool isOccupied: root.occupiedIndices.indexOf(index) >= 0
            readonly property bool isUrgent: root.urgentIndices.indexOf(index) >= 0

            width: 24
            height: 22
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
                text: item.index + 1
                color: item.isFocused ? Theme.crust
                     : item.isOccupied ? Theme.workspaceOccupied
                     : Theme.workspaceEmpty
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.weight: item.isFocused ? Font.DemiBold : Font.Normal
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                // Alleen visueel; de echte desktopwissel volgt in fase 3.
                onClicked: root.currentIndex = item.index
            }
        }
    }
}
