// SnapperWidget.qml — momentopnamen in de bar.
//
// Toont een geschiedenisicoon met het aantal beschikbare momentopnamen.
// Klikken opent de Snapper-popup met de lijst, configuratiekeuze en acties.
// Zonder toegang of zonder snapper blijft de widget zichtbaar met een
// gedempte "—", zodat de fout in de popup uitgelegd kan worden.

import QtQuick
import "../theme"
import "../services"

Item {
    id: root

    signal clicked()

    readonly property bool hasData: Snapper.snapshotCount > 0
    readonly property bool hasProblem: Snapper.accessError.length > 0
        || Snapper.lastError.length > 0 || !Snapper.available
    readonly property string countText: {
        if (!Snapper.loaded && Snapper.loading)
            return "…"
        if (Snapper.loaded && Snapper.available
                && Snapper.accessError.length === 0)
            return Snapper.snapshotCount > 99
                ? "99+" : String(Snapper.snapshotCount)
        return "—"
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
            text: "\uf1da" // clock-rotate-left
            color: root.hasProblem ? Theme.yellow
                : (root.hasData ? Theme.accent : Theme.barMuted)
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.countText
            color: root.hasProblem ? Theme.yellow : Theme.barForeground
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
