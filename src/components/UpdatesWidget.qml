// UpdatesWidget.qml — beschikbare updates in de bar.
//
// Toont het totale aantal beschikbare APT- en Flatpak-updates. Klikken opent
// de UpdatesPopup met de lijst per pakketbeheerder en de knop om alles bij te
// werken. Zonder updates blijft de widget zichtbaar met een gedempte "0",
// zodat ook de status en de verversknop bereikbaar blijven.

import QtQuick
import "../theme"
import "../services"

Item {
    id: root

    signal clicked()

    readonly property bool hasProblem: Updates.hasProblem
        || Updates.lastError.length > 0
    readonly property string countText: {
        if (!Updates.checked && Updates.loading)
            return "…"
        if (Updates.totalCount > 99)
            return "99+"
        return String(Updates.totalCount)
    }
    readonly property color iconColor: {
        if (root.hasProblem)
            return Theme.yellow
        if (Updates.hasUpdates)
            return Theme.peach
        return Theme.barMuted
    }

    implicitWidth: content.implicitWidth + Theme.scaled(12)
    implicitHeight: Theme.widgetHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: hoverArea.containsMouse ? Theme.surface0 : "transparent"
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.scaled(6)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf019" // download
            color: root.iconColor
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.countText
            color: root.hasProblem ? Theme.yellow
                : (Updates.hasUpdates ? Theme.barForeground : Theme.barMuted)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
