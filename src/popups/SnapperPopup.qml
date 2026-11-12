// SnapperPopup.qml — momentopnamen onder de Snapper-widget in de bar.
//
// Toont de momentopnamen van de actieve snapper-configuratie, met per regel
// nummer, type, datum, gebruiker en beschrijving. Vanuit hier kan de
// configuratie worden gewisseld, een nieuwe momentopname worden aangemaakt
// (via het FloatingWindow SnapperCreateWindow), een momentopname worden
// verwijderd of teruggerold, en kunnen de oudste momentopnamen worden
// opgeruimd tot er maximaal 10 overblijven. Verwijderen, opruimen en rollback
// vragen om een tweede klik.
//
// Het venster opent onder de bar, rechts uitgelijnd. Onder X11 krijgt een
// PopupWindow geen toetsenbordfocus (issue #794); de popup bevat daarom geen
// tekstinvoer. Het aanmaakvenster is een FloatingWindow.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../services"

PopupWindow {
    id: popup

    property var barWindow: null

    signal createRequested()

    readonly property int preferredWidth: Theme.scaled(470)
    readonly property int padding: Theme.scaled(14)
    readonly property int innerWidth: preferredWidth - 2 * padding
    readonly property int listMaxHeight: Theme.scaled(430)

    property int confirmDelete: -1
    property int confirmRollback: -1
    property bool confirmCleanup: false

    readonly property bool showingAccessError:
        Snapper.accessError.length > 0 && Snapper.lastError.length === 0

    readonly property string problemText: {
        if (!Snapper.available)
            return "snapper is niet gevonden. Installeer het snapper-pakket."
        if (Snapper.lastError.length > 0)
            return Snapper.lastError
        return Snapper.accessError
    }

    implicitWidth: popup.preferredWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    grabFocus: false
    visible: false

    onVisibleChanged: {
        if (popup.barWindow)
            popup.barWindow.snapperPopupVisible = popup.visible
        if (popup.visible) {
            popup.clearConfirmations()
            Snapper.refresh()
        }
    }

    Timer {
        id: confirmTimer
        interval: 5000
        repeat: false
        running: false
        onTriggered: {
            popup.confirmDelete = -1
            popup.confirmRollback = -1
            popup.confirmCleanup = false
        }
    }

    function clearConfirmations() {
        popup.confirmDelete = -1
        popup.confirmRollback = -1
        popup.confirmCleanup = false
        confirmTimer.stop()
    }

    function requestDelete(number) {
        if (Snapper.busy)
            return
        popup.confirmRollback = -1
        popup.confirmCleanup = false
        if (popup.confirmDelete === number) {
            popup.confirmDelete = -1
            confirmTimer.stop()
            Snapper.remove(number)
            return
        }
        popup.confirmDelete = number
        confirmTimer.restart()
    }

    function requestRollback(number) {
        if (Snapper.busy || !Snapper.rollbackSupported)
            return
        popup.confirmDelete = -1
        popup.confirmCleanup = false
        if (popup.confirmRollback === number) {
            popup.confirmRollback = -1
            confirmTimer.stop()
            Snapper.rollback(number)
            return
        }
        popup.confirmRollback = number
        confirmTimer.restart()
    }

    function requestCleanup() {
        if (Snapper.busy || Snapper.cleanupCount === 0)
            return
        popup.confirmDelete = -1
        popup.confirmRollback = -1
        if (popup.confirmCleanup) {
            popup.confirmCleanup = false
            confirmTimer.stop()
            Snapper.cleanup(Snapper.cleanupLimit)
            return
        }
        popup.confirmCleanup = true
        confirmTimer.restart()
    }

    function typeColor(type) {
        if (type === "pre")
            return Theme.yellow
        if (type === "post")
            return Theme.green
        return Theme.accent
    }

    function typeBackground(type) {
        if (type === "pre")
            return Theme.surface0
        if (type === "post")
            return Theme.surface0
        return Theme.mantle
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
                    text: "\uf1da" // clock-rotate-left
                    color: Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                }

                Text {
                    text: "Momentopnamen"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: Snapper.loaded
                        ? (Snapper.accessError.length > 0
                            ? "—" : "(" + Snapper.snapshotCount + ")")
                        : ""
                    color: Theme.barMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }

                // Nieuwe momentopname opent het invoervenster. Een
                // PopupWindow kan onder X11 geen tekstfocus krijgen.
                Rectangle {
                    Layout.preferredWidth: newLabel.implicitWidth + Theme.scaled(18)
                    Layout.preferredHeight: Theme.scaled(24)
                    radius: Theme.radiusSmall
                    color: newArea.containsMouse ? Theme.surface1 : Theme.surface0
                    opacity: Snapper.available ? 1 : 0.45

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.scaled(5)

                        Text {
                            text: "\uf067" // plus
                            color: Theme.accent
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            id: newLabel
                            text: "Nieuwe"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: newArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Snapper.available && !Snapper.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.createRequested()
                    }
                }

                // Opruimen: eerste klik wapent, tweede klik verwijdert de
                // oudste momentopnamen tot er maximaal 10 overblijven.
                Rectangle {
                    Layout.preferredWidth: cleanupLabel.implicitWidth
                        + Theme.scaled(18)
                    Layout.preferredHeight: Theme.scaled(24)
                    radius: Theme.radiusSmall
                    color: popup.confirmCleanup ? Theme.red
                        : (cleanupArea.containsMouse
                            ? Theme.surface1 : Theme.surface0)
                    opacity: Snapper.available && Snapper.cleanupCount > 0
                        ? 1 : 0.45

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.scaled(5)

                        Text {
                            text: "\uf51a" // broom
                            color: popup.confirmCleanup
                                ? Theme.crust : Theme.accent
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            id: cleanupLabel
                            text: popup.confirmCleanup ? "Zeker?" : "Opruimen"
                            color: popup.confirmCleanup
                                ? Theme.crust : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: cleanupArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Snapper.available && !Snapper.busy
                            && Snapper.cleanupCount > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.requestCleanup()
                    }
                }

                Item {
                    Layout.preferredWidth: Theme.scaled(22)
                    Layout.preferredHeight: Theme.scaled(22)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: refreshArea.containsMouse ? Theme.surface0 : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf021" // rotate
                        color: Theme.accentMuted
                        opacity: Snapper.loading ? 0.5 : 1
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.fontSmall

                        RotationAnimator on rotation {
                            running: Snapper.loading
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
                        onClicked: Snapper.refresh()
                    }
                }

                Item {
                    Layout.preferredWidth: Theme.scaled(20)
                    Layout.preferredHeight: Theme.scaled(20)

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

            // --- Configuratie --------------------------------------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(8)
                visible: Snapper.configs.length > 0

                Text {
                    text: "Configuratie"
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }

                Row {
                    spacing: Theme.scaled(4)

                    Repeater {
                        model: Snapper.configs

                        delegate: Rectangle {
                            id: configChip

                            required property var modelData

                            readonly property bool current:
                                modelData.name === Snapper.activeConfig

                            width: configChipLabel.implicitWidth + Theme.scaled(14)
                            height: Theme.scaled(22)
                            radius: Theme.radiusSmall
                            color: configChip.current ? Theme.surface1
                                : (configChipArea.containsMouse
                                    ? Theme.surface0 : "transparent")
                            border.width: 1
                            border.color: configChip.current
                                ? Theme.accentMuted : "transparent"

                            Text {
                                id: configChipLabel
                                anchors.centerIn: parent
                                text: configChip.modelData.name
                                color: configChip.current ? Theme.text : Theme.barMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: configChip.current
                                    ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: configChipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Snapper.selectConfig(configChip.modelData.name)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Snapper.activeSubvolume
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
                visible: Snapper.configs.length > 0
            }

            // --- Fout- en lege staten ------------------------------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(8)
                visible: popup.problemText.length > 0

                Text {
                    Layout.alignment: Qt.AlignTop
                    text: "\uf071" // triangle-exclamation
                    color: Theme.yellow
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.fontNormal
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.scaled(4)

                    Text {
                        Layout.fillWidth: true
                        text: popup.showingAccessError
                            ? "Geen toegang" : "Snapper-fout"
                        color: Theme.yellow
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: popup.showingAccessError
                            ? popup.problemText
                                + ". Snapper beheert momentopnamen als root; voer eenmalig uit:"
                            : popup.problemText
                        color: Theme.barMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.WordWrap
                    }

                    // Het commando staat selecteerbaar in de popup, zodat de
                    // gebruiker het kan kopiëren naar een terminal.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: setupCommandText.implicitHeight
                            + Theme.scaled(12)
                        visible: popup.showingAccessError
                        radius: Theme.radiusSmall
                        color: Theme.mantle
                        border.width: 1
                        border.color: Theme.surface0

                        TextEdit {
                            id: setupCommandText

                            anchors {
                                fill: parent
                                margins: Theme.scaled(6)
                            }
                            text: Snapper.setupCommand
                            readOnly: true
                            selectByMouse: true
                            textFormat: TextEdit.PlainText
                            wrapMode: TextEdit.WrapAnywhere
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: popup.showingAccessError
                        text: "Daarna werken bekijken, aanmaken en verwijderen "
                            + "zonder sudo of polkit."
                        color: Theme.barMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                width: parent.width
                visible: Snapper.loading && Snapper.snapshotCount === 0
                    && popup.problemText.length === 0
                text: "Momentopnamen laden…"
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }

            Text {
                width: parent.width
                visible: Snapper.loaded && !Snapper.loading
                    && Snapper.snapshotCount === 0
                    && popup.problemText.length === 0
                text: "Nog geen momentopnamen"
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }

            // --- Lijst ---------------------------------------------------
            Item {
                width: parent.width
                height: Snapper.snapshotCount === 0
                    ? 0 : Math.min(popup.listMaxHeight, snapshotList.contentHeight)
                visible: Snapper.snapshotCount > 0

                ListView {
                    id: snapshotList

                    anchors.fill: parent
                    model: Snapper.snapshots
                    spacing: Theme.scaled(4)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    opacity: Snapper.busy ? 0.6 : 1

                    delegate: Rectangle {
                        id: row

                        required property var modelData

                        readonly property bool confirming:
                            popup.confirmDelete === row.modelData.number
                        readonly property bool confirmingRollback:
                            popup.confirmRollback === row.modelData.number
                        readonly property bool protectedSnapshot:
                            row.modelData.isDefault || row.modelData.isActive
                        readonly property bool rollbackProtected:
                            row.modelData.isActive
                                || !Snapper.rollbackSupported

                        width: popup.innerWidth
                        implicitHeight: rowContent.implicitHeight + Theme.scaled(12)
                        radius: Theme.radiusSmall
                        color: row.confirming || row.confirmingRollback
                            ? Theme.surface0
                            : (rowHover.containsMouse ? Theme.surface0 : Theme.mantle)
                        border.width: 1
                        border.color: row.confirming ? Theme.red
                            : (row.confirmingRollback ? Theme.yellow : Theme.surface0)

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        RowLayout {
                            id: rowContent

                            anchors {
                                fill: parent
                                leftMargin: Theme.scaled(8)
                                rightMargin: Theme.scaled(8)
                                topMargin: Theme.scaled(6)
                                bottomMargin: Theme.scaled(6)
                            }
                            spacing: Theme.scaled(7)

                            Rectangle {
                                Layout.preferredWidth: Theme.scaled(40)
                                Layout.preferredHeight: Theme.scaled(26)
                                Layout.alignment: Qt.AlignVCenter
                                radius: Theme.radiusSmall
                                color: Theme.base

                                Text {
                                    anchors.centerIn: parent
                                    text: "#" + row.modelData.number
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.scaled(5)

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.description.length > 0
                                            ? row.modelData.description
                                            : "Momentopname #" + row.modelData.number
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontNormal
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: row.modelData.isDefault
                                        text: "standaard"
                                        color: Theme.sky
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontTiny
                                    }

                                    Text {
                                        visible: row.modelData.isActive
                                        text: "actief"
                                        color: Theme.green
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontTiny
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (row.confirming)
                                            return "Klik op het vinkje om te verwijderen"
                                        if (row.confirmingRollback)
                                            return "Klik nogmaals om terug te rollen"
                                        let value = Snapper.dateLabel(row.modelData.date)
                                        if (row.modelData.user.length > 0)
                                            value += " · " + row.modelData.user
                                        return value
                                    }
                                    color: row.confirming ? Theme.red
                                        : (row.confirmingRollback
                                            ? Theme.yellow : Theme.barMuted)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: Theme.scaled(48)
                                Layout.preferredHeight: Theme.scaled(20)
                                Layout.alignment: Qt.AlignVCenter
                                radius: Theme.radiusSmall
                                color: popup.typeBackground(row.modelData.type)

                                Text {
                                    anchors.centerIn: parent
                                    text: Snapper.typeLabel(row.modelData.type)
                                    color: popup.typeColor(row.modelData.type)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    font.weight: Font.DemiBold
                                }
                            }

                            // Rollback: één klik wapent, het vinkje
                            // bevestigt. De actieve momentopname is geen
                            // zinvol doel en krijgt daarom een slotje.
                            Item {
                                Layout.preferredWidth: Theme.scaled(22)
                                Layout.preferredHeight: Theme.scaled(22)
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusSmall
                                    color: row.rollbackProtected
                                        ? "transparent"
                                        : (row.confirmingRollback
                                            ? Theme.yellow
                                            : (rollbackArea.containsMouse
                                                ? Theme.surface1 : "transparent"))
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: row.rollbackProtected
                                        || !row.confirmingRollback
                                    text: row.rollbackProtected
                                        ? "\uf023" // lock
                                        : "\uf0e2" // arrow-rotate-left
                                    color: row.rollbackProtected
                                        ? Theme.overlay1
                                        : (row.confirmingRollback
                                            ? Theme.crust : Theme.yellow)
                                    opacity: row.rollbackProtected ? 0.7 : 0.9
                                    font.family: Theme.iconFamily
                                    font.pixelSize: Theme.fontSmall
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !row.rollbackProtected
                                        && row.confirmingRollback
                                    text: "\uf00c" // check
                                    color: Theme.crust
                                    font.family: Theme.iconFamily
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: rollbackArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !row.rollbackProtected
                                        && !Snapper.busy
                                    cursorShape: row.rollbackProtected
                                        ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: popup.requestRollback(
                                        row.modelData.number)
                                }
                            }

                            // Verwijderen: één klik wapent, het vinkje
                            // bevestigt. Standaard- en actieve snapshots zijn
                            // door snapper beschermd en krijgen een slotje.
                            Item {
                                Layout.preferredWidth: Theme.scaled(22)
                                Layout.preferredHeight: Theme.scaled(22)
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusSmall
                                    color: row.protectedSnapshot
                                        ? "transparent"
                                        : (row.confirming
                                            ? Theme.red
                                            : (deleteArea.containsMouse
                                                ? Theme.surface1 : "transparent"))
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: row.protectedSnapshot || !row.confirming
                                    text: row.protectedSnapshot
                                        ? "\uf023" // lock
                                        : "\uf1f8" // trash-can
                                    color: row.protectedSnapshot
                                        ? Theme.overlay1 : Theme.red
                                    opacity: row.protectedSnapshot ? 0.7 : 0.9
                                    font.family: Theme.iconFamily
                                    font.pixelSize: Theme.fontSmall
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !row.protectedSnapshot && row.confirming
                                    text: "\uf00c" // check
                                    color: Theme.crust
                                    font.family: Theme.iconFamily
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: deleteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !row.protectedSnapshot
                                        && !row.confirmingRollback
                                        && !Snapper.busy
                                    cursorShape: row.protectedSnapshot
                                        ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: popup.requestDelete(row.modelData.number)
                                }
                            }

                            // Annuleren verschijnt naast het vinkje.
                            Item {
                                Layout.preferredWidth:
                                    row.confirming || row.confirmingRollback
                                        ? Theme.scaled(22) : 0
                                Layout.preferredHeight: Theme.scaled(22)
                                Layout.alignment: Qt.AlignVCenter
                                visible: row.confirming || row.confirmingRollback

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusSmall
                                    color: cancelArea.containsMouse
                                        ? Theme.surface1 : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d" // xmark
                                    color: Theme.overlay1
                                    font.family: Theme.iconFamily
                                    font.pixelSize: Theme.fontSmall
                                }

                                MouseArea {
                                    id: cancelArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup.clearConfirmations()
                                }
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

            // --- Voettekst -----------------------------------------------
            RowLayout {
                width: parent.width
                spacing: Theme.scaled(8)

                Text {
                    Layout.fillWidth: true
                    text: Snapper.busy && Snapper.pendingAction === "cleanup"
                        ? "Oudste momentopnamen worden opgeruimd…"
                        : (Snapper.busy && Snapper.pendingAction === "rollback"
                            ? "Rollback wordt voorbereid…"
                            : (popup.confirmCleanup
                                ? "Verwijdert " + Snapper.cleanupCount
                                    + " oudste momentopnamen; max "
                                    + Snapper.cleanupLimit + " blijven staan"
                                : (popup.confirmRollback >= 0
                                    ? "Rollback naar #"
                                        + popup.confirmRollback
                                        + " voorbereiden; daarna herstarten"
                                    : (Snapper.busy
                                        && Snapper.pendingAction === "create"
                                        ? "Momentopname wordt aangemaakt…"
                                        : (Snapper.busy
                                            && Snapper.pendingAction === "delete"
                                            ? "Momentopname wordt verwijderd…"
                                            : (Snapper.accessError.length > 0
                                                ? "Geen leestoegang — acties vragen om bevoegdheid"
                                                : "Laatst bijgewerkt: "
                                                    + Snapper.updatedLabel()))))))
                    color: popup.confirmCleanup ? Theme.red
                        : (popup.confirmRollback >= 0 || Snapper.busy
                            ? Theme.yellow : Theme.overlay1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                Text {
                    visible: Snapper.lastAction.length > 0 && !Snapper.busy
                    text: Snapper.lastAction
                    color: Theme.green
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
