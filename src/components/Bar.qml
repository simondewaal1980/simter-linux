// Bar.qml — de bovenbalk, één instantie per scherm.
//
// De bar reserveert ruimte via EWMH-struts. In Quickshell 0.3.2 gebeurt dat
// automatisch met ExclusionMode.Auto: bij drie ankers (top/left/right) wordt
// precies de hoogte van het venster gereserveerd.

import QtQuick
import Quickshell
import "../theme"
import "../popups"
import "../services"

PanelWindow {
    id: bar

    // Van buitenaf te schakelen via de IPC-handler in shell.qml.
    property bool shown: true

    // Het tandwiel, het toetsenbord, de wallpaperknop en de Snapper-popup
    // vragen shell.qml om het betreffende FloatingWindow te openen (één
    // venster voor alle schermen).
    signal settingsRequested()
    signal shortcutsRequested()
    signal wallpaperRequested()
    signal snapperCreateRequested()

    // Via `qs ipc call weather open|close|toggle` (en de klik op de widget).
    function openWeatherPopup() {
        bar.closeNotificationCenter()
        bar.closePowerMenu()
        bar.closeSnapperPopup()
        bar.closeUpdatesPopup()
        weatherPopup.visible = true
    }

    function closeWeatherPopup() {
        weatherPopup.visible = false
    }

    function toggleWeatherPopup() {
        if (weatherPopup.visible) {
            weatherPopup.visible = false
        } else {
            bar.openWeatherPopup()
        }
    }

    // Via `qs ipc call notifications open|close|toggle` en de bel in de bar.
    function openNotificationCenter() {
        bar.closeWeatherPopup()
        bar.closePowerMenu()
        bar.closeSnapperPopup()
        bar.closeUpdatesPopup()
        tray.hideTooltip()
        notificationCenter.visible = true
    }

    function closeNotificationCenter() {
        notificationCenter.visible = false
    }

    function toggleNotificationCenter() {
        if (notificationCenter.visible)
            bar.closeNotificationCenter()
        else
            bar.openNotificationCenter()
    }

    // Via `qs ipc call power open|close|toggle` en de aan/uit-knop in de bar.
    // PowerMenu.qml houdt deze spiegel bij; een directe binding aan
    // powerMenu.visible zou bij het opbouwen van de bar te vroeg evalueren.
    property bool powerMenuVisible: false

    // Spiegel voor `qs ipc call snapper status`.
    property bool snapperPopupVisible: false

    // Spiegel voor `qs ipc call updates status`.
    property bool updatesPopupVisible: false

    function openPowerMenu() {
        bar.closeWeatherPopup()
        bar.closeNotificationCenter()
        bar.closeSnapperPopup()
        bar.closeUpdatesPopup()
        tray.hideTooltip()
        powerMenu.visible = true
    }

    function closePowerMenu() {
        powerMenu.visible = false
    }

    function togglePowerMenu() {
        if (powerMenu.visible)
            bar.closePowerMenu()
        else
            bar.openPowerMenu()
    }

    // Via `qs ipc call snapper open|close|toggle` en de Snapper-widget.
    function openSnapperPopup() {
        bar.closeWeatherPopup()
        bar.closeNotificationCenter()
        bar.closePowerMenu()
        bar.closeUpdatesPopup()
        tray.hideTooltip()
        Snapper.refresh()
        snapperPopup.visible = true
    }

    function closeSnapperPopup() {
        snapperPopup.visible = false
    }

    function toggleSnapperPopup() {
        if (snapperPopup.visible)
            bar.closeSnapperPopup()
        else
            bar.openSnapperPopup()
    }

    // Via `qs ipc call updates open|close|toggle` en de update-widget.
    function openUpdatesPopup() {
        bar.closeWeatherPopup()
        bar.closeNotificationCenter()
        bar.closePowerMenu()
        bar.closeSnapperPopup()
        tray.hideTooltip()
        Updates.refresh()
        updatesPopup.visible = true
    }

    function closeUpdatesPopup() {
        updatesPopup.visible = false
    }

    function toggleUpdatesPopup() {
        if (updatesPopup.visible)
            bar.closeUpdatesPopup()
        else
            bar.openUpdatesPopup()
    }

    onShownChanged: {
        if (!bar.shown) {
            weatherPopup.visible = false
            notificationCenter.visible = false
            powerMenu.visible = false
            snapperPopup.visible = false
            updatesPopup.visible = false
            tray.hideTooltip()
        }
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    exclusionMode: ExclusionMode.Auto
    aboveWindows: true
    focusable: false
    visible: bar.shown

    // Het venster zelf moet transparant zijn; anders blijft de standaard witte
    // vensterachtergrond achter de semi-transparante Rectangle zichtbaar.
    // surfaceFormat.opaque moet vóór het eerste zichtbaar maken op false staan,
    // omdat een ondoorzichtige surface later niet meer transparant kan worden.
    color: "transparent"
    surfaceFormat.opaque: false

    Rectangle {
        id: background
        anchors.fill: parent
        color: Theme.barBackgroundTransparent

        // Een klik op een leeg stuk van de bar sluit de weerpopup en de
        // traytooltip. Kinderen met een eigen MouseArea (workspaces, widgets)
        // liggen hierboven en houden hun eigen klikgedrag.
        MouseArea {
            anchors.fill: parent
            onClicked: {
                bar.closeWeatherPopup()
                bar.closeNotificationCenter()
                bar.closePowerMenu()
                bar.closeSnapperPopup()
                bar.closeUpdatesPopup()
                tray.hideTooltip()
            }
        }

        // Subtiele rand onder de bar, in dezelfde kleur als normale
        // BSPWM-vensterranden.
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.borderNormal
        }

        // Links: live workspaces + layoutindicator.
        Workspaces {
            id: workspaces
            monitorName: bar.screen ? bar.screen.name : ""
            anchors {
                left: parent.left
                leftMargin: Theme.barPadding
                verticalCenter: parent.verticalCenter
            }
        }

        // Midden: tijd en datum.
        Clock {
            anchors.centerIn: parent
        }

        // Rechts: venstertitel, weer, snapper, updates, muziek, volume, accu,
        // meldingen, sneltoetsen, instellingen en tray. Netwerk loopt via de
        // tray.
        Row {
            anchors {
                right: parent.right
                rightMargin: Theme.barPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.barSpacing

            ActiveWindow {
                id: activeWindow
                maxWidth: 340
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: activeWindow.visible
                width: 1
                height: Theme.separatorHeight
                color: Theme.surface1
            }

            WeatherWidget {
                id: weatherWidget
                anchors.verticalCenter: parent.verticalCenter
                onClicked: bar.toggleWeatherPopup()
            }

            // Snapper: aantal momentopnamen; klik opent de lijst.
            SnapperWidget {
                id: snapperWidget
                anchors.verticalCenter: parent.verticalCenter
                onClicked: bar.toggleSnapperPopup()
            }

            // Updates: aantal beschikbare APT- en Flatpak-updates; klik opent
            // de lijst en de knop om alles bij te werken.
            UpdatesWidget {
                id: updatesWidget
                anchors.verticalCenter: parent.verticalCenter
                onClicked: bar.toggleUpdatesPopup()
            }

            // Muziek (alleen als er een MPRIS-speler met een nummer is).
            MprisWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            // Volume: Pipewire, met pactl-terugval op PulseAudio.
            VolumeWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            // Accu: alleen zichtbaar als UPower een accu meldt.
            BatteryWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            // Bel + DND-schakelaar + badge (altijd zichtbaar).
            NotificationBell {
                id: notificationBell
                anchors.verticalCenter: parent.verticalCenter
                onCenterRequested: bar.toggleNotificationCenter()
                onDndToggled: Notifications.toggleDnd()
            }

            // Toetsenbord: opent het sneltoetsenoverzicht (Super+/).
            Item {
                id: shortcutsButton

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: shortcutsHover.containsMouse ? Theme.surface0 : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf11c" // keyboard
                    color: shortcutsHover.containsMouse ? Theme.text : Theme.barMuted
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                MouseArea {
                    id: shortcutsHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.shortcutsRequested()
                }
            }

            // Afbeelding: opent het wallpapervenster (kiezen, previewen,
            // toevoegen en verwijderen).
            Item {
                id: wallpaperButton

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: wallpaperHover.containsMouse ? Theme.surface0 : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf03e" // image
                    color: wallpaperHover.containsMouse ? Theme.text : Theme.barMuted
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                MouseArea {
                    id: wallpaperHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.wallpaperRequested()
                }
            }

            // Tandwiel: opent het BSPWM-instellingenvenster.
            Item {
                id: settingsButton

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: settingsHover.containsMouse ? Theme.surface0 : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf013" // gear
                    color: settingsHover.containsMouse ? Theme.text : Theme.barMuted
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                MouseArea {
                    id: settingsHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.settingsRequested()
                }
            }

            // Alleen zichtbaar als er echt tray-items zijn (anders geen
            // scheidingslijn of lege ruimte).
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: tray.hasItems
                width: 1
                height: Theme.separatorHeight
                color: Theme.surface1
            }

            TrayWidget {
                id: tray
                barWindow: bar
                anchors.verticalCenter: parent.verticalCenter
            }

            // Aan/uit-knop: opent het sessiemenu (afmelden, vergrendelen,
            // slapen, herstarten en afsluiten).
            Item {
                id: powerButton

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: powerHover.containsMouse || bar.powerMenuVisible
                        ? Theme.surface0 : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf011" // power-off
                    color: {
                        if (bar.powerMenuVisible)
                            return Theme.red
                        if (powerHover.containsMouse)
                            return Theme.text
                        return Theme.barMuted
                    }
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                MouseArea {
                    id: powerHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.togglePowerMenu()
                }
            }

        }
    }

    // Weerpopup, onder de bar en rechts uitgelijnd met de barrand.
    WeatherPopup {
        id: weatherPopup
        anchor.window: bar
        anchor.edges: Edges.Top | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.None
        anchor.rect.x: bar.width - Theme.barPadding
        anchor.rect.y: bar.height + Theme.scaled(4)
    }

    // Notificatiepopups: rechtsboven onder de bar, maximaal vier kaarten.
    NotificationStack {
        id: notificationStack
        barWindow: bar
        centerOpen: notificationCenter.visible
        barShown: bar.shown
        screenX: bar.screen ? bar.screen.x : 0
        screenY: bar.screen ? bar.screen.y : 0
    }

    // Notificatiecentrum: geschiedenis, wis alles en per-item acties.
    NotificationCenter {
        id: notificationCenter
        barWindow: bar
    }

    // Sessiemenu: afmelden, vergrendelen, slapen, herstarten en afsluiten.
    PowerMenu {
        id: powerMenu
        barWindow: bar
    }

    // Momentopnamen: configuratiekeuze, aanmaken en verwijderen.
    SnapperPopup {
        id: snapperPopup
        barWindow: bar
        onCreateRequested: {
            bar.closeSnapperPopup()
            bar.snapperCreateRequested()
        }
    }

    // Updates: APT en Flatpak bekijken en bijwerken.
    UpdatesPopup {
        id: updatesPopup
        barWindow: bar
    }
}
