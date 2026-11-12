// NotificationStack.qml — popupkaarten rechtsboven onder de bar.
//
// Eén PopupWindow met maximaal vier kaarten (de service begrenst de lijst).
// Elke kaart toont app-icoon, appnaam, samenvatting, body, afbeelding en de
// actieknoppen van de melding. De sluitknop haalt alleen de popup weg; de
// melding blijft in het notificatiecentrum staan.
//
// Time-out: de NotificationDaemon bepaalt de duur (laag 4 s, normaal 8 s,
// kritiek nooit, expliciete expireTimeout respecteren). Zweven boven een
// kaart pauzeert de timer; bij het verlaten begint de volledige duur opnieuw.
//
// X11 (issue #794): PopupWindow krijgt geen toetsenbordfocus. grabFocus staat
// daarom uit; alle knoppen zijn gewone MouseAreas en blijven klikbaar.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../theme"
import "../services"

PopupWindow {
    id: stack

    // Het barvenster om onder te ankeren.
    property var barWindow: null

    // Het notificatiecentrum ligt op dezelfde plek; dan de stap verbergen.
    property bool centerOpen: false

    // Als de bar verborgen is, horen de popups ook weg te blijven.
    property bool barShown: true

    readonly property int cardWidth: Theme.scaled(360)
    readonly property int cardPadding: Theme.scaled(12)

    // Absolute schermpositie van de monitor (voor de hovercontrole).
    property int screenX: 0
    property int screenY: 0

    // Laatst bekende aanwijzerpositie (xdotool, alleen tijdens popups).
    property real pointerX: 0
    property real pointerY: 0
    property bool pointerKnown: false

    // Alleen pollen als er een kaart met automatische time-out zichtbaar is.
    readonly property bool needsPointerPoll: {
        for (var i = 0; i < Notifications.popups.length; i++) {
            if (Notifications.timeoutMs(Notifications.popups[i]) > 0)
                return true
        }
        return false
    }

    visible: Notifications.popupCount > 0 && !stack.centerOpen && stack.barShown
    color: "transparent"
    grabFocus: false

    implicitWidth: stack.cardWidth
    implicitHeight: cards.implicitHeight

    anchor.window: stack.barWindow
    anchor.rect.x: stack.barWindow ? stack.barWindow.width - Theme.barPadding : 0
    anchor.rect.y: stack.barWindow ? stack.barWindow.height + Theme.scaled(4) : 0
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.None

    Column {
        id: cards

        width: stack.cardWidth
        spacing: Theme.spacing

        Repeater {
            model: Notifications.popups

            delegate: Rectangle {
                id: card

                required property var modelData

                readonly property var notification: card.modelData
                readonly property int timeout: Notifications.timeoutMs(card.notification)
                readonly property bool critical:
                    card.notification.urgency === NotificationUrgency.Critical

                readonly property string iconSource:
                    Notifications.appIconSource(card.notification.appIcon)

                width: stack.cardWidth
                implicitHeight: cardContent.implicitHeight + 2 * stack.cardPadding
                radius: Theme.radiusSmall + 2
                color: Theme.base
                border.width: 1
                border.color: card.critical ? Theme.red : Theme.surface0

                // Hover pauzeert de time-out. Het popupvenster krijgt onder
                // X11 geen leave-event als de aanwijzer naar een ander venster
                // gaat, waardoor MouseArea.containsMouse en HoverHandler
                // blijven hangen. Daarom pollt de stack de echte
                // aanwijzerpositie met xdotool zolang er een popup met
                // time-out zichtbaar is.
                readonly property bool pointerInside: {
                    if (!stack.pointerKnown || !stack.barWindow)
                        return false

                    const pos = card.mapToItem(stack.contentItem, 0, 0)
                    const left = stack.screenX + stack.barWindow.width
                        - Theme.barPadding - stack.cardWidth + pos.x
                    const top = stack.screenY + stack.barWindow.height
                        + Theme.scaled(4) + pos.y

                    return stack.pointerX >= left
                        && stack.pointerX < left + card.width
                        && stack.pointerY >= top
                        && stack.pointerY < top + card.height
                }

                Timer {
                    id: autoClose

                    // Een interval van 0 zou direct vuren; gebruik 1 ms als
                    // tijdelijke waarde terwijl running false is.
                    interval: card.timeout > 0 ? card.timeout : 1
                    repeat: false
                    running: card.timeout > 0 && !card.pointerInside

                    onTriggered: Notifications.expirePopup(card.notification)
                }

                Column {
                    id: cardContent

                    x: stack.cardPadding
                    y: stack.cardPadding
                    width: card.width - 2 * stack.cardPadding
                    spacing: 6

                    // --- Kop: icoon, appnaam, samenvatting, sluiten -------
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignTop

                            Image {
                                id: appIcon

                                anchors.fill: parent
                                source: card.iconSource
                                sourceSize.width: 20
                                sourceSize.height: 20
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: "\uf0f3" // bell
                                color: card.critical ? Theme.red : Theme.accentMuted
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.iconSize
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: card.notification.appName.length > 0
                                    ? card.notification.appName : "Melding"
                                color: Theme.barMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.notification.summary
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }

                        Item {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignTop

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSmall
                                color: closeArea.containsMouse ? Theme.surface1 : "transparent"
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
                                onClicked: Notifications.expirePopup(card.notification)
                            }
                        }
                    }

                    // --- Body ---------------------------------------------
                    Text {
                        width: parent.width
                        visible: card.notification.body.length > 0
                        text: card.notification.body
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    // --- Afbeelding (bijvoorbeeld een profielfoto) --------
                    Image {
                        width: 56
                        height: 56
                        visible: card.notification.image.length > 0
                        source: card.notification.image
                        sourceSize.width: 112
                        sourceSize.height: 112
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    // --- Acties -------------------------------------------
                    Row {
                        width: parent.width
                        spacing: 6
                        visible: card.notification.actions.length > 0

                        Repeater {
                            model: card.notification.actions

                            delegate: Rectangle {
                                id: actionButton

                                required property var modelData

                                readonly property string label:
                                    modelData.text.length > 0
                                        ? modelData.text : modelData.identifier

                                width: actionLabel.implicitWidth + 18
                                height: 24
                                radius: Theme.radiusSmall
                                color: actionArea.containsMouse
                                    ? Theme.surface1 : Theme.surface0

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionButton.label
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: actionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        // Eerst de popup weg, daarna de actie:
                                        // de melding kan door de actie worden
                                        // vernietigd (tenzij resident).
                                        Notifications.expirePopup(card.notification)
                                        actionButton.modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Aanwijzerpositie voor hover-pauze --------------------------------

    Process {
        id: pointerProcess

        command: ["xdotool", "getmouselocation", "--shell"]

        stdout: StdioCollector {
            id: pointerOutput
            waitForEnd: true
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                return

            const text = pointerOutput.text
            const x = /(?:^|\n)X=(\d+)/.exec(text)
            const y = /(?:^|\n)Y=(\d+)/.exec(text)
            if (x && y) {
                stack.pointerX = Number(x[1])
                stack.pointerY = Number(y[1])
                stack.pointerKnown = true
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: stack.visible && stack.needsPointerPoll

        onTriggered: {
            if (!pointerProcess.running)
                pointerProcess.running = true
        }
    }
}
