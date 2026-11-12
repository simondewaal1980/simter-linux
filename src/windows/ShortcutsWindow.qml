// ShortcutsWindow.qml — doorzoekbaar sneltoetsenoverzicht en editor (fase 8).
//
// Leest ~/.config/sxhkd/sxhkdrc met FileView.watchChanges en parseert die met
// SxhkdParser.js. Daardoor is dit venster per definitie dezelfde bron als de
// sneltoetsen die sxhkd daadwerkelijk gebruikt: na een wijziging + SIGUSR1
// verschijnt de nieuwe binding hier automatisch.
//
// Eigen bindingen voeg je met “Nieuwe sneltoets” toe. Die worden als
// gemarkeerd blok (zie SxhkdParser.js) achteraan dezelfde sxhkdrc bewaard,
// zodat sxhkd en het overzicht één bron blijven. Bestaande, handmatige regels
// worden nooit herschreven; alleen blokken met een @qs-shortcut-marker zijn
// vanuit dit venster te bewerken of te verwijderen.
//
// Zoeken filtert op omschrijving, toetsen, commando en groep. De groepskeuze
// staat in een horizontaal scrollbare rij chips. Als FloatingWindow krijgt het
// venster onder X11 wel toetsenbordfocus (issue #794 geldt alleen voor
// PopupWindows), dus het zoekveld en het formulier werken gewoon.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../components"
import "../utils/SxhkdParser.js" as SxhkdParser

