// NotificationBell.qml — bel, DND-schakelaar en badge in de bar.
//
// Linksklik op de bel opent of sluit het notificatiecentrum; rechtsklik
// schakelt "niet storen". Het maantje (bell-slash) rechts van de bel is een
// aparte DND-schakelaar: gedimd als DND uit staat, geel als het aan staat.
// De badge toont het aantal ongelezen meldingen; die teller gaat naar nul
// zodra het centrum opent.

import QtQuick
import "../theme"
import "../services"

Row {
    id: root

    signal centerRequested()
    signal dndToggled()

    readonly property int unread: Notifications.unreadCount
    readonly property bool dnd: Notifications.dnd

    spacing: Theme.scaled(2)

    // --- Bel met badge -----------------------------------------------------
    Item {
        id: bellButton

        width: Theme.iconButtonSize
        height: Theme.iconButtonSize

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: bellArea.containsMouse ? Theme.surface0 : "transparent"
        }

        Text {
            anchors.centerIn: parent
            text: "\uf0f3" // bell
            color: root.unread > 0 ? Theme.accent : Theme.barMuted
            opacity: root.dnd ? 0.55 : 1
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
        }

        Rectangle {
            id: badge

            visible: root.unread > 0
            x: bellButton.width - width + Theme.scaled(3)
            y: -Theme.scaled(1)
            width: Math.max(Theme.scaled(14), badgeLabel.implicitWidth + Theme.scaled(6))
            height: Theme.scaled(15)
            radius: height / 2
            color: Theme.red

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.unread > 99 ? "99+" : String(root.unread)
                color: Theme.crust
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                font.weight: Font.Bold
            }
        }

        MouseArea {
            id: bellArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    root.dndToggled()
                else
                    root.centerRequested()
            }
        }
    }

    // --- DND-schakelaar ----------------------------------------------------
    Item {
        id: dndButton

        width: Theme.iconButtonSize
        height: Theme.iconButtonSize

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: dndArea.containsMouse ? Theme.surface0 : "transparent"
        }

        Text {
            anchors.centerIn: parent
            text: "\uf1f6" // bell-slash
            color: root.dnd ? Theme.yellow : Theme.barMuted
            opacity: root.dnd ? 1 : 0.45
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
        }

        MouseArea {
            id: dndArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dndToggled()
        }
    }
}
