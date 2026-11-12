// WeatherPopup.qml — detailvenster onder de weerwidget in de bar.
//
// Toont gevoelstemperatuur, luchtvochtigheid, wind, neerslagkans, de min/max
// van vandaag, de drie volgende dagen en wanneer de gegevens zijn opgehaald.
// Het venster wordt door Bar.qml aan de bar verankerd; de zichtbaarheid wordt
// van buitenaf geschakeld (klik op de widget of `qs ipc call weather toggle`).
//
// Let op: onder X11 vraagt een PopupWindow geen toetsenbordfocus en wordt een
// klik buiten de popup niet gedetecteerd (issue #794). Daarom sluit de popup
// via de X-knop, een tweede klik op de weerwidget, een klik op de bar of
// `qs ipc call weather close`. grabFocus blijft aan staan voor platforms waar
// het wel werkt.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../services"
import "../utils/WeatherCodes.js" as WeatherCodes

PopupWindow {
    id: popup

    readonly property int preferredWidth: Theme.scaled(368)
    readonly property int padding: Theme.scaled(16)
    readonly property int innerWidth: preferredWidth - 2 * padding

    // Vandaag staat in de kop; de drie volgende dagen in de lijst.
    readonly property var forecastDays: Weather.daily.length > 1
        ? Weather.daily.slice(1, 4) : []

    readonly property var detailItems: {
        if (!Weather.hasData)
            return []

        const c = Weather.current
        const today = Weather.today
        var chance = "—"
        if (today && today.precipitationProbability !== null
                && today.precipitationProbability !== undefined)
            chance = Math.round(today.precipitationProbability) + "%"

        return [
            { icon: "\uf043", label: "Vocht", value: Math.round(c.humidity) + "%" },
            { icon: "\uf72e", label: "Wind", value: Math.round(c.windSpeed) + " km/u" },
            { icon: "\uf73d", label: "Kans", value: chance },
            { icon: "\uf2c9", label: "Min/max", value: popup.minMaxLabel(today) }
        ]
    }

    function minMaxLabel(day) {
        if (!day || day.min === null || day.min === undefined
                || day.max === null || day.max === undefined)
            return "—"
        return Math.round(day.min) + "° / " + Math.round(day.max) + "°"
    }

    function percentLabel(value) {
        if (value === null || value === undefined)
            return "—"
        return Math.round(value) + "%"
    }

    function dayLabel(value) {
        const parts = String(value).split("-")
        if (parts.length !== 3)
            return String(value)
        const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
        return date.toLocaleDateString(Qt.locale("nl_NL"), "ddd d MMM")
    }

    implicitWidth: preferredWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    grabFocus: true
    visible: false

    Rectangle {
        id: panel

        anchors.fill: parent
        implicitHeight: content.implicitHeight + 2 * popup.padding
        radius: Theme.radiusSmall + 2
        color: Theme.base
        border.width: 1
        border.color: Theme.surface0

        Column {
            id: content

            x: popup.padding
            y: popup.padding
            width: popup.innerWidth
            spacing: Theme.scaled(10)

            // --- Kop: locatie, conditie, temperatuur, sluiten --------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(10)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: Weather.location
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLarge
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Weather.hasData
                            ? WeatherCodes.text(Weather.current.weatherCode)
                            : "Geen gegevens"
                        color: Theme.barMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: Weather.hasData
                            ? Math.round(Weather.current.temperature) + "°"
                            : "—"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.scaled(28)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: Weather.hasData
                            ? "voelt als " + Math.round(Weather.current.apparentTemperature) + "°"
                            : " "
                        color: Theme.barMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }
                }

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignTop

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
                        onClicked: popup.visible = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            // --- Nog geen data -------------------------------------------
            Text {
                width: parent.width
                visible: !Weather.hasData
                text: Weather.loading
                    ? "Weer wordt opgehaald…"
                    : (Weather.lastError.length > 0
                        ? "Weer niet beschikbaar: " + Weather.lastError
                        : "Nog geen weerdata")
                color: Weather.lastError.length > 0 ? Theme.yellow : Theme.barMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                wrapMode: Text.WordWrap
            }

            // --- Detailcijfers -------------------------------------------
            Row {
                width: parent.width
                visible: Weather.hasData

                Repeater {
                    model: popup.detailItems

                    delegate: Column {
                        id: detail

                        required property var modelData

                        width: popup.detailItems.length > 0
                            ? popup.innerWidth / popup.detailItems.length : popup.innerWidth
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: detail.modelData.icon
                            color: Theme.accentMuted
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.iconSize
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: detail.modelData.value
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: detail.modelData.label
                            color: Theme.barMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
                visible: Weather.hasData
            }

            // --- Verwachting ---------------------------------------------
            Column {
                width: parent.width
                spacing: 6
                visible: Weather.hasData && popup.forecastDays.length > 0

                Text {
                    text: "Komende dagen"
                    color: Theme.barMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: popup.forecastDays

                    delegate: RowLayout {
                        required property var modelData

                        width: popup.innerWidth
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 62
                            text: popup.dayLabel(modelData.date)
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                        }

                        Text {
                            Layout.preferredWidth: 20
                            text: WeatherCodes.icon(modelData.weatherCode)
                            color: Theme.accent
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.iconSize
                        }

                        Text {
                            Layout.fillWidth: true
                            text: WeatherCodes.text(modelData.weatherCode)
                            color: Theme.barMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                            text: popup.percentLabel(modelData.precipitationProbability)
                            color: Theme.sky
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                        }

                        Text {
                            Layout.preferredWidth: 74
                            horizontalAlignment: Text.AlignRight
                            text: popup.minMaxLabel(modelData)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            // --- Voettekst: laatst bijgewerkt + verversen -----------------
            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Laatst bijgewerkt: " + Weather.updatedLabel()
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                Text {
                    visible: Weather.lastError.length > 0
                    text: "offline"
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: refreshArea.containsMouse ? Theme.surface0 : "transparent"
                    }

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "\uf021" // rotate
                        color: Theme.accentMuted
                        opacity: Weather.loading ? 0.5 : 1
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.fontSmall

                        RotationAnimator on rotation {
                            running: Weather.loading
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Weather.refresh()
                    }
                }
            }
        }
    }
}
