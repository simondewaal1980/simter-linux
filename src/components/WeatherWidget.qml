// WeatherWidget.qml — icoon en temperatuur in de bar.
//
// De gegevens komen uit de Weather-service. Zonder weerdata toont de widget
// een streepje ("—"); met cache maar zonder netwerk blijft de laatst bekende
// temperatuur staan, met een klein waarschuwingsicoon erbij. Klikken opent de
// popup met details en de verwachting.

import QtQuick
import "../theme"
import "../services"
import "../utils/WeatherCodes.js" as WeatherCodes

Item {
    id: root

    signal clicked()

    implicitWidth: content.implicitWidth + Theme.scaled(12)
    implicitHeight: Theme.widgetHeight

    readonly property bool hasData: Weather.hasData
    readonly property bool offline: Weather.lastError.length > 0

    readonly property string iconText: root.hasData
        ? WeatherCodes.icon(Weather.current.weatherCode)
        : "\uf6c4" // cloud-sun als neutraal "nog geen data"-icoon
    readonly property string temperatureText: root.hasData
        ? Math.round(Weather.current.temperature) + "°"
        : "—"

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
            text: root.iconText
            color: root.hasData ? Theme.accent : Theme.barMuted
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temperatureText
            color: Theme.barForeground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.offline
            text: "\uf071" // triangle-exclamation
            color: Theme.yellow
            font.family: Theme.iconFamily
            font.pixelSize: Theme.fontSmall
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
