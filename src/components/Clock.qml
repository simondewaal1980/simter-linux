// Clock.qml — tijd en datum, met een SystemClock die per minuut ververst.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

Item {
    id: root

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacing

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.barForeground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLarge
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 1
            implicitHeight: 14
            color: Theme.surface1
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: {
                // clock.date als dependency; de weergave zelf via een
                // Date-object zodat Qt.locale("nl_NL") de juiste
                // Nederlandse afkortingen geeft.
                clock.date
                return new Date().toLocaleDateString(Qt.locale("nl_NL"), "ddd d MMM")
            }
            color: Theme.barMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
        }
    }
}
