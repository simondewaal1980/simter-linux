// PowerMenu.qml — sessiemenu onder de aan/uit-knop in de bar.
//
// Vier acties: afmelden (BSPWM-sessie beëindigen), vergrendelen, slapen
// (opschorten) en afsluiten. De uitvoering loopt via de Power-service, die de
// commando's losgekoppeld start.
//
// Het venster opent onder de bar, rechts uitgelijnd. Onder X11 krijgt een
// PopupWindow geen toetsenbordfocus (issue #794); alle bediening loopt via de
// muis. Sluiten kan met de X, een tweede klik op de aan/uit-knop, een klik op
// de bar of `qs ipc call power close`.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../services"

PopupWindow {
    id: menu

    // Het barvenster om onder te ankeren.
    property var barWindow: null

    readonly property int preferredWidth: Theme.scaled(300)
    readonly property int padding: Theme.scaled(12)
    readonly property int innerWidth: preferredWidth - 2 * padding
    readonly property int rowHeight: Theme.scaled(52)

    // De acties in de volgorde waarin ze in het menu staan. De kleur is de
    // accentkleur van het icoon; afsluiten blijft rood als waarschuwing.
    readonly property var actions: [
        {
            action: "logout",
            label: "Afmelden",
            description: "BSPWM-sessie beëindigen",
            icon: "\uf2f5", // right-from-bracket
            color: Theme.accentMuted
        },
        {
            action: "lock",
            label: "Vergrendelen",
            description: "Scherm vergrendelen",
            icon: "\uf023", // lock
            color: Theme.accent
        },
        {
            action: "sleep",
            label: "Slapen",
            description: "Systeem opschorten",
            icon: "\uf186", // moon
            color: Theme.sky
        },
        {
            action: "shutdown",
            label: "Afsluiten",
            description: "Systeem uitschakelen",
            icon: "\uf011", // power-off
            color: Theme.red
        }
    ]

    implicitWidth: menu.preferredWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    grabFocus: false
    visible: false

    anchor.window: menu.barWindow
    anchor.rect.x: menu.barWindow ? menu.barWindow.width - Theme.barPadding : 0
    anchor.rect.y: menu.barWindow ? menu.barWindow.height + Theme.scaled(4) : 0
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.None

    // Houd de spiegel in Bar.qml actueel, zodat de aan/uit-knop en de
    // IPC-status de zichtbaarheid kunnen volgen.
    onVisibleChanged: {
        if (menu.barWindow)
            menu.barWindow.powerMenuVisible = menu.visible
    }

    function choose(action) {
        menu.visible = false

        if (action === "logout")
            Power.logout()
        else if (action === "lock")
            Power.lock()
        else if (action === "sleep")
            Power.sleep()
        else if (action === "shutdown")
            Power.shutdown()
    }

    Rectangle {
        id: panel

        anchors.fill: parent
        implicitHeight: content.implicitHeight + 2 * menu.padding
        radius: Theme.radiusSmall + 2
        color: Theme.base
        border.width: 1
        border.color: Theme.surface0

        Column {
            id: content

            x: menu.padding
            y: menu.padding
            width: menu.innerWidth
            spacing: Theme.scaled(6)

            // --- Kop: titel en sluiten ------------------------------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(8)

                Text {
                    text: "\uf011" // power-off
                    color: Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                Text {
                    Layout.fillWidth: true
                    text: "Sessie"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge
                    font.weight: Font.DemiBold
                }

                Item {
                    Layout.preferredWidth: Theme.scaled(20)
                    Layout.preferredHeight: Theme.scaled(20)

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
                        onClicked: menu.visible = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            // --- Acties ---------------------------------------------------
            Repeater {
                model: menu.actions

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    readonly property bool hovered: rowArea.containsMouse

                    width: menu.innerWidth
                    height: menu.rowHeight
                    radius: Theme.radiusSmall
                    color: row.hovered ? Theme.surface0 : "transparent"

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Theme.scaled(8)
                            rightMargin: Theme.scaled(8)
                        }
                        spacing: Theme.scaled(10)

                        Rectangle {
                            Layout.preferredWidth: Theme.scaled(32)
                            Layout.preferredHeight: Theme.scaled(32)
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.radiusSmall
                            color: row.hovered ? Theme.surface1 : Theme.mantle

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.icon
                                color: row.modelData.color
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.iconSize
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.description
                                color: Theme.barMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.choose(row.modelData.action)
                    }
                }
            }
        }
    }
}
