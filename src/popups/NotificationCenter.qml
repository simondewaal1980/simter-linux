// NotificationCenter.qml — geschiedenis van meldingen onder de bel.
//
// Toont de volledige geschiedenis (max. 50, nieuwste bovenaan) met per item
// app-icoon, appnaam, tijd, samenvatting en body. Klikken op een item klapt
// het open of dicht; opengeklapt verschijnen de volledige body en de
// actieknoppen. De X per item sluit de melding definitief, "Wis alles" leegt
// de geschiedenis.
//
// Het venster opent onder de bar, rechts uitgelijnd. Onder X11 krijgt een
// PopupWindow geen toetsenbordfocus (issue #794); grabFocus staat daarom uit
// en alle bediening loopt via de muis. Zodra het venster opent, gelden alle
// meldingen als gelezen (de badge in de bar verdwijnt).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "../theme"
import "../services"

PopupWindow {
    id: center

    property var barWindow: null

    readonly property int preferredWidth: Theme.scaled(400)
    readonly property int padding: Theme.scaled(14)
    readonly property int innerWidth: preferredWidth - 2 * padding
    readonly property int listMaxHeight: Theme.scaled(460)

    // Tickt terwijl het venster open is, zodat de relatieve tijden bijwerken.
    property double nowTick: Date.now()

    implicitWidth: center.preferredWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    grabFocus: false
    visible: false

    onVisibleChanged: {
        if (center.visible) {
            Notifications.markAllRead()
            center.nowTick = Date.now()
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: center.visible
        onTriggered: center.nowTick = Date.now()
    }

    anchor.window: center.barWindow
    anchor.rect.x: center.barWindow ? center.barWindow.width - Theme.barPadding : 0
    anchor.rect.y: center.barWindow ? center.barWindow.height + 4 : 0
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.None

    Rectangle {
        id: panel

        anchors.fill: parent
        implicitHeight: content.implicitHeight + 2 * center.padding
        radius: Theme.radiusSmall + 2
        color: Theme.base
        border.width: 1
        border.color: Theme.surface0

        Column {
            id: content

            x: center.padding
            y: center.padding
            width: center.innerWidth
            spacing: 10

            // --- Kop ------------------------------------------------
            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    text: "\uf0f3" // bell
                    color: Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                Text {
                    text: "Meldingen"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: Notifications.historyCount > 0
                        ? "(" + Notifications.historyCount + ")" : ""
                    color: Theme.barMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }

                // DND-schakelaar in de kop.
                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: dndArea.containsMouse ? Theme.surface0 : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf1f6" // bell-slash
                        color: Notifications.dnd ? Theme.yellow : Theme.barMuted
                        opacity: Notifications.dnd ? 1 : 0.55
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.iconSize
                    }

                    MouseArea {
                        id: dndArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.toggleDnd()
                    }
                }

                // "Wis alles"
                Item {
                    Layout.preferredWidth: clearLabel.implicitWidth + 14
                    Layout.preferredHeight: 22
                    visible: Notifications.historyCount > 0

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: clearArea.containsMouse ? Theme.surface0 : "transparent"
                    }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Wis alles"
                        color: clearArea.containsMouse ? Theme.text : Theme.barMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.clear()
                    }
                }

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: closeArea.containsMouse ? Theme.surface0 : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d" // xmark
                        color: Theme.overlay1
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: center.visible = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            // --- Lege staat ------------------------------------------
            Text {
                width: parent.width
                visible: Notifications.historyCount === 0
                text: Notifications.dnd
                    ? "Niet storen staat aan. Nieuwe meldingen worden hier bewaard."
                    : "Geen meldingen"
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                wrapMode: Text.WordWrap
            }

            // --- Geschiedenis ----------------------------------------
            Item {
                width: parent.width
                height: Notifications.historyCount === 0
                    ? 0
                    : Math.min(center.listMaxHeight, historyList.contentHeight)
                visible: Notifications.historyCount > 0

                ListView {
                    id: historyList

                    anchors.fill: parent
                    model: Notifications.history
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: entry

                        required property var modelData

                        readonly property var notification: entry.modelData.notification
                        readonly property bool critical:
                            entry.notification.urgency === NotificationUrgency.Critical
                        readonly property string iconSource:
                            Notifications.appIconSource(entry.notification.appIcon)

                        readonly property int entryPadding: 9

                        property bool expanded: false

                        width: center.innerWidth
                        implicitHeight: entryContent.implicitHeight + 2 * entryPadding
                        radius: Theme.radiusSmall
                        color: entryHover.containsMouse ? Theme.surface0 : Theme.mantle
                        border.width: 1
                        border.color: entry.critical ? Theme.red : Theme.surface0

                        onModelDataChanged: entry.expanded = false

                        // Klik op het item klapt het open/dicht. Ligt onder de
                        // knoppen, zodat die hun eigen klikgedrag houden.
                        MouseArea {
                            id: entryHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: entry.expanded = !entry.expanded
                        }

                        // Ongelezen-markering.
                        Rectangle {
                            visible: entry.modelData.unread === true
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: 3
                            radius: 1.5
                            color: Theme.accent
                        }

                        Column {
                            id: entryContent

                            x: entry.entryPadding + 4
                            y: entry.entryPadding
                            width: entry.width - 2 * entry.entryPadding - 4
                            spacing: 5

                            RowLayout {
                                width: parent.width
                                spacing: 7

                                Item {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignTop

                                    Image {
                                        id: entryIcon

                                        anchors.fill: parent
                                        source: entry.iconSource
                                        sourceSize.width: 16
                                        sourceSize.height: 16
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !entryIcon.visible
                                        text: "\uf0f3"
                                        color: entry.critical ? Theme.red : Theme.accentMuted
                                        font.family: Theme.iconFamily
                                        font.pixelSize: Theme.fontSmall
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: entry.notification.appName.length > 0
                                        ? entry.notification.appName : "Melding"
                                    color: Theme.barMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: Notifications.relativeTime(
                                        entry.modelData.receivedAt, center.nowTick)
                                    color: Theme.overlay1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                }

                                Text {
                                    text: entry.expanded ? "\uf077" : "\uf078" // chevron
                                    color: Theme.overlay1
                                    font.family: Theme.iconFamily
                                    font.pixelSize: Theme.fontSmall
                                }

                                Item {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusSmall
                                        color: dismissArea.containsMouse
                                            ? Theme.surface1 : "transparent"
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00d"
                                        color: Theme.overlay1
                                        font.family: Theme.iconFamily
                                        font.pixelSize: Theme.fontSmall
                                    }

                                    MouseArea {
                                        id: dismissArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifications.dismissNotification(
                                            entry.notification)
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: entry.notification.summary
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                                maximumLineCount: entry.expanded ? -1 : 2
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }

                            Text {
                                width: parent.width
                                visible: entry.notification.body.length > 0
                                text: entry.notification.body
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                wrapMode: Text.WordWrap
                                maximumLineCount: entry.expanded ? -1 : 2
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }

                            // Acties alleen tonen als het item opengeklapt is.
                            Row {
                                width: parent.width
                                spacing: 6
                                visible: entry.expanded
                                    && entry.notification.actions.length > 0

                                Repeater {
                                    model: entry.notification.actions

                                    delegate: Rectangle {
                                        id: entryAction

                                        required property var modelData

                                        readonly property string label:
                                            modelData.text.length > 0
                                                ? modelData.text : modelData.identifier

                                        width: entryActionLabel.implicitWidth + 18
                                        height: 24
                                        radius: Theme.radiusSmall
                                        color: entryActionArea.containsMouse
                                            ? Theme.surface1 : Theme.surface0

                                        Text {
                                            id: entryActionLabel
                                            anchors.centerIn: parent
                                            text: entryAction.label
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSmall
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: entryActionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                Notifications.expirePopup(entry.notification)
                                                entryAction.modelData.invoke()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- Voettekst -------------------------------------------
            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: Notifications.dnd
                        ? "Niet storen aan — popups zijn uit"
                        : "Niet storen uit"
                    color: Notifications.dnd ? Theme.yellow : Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }

                Text {
                    text: Notifications.historyCount + " / "
                        + Notifications.maxHistory
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }
}
