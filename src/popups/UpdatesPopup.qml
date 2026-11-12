// UpdatesPopup.qml — beschikbare updates onder de Updates-widget in de bar.
//
// Toont de APT- en Flatpak-updates die de Updates-service heeft gevonden.
// Met de verversknop wordt opnieuw gekeken; met "Bijwerken" worden eerst de
// systeemupdates en daarna de Flatpaks bijgewerkt. Omdat dit systeemwijzigingen
// zijn, vraagt de knop om een tweede klik. APT gebruikt daarbij pkexec
// (instelbaar met UPDATES_ELEVATE); Flatpak regelt eventuele bevoegdheid zelf.
//
// Onder X11 krijgt een PopupWindow geen toetsenbordfocus (issue #794); de
// popup bevat daarom geen tekstinvoer en sluit via de X-knop, een klik op de
// bar of `qs ipc call updates close`.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../services"

PopupWindow {
    id: popup

    property var barWindow: null

    readonly property int preferredWidth: Theme.scaled(440)
    readonly property int padding: Theme.scaled(14)
    readonly property int innerWidth: preferredWidth - 2 * padding
    readonly property int listMaxHeight: Theme.scaled(400)

    property bool confirmUpdate: false

    readonly property bool showEmpty: Updates.checked && !Updates.loading
        && !Updates.hasUpdates && Updates.lastError.length === 0
    readonly property bool hasProblem: Updates.lastError.length > 0
        || (Updates.checked && !Updates.anyManagerAvailable)

    // Eén lijst met kopschriften per pakketbeheerder en daaronder de pakketten.
    readonly property var rows: {
        const result = []

        if (Updates.aptCount > 0) {
            result.push({
                header: true,
                key: "header-apt",
                title: "Systeem (APT)",
                count: Updates.aptCount,
                icon: "\uf17c", // linux
                name: "",
                detail: ""
            })
            for (let i = 0; i < Updates.aptUpdates.length; i++) {
                const item = Updates.aptUpdates[i]
                result.push({
                    header: false,
                    key: item.id,
                    icon: "\uf17c",
                    name: item.name,
                    detail: popup.versionLabel(item),
                    title: "",
                    count: 0
                })
            }
        }

        if (Updates.flatpakCount > 0) {
            result.push({
                header: true,
                key: "header-flatpak",
                title: "Flatpak",
                count: Updates.flatpakCount,
                icon: "\uf1b2", // cube
                name: "",
                detail: ""
            })
            for (let i = 0; i < Updates.flatpakUpdates.length; i++) {
                const item = Updates.flatpakUpdates[i]
                result.push({
                    header: false,
                    key: item.id,
                    icon: "\uf1b2",
                    name: item.name,
                    detail: popup.versionLabel(item),
                    title: "",
                    count: 0
                })
            }
        }

        return result
    }

    readonly property int listHeight: {
        let height = 0
        for (let i = 0; i < popup.rows.length; i++)
            height += popup.rows[i].header
                ? Theme.scaled(32) : Theme.scaled(42)
        return Math.min(popup.listMaxHeight, height)
    }

    function versionLabel(item) {
        if (item.source === "flatpak") {
            let value = item.version.length > 0 ? item.version : item.branch
            if (item.origin.length > 0)
                value += " · " + item.origin
            return value
        }
        if (item.oldVersion.length > 0)
            return item.oldVersion + " → " + item.version
        return item.version
    }

    implicitWidth: preferredWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    grabFocus: false
    visible: false

    onVisibleChanged: {
        if (popup.barWindow)
            popup.barWindow.updatesPopupVisible = popup.visible
        if (popup.visible) {
            popup.confirmUpdate = false
            updateConfirmTimer.stop()
            Updates.refresh()
        }
    }

    Timer {
        id: updateConfirmTimer
        interval: 5000
        repeat: false
        running: false
        onTriggered: popup.confirmUpdate = false
    }

    function requestUpdate() {
        if (Updates.busy || !Updates.hasUpdates)
            return
        if (popup.confirmUpdate) {
            popup.confirmUpdate = false
            updateConfirmTimer.stop()
            Updates.updateAll()
            return
        }
        popup.confirmUpdate = true
        updateConfirmTimer.restart()
    }

    anchor.window: popup.barWindow
    anchor.rect.x: popup.barWindow ? popup.barWindow.width - Theme.barPadding : 0
    anchor.rect.y: popup.barWindow ? popup.barWindow.height + Theme.scaled(4) : 0
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.None

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
            spacing: Theme.scaled(9)

            // --- Kop ------------------------------------------------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(8)

                Text {
                    text: "\uf019" // download
                    color: Updates.hasUpdates ? Theme.peach : Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                Text {
                    text: "Updates"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: Updates.loading
                        ? "controleren…"
                        : (Updates.checked
                            ? "(" + Updates.totalCount + ")" : "")
                    color: Theme.barMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }

                Item {
                    Layout.preferredWidth: Theme.scaled(22)
                    Layout.preferredHeight: Theme.scaled(22)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: refreshArea.containsMouse
                            ? Theme.surface0 : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf021" // rotate
                        color: Theme.accentMuted
                        opacity: Updates.loading ? 0.5 : 1
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.fontSmall

                        RotationAnimator on rotation {
                            running: Updates.loading
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
                        enabled: !Updates.loading && !Updates.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Updates.refresh()
                    }
                }

                Item {
                    Layout.preferredWidth: Theme.scaled(20)
                    Layout.preferredHeight: Theme.scaled(20)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: closeArea.containsMouse
                            ? Theme.surface0 : "transparent"
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

            // --- Fout- en laadstatus --------------------------------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(8)
                visible: popup.hasProblem

                Text {
                    Layout.alignment: Qt.AlignTop
                    text: "\uf071" // triangle-exclamation
                    color: Theme.yellow
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.fontNormal
                }

                Text {
                    Layout.fillWidth: true
                    text: Updates.lastError.length > 0
                        ? Updates.lastError
                        : "Geen pakketbeheer gevonden (apt of flatpak)"
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                width: parent.width
                visible: Updates.loading && !Updates.checked
                text: "Updates worden gecontroleerd…"
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }

            Text {
                width: parent.width
                visible: popup.showEmpty
                text: "Alles is up-to-date"
                color: Theme.green
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }

            // --- Lijst ----------------------------------------------------
            Item {
                width: parent.width
                height: popup.rows.length > 0 ? popup.listHeight : 0
                visible: popup.rows.length > 0

                ListView {
                    id: updateList

                    anchors.fill: parent
                    model: popup.rows
                    spacing: 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    opacity: Updates.busy ? 0.55 : 1

                    delegate: Item {
                        id: row

                        required property var modelData

                        width: popup.innerWidth
                        height: row.modelData.header
                            ? Theme.scaled(32) : Theme.scaled(42)

                        // Sectiekop
                        RowLayout {
                            anchors.fill: parent
                            visible: row.modelData.header
                            spacing: Theme.scaled(7)

                            Text {
                                text: row.modelData.icon
                                color: Theme.accentMuted
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.fontSmall
                            }

                            Text {
                                text: row.modelData.title
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "(" + row.modelData.count + ")"
                                color: Theme.overlay1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                            }
                        }

                        // Pakketregel
                        Rectangle {
                            anchors.fill: parent
                            visible: !row.modelData.header
                            radius: Theme.radiusSmall
                            color: rowHover.containsMouse ? Theme.surface0 : "transparent"

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: !row.modelData.header
                                    ? Theme.scaled(8) : 0
                                rightMargin: !row.modelData.header
                                    ? Theme.scaled(8) : 0
                            }
                            visible: !row.modelData.header
                            spacing: Theme.scaled(8)

                            Text {
                                text: row.modelData.icon
                                color: Theme.accent
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.fontSmall
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.maximumWidth: popup.innerWidth * 0.45
                                text: row.modelData.detail
                                color: Theme.barMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            // --- Voettekst ------------------------------------------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(8)

                Text {
                    Layout.fillWidth: true
                    text: Updates.busy
                        ? (Updates.pendingUpdate === "flatpak"
                            ? "Flatpaks worden bijgewerkt…"
                            : "Systeem wordt bijgewerkt…")
                        : (popup.confirmUpdate
                            ? "Nogmaals klikken: APT full-upgrade + Flatpak"
                            : (Updates.lastAction.length > 0
                                ? Updates.lastAction
                                : "Laatst gecontroleerd: "
                                    + Updates.updatedLabel()))
                    color: popup.confirmUpdate ? Theme.yellow
                        : (Updates.lastAction.length > 0 && !Updates.busy
                            ? Theme.green : Theme.overlay1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                Text {
                    visible: Updates.checked && Updates.aptAvailable
                        && !Updates.flatpakAvailable
                    text: "flatpak ontbreekt"
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }

                // Alles bijwerken: eerste klik wapent, tweede klik voert uit.
                Rectangle {
                    visible: Updates.hasUpdates
                    Layout.preferredWidth: updateLabel.implicitWidth
                        + Theme.scaled(18)
                    Layout.preferredHeight: Theme.scaled(24)
                    radius: Theme.radiusSmall
                    color: popup.confirmUpdate ? Theme.peach
                        : (updateArea.containsMouse
                            ? Theme.surface1 : Theme.surface0)
                    opacity: Updates.busy || Updates.loading ? 0.55 : 1

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.scaled(5)

                        Text {
                            text: "\uf019" // download
                            color: popup.confirmUpdate
                                ? Theme.crust : Theme.accent
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            id: updateLabel
                            text: Updates.busy ? "Bezig…"
                                : (popup.confirmUpdate ? "Zeker?" : "Bijwerken")
                            color: popup.confirmUpdate
                                ? Theme.crust : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: updateArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !Updates.busy && !Updates.loading
                            && Updates.hasUpdates
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.requestUpdate()
                    }
                }
            }
        }
    }
}
