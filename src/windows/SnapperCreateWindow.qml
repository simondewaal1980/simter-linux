// SnapperCreateWindow.qml — dialoog voor een nieuwe snapper-momentopname.
//
// Een PopupWindow krijgt onder X11 geen toetsenbordfocus (issue #794); daarom
// is dit een klein FloatingWindow, net als de instellingen- en
// wallpapervensters. De beschrijving is optioneel. Aanmaken loopt via de
// Snapper-service, die bij ontbrekende leesrechten automatisch via pkexec om
// bevoegdheid vraagt.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../services"

FloatingWindow {
    id: win

    title: "Nieuwe momentopname"
    implicitWidth: Theme.scaled(520)
    implicitHeight: Theme.scaled(300)
    minimumSize: Qt.size(Theme.scaled(440), Theme.scaled(260))
    color: Theme.base
    visible: false

    property string description: ""
    property string localError: ""

    function openWindow() {
        win.description = ""
        win.localError = ""
        win.visible = true
        rootFocus.forceActiveFocus()
        descriptionInput.forceActiveFocus()
    }

    function closeWindow() {
        if (Snapper.busy)
            return
        win.visible = false
    }

    function toggleWindow() {
        if (win.visible)
            win.closeWindow()
        else
            win.openWindow()
    }

    function submit() {
        if (Snapper.busy)
            return

        win.localError = ""
        if (!Snapper.create(win.description)) {
            win.localError = Snapper.lastError.length > 0
                ? Snapper.lastError
                : "Kon geen momentopname aanmaken"
        }
    }

    onClosed: win.visible = false

    onVisibleChanged: {
        if (win.visible) {
            win.localError = ""
            rootFocus.forceActiveFocus()
            descriptionInput.forceActiveFocus()
        }
    }

    Connections {
        target: Snapper

        function onCreated(number) {
            win.visible = false
        }

        function onActionFinished(ok, message) {
            if (!ok && win.visible)
                win.localError = message
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: win.closeWindow()
    }

    Item {
        id: rootFocus

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: win.closeWindow()

        Rectangle {
            anchors.fill: parent
            color: Theme.base
            border.width: 1
            border.color: Theme.surface0
        }

        Rectangle {
            id: header

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: Theme.scaled(50)
            color: Theme.mantle

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 1
                color: Theme.surface0
            }

            RowLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.scaled(18)
                    rightMargin: Theme.scaled(12)
                }
                spacing: Theme.scaled(10)

                Text {
                    text: "\uf1da" // clock-rotate-left
                    color: Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.fontLarge
                }

                Text {
                    Layout.fillWidth: true
                    text: "Nieuwe momentopname"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge
                    font.weight: Font.DemiBold
                }

                Item {
                    Layout.preferredWidth: Theme.scaled(24)
                    Layout.preferredHeight: Theme.scaled(24)

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
                        onClicked: win.closeWindow()
                    }
                }
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                topMargin: header.height + Theme.scaled(18)
                leftMargin: Theme.scaled(18)
                rightMargin: Theme.scaled(18)
                bottomMargin: Theme.scaled(16)
            }
            spacing: Theme.scaled(10)

            Text {
                Layout.fillWidth: true
                text: "Configuratie: " + (Snapper.activeConfig.length > 0
                    ? Snapper.activeConfig : "—")
                    + (Snapper.activeSubvolume.length > 0
                        ? "  ·  " + Snapper.activeSubvolume : "")
                color: Theme.barMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideMiddle
            }

            Text {
                Layout.fillWidth: true
                text: "Beschrijving (optioneel)"
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.scaled(40)
                radius: Theme.radiusSmall
                color: Theme.mantle
                border.width: 1
                border.color: descriptionInput.activeFocus
                    ? Theme.accent : Theme.surface0

                TextInput {
                    id: descriptionInput

                    anchors {
                        fill: parent
                        leftMargin: Theme.scaled(10)
                        rightMargin: Theme.scaled(10)
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.crust
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                    clip: true
                    selectByMouse: true
                    maximumLength: 140
                    text: win.description
                    onTextChanged: win.description = text
                    onAccepted: win.submit()
                    Keys.onEscapePressed: win.closeWindow()
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.scaled(11)
                        verticalCenter: parent.verticalCenter
                    }
                    visible: descriptionInput.text.length === 0
                    text: "Bijvoorbeeld: voor update"
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }
            }

            TextEdit {
                Layout.fillWidth: true
                visible: Snapper.accessError.length > 0
                text: "Je gebruiker heeft nog geen snapper-rechten. "
                    + "Voer eenmalig uit:\n" + Snapper.setupCommand
                    + "\nOf laat de actie via pkexec lopen "
                    + "(daarvoor is een polkit-agent nodig)."
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                wrapMode: TextEdit.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: win.localError.length > 0
                text: win.localError
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: Snapper.busy
                text: "Bezig met aanmaken…"
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(8)

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: cancelLabel.implicitWidth + Theme.scaled(24)
                    Layout.preferredHeight: Theme.scaled(32)
                    radius: Theme.radiusSmall
                    color: cancelArea.containsMouse
                        ? Theme.surface1 : Theme.surface0

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Annuleren"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.closeWindow()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: createLabel.implicitWidth + Theme.scaled(24)
                    Layout.preferredHeight: Theme.scaled(32)
                    radius: Theme.radiusSmall
                    color: Snapper.busy ? Theme.surface0
                        : (createArea.containsMouse ? Theme.accent : Theme.blue)
                    opacity: Snapper.available && !Snapper.busy ? 1 : 0.55

                    Text {
                        id: createLabel
                        anchors.centerIn: parent
                        text: Snapper.busy ? "Bezig…" : "Aanmaken"
                        color: Theme.crust
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: createArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Snapper.available && !Snapper.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.submit()
                    }
                }
            }
        }
    }
}