FloatingWindow {
    id: win

    title: "Sneltoetsen"
    implicitWidth: 940
    implicitHeight: 680
    minimumSize: Qt.size(780, 520)
    color: Theme.base
    visible: false

    readonly property string sxhkdrcPath:
        Quickshell.env("HOME") + "/.config/sxhkd/sxhkdrc"

    readonly property string customGroupName: "Eigen sneltoetsen"

    // --- Geparseerde inhoud ----------------------------------------------

    property var entries: []
    property var groups: []
    property string parseError: ""
    property string sourceText: ""

    property string searchText: ""
    property string activeGroup: ""

    // --- Eigen sneltoetsen bewerken --------------------------------------

    property bool editorOpen: false
    property string editingId: ""
    property string formKeys: ""
    property string formDescription: ""
    property string formCommand: ""
    property string formGroup: win.customGroupName
    property string formError: ""
    property string statusMessage: ""
    property string confirmDeleteId: ""

    readonly property var filteredEntries:
        SxhkdParser.filter(win.entries, win.searchText, win.activeGroup)
    readonly property var sections:
        SxhkdParser.groupEntries(win.filteredEntries)

    readonly property int matchCount: win.filteredEntries.length

    function applyParsedText(text) {
        const result = SxhkdParser.parseResult(text)
        win.entries = result.entries
        win.groups = result.groups
        win.parseError = result.error
        if (win.activeGroup.length > 0
                && result.groups.indexOf(win.activeGroup) < 0)
            win.activeGroup = ""
    }

    function reloadFromDisk() {
        const text = sxhkdFile.text()
        win.sourceText = text === null || text === undefined ? "" : text
        win.applyParsedText(win.sourceText)
    }

    function openWindow() {
        // FileView.watchChanges is onder X11 niet altijd betrouwbaar voor een
        // symlink; lees bij openen expliciet opnieuw. onLoaded parseert daarna
        // nog eens, zodat een net gewijzigd bestand zeker meegenomen wordt.
        sxhkdFile.reload()
        win.reloadFromDisk()
        refreshTimer.restart()
        win.visible = true
    }

    function closeWindow() {
        win.visible = false
    }

    function toggleWindow() {
        if (win.visible)
            win.closeWindow()
        else
            win.openWindow()
    }

    function open() {
        win.openWindow()
    }

    function close() {
        win.closeWindow()
    }

    function toggle() {
        win.toggleWindow()
    }

    function clearSearch() {
        win.searchText = ""
        searchField.text = ""
    }

    // --- Formulier --------------------------------------------------------

    function showStatus(text) {
        win.statusMessage = text
        statusTimer.restart()
    }

    function focusKeysField() {
        Qt.callLater(function () {
            if (win.editorOpen)
                keysField.input.forceActiveFocus()
        })
    }

    function startAdd() {
        win.editingId = ""
        win.formKeys = ""
        win.formDescription = ""
        win.formCommand = ""
        win.formGroup = win.customGroupName
        win.formError = ""
        win.confirmDeleteId = ""
        win.editorOpen = true
        win.focusKeysField()
    }

    function startEdit(entry) {
        win.editingId = entry.id || ""
        win.formKeys = entry.sourceKey || entry.key || ""
        win.formDescription = entry.description || ""
        win.formCommand = entry.sourceCommand || entry.command || ""
        win.formGroup = entry.group || win.customGroupName
        win.formError = ""
        win.confirmDeleteId = ""
        win.editorOpen = true
        win.focusKeysField()
    }

    function cancelEdit() {
        win.editorOpen = false
        win.formError = ""
        win.confirmDeleteId = ""
        searchField.forceActiveFocus()
    }

    function hasModifier(raw, name) {
        const parts = String(raw || "").toLowerCase().split("+")
        for (var i = 0; i < parts.length; i++) {
            const token = parts[i].trim()
            if (token === name)
                return true
            if (name === "super" && token === "mod4")
                return true
            if (name === "ctrl" && token === "control")
                return true
            if (name === "alt" && token === "mod1")
                return true
        }
        return false
    }

    function toggleModifier(name) {
        win.formKeys = SxhkdParser.toggleModifier(win.formKeys, name)
        keysField.input.forceActiveFocus()
    }

    // Schrijft één eigen binding naar de sxhkdrc. Wordt zowel door het
    // formulier als door IPC gebruikt; de bron blijft hetzelfde bestand.
    function saveShortcut(data) {
        if (!data || typeof data !== "object")
            return { ok: false, error: "Geen sneltoetsgegevens", id: "" }

        const checked = SxhkdParser.validateKeys(data.keys)
        if (!checked.ok)
            return { ok: false, error: checked.error, id: "" }

        const command = String(data.command === null
            || data.command === undefined ? "" : data.command).trim()
        if (command.length === 0)
            return { ok: false, error: "Vul een commando in", id: "" }
        if (/[\r\n]/.test(command))
            return {
                ok: false,
                error: "Het commando moet op één regel passen",
                id: ""
            }

        const description = String(data.description === null
            || data.description === undefined ? "" : data.description).trim()
        const group = String(data.group === null || data.group === undefined
            ? "" : data.group).trim() || win.customGroupName
        const editingId = String(data.id === null || data.id === undefined
            ? "" : data.id)
        const signatures = SxhkdParser.keySignatures(checked.keys)

        for (var i = 0; i < win.entries.length; i++) {
            const entry = win.entries[i]
            if (entry.id && entry.id === editingId)
                continue
            if (signatures.indexOf(SxhkdParser.keySignature(entry.key)) >= 0) {
                const label = entry.description.length > 0
                    ? entry.description : entry.key
                return {
                    ok: false,
                    id: "",
                    error: "Deze combinatie is al in gebruik: " + label
                }
            }
        }

        const current = win.sourceText.length > 0
            ? win.sourceText : (sxhkdFile.text() || "")
        const result = SxhkdParser.upsertCustomShortcut(current, {
            id: editingId,
            keys: checked.keys,
            description: description,
            command: command,
            group: group
        })
        if (!result.ok)
            return { ok: false, error: result.error, id: "" }

        win.sourceText = result.text
        win.applyParsedText(result.text)
        win.editingId = result.id
        sxhkdWriter.setText(result.text)
        win.reloadSxhkd()
        return { ok: true, error: "", id: result.id }
    }

    function saveEntry() {
        const wasEditing = win.editingId.length > 0
        const result = win.saveShortcut({
            id: win.editingId,
            keys: win.formKeys,
            description: win.formDescription,
            command: win.formCommand,
            group: win.formGroup
        })
        if (!result.ok) {
            win.formError = result.error
            return
        }
        win.editorOpen = false
        win.formError = ""
        win.showStatus(wasEditing
            ? "Sneltoets bijgewerkt" : "Sneltoets toegevoegd")
    }

    function deleteShortcut(id) {
        const result = SxhkdParser.removeCustomShortcut(win.sourceText, id)
        if (!result.ok) {
            win.showStatus(result.error)
            return false
        }
        win.sourceText = result.text
        win.applyParsedText(result.text)
        win.confirmDeleteId = ""
        deleteTimer.stop()
        sxhkdWriter.setText(result.text)
        win.reloadSxhkd()
        win.showStatus("Sneltoets verwijderd")
        return true
    }

    function requestDelete(entry) {
        if (win.confirmDeleteId === entry.id) {
            win.deleteShortcut(entry.id)
            return
        }
        win.confirmDeleteId = entry.id
        win.showStatus("Klik nog een keer op de prullenbak om te verwijderen")
        deleteTimer.restart()
    }

    function addShortcut(keys, description, command, group) {
        return win.saveShortcut({
            id: "",
            keys: keys,
            description: description,
            command: command,
            group: group
        })
    }

    function removeShortcut(id) {
        return win.deleteShortcut(id)
    }

    function reloadSxhkd() {
        if (!sxhkdReloadProcess.running)
            sxhkdReloadProcess.running = true
    }

    onClosed: win.visible = false

    onVisibleChanged: {
        if (win.visible) {
            win.reloadFromDisk()
            searchField.forceActiveFocus()
        } else {
            win.editorOpen = false
            win.confirmDeleteId = ""
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
            if (win.editorOpen) {
                win.cancelEdit()
                return
            }
            if (searchField.text.length > 0)
                win.clearSearch()
            else
                win.closeWindow()
        }
    }

    Timer {
        id: refreshTimer
        interval: 80
        repeat: false
        running: false
        onTriggered: sxhkdFile.reload()
    }

    Timer {
        id: statusTimer
        interval: 4200
        repeat: false
        running: false
        onTriggered: win.statusMessage = ""
    }

    Timer {
        id: deleteTimer
        interval: 3200
        repeat: false
        running: false
        onTriggered: win.confirmDeleteId = ""
    }

    // --- Bestand ----------------------------------------------------------

    FileView {
        id: sxhkdFile

        path: win.sxhkdrcPath
        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: win.reloadFromDisk()
        // Bij een atomaire schrijfactie is de cache op het moment van het
        // event soms nog de oude inhoud. Vraag daarom een echte herlaad aan;
        // onLoaded parseert daarna de nieuwe tekst.
        onFileChanged: sxhkdFile.reload()
    }

    // Schrijft eigen bindingen terug naar dezelfde sxhkdrc. Atomair, zodat
    // een crash nooit een half bestand achterlaat; de lezer hierboven ziet
    // de wijziging via watchChanges en via de expliciete reload.
    FileView {
        id: sxhkdWriter

        path: win.sxhkdrcPath
        atomicWrites: true
        printErrors: false

        onSaved: refreshTimer.restart()
        onSaveFailed: (error) => {
            win.showStatus("Opslaan van sxhkdrc mislukt")
        }
    }

    Process {
        id: sxhkdReloadProcess
        command: ["pkill", "-USR1", "sxhkd"]

        onExited: (exitCode) => {
            if (exitCode !== 0)
                win.showStatus("Opgeslagen; sxhkd draait niet")
        }
    }

    // --- Titelbalk --------------------------------------------------------

    Item {
        anchors.fill: parent
        focus: true

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
            height: 50
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
                    leftMargin: 18
                    rightMargin: 12
                }
                spacing: 10

                Text {
                    text: "\uf11c" // keyboard
                    color: Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.fontLarge
                }

                Text {
                    text: "Sneltoetsen"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge + 1
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: win.matchCount + " van " + win.entries.length
                        + " bindingen"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                ActionButton {
                    text: "Nieuwe sneltoets"
                    primary: true
                    onClicked: win.startAdd()
                }

                Item {
                    width: 24
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: closeArea.containsMouse ? Theme.surface0 : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: Theme.overlay1
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.fontNormal
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

        // --- Zoeken en groepen -------------------------------------------

        Rectangle {
            id: searchBar

            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
            }
            height: 92
            color: Theme.base

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 18
                    rightMargin: 18
                    topMargin: 10
                }
                spacing: 8

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: Theme.radiusSmall
                    color: Theme.mantle
                    border.width: 1
                    border.color: searchField.activeFocus
                        ? Theme.accent : Theme.surface0

                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 9
                            rightMargin: 7
                        }
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf002" // magnifying-glass
                            color: Theme.overlay0
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        TextField {
                            id: searchField

                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24 - clearSearchLabel.width
                            height: 26
                            padding: 0
                            background: Item {}
                            text: win.searchText
                            placeholderText: "Zoek op toets, omschrijving of commando…"
                            placeholderTextColor: Theme.overlay0
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            selectByMouse: true
                            onTextChanged: win.searchText = text
                        }

                        Item {
                            id: clearSearchLabel

                            width: 18
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                color: clearArea.containsMouse
                                    ? Theme.text : Theme.overlay0
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.fontSmall
                            }

                            MouseArea {
                                id: clearArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.clearSearch()
                            }
                        }
                    }
                }

                Flickable {
                    id: groupBar

                    width: parent.width
                    height: 26
                    contentWidth: groupRow.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: groupRow
                        spacing: 6

                        Repeater {
                            model: [""].concat(win.groups)

                            delegate: Rectangle {
                                id: groupChip

                                required property var modelData

                                readonly property bool active:
                                    win.activeGroup === modelData
                                readonly property string label:
                                    modelData.length === 0
                                        ? "Alle groepen" : modelData

                                width: chipLabel.implicitWidth + 20
                                height: 24
                                radius: 12
                                color: groupChip.active
                                    ? Theme.accent
                                    : (chipArea.containsMouse
                                        ? Theme.surface1 : Theme.surface0)

                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: groupChip.label
                                    color: groupChip.active
                                        ? Theme.crust : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: groupChip.active
                                        ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.activeGroup = groupChip.modelData
                                }
                            }
                        }
                    }

                    WheelHandler {
                        onWheel: (event) => {
                            groupBar.contentX = Math.max(0, Math.min(
                                groupBar.contentWidth - groupBar.width,
                                groupBar.contentX - event.angleDelta.y * 0.8))
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 1
                color: Theme.surface0
            }
        }

        // --- Lijst --------------------------------------------------------

        Rectangle {
            id: footer

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 38
            color: Theme.mantle

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 1
                color: Theme.surface0
            }

            RowLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: win.parseError.length > 0
                        ? win.parseError
                        : (win.statusMessage.length > 0
                            ? win.statusMessage
                            : "Bron: " + win.sxhkdrcPath
                                + " — herladen met pkill -USR1 sxhkd")
                    color: win.parseError.length > 0
                        ? Theme.red
                        : (win.statusMessage.length > 0
                            ? Theme.green : Theme.overlay1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                }

                Text {
                    text: win.editorOpen ? "Esc annuleert" : "Esc sluit"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }
        }

        Flickable {
            id: listView

            anchors {
                left: parent.left
                right: parent.right
                top: searchBar.bottom
                bottom: footer.top
            }
            contentWidth: width
            contentHeight: listColumn.implicitHeight + 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                onWheel: (event) => {
                    listView.contentY = Math.max(0, Math.min(
                        listView.contentHeight - listView.height,
                        listView.contentY - event.angleDelta.y * 0.7))
                }
            }

            Column {
                id: listColumn

                x: 18
                y: 14
                width: listView.width - 36
                spacing: 4

                // Lege staat.
                Text {
                    visible: win.entries.length === 0
                    width: parent.width
                    text: win.parseError.length > 0
                        ? win.parseError
                        : "Geen sneltoetsen gevonden in " + win.sxhkdrcPath
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: win.sections

                    delegate: Column {
                        id: section

                        required property var modelData

                        width: listColumn.width
                        spacing: 6

                        // Groepskop.
                        Item {
                            width: parent.width
                            height: 30

                            Text {
                                anchors {
                                    left: parent.left
                                    bottom: parent.bottom
                                    bottomMargin: 4
                                }
                                text: section.modelData.name
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.8
                            }

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                height: 1
                                color: Theme.surface0
                            }
                        }

                        Repeater {
                            model: section.modelData.entries

                            delegate: Rectangle {
                                id: entry

                                required property var modelData

                                width: section.width
                                implicitHeight: entryContent.implicitHeight + 18
                                radius: Theme.radiusSmall
                                color: entryHover.containsMouse
                                    ? Theme.mantle : "transparent"

                                MouseArea {
                                    id: entryHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    id: entryContent

                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        leftMargin: 10
                                        rightMargin: 10
                                        topMargin: 9
                                    }
                                    spacing: 14

                                    // Toetscombinatie(s).
                                    Column {
                                        Layout.preferredWidth: Math.min(
                                            300, section.width * 0.38)
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 4

                                        Row {
                                            spacing: 3

                                            Repeater {
                                                model: entry.modelData.chords

                                                delegate: Row {
                                                    id: chord

                                                    required property var modelData
                                                    required property int index

                                                    spacing: 3

                                                    Repeater {
                                                        model: chord.modelData

                                                        delegate: Keycap {
                                                            required property var modelData

                                                            label: modelData
                                                            modifier: {
                                                                const lower =
                                                                    String(modelData).toLowerCase()
                                                                return lower === "super"
                                                                    || lower === "shift"
                                                                    || lower === "ctrl"
                                                                    || lower === "alt"
                                                                    || lower.indexOf("mod") === 0
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        anchors.verticalCenter:
                                                            parent.verticalCenter
                                                        visible: chord.index
                                                            < entry.modelData.chords.length - 1
                                                        text: "\uf061" // arrow-right
                                                        color: Theme.overlay0
                                                        font.family: Theme.iconFamily
                                                        font.pixelSize: Theme.fontTiny
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: entry.modelData.description.length > 0
                                                ? entry.modelData.description
                                                : "Sneltoets"
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontNormal
                                            font.weight: Font.DemiBold
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    // Commando.
                                    Column {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: entry.modelData.command
                                            color: Theme.subtext0
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSmall
                                            wrapMode: Text.WrapAnywhere
                                            textFormat: Text.PlainText
                                        }

                                        Text {
                                            text: "regel " + entry.modelData.line
                                            color: Theme.overlay0
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontTiny
                                        }
                                    }

                                    // Eigen bindingen zijn hier te bewerken
                                    // of te verwijderen; de vaste sxhkdrc-
                                    // regels blijven alleen-lezen.
                                    Row {
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 3
                                        visible: entry.modelData.custom === true

                                        IconButton {
                                            icon: "\uf044" // pencil
                                            onClicked: win.startEdit(entry.modelData)
                                        }

                                        IconButton {
                                            icon: "\uf2ed" // trash
                                            danger: win.confirmDeleteId
                                                === entry.modelData.id
                                            onClicked: win.requestDelete(
                                                entry.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Ruimte onderaan, zodat de laatste regel niet tegen de
                // voettekst plakt.
                Item {
                    width: parent.width
                    height: 10
                }
            }
        }

        // --- Editor voor eigen sneltoetsen --------------------------------

        Rectangle {
            id: editorOverlay

            anchors.fill: parent
            z: 100
            visible: win.editorOpen
            color: "#b3000000"

            // Achtergrond blokkeert klikken op de lijst eronder.
            MouseArea {
                anchors.fill: parent
            }

            Rectangle {
                id: editorCard

                width: Math.min(660, parent.width - 80)
                implicitHeight: editorColumn.implicitHeight + 40
                anchors.centerIn: parent
                radius: Theme.radiusSmall + 2
                color: Theme.base
                border.width: 1
                border.color: Theme.surface1

                Keys.onEscapePressed: win.cancelEdit()

                Column {
                    id: editorColumn

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: 20
                        rightMargin: 20
                        topMargin: 18
                    }
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: win.editingId.length > 0
                                ? "Sneltoets bewerken" : "Nieuwe sneltoets"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLarge + 1
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        IconButton {
                            icon: "\uf00d" // xmark
                            onClicked: win.cancelEdit()
                        }
                    }

                    Text {
                        width: parent.width
                        text: "De binding wordt onderaan de sxhkdrc bewaard en "
                            + "direct met pkill -USR1 aan sxhkd doorgegeven."
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.WordWrap
                    }

                    FormField {
                        label: "Toetsen"
                        hint: "Tip: gebruik plus voor de +-toets. Brace-expansie "
                            + "zoals super + {h,j,k,l} mag ook."

                        InputField {
                            id: keysField

                            placeholderText: "super + shift + e"
                            text: win.formKeys
                            onTextChanged: win.formKeys = text
                            onAccepted: win.saveEntry()
                        }

                        Row {
                            spacing: 5

                            Repeater {
                                model: ["super", "ctrl", "alt", "shift"]

                                delegate: Rectangle {
                                    id: modifierChip

                                    required property var modelData

                                    readonly property bool active:
                                        win.hasModifier(win.formKeys, modelData)

                                    width: modifierLabel.implicitWidth + 18
                                    height: 22
                                    radius: 11
                                    color: modifierChip.active
                                        ? Theme.accent
                                        : (modifierArea.containsMouse
                                            ? Theme.surface1 : Theme.surface0)

                                    Text {
                                        id: modifierLabel

                                        anchors.centerIn: parent
                                        text: modifierChip.modelData === "super"
                                            ? "Super"
                                            : (modifierChip.modelData === "ctrl"
                                                ? "Ctrl"
                                                : (modifierChip.modelData === "alt"
                                                    ? "Alt" : "Shift"))
                                        color: modifierChip.active
                                            ? Theme.crust : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSmall
                                        font.weight: modifierChip.active
                                            ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        id: modifierArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.toggleModifier(
                                            modifierChip.modelData)
                                    }
                                }
                            }
                        }
                    }

                    FormField {
                        label: "Omschrijving"
                        hint: "Deze tekst verschijnt boven de toetsen in het overzicht."

                        InputField {
                            placeholderText: "Wat doet deze sneltoets?"
                            text: win.formDescription
                            onTextChanged: win.formDescription = text
                            onAccepted: win.saveEntry()
                        }
                    }

                    FormField {
                        label: "Groep"
                        hint: "Leeg laten zet de binding onder “Eigen sneltoetsen”."

                        InputField {
                            placeholderText: win.customGroupName
                            text: win.formGroup
                            onTextChanged: win.formGroup = text
                            onAccepted: win.saveEntry()
                        }
                    }

                    FormField {
                        label: "Commando"
                        hint: "Eén regel, bijvoorbeeld: alacritty -e htop"

                        InputField {
                            placeholderText: "alacritty"
                            text: win.formCommand
                            onTextChanged: win.formCommand = text
                            onAccepted: win.saveEntry()
                        }
                    }

                    Text {
                        visible: win.formError.length > 0
                        width: parent.width
                        text: win.formError
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }

                        ActionButton {
                            text: "Annuleren"
                            onClicked: win.cancelEdit()
                        }

                        ActionButton {
                            text: win.editingId.length > 0
                                ? "Opslaan" : "Toevoegen"
                            primary: true
                            onClicked: win.saveEntry()
                        }
                    }
                }
            }
        }
    }

    // ====================================================================
    // Inline componenten
    // ====================================================================

    component ActionButton: Rectangle {
        id: actionButton

        property string text: ""
        property bool primary: false
        property bool danger: false

        signal clicked()

        implicitWidth: actionLabel.implicitWidth + Theme.scaled(24)
        implicitHeight: Theme.scaled(30)
        width: implicitWidth
        height: implicitHeight
        radius: Theme.radiusSmall
        color: {
            if (actionButton.primary)
                return actionArea.containsMouse ? Theme.lavender : Theme.accent
            if (actionButton.danger)
                return actionArea.containsMouse ? Theme.red : Theme.surface1
            return actionArea.containsMouse ? Theme.surface1 : Theme.surface0
        }
        border.width: 1
        border.color: actionButton.primary ? Theme.accent : Theme.surface1

        Text {
            id: actionLabel

            anchors.centerIn: parent
            text: actionButton.text
            color: actionButton.primary || actionButton.danger
                ? Theme.crust : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            font.weight: actionButton.primary ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }

    component IconButton: Rectangle {
        id: iconButton

        property string icon: ""
        property bool danger: false

        signal clicked()

        width: Theme.scaled(24)
        height: Theme.scaled(24)
        radius: Theme.radiusSmall
        color: iconArea.containsMouse
            ? (iconButton.danger ? Theme.red : Theme.surface1)
            : "transparent"

        Text {
            anchors.centerIn: parent
            text: iconButton.icon
            color: iconButton.danger ? Theme.crust : Theme.overlay1
            font.family: Theme.iconFamily
            font.pixelSize: Theme.fontSmall
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }
    }

    component FormField: Column {
        id: formField

        property string label: ""
        property string hint: ""
        default property alias contentData: fieldContent.data

        width: parent ? parent.width : 0
        spacing: 5

        Text {
            width: parent.width
            text: formField.label
            color: Theme.overlay1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }

        Column {
            id: fieldContent
            width: parent.width
            spacing: 5
        }

        Text {
            visible: formField.hint.length > 0
            width: parent.width
            text: formField.hint
            color: Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
            wrapMode: Text.WordWrap
        }
    }

    component InputField: Rectangle {
        id: inputField

        property alias text: input.text
        property alias input: input
        property string placeholderText: ""

        signal accepted()

        width: parent ? parent.width : 0
        height: Theme.scaled(30)
        radius: Theme.radiusSmall
        color: Theme.mantle
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.surface0

        TextField {
            id: input

            anchors.fill: parent
            leftPadding: 9
            rightPadding: 9
            topPadding: 0
            bottomPadding: 0
            background: Item {}
            color: Theme.text
            placeholderText: inputField.placeholderText
            placeholderTextColor: Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            selectByMouse: true
            onAccepted: inputField.accepted()
        }
    }
}
