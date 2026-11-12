// SettingsWindow.qml — instellingenvenster voor BSPWM (fase 7).
//
// Een FloatingWindow met vijf tabs: Gaps & randen, Lay-outs, Kleuren & thema,
// Gedrag en Info/acties. Alle waarden lopen via de BspwmSettings-singleton:
// die past wijzigingen met een korte debounce toe met `bspc config` en schrijft
// ze atomair naar ~/.config/bspwm/settings.json.
//
// Onder X11 krijgt een PopupWindow geen toetsenbordfocus (issue #794); een
// FloatingWindow wel. Daarom is dit venster een FloatingWindow en geen popup.
// De kleurvelden gebruiken TextInput, de sliders QtQuick.Controls' Slider met
// een eigen Catppuccin-uiterlijk.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

FloatingWindow {
    id: win

    title: "BSPWM-instellingen"
    implicitWidth: 940
    implicitHeight: 680
    minimumSize: Qt.size(780, 560)
    color: Theme.base
    visible: false

    // --- Tabs -------------------------------------------------------------

    readonly property var tabNames: [
        "Gaps & randen",
        "Lay-outs",
        "Kleuren",
        "Gedrag",
        "Weergave",
        "Info & acties"
    ]

    readonly property var tabIcons: [
        "\uf0c9", // bars
        "\uf1b2", // cubes
        "\uf53f", // palette
        "\uf085", // gears
        "\uf031", // font
        "\uf05a"  // circle-info
    ]

    property int currentTab: 0

    // --- Hulpfuncties -----------------------------------------------------

    function openWindow() {
        // Niet synchroon loadFromDisk() gebruiken: de cache van settingsFile
        // kan na een eigen schrijfactie nog verouderd zijn. reloadFromDisk()
        // leest het bestand opnieuw en past de waarden toe zodra dat klaar is.
        BspwmSettings.reloadFromDisk()
        Bspwm.refreshDesktopLayouts()
        win.visible = true
    }

    function closeWindow() {
        if (BspwmSettings.dirty)
            BspwmSettings.saveNow()
        win.visible = false
    }

    function toggleWindow() {
        if (win.visible)
            win.closeWindow()
        else
            win.openWindow()
    }

    // Korte aliassen, gebruikt door de IPC-handler en de bar.
    function open() {
        win.openWindow()
    }

    function close() {
        win.closeWindow()
    }

    function toggle() {
        win.toggleWindow()
    }

    function percent(value) {
        return Math.round(value * 100) + "%"
    }

    function colorName(key) {
        const names = {
            "focused": "Gefocust venster",
            "normal": "Normaal venster",
            "active": "Actief venster",
            "presel_feedback": "Preselectie"
        }
        return names[key] || key
    }

    function paddingLabel(side) {
        const names = {
            "top": "Boven",
            "right": "Rechts",
            "bottom": "Onder",
            "left": "Links"
        }
        return names[side] || side
    }

    property bool confirmReset: false
    property string localMessage: ""
    property string bspwmVersion: ""
    property string sxhkdVersion: ""
    property string quickshellVersion: ""

    Timer {
        id: resetTimer
        interval: 3200
        repeat: false
        running: false
        onTriggered: win.confirmReset = false
    }

    Timer {
        id: messageTimer
        interval: 4000
        repeat: false
        running: false
        onTriggered: win.localMessage = ""
    }

    function showMessage(text) {
        win.localMessage = text
        messageTimer.restart()
    }

    function resetDefaults() {
        if (!win.confirmReset) {
            win.confirmReset = true
            resetTimer.restart()
            return
        }
        win.confirmReset = false
        resetTimer.stop()
        if (BspwmSettings.reset())
            win.showMessage("Standaardwaarden hersteld en toegepast")
    }

    function reloadSxhkd() {
        if (!sxhkdReloadProcess.running)
            sxhkdReloadProcess.running = true
    }

    function reloadQuickshell() {
        win.showMessage("Quickshell wordt herladen…")
        Quickshell.reload(false)
    }

    onClosed: win.visible = false

    onVisibleChanged: {
        if (win.visible) {
            Bspwm.refreshDesktopLayouts()
            win.confirmReset = false
            rootFocus.forceActiveFocus()
        }
    }

    // Escape sluit het venster, behalve wanneer een tekstveld bezig is.
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: win.close()
    }

    // --- Titelbalk --------------------------------------------------------

    Item {
        id: rootFocus

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: win.close()

        // Achtergrond en dunne rand.
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
                    text: "\uf085" // gears
                    color: Theme.accent
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.fontLarge
                }

                Text {
                    text: "BSPWM-instellingen"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLarge + 1
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: BspwmSettings.settingsPath
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                }

                // Indicatie of er nog niet-opgeslagen wijzigingen zijn.
                Rectangle {
                    visible: BspwmSettings.dirty
                    width: dirtyLabel.implicitWidth + 14
                    height: 20
                    radius: 10
                    color: Theme.surface0

                    Text {
                        id: dirtyLabel
                        anchors.centerIn: parent
                        text: "opslaan…"
                        color: Theme.yellow
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }
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
                        onClicked: win.close()
                    }
                }
            }
        }

        // --- Tabbladen ----------------------------------------------------

        Rectangle {
            id: tabBar

            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
            }
            height: 44
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

            Row {
                anchors {
                    left: parent.left
                    leftMargin: 18
                    verticalCenter: parent.verticalCenter
                }
                spacing: 4

                Repeater {
                    model: win.tabNames.length

                    delegate: Rectangle {
                        id: tabButton

                        required property int index

                        readonly property bool active: win.currentTab === index

                        width: tabLabel.implicitWidth + 34
                        height: 30
                        radius: Theme.radiusSmall
                        color: tabButton.active
                            ? Theme.surface0
                            : (tabArea.containsMouse ? Theme.mantle : "transparent")

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            height: 2
                            radius: 1
                            color: tabButton.active ? Theme.accent : "transparent"
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            Text {
                                text: win.tabIcons[tabButton.index]
                                color: tabButton.active ? Theme.accent : Theme.overlay0
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.fontSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: tabLabel
                                text: win.tabNames[tabButton.index]
                                color: tabButton.active ? Theme.text : Theme.barMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                font.weight: tabButton.active ? Font.DemiBold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.currentTab = tabButton.index
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

                // Status links: fout gaat voor actie/opgeslagen.
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (BspwmSettings.lastError.length > 0)
                            return BspwmSettings.lastError
                        if (win.localMessage.length > 0)
                            return win.localMessage
                        if (BspwmSettings.lastAction.length > 0)
                            return BspwmSettings.lastAction
                        return Bspwm.available
                            ? "Wijzigingen worden direct toegepast"
                            : "bspwm niet actief — wijzigingen worden wel bewaard"
                    }
                    color: BspwmSettings.lastError.length > 0
                        ? Theme.red
                        : (win.localMessage.length > 0 ? Theme.green : Theme.overlay1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                ActionButton {
                    text: win.confirmReset ? "Zeker weten?" : "Standaardwaarden"
                    danger: win.confirmReset
                    onClicked: win.resetDefaults()
                }

                ActionButton {
                    text: "Sluiten"
                    primary: true
                    onClicked: win.close()
                }
            }
        }

        // --- Inhoud -------------------------------------------------------

        StackLayout {
            id: pages

            anchors {
                left: parent.left
                right: parent.right
                top: tabBar.bottom
                bottom: footer.top
            }
            currentIndex: win.currentTab

            // ============================================================
            // Tab 1 — Gaps & randen
            // ============================================================

            Flickable {
                id: gapsPage

                contentWidth: width
                contentHeight: gapsColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        gapsPage.contentY = Math.max(0, Math.min(
                            gapsPage.contentHeight - gapsPage.height,
                            gapsPage.contentY - event.angleDelta.y * 0.55))
                    }
                }

                Column {
                    id: gapsColumn

                    x: 24
                    y: 24
                    width: gapsPage.width - 48
                    spacing: 16

                    Card {
                        heading: "Afmetingen"

                        SliderRow {
                            label: "Ruimte tussen vensters"
                            hint: "window_gap"
                            from: 0
                            to: 48
                            stepSize: 1
                            value: BspwmSettings.windowGap
                            valueText: BspwmSettings.windowGap + " px"
                            onMoved: (value) => BspwmSettings.setWindowGap(value)
                        }

                        SliderRow {
                            label: "Dikte vensterrand"
                            hint: "border_width"
                            from: 0
                            to: 12
                            stepSize: 1
                            value: BspwmSettings.borderWidth
                            valueText: BspwmSettings.borderWidth + " px"
                            onMoved: (value) => BspwmSettings.setBorderWidth(value)
                        }

                        SliderRow {
                            label: "Splitverhouding"
                            hint: "split_ratio — standaard 52%"
                            from: 0.1
                            to: 0.9
                            stepSize: 0.01
                            value: BspwmSettings.splitRatio
                            valueText: win.percent(BspwmSettings.splitRatio)
                            onMoved: (value) => BspwmSettings.setSplitRatio(value)
                        }
                    }

                    Card {
                        heading: "Padding per monitor"

                        Text {
                            width: parent.width
                            text: "De bar reserveert al ruimte met EWMH-struts. Extra "
                                + "bspwm-padding komt daar bovenop; houd dit op 0 tenzij je "
                                + "bewust extra marge wilt."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: ["top", "right", "bottom", "left"]

                            delegate: SliderRow {
                                required property string modelData

                                label: win.paddingLabel(modelData)
                                hint: modelData + "_padding"
                                from: 0
                                to: 120
                                stepSize: 1
                                value: BspwmSettings.padding[modelData] || 0
                                valueText: (BspwmSettings.padding[modelData] || 0) + " px"
                                onMoved: (value) => BspwmSettings.setPadding(modelData, value)
                            }
                        }

                        Text {
                            visible: BspwmSettings.monitorNames.length > 0
                            width: parent.width
                            text: "Monitors: " + BspwmSettings.monitorNames.join(", ")
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }

                    Card {
                        heading: "Monocle"

                        ToggleRow {
                            label: "Eén venster in monocle"
                            hint: "single_monocle"
                            checked: BspwmSettings.layout.single_monocle === true
                            onToggled: (checked) => BspwmSettings.setLayout("single_monocle", checked)
                        }

                        ToggleRow {
                            label: "Geen rand in monocle"
                            hint: "borderless_monocle"
                            checked: BspwmSettings.layout.borderless_monocle === true
                            onToggled: (checked) => BspwmSettings.setLayout("borderless_monocle", checked)
                        }

                        ToggleRow {
                            label: "Geen tussenruimte in monocle"
                            hint: "gapless_monocle"
                            checked: BspwmSettings.layout.gapless_monocle === true
                            onToggled: (checked) => BspwmSettings.setLayout("gapless_monocle", checked)
                        }
                    }
                }
            }

            // ============================================================
            // Tab 2 — Lay-outs
            // ============================================================

            Flickable {
                id: layoutPage

                contentWidth: width
                contentHeight: layoutColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        layoutPage.contentY = Math.max(0, Math.min(
                            layoutPage.contentHeight - layoutPage.height,
                            layoutPage.contentY - event.angleDelta.y * 0.55))
                    }
                }

                Column {
                    id: layoutColumn

                    x: 24
                    y: 24
                    width: layoutPage.width - 48
                    spacing: 16

                    Card {
                        heading: "Gefocuste desktop"

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: Bspwm.focusedDesktop.length > 0
                                    ? "Desktop " + Bspwm.focusedDesktop
                                    : "Geen actieve desktop"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                            }

                            Text {
                                text: Bspwm.layout.length > 0 ? Bspwm.layout : "—"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                font.weight: Font.DemiBold
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            ActionButton {
                                text: "Tiled"
                                primary: Bspwm.layout === "tiled"
                                onClicked: Bspwm.setDesktopLayout(Bspwm.focusedDesktop, "tiled")
                            }

                            ActionButton {
                                text: "Monocle"
                                primary: Bspwm.layout === "monocle"
                                onClicked: Bspwm.setDesktopLayout(Bspwm.focusedDesktop, "monocle")
                            }

                            ActionButton {
                                text: "Wisselen"
                                onClicked: Bspwm.toggleLayout()
                            }
                        }
                    }

                    Card {
                        heading: "Layout per desktop"

                        Text {
                            width: parent.width
                            text: "Klik op T of M om de layout van die desktop te wijzigen."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: {
                                // Forceer een binding op de volledige lijst, niet
                                // alleen op focusedMonitor.
                                const dependency = Bspwm.desktops
                                return Bspwm.desktopsForMonitor(Bspwm.focusedMonitor)
                            }

                            delegate: RowLayout {
                                id: desktopRow

                                required property var modelData

                                readonly property string desktopName: modelData.name
                                readonly property string desktopLayout:
                                    Bspwm.layoutForDesktop(modelData.name)

                                width: parent.width
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        const mark = modelData.focused ? "● " : "  "
                                        const occupied = modelData.occupied ? "bezet" : "leeg"
                                        return mark + modelData.name + "  ·  " + occupied
                                    }
                                    color: modelData.focused ? Theme.text : Theme.barMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                }

                                ActionButton {
                                    text: "T"
                                    compact: true
                                    primary: desktopRow.desktopLayout === "tiled"
                                    onClicked: Bspwm.setDesktopLayout(
                                        desktopRow.desktopName, "tiled")
                                }

                                ActionButton {
                                    text: "M"
                                    compact: true
                                    primary: desktopRow.desktopLayout === "monocle"
                                    onClicked: Bspwm.setDesktopLayout(
                                        desktopRow.desktopName, "monocle")
                                }
                            }
                        }

                        Text {
                            visible: !Bspwm.available
                            width: parent.width
                            text: "bspwm is niet actief; de desktoplijst is niet beschikbaar."
                            color: Theme.red
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }
                    }

                    Card {
                        heading: "Boominstellingen"

                        ChoiceRow {
                            label: "Automatische schema"
                            hint: "automatic_scheme"
                            options: ["longest_side", "alternate", "spiral"]
                            value: BspwmSettings.layout.automatic_scheme || "longest_side"
                            onSelected: (value) => BspwmSettings.setLayout("automatic_scheme", value)
                        }

                        ChoiceRow {
                            label: "Initiële polariteit"
                            hint: "initial_polarity"
                            options: ["second_child", "first_child"]
                            value: BspwmSettings.layout.initial_polarity || "second_child"
                            onSelected: (value) => BspwmSettings.setLayout("initial_polarity", value)
                        }

                        ToggleRow {
                            label: "Geen rand bij één venster"
                            hint: "borderless_singleton"
                            checked: BspwmSettings.layout.borderless_singleton === true
                            onToggled: (checked) => BspwmSettings.setLayout("borderless_singleton", checked)
                        }
                    }

                    Card {
                        heading: "Boom transformeren"

                        Text {
                            width: parent.width
                            text: "Deze acties werken op de gefocuste node van de "
                                + "gefocuste desktop."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        Flow {
                            width: parent.width
                            spacing: 8

                            ActionButton {
                                text: "Draai 90°"
                                onClicked: Bspwm.rotateNode(90)
                            }
                            ActionButton {
                                text: "Draai 270°"
                                onClicked: Bspwm.rotateNode(270)
                            }
                            ActionButton {
                                text: "Spiegel horizontaal"
                                onClicked: Bspwm.flipNode("horizontal")
                            }
                            ActionButton {
                                text: "Spiegel verticaal"
                                onClicked: Bspwm.flipNode("vertical")
                            }
                            ActionButton {
                                text: "Balanceer"
                                onClicked: Bspwm.balanceNode()
                            }
                            ActionButton {
                                text: "Gelijkmatig"
                                onClicked: Bspwm.equalizeNode()
                            }
                            ActionButton {
                                text: "Circulatie ←"
                                onClicked: Bspwm.circulateNode("backward")
                            }
                            ActionButton {
                                text: "Circulatie →"
                                onClicked: Bspwm.circulateNode("forward")
                            }
                        }
                    }

                    Card {
                        heading: "Volledige layout bewaren"

                        Text {
                            width: parent.width
                            text: "Bewaart de boom van alle desktops met `bspc wm -d` "
                                + "en herstelt die met `bspc wm -l`. Handig vóór een "
                                + "experiment; dit staat los van settings.json."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            ActionButton {
                                text: "Bewaar layout"
                                onClicked: BspwmSettings.saveLayoutState()
                            }

                            ActionButton {
                                text: "Herstel layout"
                                onClicked: BspwmSettings.restoreLayoutState()
                            }
                        }
                    }
                }
            }

            // ============================================================
            // Tab 3 — Kleuren & thema
            // ============================================================

            Flickable {
                id: colorsPage

                contentWidth: width
                contentHeight: colorsColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        colorsPage.contentY = Math.max(0, Math.min(
                            colorsPage.contentHeight - colorsPage.height,
                            colorsPage.contentY - event.angleDelta.y * 0.55))
                    }
                }

                Column {
                    id: colorsColumn

                    x: 24
                    y: 24
                    width: colorsPage.width - 48
                    spacing: 16

                    Card {
                        heading: "BSPWM-kleuren"

                        Text {
                            width: parent.width
                            text: "De focused-kleur is tegelijk het accent in de bar. "
                                + "Wijzigingen zijn direct zichtbaar op vensterranden en "
                                + "in de bar."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: ["focused", "normal", "active", "presel_feedback"]

                            delegate: ColorRow {
                                required property string modelData

                                label: win.colorName(modelData)
                                colorKey: modelData
                            }
                        }
                    }

                    Card {
                        heading: "Presets"

                        Text {
                            width: parent.width
                            text: "Een preset vervangt alle vier de kleuren en past "
                                + "ze direct toe."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        Flow {
                            width: parent.width
                            spacing: 10

                            Repeater {
                                model: BspwmSettings.colorPresets

                                delegate: Rectangle {
                                    id: preset

                                    required property var modelData
                                    required property int index

                                    width: 200
                                    height: 74
                                    radius: Theme.radiusSmall + 2
                                    color: presetArea.containsMouse
                                        ? Theme.mantle : "transparent"
                                    border.width: 1
                                    border.color: presetArea.containsMouse
                                        ? Theme.accent : Theme.surface0

                                    Column {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 12
                                            rightMargin: 12
                                        }
                                        spacing: 8

                                        Text {
                                            text: preset.modelData.name
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontNormal
                                            font.weight: Font.DemiBold
                                        }

                                        Row {
                                            spacing: 5

                                            Repeater {
                                                model: ["focused", "normal", "active", "presel_feedback"]

                                                delegate: Rectangle {
                                                    required property string modelData

                                                    width: 28
                                                    height: 14
                                                    radius: 4
                                                    color: preset.modelData.colors[modelData]
                                                    border.width: 1
                                                    border.color: Theme.crust
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: presetArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            BspwmSettings.applyPreset(preset.index)
                                            win.showMessage(preset.modelData.name
                                                + " toegepast")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ============================================================
            // Tab 4 — Gedrag
            // ============================================================

            Flickable {
                id: behaviorPage

                contentWidth: width
                contentHeight: behaviorColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        behaviorPage.contentY = Math.max(0, Math.min(
                            behaviorPage.contentHeight - behaviorPage.height,
                            behaviorPage.contentY - event.angleDelta.y * 0.55))
                    }
                }

                Column {
                    id: behaviorColumn

                    x: 24
                    y: 24
                    width: behaviorPage.width - 48
                    spacing: 16

                    Card {
                        heading: "Focus en aanwijzer"

                        ToggleRow {
                            label: "Focus volgt de aanwijzer"
                            hint: "focus_follows_pointer"
                            checked: BspwmSettings.behavior.focus_follows_pointer === true
                            onToggled: (checked) => BspwmSettings.setBehavior(
                                "focus_follows_pointer", checked)
                        }

                        ToggleRow {
                            label: "Aanwijzer volgt de focus"
                            hint: "pointer_follows_focus"
                            checked: BspwmSettings.behavior.pointer_follows_focus === true
                            onToggled: (checked) => BspwmSettings.setBehavior(
                                "pointer_follows_focus", checked)
                        }

                        ChoiceRow {
                            label: "Klik om te focussen"
                            hint: "click_to_focus"
                            options: ["any", "button1", "button2", "button3", "none"]
                            value: BspwmSettings.behavior.click_to_focus || "any"
                            onSelected: (value) => BspwmSettings.setBehavior(
                                "click_to_focus", value)
                        }

                        ChoiceRow {
                            label: "Aanwijzermodifier"
                            hint: "pointer_modifier"
                            options: ["mod4", "mod1", "mod2", "mod3", "mod5"]
                            value: BspwmSettings.behavior.pointer_modifier || "mod4"
                            onSelected: (value) => BspwmSettings.setBehavior(
                                "pointer_modifier", value)
                        }

                        ToggleRow {
                            label: "Eerste klik inslikken"
                            hint: "swallow_first_click"
                            checked: BspwmSettings.behavior.swallow_first_click === true
                            onToggled: (checked) => BspwmSettings.setBehavior(
                                "swallow_first_click", checked)
                        }
                    }

                    Card {
                        heading: "Fullscreen en monitors"

                        ChoiceRow {
                            label: "EWMH-fullscreen negeren"
                            hint: "ignore_ewmh_fullscreen"
                            options: ["none", "all", "enter", "exit"]
                            value: BspwmSettings.behavior.ignore_ewmh_fullscreen || "none"
                            onSelected: (value) => BspwmSettings.setBehavior(
                                "ignore_ewmh_fullscreen", value)
                        }

                        ToggleRow {
                            label: "Verwijder losgekoppelde monitors"
                            hint: "remove_unplugged_monitors"
                            checked: BspwmSettings.behavior.remove_unplugged_monitors === true
                            onToggled: (checked) => BspwmSettings.setBehavior(
                                "remove_unplugged_monitors", checked)
                        }

                        ToggleRow {
                            label: "Voeg overlappende monitors samen"
                            hint: "merge_overlapping_monitors"
                            checked: BspwmSettings.behavior.merge_overlapping_monitors === true
                            onToggled: (checked) => BspwmSettings.setBehavior(
                                "merge_overlapping_monitors", checked)
                        }
                    }
                }
            }

            // ============================================================
            // Tab 5 — Weergave
            // ============================================================

            Flickable {
                id: displayPage

                contentWidth: width
                contentHeight: displayColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        displayPage.contentY = Math.max(0, Math.min(
                            displayPage.contentHeight - displayPage.height,
                            displayPage.contentY - event.angleDelta.y * 0.55))
                    }
                }

                Column {
                    id: displayColumn

                    x: 24
                    y: 24
                    width: displayPage.width - 48
                    spacing: 16

                    Card {
                        heading: "Schaal van de interface"

                        Text {
                            width: parent.width
                            text: "Vergroot of verklein de tekst en widgets van de bar, "
                                + "de popups en dit venster. De standaard is 100%; "
                                + "de schaal loopt van 80% tot 150%."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        SliderRow {
                            label: "Schaal"
                            hint: "ui.scale"
                            from: 80
                            to: 150
                            stepSize: 5
                            value: Math.round(BspwmSettings.ui.scale * 100)
                            valueText: win.percent(BspwmSettings.ui.scale)
                            onMoved: (value) => BspwmSettings.setUiScale(value / 100)
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            ActionButton {
                                text: "Kleiner"
                                onClicked: BspwmSettings.setUiScale(
                                    BspwmSettings.ui.scale - 0.1)
                            }

                            ActionButton {
                                text: "Normaal (100%)"
                                primary: Math.abs(BspwmSettings.ui.scale - 1.0) < 0.001
                                onClicked: BspwmSettings.setUiScale(1.0)
                            }

                            ActionButton {
                                text: "Groter"
                                onClicked: BspwmSettings.setUiScale(
                                    BspwmSettings.ui.scale + 0.1)
                            }
                        }
                    }

                    Card {
                        heading: "Transparantie van de bar"

                        Text {
                            width: parent.width
                            text: "Maak de achtergrond van de bar doorschijnend, "
                                + "zodat de wallpaper erdoorheen komt. 0% is "
                                + "volledig dekkend; de ondergrens is 70% "
                                + "transparant (30% dekking). Standaard staat "
                                + "de bar op 20% transparant."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        SliderRow {
                            label: "Transparantie"
                            hint: "ui.bar_opacity"
                            from: 0
                            to: 70
                            stepSize: 5
                            value: Math.round(
                                (1 - BspwmSettings.ui.bar_opacity) * 100)
                            valueText: Math.round(
                                (1 - BspwmSettings.ui.bar_opacity) * 100) + "%"
                            onMoved: (value) => BspwmSettings.setBarOpacity(
                                1 - value / 100)
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            ActionButton {
                                text: "Deckend"
                                primary: BspwmSettings.ui.bar_opacity >= 0.995
                                onClicked: BspwmSettings.setBarOpacity(1.0)
                            }

                            ActionButton {
                                text: "Standaard (20%)"
                                primary: Math.abs(
                                    BspwmSettings.ui.bar_opacity - 0.8) < 0.005
                                onClicked: BspwmSettings.setBarOpacity(0.8)
                            }
                        }

                        // Voorbeeld: de semi-transparante bar over een
                        // kleurverloop, zodat het effect zichtbaar is.
                        Rectangle {
                            width: parent.width
                            height: 44
                            radius: Theme.radiusSmall
                            clip: true

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.base }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Theme.barBackgroundTransparent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Voorbeeld van de barachtergrond"
                                    color: Theme.barForeground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                }
                            }
                        }
                    }

                    Card {
                        heading: "Effectieve maten"

                        InfoRow {
                            label: "Kleine tekst"
                            value: Theme.fontSmall + " px"
                        }
                        InfoRow {
                            label: "Normale tekst"
                            value: Theme.fontNormal + " px"
                        }
                        InfoRow {
                            label: "Grote tekst"
                            value: Theme.fontLarge + " px"
                        }
                        InfoRow {
                            label: "Iconen"
                            value: Theme.iconSize + " px"
                        }
                        InfoRow {
                            label: "Barhoogte"
                            value: Theme.barHeight + " px"
                        }
                        InfoRow {
                            label: "Bar-dekking"
                            value: Math.round(Theme.barOpacity * 100) + "%"
                        }
                    }

                    Card {
                        heading: "Voorbeeld"

                        Text {
                            width: parent.width
                            text: "Workspaces  ·  muziek  ·  volume  ·  14:30"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "Dit is hoe de tekst in de bar en de widgets eruitziet."
                            color: Theme.barMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ============================================================
            // Tab 6 — Info & acties
            // ============================================================

            Flickable {
                id: infoPage

                contentWidth: width
                contentHeight: infoColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        infoPage.contentY = Math.max(0, Math.min(
                            infoPage.contentHeight - infoPage.height,
                            infoPage.contentY - event.angleDelta.y * 0.55))
                    }
                }

                Column {
                    id: infoColumn

                    x: 24
                    y: 24
                    width: infoPage.width - 48
                    spacing: 16

                    Card {
                        heading: "Systeem"

                        InfoRow {
                            label: "bspwm"
                            value: win.bspwmVersion.length > 0
                                ? win.bspwmVersion : "onbekend"
                        }
                        InfoRow {
                            label: "sxhkd"
                            value: win.sxhkdVersion.length > 0
                                ? win.sxhkdVersion : "onbekend"
                        }
                        InfoRow {
                            label: "Quickshell"
                            value: win.quickshellVersion.length > 0
                                ? win.quickshellVersion : "onbekend"
                        }
                        InfoRow {
                            label: "Monitor(en)"
                            value: BspwmSettings.monitorNames.length > 0
                                ? BspwmSettings.monitorNames.join(", ")
                                : (Bspwm.monitors.map(m => m.name).join(", ") || "—")
                        }
                        InfoRow {
                            label: "Gefocuste desktop"
                            value: Bspwm.focusedDesktop.length > 0
                                ? Bspwm.focusedDesktop : "—"
                        }
                    }

                    Card {
                        heading: "Paden"

                        InfoRow {
                            label: "settings.json"
                            value: BspwmSettings.settingsPath
                        }
                        InfoRow {
                            label: "standaardwaarden"
                            value: BspwmSettings.defaultSettingsPath
                        }
                        InfoRow {
                            label: "layoutstate"
                            value: BspwmSettings.layoutStatePath
                        }
                    }

                    Card {
                        heading: "Acties"

                        Text {
                            width: parent.width
                            text: "BSPWM herstarten past settings.json opnieuw toe. "
                                + "Sxhkd herladen is nodig na een wijziging in sxhkdrc. "
                                + "Quickshell herladen herstart alleen de QML."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        Flow {
                            width: parent.width
                            spacing: 8

                            ActionButton {
                                text: "BSPWM herstarten"
                                onClicked: {
                                    Bspwm.reloadWindowManager()
                                    win.showMessage("BSPWM wordt herstart")
                                }
                            }

                            ActionButton {
                                text: "Sxhkd herladen"
                                onClicked: win.reloadSxhkd()
                            }

                            ActionButton {
                                text: "Quickshell herladen"
                                onClicked: win.reloadQuickshell()
                            }
                        }
                    }

                    Card {
                        heading: "Waarschuwing: dubbele ruimte"

                        Text {
                            width: parent.width
                            text: "De bar reserveert ruimte via EWMH-struts en bspwm "
                                + "past die toe als padding. Als je hier ook padding "
                                + "instelt, komt daar nog eens ruimte bij. Standaard "
                                + "staat alle padding op 0."
                            color: Theme.yellow
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        // --- Versies (eenmalig) ------------------------------------------

        Process {
            id: bspwmVersionProcess
            command: ["bspwm", "-v"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: win.bspwmVersion = text.trim()
            }
        }

        Process {
            id: sxhkdVersionProcess
            command: ["sxhkd", "-v"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: win.sxhkdVersion = text.trim()
            }
        }

        Process {
            id: quickshellVersionProcess
            command: ["qs", "--version"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: win.quickshellVersion = text.trim()
            }
        }

        Process {
            id: sxhkdReloadProcess
            command: ["pkill", "-USR1", "sxhkd"]

            onExited: (exitCode) => {
                if (exitCode === 0)
                    win.showMessage("Sxhkd herladen")
                else
                    win.showMessage("Sxhkd herladen mislukt (exit " + exitCode + ")")
            }
        }

        Component.onCompleted: {
            bspwmVersionProcess.running = true
            sxhkdVersionProcess.running = true
            quickshellVersionProcess.running = true
        }
    }

    // ====================================================================
    // Inline componenten
    // ====================================================================

    component Card: Rectangle {
        id: card

        default property alias contentData: cardContent.data
        property string heading: ""

        width: parent ? parent.width : 0
        implicitHeight: cardContent.implicitHeight + 32
        radius: Theme.radiusSmall + 2
        color: Theme.mantle
        border.width: 1
        border.color: Theme.surface0

        Column {
            id: cardContent

            x: 16
            y: 16
            width: card.width - 32
            spacing: 12

            Text {
                visible: card.heading.length > 0
                width: parent.width
                text: card.heading
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
            }
        }
    }

    component SliderRow: Column {
        id: sliderRow

        property string label: ""
        property string hint: ""
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property real value: 0
        property string valueText: String(Math.round(sliderRow.value))

        signal moved(real value)

        width: parent ? parent.width : 0
        spacing: 5

        RowLayout {
            width: parent.width
            spacing: 8

            Text {
                text: sliderRow.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }

            Text {
                visible: sliderRow.hint.length > 0
                text: sliderRow.hint
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: sliderRow.valueText
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 48
            }
        }

        Slider {
            id: slider

            width: parent.width
            height: 24
            topPadding: 0
            bottomPadding: 0
            leftPadding: 0
            rightPadding: 0
            from: sliderRow.from
            to: sliderRow.to
            stepSize: sliderRow.stepSize
            value: sliderRow.value
            onMoved: sliderRow.moved(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: Theme.surface1

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition
                    * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 14
                height: 14
                radius: 7
                color: Theme.accent
                border.width: 2
                border.color: Theme.base
            }
        }
    }

    component ToggleRow: RowLayout {
        id: toggleRow

        property string label: ""
        property string hint: ""
        property bool checked: false

        signal toggled(bool checked)

        width: parent ? parent.width : 0
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: toggleRow.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }

            Text {
                visible: toggleRow.hint.length > 0
                Layout.fillWidth: true
                text: toggleRow.hint
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
        }

        Rectangle {
            id: switchTrack

            width: 38
            height: 20
            radius: 10
            color: toggleRow.checked ? Theme.accent : Theme.surface1

            Rectangle {
                x: toggleRow.checked ? switchTrack.width - width - 3 : 3
                y: 3
                width: 14
                height: 14
                radius: 7
                color: toggleRow.checked ? Theme.crust : Theme.overlay0
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleRow.toggled(!toggleRow.checked)
            }
        }
    }

    component ChoiceRow: Column {
        id: choiceRow

        property string label: ""
        property string hint: ""
        property var options: []
        property string value: ""

        signal selected(string value)

        width: parent ? parent.width : 0
        spacing: 6

        RowLayout {
            width: parent.width
            spacing: 8

            Text {
                text: choiceRow.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }

            Text {
                visible: choiceRow.hint.length > 0
                text: choiceRow.hint
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: choiceRow.options

                delegate: Rectangle {
                    id: option

                    required property var modelData

                    readonly property string optionValue:
                        typeof modelData === "object" ? modelData.value : modelData
                    readonly property string optionLabel:
                        typeof modelData === "object" ? modelData.label : modelData
                    readonly property bool active: choiceRow.value === optionValue

                    width: optionLabelText.implicitWidth + 22
                    height: 26
                    radius: Theme.radiusSmall
                    color: option.active
                        ? Theme.accent
                        : (optionArea.containsMouse ? Theme.surface1 : Theme.surface0)

                    Text {
                        id: optionLabelText
                        anchors.centerIn: parent
                        text: option.optionLabel
                        color: option.active ? Theme.crust : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: option.active ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choiceRow.selected(option.optionValue)
                    }
                }
            }
        }
    }

    component ColorRow: RowLayout {
        id: colorRow

        property string label: ""
        property string colorKey: ""

        readonly property string currentColor:
            BspwmSettings.colors[colorRow.colorKey] || "#000000"

        width: parent ? parent.width : 0
        spacing: 10

        Rectangle {
            width: 34
            height: 24
            radius: 5
            color: colorRow.currentColor
            border.width: 1
            border.color: Theme.crust
        }

        Text {
            Layout.fillWidth: true
            text: colorRow.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
        }

        Text {
            text: colorRow.colorKey
            color: Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }

        Rectangle {
            width: 104
            height: 28
            radius: Theme.radiusSmall
            color: Theme.base
            border.width: 1
            border.color: colorInput.activeFocus ? Theme.accent : Theme.surface1

            TextInput {
                id: colorInput

                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                text: colorRow.currentColor
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.crust
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                selectByMouse: true
                clip: true

                onEditingFinished: {
                    BspwmSettings.setColor(colorRow.colorKey, colorInput.text)
                    colorInput.text = colorRow.currentColor
                }

                Connections {
                    target: BspwmSettings

                    // Ook bij focus bijwerken: een preset of "Standaardwaarden"
                    // moet het veld meteen verversen. Anders zou de oude
                    // getypte waarde bij het sluiten opnieuw worden toegepast.
                    function onColorsChanged() {
                        colorInput.text = colorRow.currentColor
                    }
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: actionButton

        property string text: ""
        property bool primary: false
        property bool danger: false
        property bool compact: false

        signal clicked()

        implicitWidth: (actionButton.compact
            ? Math.max(Theme.scaled(26), actionLabel.implicitWidth + Theme.scaled(14))
            : actionLabel.implicitWidth + Theme.scaled(24))
        implicitHeight: Theme.scaled(actionButton.compact ? 26 : 30)
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
            color: {
                if (actionButton.primary || actionButton.danger)
                    return Theme.crust
                return Theme.text
            }
            font.family: Theme.fontFamily
            font.pixelSize: actionButton.compact
                ? Theme.fontSmall : Theme.fontNormal
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

    component InfoRow: RowLayout {
        id: infoRow

        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        spacing: 10

        Text {
            width: 150
            text: infoRow.label
            color: Theme.overlay1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: infoRow.value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
            elide: Text.ElideMiddle
        }
    }
}
