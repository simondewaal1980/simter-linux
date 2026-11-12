// WallpaperWindow.qml — wallpapers kiezen, previewen, toevoegen en verwijderen.
//
// Het venster toont alle wallpapers die scripts/wallpaper-theme.sh kent:
// ~/Pictures/wallpaper.jpg en ~/Pictures/Wallpapers/. Klikken selecteert een
// wallpaper en toont hem groot rechts; dubbelklikken of “Toepassen” zet hem
// met het themascript (feh + matugen + BSPWM + GTK + alacritty + rofi).
//
// “Toevoegen” opent een ingebouwde bestandsbrowser. Die werkt zonder zenity of
// een desktop-portal: mappen worden met `find` gelezen, afbeeldingen direct
// gepreviewd en pas bij “Toevoegen” naar de wallpapermappen gekopieerd.
//
// Als FloatingWindow krijgt het venster onder X11 toetsenbordfocus, zodat het
// padveld en Escape werken.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

FloatingWindow {
    id: win

    title: "Wallpapers"
    implicitWidth: 1120
    implicitHeight: 760
    minimumSize: Qt.size(880, 600)
    color: Theme.base
    visible: false

    property string selectedPath: ""
    property string statusMessage: ""
    property string confirmDeletePath: ""

    // --- Bestandsbrowser ---------------------------------------------------

    property bool pickerOpen: false
    property string pickerPath: Quickshell.env("HOME") + "/Pictures"
    property string pickerDraftPath: win.pickerPath
    property var pickerEntries: []
    property string pickerSelected: ""
    property bool pickerScanning: false
    property string pickerError: ""

    readonly property string home: Quickshell.env("HOME")

    // --- Venster -----------------------------------------------------------

    function openWindow() {
        Wallpaper.lastError = ""
        win.statusMessage = ""
        win.confirmDeletePath = ""
        Wallpaper.refresh()
        win.ensureSelection()
        win.visible = true
        rootFocus.forceActiveFocus()
    }

    function closeWindow() {
        win.pickerOpen = false
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

    function ensureSelection() {
        if (win.selectedPath.length > 0 && Wallpaper.hasPath(win.selectedPath))
            return
        if (Wallpaper.currentPath.length > 0
                && Wallpaper.hasPath(Wallpaper.currentPath)) {
            win.selectedPath = Wallpaper.currentPath
            return
        }
        win.selectedPath = Wallpaper.items.length > 0
            ? Wallpaper.items[0].path : ""
    }

    function selectedItem() {
        for (let i = 0; i < Wallpaper.items.length; i++) {
            if (Wallpaper.items[i].path === win.selectedPath)
                return Wallpaper.items[i]
        }
        return null
    }

    function showMessage(text) {
        win.statusMessage = text
        messageTimer.restart()
    }

    function applySelected() {
        if (win.selectedPath.length === 0 || Wallpaper.busy)
            return
        if (Wallpaper.apply(win.selectedPath))
            win.showMessage("Bezig met toepassen…")
    }

    function applyNext() {
        if (Wallpaper.busy)
            return
        if (Wallpaper.next())
            win.showMessage("Volgende wallpaper wordt toegepast…")
    }

    function requestDelete() {
        if (win.selectedPath.length === 0 || Wallpaper.busy)
            return
        if (win.confirmDeletePath === win.selectedPath) {
            win.confirmDeletePath = ""
            deleteTimer.stop()
            if (Wallpaper.remove(win.selectedPath))
                win.showMessage("Bezig met verwijderen…")
            return
        }
        win.confirmDeletePath = win.selectedPath
        deleteTimer.restart()
        win.showMessage("Nog één keer klikken om te verwijderen")
    }

    onClosed: win.visible = false

    onVisibleChanged: {
        if (win.visible) {
            Wallpaper.refresh()
            win.ensureSelection()
            rootFocus.forceActiveFocus()
        } else {
            win.pickerOpen = false
        }
    }

    Timer {
        id: messageTimer
        interval: 4500
        repeat: false
        onTriggered: win.statusMessage = ""
    }

    Timer {
        id: deleteTimer
        interval: 3500
        repeat: false
        onTriggered: win.confirmDeletePath = ""
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
            if (win.pickerOpen)
                win.closePicker()
            else
                win.closeWindow()
        }
    }

    Connections {
        target: Wallpaper

        function onItemsChanged() {
            if (!win.visible)
                return
            win.ensureSelection()
        }

        function onAdded(path) {
            win.pickerOpen = false
            win.selectedPath = path
            win.showMessage("Toegevoegd: " + Wallpaper.fileName(path))
        }

        function onBusyChanged() {
            if (Wallpaper.busy)
                return
            if (win.statusMessage === "Bezig met toepassen…"
                    || win.statusMessage === "Bezig met verwijderen…"
                    || win.statusMessage === "Toevoegen…")
                win.statusMessage = ""
        }

        function onRemoved(path) {
            if (win.selectedPath === path)
                win.selectedPath = ""
            win.ensureSelection()
            win.showMessage("Verwijderd: " + Wallpaper.fileName(path))
        }
    }

    // --- Bestandsbrowser: mappen en afbeeldingen ---------------------------

    function normalizePath(path) {
        let value = String(path).trim()
        if (value.length === 0)
            return win.home
        if (value === "~")
            value = win.home
        else if (value.indexOf("~/") === 0)
            value = win.home + value.slice(1)
        while (value.length > 1 && value.charAt(value.length - 1) === "/")
            value = value.slice(0, value.length - 1)
        return value
    }

    function parentPath(path) {
        const value = win.normalizePath(path)
        if (value === "/")
            return "/"
        const index = value.lastIndexOf("/")
        return index <= 0 ? "/" : value.slice(0, index)
    }

    function joinPath(directory, name) {
        return directory === "/" ? "/" + name : directory + "/" + name
    }

    function openPicker() {
        win.pickerOpen = true
        win.pickerSelected = ""
        win.pickerError = ""
        win.loadFolder(win.home + "/Pictures")
        pickerPathInput.forceActiveFocus()
        pickerPathInput.selectAll()
    }

    function closePicker() {
        win.pickerOpen = false
        win.pickerSelected = ""
        rootFocus.forceActiveFocus()
    }

    function loadFolder(path) {
        if (folderProcess.running)
            return
        win.pickerPath = win.normalizePath(path)
        win.pickerDraftPath = win.pickerPath
        win.pickerSelected = ""
        win.pickerError = ""
        win.pickerEntries = []
        win.pickerScanning = true
        folderProcess.command = ["sh", "-c",
            'find "$1" -mindepth 1 -maxdepth 1 -printf "%y\\t%f\\n"; exit 0',
            "wallpaper-browse", win.pickerPath]
        folderProcess.running = true
    }

    function chooseEntry(entry) {
        if (entry.kind === "dir" || entry.kind === "parent") {
            win.loadFolder(entry.path)
            return
        }
        win.pickerSelected = entry.path
    }

    function addPicked() {
        if (win.pickerSelected.length === 0 || Wallpaper.busy)
            return
        const destination = Wallpaper.add(win.pickerSelected)
        if (destination.length > 0) {
            const alreadyThere = destination === win.pickerSelected
            win.pickerOpen = false
            win.selectedPath = destination
            win.showMessage(alreadyThere
                ? "Deze wallpaper staat al in de map"
                : "Toevoegen…")
        } else if (Wallpaper.lastError.length > 0) {
            win.pickerError = Wallpaper.lastError
        }
    }

    Process {
        id: folderProcess

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                const lines = text.split("\n")
                const result = []

                if (win.pickerPath !== "/") {
                    result.push({
                        kind: "parent",
                        name: "..",
                        path: win.parentPath(win.pickerPath)
                    })
                }

                const dirs = []
                const files = []

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    const tab = line.indexOf("\t")
                    if (tab < 1)
                        continue
                    const kind = line.slice(0, tab)
                    const name = line.slice(tab + 1)
                    if (name.length === 0 || name.charAt(0) === ".")
                        continue
                    const path = win.joinPath(win.pickerPath, name)

                    if (kind === "d") {
                        dirs.push({ kind: "dir", name: name, path: path })
                    } else if (kind === "f" && Wallpaper.isImage(name)) {
                        files.push({ kind: "image", name: name, path: path })
                    }
                }

                dirs.sort(function(a, b) { return a.name.localeCompare(b.name) })
                files.sort(function(a, b) { return a.name.localeCompare(b.name) })
                win.pickerEntries = result.concat(dirs, files)
            }
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: win.pickerError = text.trim()
        }

        onExited: win.pickerScanning = false
    }

    // --- Hoofdindeling -----------------------------------------------------

    Rectangle {
        id: rootFocus

        anchors.fill: parent
        color: Theme.base
        border.width: 1
        border.color: Theme.surface0
        focus: true

        Keys.onEscapePressed: {
            if (win.pickerOpen)
                win.closePicker()
            else
                win.closeWindow()
        }

        // --- Titelbalk ----------------------------------------------------
        Rectangle {
            id: header

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 56
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
                    text: "\uf03e" // image
                    color: Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.fontLarge
                }

                Text {
                    text: "Wallpapers"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge + 1
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.leftMargin: 4
                    Layout.preferredWidth: countLabel.implicitWidth + 16
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10
                    color: Theme.surface0

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: Wallpaper.items.length + " afbeeldingen"
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: Wallpaper.wallpaperDir.replace(win.home, "~")
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                }

                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

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

        // --- Werkbalk -----------------------------------------------------
        Rectangle {
            id: toolbar

            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
            }
            height: 48
            color: Theme.base

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
                    rightMargin: 18
                }
                spacing: 8

                ActionButton {
                    text: "Toevoegen"
                    icon: "\uf067" // plus
                    onClicked: win.openPicker()
                }

                ActionButton {
                    text: "Vernieuwen"
                    icon: "\uf021" // rotate
                    onClicked: {
                        Wallpaper.refresh()
                        win.showMessage("Wallpaperlijst vernieuwd")
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    visible: Wallpaper.scanning
                    text: "Lijst laden…"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }

                Text {
                    text: "Dubbelklik op een afbeelding om direct toe te passen"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }
        }

        // --- Lijst en voorbeeld -------------------------------------------
        RowLayout {
            id: content

            anchors {
                left: parent.left
                right: parent.right
                top: toolbar.bottom
                bottom: footer.top
                margins: 18
            }
            spacing: 16

            Flickable {
                id: gridView

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: gridFlow.height + 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        gridView.contentY = Math.max(0, Math.min(
                            gridView.contentHeight - gridView.height,
                            gridView.contentY - event.angleDelta.y * 0.6))
                    }
                }

                Flow {
                    id: gridFlow

                    width: gridView.width
                    spacing: 14

                    Repeater {
                        model: Wallpaper.items

                        delegate: Rectangle {
                            id: card

                            required property var modelData

                            readonly property bool selected:
                                win.selectedPath === card.modelData.path
                            readonly property bool current:
                                Wallpaper.currentPath === card.modelData.path

                            width: 214
                            height: 178
                            radius: Theme.radiusSmall + 2
                            color: card.selected ? Theme.surface0 : Theme.mantle
                            border.width: card.selected ? 2 : 1
                            border.color: card.selected
                                ? Theme.accent
                                : (cardArea.containsMouse
                                    ? Theme.surface1 : Theme.surface0)

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 8
                                }
                                height: 112
                                radius: Theme.radiusSmall
                                color: Theme.crust
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: Wallpaper.fileUrl(card.modelData.path)
                                    sourceSize.width: 430
                                    sourceSize.height: 230
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                }

                                Rectangle {
                                    visible: card.current
                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        margins: 7
                                    }
                                    width: currentLabel.implicitWidth + 14
                                    height: 20
                                    radius: 10
                                    color: Theme.green

                                    Text {
                                        id: currentLabel
                                        anchors.centerIn: parent
                                        text: "Actief"
                                        color: Theme.crust
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontTiny
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    topMargin: 126
                                    leftMargin: 9
                                    rightMargin: 9
                                }
                                text: Wallpaper.displayName(card.modelData.path)
                                color: card.current ? Theme.green : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: card.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideMiddle
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                    bottomMargin: 8
                                    leftMargin: 9
                                    rightMargin: 9
                                }
                                text: card.current
                                    ? "Huidige wallpaper"
                                    : (card.selected ? "Geselecteerd" : "Klik voor voorbeeld")
                                color: card.current
                                    ? Theme.green
                                    : (card.selected ? Theme.accent : Theme.overlay0)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: cardArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.selectedPath = card.modelData.path
                                onDoubleClicked: {
                                    win.selectedPath = card.modelData.path
                                    win.applySelected()
                                }
                            }
                        }
                    }

                    // Lege toestand.
                    Text {
                        visible: Wallpaper.items.length === 0 && !Wallpaper.scanning
                        width: gridView.width
                        text: "Nog geen wallpapers gevonden.\n"
                            + "Gebruik “Toevoegen” of zet een afbeelding in "
                            + Wallpaper.wallpaperDir.replace(win.home, "~") + "."
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        topPadding: 40
                    }
                }
            }

            // Groot voorbeeld van de selectie.
            Rectangle {
                Layout.preferredWidth: 348
                Layout.fillHeight: true
                radius: Theme.radiusSmall + 2
                color: Theme.mantle
                border.width: 1
                border.color: Theme.surface0

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: "VOORBEELD"
                        color: Theme.overlay1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: Theme.crust
                        clip: true
                        border.width: 1
                        border.color: Theme.surface0

                        Image {
                            anchors.fill: parent
                            source: win.selectedPath.length > 0
                                ? Wallpaper.fileUrl(win.selectedPath) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }

                        Text {
                            visible: win.selectedPath.length === 0
                            anchors.centerIn: parent
                            text: "\uf03e"
                            color: Theme.overlay0
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.scaled(48)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const item = win.selectedItem()
                            return item ? Wallpaper.displayName(item.path)
                                : "Geen wallpaper geselecteerd"
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const item = win.selectedItem()
                            if (!item)
                                return ""
                            const prefix = item.isDefault
                                ? "Standaardwallpaper  ·  " : ""
                            return prefix + item.path.replace(win.home, "~")
                        }
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        elide: Text.ElideMiddle
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: {
                            const item = win.selectedItem()
                            return item !== null && item.path === Wallpaper.currentPath
                        }
                        text: "Deze wallpaper is nu actief"
                        color: Theme.green
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ActionButton {
                            Layout.fillWidth: true
                            text: Wallpaper.busy ? "Bezig…" : "Toepassen"
                            icon: "\uf00c" // check
                            primary: true
                            enabled: win.selectedPath.length > 0 && !Wallpaper.busy
                            onClicked: win.applySelected()
                        }

                        ActionButton {
                            text: win.confirmDeletePath === win.selectedPath
                                && win.selectedPath.length > 0
                                ? "Zeker?" : "Verwijderen"
                            icon: "\uf1f8" // trash
                            danger: win.confirmDeletePath === win.selectedPath
                            compact: true
                            enabled: win.selectedPath.length > 0
                                && !Wallpaper.busy
                                && win.selectedPath.indexOf(Wallpaper.wallpaperDir + "/") === 0
                                && win.selectedPath !== Wallpaper.currentPath
                            onClicked: win.requestDelete()
                        }
                    }
                }
            }
        }

        // --- Voettekst ----------------------------------------------------
        Rectangle {
            id: footer

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 54
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
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (Wallpaper.lastError.length > 0)
                            return Wallpaper.lastError
                        if (win.statusMessage.length > 0)
                            return win.statusMessage
                        if (Wallpaper.lastAction.length > 0)
                            return Wallpaper.lastAction
                        return "Kies een wallpaper en klik op Toepassen"
                    }
                    color: Wallpaper.lastError.length > 0
                        ? Theme.red
                        : (win.statusMessage.length > 0
                            ? Theme.green : Theme.overlay1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                ActionButton {
                    text: "Volgende"
                    icon: "\uf061" // arrow-right
                    enabled: !Wallpaper.busy
                    onClicked: win.applyNext()
                }

                ActionButton {
                    text: "Sluiten"
                    primary: true
                    onClicked: win.closeWindow()
                }
            }
        }

        // --- Toevoegen: ingebouwde bestandsbrowser ------------------------
        Rectangle {
            id: pickerOverlay

            anchors.fill: parent
            visible: win.pickerOpen
            color: "#aa000000"
            z: 100

            MouseArea {
                anchors.fill: parent
                onClicked: win.closePicker()
            }

            Rectangle {
                id: pickerPanel

                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 820)
                height: Math.min(parent.height - 48, 590)
                radius: Theme.radiusSmall + 4
                color: Theme.base
                border.width: 1
                border.color: Theme.surface1

                // Klikken op lege plekken in het paneel mogen de overlay niet
                // sluiten; inhoud hierboven houdt zijn eigen klikgedrag.
                MouseArea {
                    anchors.fill: parent
                }

                Rectangle {
                    id: pickerHeader

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    height: 50
                    color: Theme.mantle
                    radius: pickerPanel.radius

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
                            leftMargin: 16
                            rightMargin: 12
                        }
                        spacing: 9

                        Text {
                            text: "\uf067" // plus
                            color: Theme.accent
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.fontNormal
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Wallpaper toevoegen"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLarge
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSmall
                                color: pickerCloseArea.containsMouse
                                    ? Theme.surface0 : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                color: Theme.overlay1
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.fontNormal
                            }

                            MouseArea {
                                id: pickerCloseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.closePicker()
                            }
                        }
                    }
                }

                RowLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: pickerHeader.bottom
                        bottom: pickerFooter.top
                        margins: 14
                    }
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            ActionButton {
                                text: "Home"
                                compact: true
                                onClicked: win.loadFolder(win.home)
                            }

                            ActionButton {
                                text: "Afbeeldingen"
                                compact: true
                                onClicked: win.loadFolder(win.home + "/Pictures")
                            }

                            ActionButton {
                                text: "Wallpapers"
                                compact: true
                                onClicked: win.loadFolder(Wallpaper.wallpaperDir)
                            }

                            ActionButton {
                                text: "Omhoog"
                                icon: "\uf062" // arrow-up
                                compact: true
                                onClicked: win.loadFolder(win.parentPath(win.pickerPath))
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: Theme.radiusSmall
                            color: Theme.mantle
                            border.width: 1
                            border.color: pickerPathInput.activeFocus
                                ? Theme.accent : Theme.surface0

                            TextInput {
                                id: pickerPathInput

                                anchors {
                                    fill: parent
                                    leftMargin: 9
                                    rightMargin: 9
                                }
                                text: win.pickerDraftPath
                                color: Theme.text
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.crust
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                clip: true

                                onAccepted: win.loadFolder(pickerPathInput.text)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: Theme.mantle
                            border.width: 1
                            border.color: Theme.surface0
                            clip: true

                            ListView {
                                id: pickerList

                                anchors {
                                    fill: parent
                                    margins: 4
                                }
                                clip: true
                                spacing: 2
                                model: win.pickerEntries

                                delegate: Rectangle {
                                    id: pickerRow

                                    required property var modelData

                                    readonly property bool isImage:
                                        pickerRow.modelData.kind === "image"
                                    readonly property bool selected:
                                        pickerRow.modelData.path === win.pickerSelected

                                    width: pickerList.width
                                    height: 44
                                    radius: Theme.radiusSmall
                                    color: pickerRow.selected
                                        ? Theme.surface0
                                        : (pickerRowArea.containsMouse
                                            ? Theme.mantle : "transparent")

                                    Rectangle {
                                        anchors {
                                            left: parent.left
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 6
                                        }
                                        width: 48
                                        height: 32
                                        radius: 4
                                        color: Theme.crust
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            visible: pickerRow.isImage
                                            source: pickerRow.isImage
                                                ? Wallpaper.fileUrl(pickerRow.modelData.path)
                                                : ""
                                            sourceSize.width: 96
                                            sourceSize.height: 64
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !pickerRow.isImage
                                            text: pickerRow.modelData.kind === "parent"
                                                ? "\uf062" : "\uf07b" // folder
                                            color: Theme.yellow
                                            font.family: Theme.iconFamily
                                            font.pixelSize: Theme.fontNormal
                                        }
                                    }

                                    Text {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 64
                                            rightMargin: 8
                                        }
                                        text: pickerRow.modelData.name
                                        color: pickerRow.isImage
                                            ? Theme.text : Theme.accentMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSmall
                                        elide: Text.ElideMiddle
                                    }

                                    MouseArea {
                                        id: pickerRowArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.chooseEntry(pickerRow.modelData)
                                        onDoubleClicked: {
                                            if (pickerRow.isImage) {
                                                win.pickerSelected = pickerRow.modelData.path
                                                win.addPicked()
                                            } else {
                                                win.chooseEntry(pickerRow.modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: win.pickerEntries.length === 0
                                anchors.centerIn: parent
                                width: parent.width - 30
                                text: win.pickerScanning
                                    ? "Map lezen…"
                                    : (win.pickerError.length > 0
                                        ? win.pickerError
                                        : "Geen mappen of afbeeldingen in deze map")
                                color: win.pickerError.length > 0
                                    ? Theme.red : Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Voorbeeld van de gekozen afbeelding in de browser.
                    Rectangle {
                        Layout.preferredWidth: 250
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: Theme.mantle
                        border.width: 1
                        border.color: Theme.surface0

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 10
                            }
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusSmall
                                color: Theme.crust
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: win.pickerSelected.length > 0
                                        ? Wallpaper.fileUrl(win.pickerSelected) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                }

                                Text {
                                    visible: win.pickerSelected.length === 0
                                    anchors.centerIn: parent
                                    text: "Kies een afbeelding"
                                    color: Theme.overlay0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: win.pickerSelected.length > 0
                                    ? Wallpaper.displayName(win.pickerSelected)
                                    : "Nog niets gekozen"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                elide: Text.ElideMiddle
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: win.pickerSelected.length > 0
                                text: "Wordt gekopieerd naar Wallpapers; het "
                                    + "originele bestand blijft staan."
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Rectangle {
                    id: pickerFooter

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 52
                    color: Theme.mantle
                    radius: pickerPanel.radius

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
                            fill: parent
                            leftMargin: 16
                            rightMargin: 16
                        }
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: win.pickerError.length > 0
                                ? win.pickerError
                                : (win.pickerSelected.length > 0
                                    ? win.pickerSelected.replace(win.home, "~")
                                    : win.pickerPath.replace(win.home, "~"))
                            color: win.pickerError.length > 0
                                ? Theme.red : Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            elide: Text.ElideMiddle
                        }

                        ActionButton {
                            text: "Annuleren"
                            compact: true
                            onClicked: win.closePicker()
                        }

                        ActionButton {
                            text: Wallpaper.busy ? "Bezig…" : "Toevoegen"
                            icon: "\uf067"
                            primary: true
                            compact: true
                            enabled: win.pickerSelected.length > 0
                                && !Wallpaper.busy
                            onClicked: win.addPicked()
                        }
                    }
                }
            }
        }
    }

    // --- Inline componenten ------------------------------------------------

    component ActionButton: Rectangle {
        id: actionButton

        property string text: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        property bool compact: false

        signal clicked()

        implicitWidth: actionLabel.implicitWidth + Theme.scaled(24)
            + (actionButton.icon.length > 0 ? Theme.scaled(18) : 0)
        implicitHeight: Theme.scaled(actionButton.compact ? 26 : 30)
        width: implicitWidth
        height: implicitHeight
        radius: Theme.radiusSmall
        opacity: actionButton.enabled ? 1 : 0.45
        color: {
            if (actionButton.primary)
                return actionArea.containsMouse && actionButton.enabled
                    ? Theme.lavender : Theme.accent
            if (actionButton.danger)
                return actionArea.containsMouse && actionButton.enabled
                    ? Theme.red : Theme.surface1
            return actionArea.containsMouse && actionButton.enabled
                ? Theme.surface1 : Theme.surface0
        }
        border.width: 1
        border.color: actionButton.primary ? Theme.accent : Theme.surface1

        Row {
            anchors.centerIn: parent
            spacing: Theme.scaled(6)

            Text {
                visible: actionButton.icon.length > 0
                text: actionButton.icon
                color: actionButton.primary || actionButton.danger
                    ? Theme.crust : Theme.text
                font.family: Theme.iconFamily
                font.pixelSize: Theme.fontSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: actionLabel
                text: actionButton.text
                color: actionButton.primary || actionButton.danger
                    ? Theme.crust : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: actionButton.compact
                    ? Theme.fontSmall : Theme.fontNormal
                font.weight: actionButton.primary ? Font.DemiBold : Font.Normal
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            enabled: actionButton.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }
}
