// BatteryWidget.qml — accu-indicator voor de bar (fase 9).
//
// Alleen zichtbaar als UPower een aanwezige accu met een geldig percentage
// meldt. Op een desktop (zoals deze VM) blijft de widget dus weg; op een laptop
// ververst UPower de waarde vanzelf.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../theme"

Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: root.device !== null
        && root.device.isPresent === true
        && root.device.percentage > 0

    readonly property int percentage: root.present
        ? Math.round(root.device.percentage) : 0
    readonly property bool charging: root.present
        && root.device.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: root.present
        && root.device.state === UPowerDeviceState.FullyCharged

    readonly property string icon: {
        if (root.charging)
            return "\uf0e7" // bolt
        if (root.percentage >= 90)
            return "\uf240" // battery-full
        if (root.percentage >= 65)
            return "\uf241" // battery-three-quarters
        if (root.percentage >= 40)
            return "\uf242" // battery-half
        if (root.percentage >= 15)
            return "\uf243" // battery-quarter
        return "\uf244" // battery-empty
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.widgetHeight
    visible: root.present

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.percentage <= 15 && !root.charging
                ? Theme.red
                : (root.charging ? Theme.green : Theme.barMuted)
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.percentage + "%"
            color: Theme.barMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }
    }
}
