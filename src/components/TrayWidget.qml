// TrayWidget.qml — StatusNotifierItem-iconen (SNI) in de bar.
//
// Quickshell levert zelf de StatusNotifierWatcher; zodra deze component
// `SystemTray.items` leest, worden tray-apps zoals nm-applet en blueman-applet
// gevolgd. Er is geen lege ruimte als er geen items zijn: de widget verbergt
// zichzelf volledig.
//
// Klikgedrag:
//   links        → item.activate()
//   midden       → item.secondaryActivate()
//   rechts       → menu (item.display(); QsMenuAnchor als terugval)
//   scrollen     → item.scroll(delta, horizontaal)
//
// Menu's worden door QtWidgets' QMenu getekend. Daarvoor moet de shell in
// QApplication-modus starten (`//@ pragma UseQApplication` in shell.qml);
// zonder die pragma weigert Quickshell platformmenu's en werkt alleen de
// terugval. Zet QS_TRAY_FALLBACK_MENU=1 om altijd QsMenuAnchor te gebruiken.
//
// Let op: legacy XEmbed-trayicons (het oude X11-systeem) worden niet
// ondersteund; Quickshell ondersteunt uitsluitend SNI. Moderne apps leveren
// SNI aan.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"

Row {
    id: root

    // Het barvenster, nodig om menu's en tooltips te ankeren.
    property var barWindow: null

    // Fallback voor omgevingen waar de platformmenu's niet werken.
    readonly property bool useFallbackMenu:
        Quickshell.env("QS_TRAY_FALLBACK_MENU") === "1"

    readonly property int iconSize: Theme.scaled(18)
    readonly property int buttonSize: Theme.iconButtonSize

    readonly property bool hasItems: trayRepeater.count > 0
    visible: hasItems
    spacing: Theme.scaled(2)

    // --- Tooltip-state -----------------------------------------------------
    property var hoveredItem: null
    property var hoveredDelegate: null
    // Horizontale ankerpositie (midden van het icoon) in venstercoördinaten.
    property real tooltipX: 0

    readonly property string tooltipTitle: {
        const item = root.hoveredItem
        if (!item)
            return ""
        return item.tooltipTitle.length > 0 ? item.tooltipTitle : item.title
    }

    readonly property string tooltipDescription:
        root.hoveredItem ? root.hoveredItem.tooltipDescription : ""

    function hideTooltip() {
        tooltipTimer.stop()
        tooltip.visible = false
        root.hoveredItem = null
        root.hoveredDelegate = null
    }

    function scheduleTooltip(button) {
        const item = button.item
        if (!item)
            return

        const title = item.tooltipTitle.length > 0 ? item.tooltipTitle : item.title
        const description = item.tooltipDescription
        if (title.length === 0 && description.length === 0) {
            root.hideTooltip()
            return
        }

        root.hoveredItem = item
        root.hoveredDelegate = button
        root.tooltipX = root.windowPosition(button).x + button.width / 2
        tooltipTimer.restart()
    }

    // --- Menu --------------------------------------------------------------

    // Actief menu-item voor de QsMenuAnchor-terugval.
    property var menuItem: null
    // Positie van het menu in venstercoördinaten.
    property real menuX: 0
    property real menuY: 0

    function openMenu(button) {
        const item = button.item
        if (!item)
            return

        root.hideTooltip()

        if (!item.hasMenu)
            return

        root.menuItem = item

        // Coördinaten ten opzichte van het barvenster, voor zowel
        // item.display() als de QsMenuAnchor-terugval.
        const pos = root.windowPosition(button)
        root.menuX = pos.x + button.width / 2
        root.menuY = pos.y + button.height + Theme.scaled(2)

        if (root.useFallbackMenu || !root.barWindow) {
            // Een tweede rechtsklik sluit het al openstaande menu; zonder
            // deze guard waarschuwt QsMenuAnchor dat het al open is.
            if (menuAnchor.visible) {
                menuAnchor.close()
                return
            }
            menuAnchor.open()
            return
        }

        item.display(root.barWindow, Math.round(root.menuX), Math.round(root.menuY))
    }

    function windowPosition(button) {
        if (!root.barWindow || !root.barWindow.contentItem || !button)
            return Qt.point(0, 0)
        return root.barWindow.contentItem.mapFromItem(button, 0, 0)
    }

    // --- Iconen ------------------------------------------------------------

    Repeater {
        id: trayRepeater
        model: SystemTray.items

        delegate: Item {
            id: button

            required property SystemTrayItem modelData
            readonly property var item: modelData

            readonly property bool needsAttention:
                item.status === Status.NeedsAttention
            readonly property bool hovered: hoverArea.containsMouse

            width: root.buttonSize
            height: root.buttonSize

            Component.onDestruction: {
                if (root.hoveredDelegate === button)
                    root.hideTooltip()
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: {
                    if (button.needsAttention)
                        return Theme.urgent
                    if (button.hovered)
                        return Theme.surface0
                    return "transparent"
                }
                opacity: button.needsAttention ? 0.35 : 1
            }

            Image {
                id: icon

                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize
                source: button.item.icon
                sourceSize.width: root.iconSize
                sourceSize.height: root.iconSize
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: status === Image.Ready
            }

            // Terugval als de app geen (bruikbaar) icoon levert.
            Text {
                anchors.centerIn: parent
                visible: !icon.visible
                text: "\uf2d0" // window-maximize als neutraal icoon
                color: Theme.barMuted
                font.family: Theme.iconFamily
                font.pixelSize: Theme.iconSize
                opacity: 0.7
            }

            MouseArea {
                id: hoverArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onEntered: root.scheduleTooltip(button)
                onExited: {
                    if (root.hoveredDelegate === button)
                        root.hideTooltip()
                }

                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.hideTooltip()
                        button.item.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton) {
                        if (button.item.hasMenu)
                            root.openMenu(button)
                    } else if (button.item.onlyMenu) {
                        root.openMenu(button)
                    } else {
                        root.hideTooltip()
                        button.item.activate()
                    }
                }
            }

            WheelHandler {
                onWheel: (event) => {
                    const dy = event.angleDelta.y
                    const dx = event.angleDelta.x
                    const delta = dy !== 0 ? dy : dx
                    if (delta === 0)
                        return
                    button.item.scroll(delta > 0 ? 1 : -1, dy === 0 && dx !== 0)
                }
            }
        }
    }

    // Terugvalpad voor menu's: QsMenuAnchor toont hetzelfde DBusMenu.
    QsMenuAnchor {
        id: menuAnchor

        menu: root.menuItem ? root.menuItem.menu : null
        anchor.window: root.barWindow
        anchor.rect.x: root.menuX
        anchor.rect.y: root.menuY
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX

        onClosed: {
            root.menuItem = null
        }
    }

    // --- Tooltip -----------------------------------------------------------

    Timer {
        id: tooltipTimer
        interval: 350

        onTriggered: {
            if (root.hoveredDelegate && root.hoveredItem) {
                tooltip.visible = false
                tooltip.visible = true
            }
        }
    }

    PopupWindow {
        id: tooltip

        visible: false
        color: "transparent"
        grabFocus: false

        // De tooltip hangt onder de bar, gecentreerd boven het icoon.
        anchor.window: root.barWindow
        anchor.rect.x: root.tooltipX - tooltip.implicitWidth / 2
        anchor.rect.y: root.barWindow ? root.barWindow.height + Theme.scaled(2) : 0
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.SlideX

        implicitWidth: bubble.width
        implicitHeight: bubble.height

        TextMetrics {
            id: titleMetrics
            text: root.tooltipTitle
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            font.weight: Font.DemiBold
        }

        TextMetrics {
            id: descriptionMetrics
            text: root.tooltipDescription
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }

        Rectangle {
            id: bubble

            readonly property int maxWidth: Theme.scaled(280)
            readonly property int padding: Theme.scaled(8)

            width: Math.max(Theme.scaled(80), Math.min(
                Math.max(titleMetrics.advanceWidth, descriptionMetrics.advanceWidth)
                    + 2 * padding,
                maxWidth))
            height: content.implicitHeight + 2 * padding

            radius: Theme.radiusSmall
            color: Theme.base
            border.width: 1
            border.color: Theme.surface0

            Column {
                id: content

                x: bubble.padding
                y: bubble.padding
                width: bubble.width - 2 * bubble.padding
                spacing: Theme.scaled(2)

                Text {
                    width: parent.width
                    visible: root.tooltipTitle.length > 0
                    text: root.tooltipTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.tooltipDescription.length > 0
                    text: root.tooltipDescription
                    color: Theme.barMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
