pragma Singleton

// BspwmSettings.qml — één bron van waarheid voor de BSPWM-instellingen.
//
// Leest ~/.config/bspwm/settings.json (met settings.default.json als
// terugval), past wijzigingen direct toe met `bspc config` en schrijft ze met
// een korte vertraging terug naar hetzelfde JSON-bestand. Het bestand wordt
// atomair geschreven, zodat een crash nooit een half bestand achterlaat.
//
// Dezelfde JSON wordt door scripts/apply-bspwm-settings.sh bij elke bspwm-start
// toegepast en door Theme.qml gelezen voor de barkleuren. Zo blijven BSPWM,
// de bar en het instellingenvenster synchroon.
//
// Debounce:
//   - 120 ms voordat een sleepwijziging naar bspc gaat (sliders);
//   - 500 ms voordat het bestand wordt geschreven (minder schijfverkeer).
// Een expliciete reset schrijft en past direct toe.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- Paden ------------------------------------------------------------

    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME")
        if (xdg && xdg.length > 0)
            return xdg
        return Quickshell.env("HOME") + "/.config"
    }

    readonly property string settingsPath: root.configHome + "/bspwm/settings.json"
    readonly property string defaultSettingsPath: root.configHome + "/bspwm/settings.default.json"
    readonly property string layoutStatePath: Quickshell.statePath("bspwm-layout.json")

    // --- Standaardwaarden -------------------------------------------------
    // Dezelfde waarden als config/bspwm/settings.default.json. Ze dienen als
    // terugval wanneer het bestand ontbreekt of een sleutel mist.

    readonly property var defaults: ({
        "window_gap": 8,
        "border_width": 2,
        "split_ratio": 0.52,
        "padding": {
            "top": 0,
            "right": 0,
            "bottom": 0,
            "left": 0
        },
        "colors": {
            "focused": "#89b4fa",
            "normal": "#313244",
            "active": "#6c7086",
            "presel_feedback": "#94e2d5"
        },
        "behavior": {
            "focus_follows_pointer": true,
            "pointer_follows_focus": false,
            "click_to_focus": "any",
            "pointer_modifier": "mod4",
            "swallow_first_click": false,
            "ignore_ewmh_fullscreen": "none",
            "remove_unplugged_monitors": true,
            "merge_overlapping_monitors": false
        },
        "layout": {
            "automatic_scheme": "longest_side",
            "initial_polarity": "second_child",
            "single_monocle": false,
            "borderless_singleton": false,
            "borderless_monocle": false,
            "gapless_monocle": false
        },
        "ui": {
            "scale": 1.0,
            "bar_opacity": 0.8
        }
    })

    // --- In-memory state --------------------------------------------------

    property int windowGap: root.defaults.window_gap
    property int borderWidth: root.defaults.border_width
    property real splitRatio: root.defaults.split_ratio
    property var padding: root.cloneGroup(root.defaults.padding, root.defaults.padding)
    property var colors: root.cloneGroup(root.defaults.colors, root.defaults.colors)
    property var behavior: root.cloneGroup(root.defaults.behavior, root.defaults.behavior)
    property var layout: root.cloneGroup(root.defaults.layout, root.defaults.layout)
    property var ui: root.cloneGroup(root.defaults.ui, root.defaults.ui)

    // --- Status voor de UI ------------------------------------------------

    property bool loaded: false
    property bool dirty: false
    property string lastError: ""
    property string lastAction: ""
    property var lastSavedAt: null

    property var monitorNames: []

    // --- Sleutelkoppelingen met bspc --------------------------------------

    readonly property var colorKeys: ({
        "focused": "focused_border_color",
        "normal": "normal_border_color",
        "active": "active_border_color",
        "presel_feedback": "presel_feedback_color"
    })

    readonly property var behaviorKeys: ({
        "focus_follows_pointer": "focus_follows_pointer",
        "pointer_follows_focus": "pointer_follows_focus",
        "click_to_focus": "click_to_focus",
        "pointer_modifier": "pointer_modifier",
        "swallow_first_click": "swallow_first_click",
        "ignore_ewmh_fullscreen": "ignore_ewmh_fullscreen",
        "remove_unplugged_monitors": "remove_unplugged_monitors",
        "merge_overlapping_monitors": "merge_overlapping_monitors"
    })

    readonly property var layoutKeys: ({
        "automatic_scheme": "automatic_scheme",
        "initial_polarity": "initial_polarity",
        "single_monocle": "single_monocle",
        "borderless_singleton": "borderless_singleton",
        "borderless_monocle": "borderless_monocle",
        "gapless_monocle": "gapless_monocle"
    })

    // Presets voor de kleurentab. De focused-kleur is tegelijk het accent in
    // de bar (Theme.accent), zodat een preset in één klik overal doorwerkt.
    readonly property var colorPresets: ([
        {
            "name": "Catppuccin Mocha",
            "colors": {
                "focused": "#89b4fa",
                "normal": "#313244",
                "active": "#6c7086",
                "presel_feedback": "#94e2d5"
            }
        },
        {
            "name": "Nord",
            "colors": {
                "focused": "#88c0d0",
                "normal": "#3b4252",
                "active": "#4c566a",
                "presel_feedback": "#8fbcbb"
            }
        },
        {
            "name": "Gruvbox",
            "colors": {
                "focused": "#83a598",
                "normal": "#3c3836",
                "active": "#504945",
                "presel_feedback": "#8ec07c"
            }
        },
        {
            "name": "Tokyo Night",
            "colors": {
                "focused": "#7aa2f7",
                "normal": "#292e42",
                "active": "#565f89",
                "presel_feedback": "#73daca"
            }
        },
        {
            "name": "Dracula",
            "colors": {
                "focused": "#bd93f9",
                "normal": "#44475a",
                "active": "#6272a4",
                "presel_feedback": "#50fa7b"
            }
        },
        {
            "name": "One Dark",
            "colors": {
                "focused": "#61afef",
                "normal": "#3e4451",
                "active": "#5c6370",
                "presel_feedback": "#98c379"
            }
        },
        {
            "name": "Rosé Pine",
            "colors": {
                "focused": "#ebbcba",
                "normal": "#26233a",
                "active": "#6e6a86",
                "presel_feedback": "#31748f"
            }
        },
        {
            "name": "Everforest",
            "colors": {
                "focused": "#a7c080",
                "normal": "#343f44",
                "active": "#859289",
                "presel_feedback": "#dbbc7f"
            }
        }
    ])

    // --- Hulpjes ----------------------------------------------------------

    function numberOr(value, fallback) {
        return typeof value === "number" && isFinite(value) ? value : fallback
    }

    function stringOr(value, fallback) {
        return typeof value === "string" && value.length > 0 ? value : fallback
    }

    function booleanOr(value, fallback) {
        return typeof value === "boolean" ? value : fallback
    }

    function cloneGroup(value, fallback) {
        const result = {}
        const source = (value && typeof value === "object") ? value : {}
        for (const key in fallback) {
            result[key] = (key in source) ? source[key] : fallback[key]
        }
        return result
    }

    function clamp(value, minimum, maximum) {
        return Math.min(maximum, Math.max(minimum, value))
    }

    function formatValue(value) {
        if (typeof value === "boolean")
            return value ? "true" : "false"
        if (typeof value === "number")
            return String(value)
        return String(value)
    }

    function normalizeColor(value) {
        const text = String(value).trim().toLowerCase()
        if (/^#[0-9a-f]{6}$/.test(text))
            return text
        if (/^#[0-9a-f]{3}$/.test(text)) {
            return "#" + text.charAt(1) + text.charAt(1)
                + text.charAt(2) + text.charAt(2)
                + text.charAt(3) + text.charAt(3)
        }
        return ""
    }

    // --- Laden ------------------------------------------------------------

    function applyData(data) {
        root.windowGap = Math.round(root.numberOr(data.window_gap,
            root.defaults.window_gap))
        root.borderWidth = Math.round(root.numberOr(data.border_width,
            root.defaults.border_width))
        root.splitRatio = root.clamp(root.numberOr(data.split_ratio,
            root.defaults.split_ratio), 0.05, 0.95)
        root.padding = root.cloneGroup(data.padding, root.defaults.padding)
        root.colors = root.cloneGroup(data.colors, root.defaults.colors)
        root.behavior = root.cloneGroup(data.behavior, root.defaults.behavior)
        root.layout = root.cloneGroup(data.layout, root.defaults.layout)

        const ui = root.cloneGroup(data.ui, root.defaults.ui)
        ui.scale = root.clamp(root.numberOr(ui.scale, root.defaults.ui.scale),
            0.8, 1.5)
        ui.bar_opacity = root.clamp(root.numberOr(ui.bar_opacity,
            root.defaults.ui.bar_opacity), 0.3, 1.0)
        root.ui = ui
    }

    function parseJson(text) {
        if (!text || text.length === 0)
            return null
        try {
            const data = JSON.parse(text)
            return (data && typeof data === "object") ? data : null
        } catch (error) {
            return null
        }
    }

    // Ververs de bestandscache en laat onLoaded de waarden toepassen. Dit is
    // nodig voordat het instellingenvenster opent: na een eigen schrijfactie
    // kan de cache van settingsFile nog de oude inhoud bevatten.
    function reloadFromDisk() {
        settingsFile.reload()
    }

    // Leest settings.json opnieuw. Tijdens een eigen schrijfactie of een
    // lopende debounce negeren we de melding, zodat de UI niet terugspringt
    // naar een net iets oudere versie van het bestand.
    function loadFromDisk(force) {
        const text = settingsFile.text()
        if (!text || text.trim().length === 0) {
            if (force)
                root.lastError = "settings.json ontbreekt; standaardwaarden gebruikt"
            return false
        }
        if (!force && (root.dirty || saveTimer.running || applyTimer.running))
            return false

        const data = root.parseJson(text)
        if (data === null) {
            root.lastError = "settings.json bevat ongeldige JSON"
            return false
        }

        root.applyData(data)
        root.loaded = true
        root.lastError = ""
        return true
    }

    // --- Opslaan ----------------------------------------------------------

    function serialize() {
        return JSON.stringify({
            "window_gap": root.windowGap,
            "border_width": root.borderWidth,
            "split_ratio": root.splitRatio,
            "padding": root.padding,
            "colors": root.colors,
            "behavior": root.behavior,
            "layout": root.layout,
            "ui": root.ui
        }, null, 2) + "\n"
    }

    function markDirty() {
        root.dirty = true
        saveTimer.restart()
    }

    function saveNow() {
        if (!root.loaded) {
            root.lastError = "Nog geen instellingen geladen"
            return
        }
        settingsWriter.setText(root.serialize())
        root.dirty = false
    }

    // --- Toepassen op bspwm ----------------------------------------------

    // Wachtrij met bspc-commando's. Eén proces tegelijk, zodat een snel
    // bewogen slider geen processen opstapelt; gelijke commando's worden
    // gecoalesceerd (de laatste waarde wint).
    property var pendingCommands: []
    property var commandQueue: []
    property bool applying: false
    property var lastAppliedCommand: []

    function commandKey(args) {
        return args.join("\u001f")
    }

    function enqueue(args) {
        const key = root.commandKey(args)
        const next = []
        for (var i = 0; i < root.pendingCommands.length; i++) {
            if (root.commandKey(root.pendingCommands[i]) !== key)
                next.push(root.pendingCommands[i])
        }
        next.push(args)
        root.pendingCommands = next
        applyTimer.restart()
    }

    function flushApply() {
        if (root.pendingCommands.length > 0) {
            root.commandQueue = root.commandQueue.concat(root.pendingCommands)
            root.pendingCommands = []
        }
        root.pumpCommands()
    }

    function pumpCommands() {
        if (root.applying)
            return
        if (root.commandQueue.length === 0)
            return

        const next = root.commandQueue[0]
        root.commandQueue = root.commandQueue.slice(1)
        root.lastAppliedCommand = next
        root.applying = true
        applyProcess.command = next
        applyProcess.running = true
    }

    function queueChange(args) {
        root.enqueue(args)
        root.markDirty()
    }

    // --- Setters: gaps, randen, ratio -------------------------------------

    function setWindowGap(value) {
        const next = Math.max(0, Math.round(value))
        if (next === root.windowGap)
            return
        root.windowGap = next
        root.queueChange(["bspc", "config", "window_gap", String(next)])
    }

    function setBorderWidth(value) {
        const next = Math.max(0, Math.round(value))
        if (next === root.borderWidth)
            return
        root.borderWidth = next
        root.queueChange(["bspc", "config", "border_width", String(next)])
    }

    function setSplitRatio(value) {
        const next = Math.round(root.clamp(value, 0.05, 0.95) * 100) / 100
        if (next === root.splitRatio)
            return
        root.splitRatio = next
        root.queueChange(["bspc", "config", "split_ratio", next.toFixed(2)])
    }

    // --- Setters: padding (per monitor, maar één waarde voor allemaal) -----

    function refreshMonitors() {
        if (!monitorsProcess.running)
            monitorsProcess.running = true
    }

    function applyPadding(side, value) {
        const key = side + "_padding"
        const names = root.monitorNames.length > 0
            ? root.monitorNames : ["focused"]
        for (var i = 0; i < names.length; i++)
            root.enqueue(["bspc", "config", "-m", names[i], key, String(value)])
    }

    function setPadding(side, value) {
        if (!(side in root.defaults.padding))
            return
        const next = root.cloneGroup(root.padding, root.defaults.padding)
        const number = root.clamp(Math.round(value), 0, 400)
        if (next[side] === number)
            return
        next[side] = number
        root.padding = next
        root.applyPadding(side, number)
        root.markDirty()
    }

    // --- Setters: kleuren -------------------------------------------------

    function setColor(key, value) {
        if (!(key in root.defaults.colors))
            return false
        const color = root.normalizeColor(value)
        if (color.length === 0) {
            root.lastError = "Ongeldige kleur (gebruik #rrggbb)"
            return false
        }
        if (root.colors[key] === color)
            return true

        const next = root.cloneGroup(root.colors, root.defaults.colors)
        next[key] = color
        root.colors = next
        root.queueChange(["bspc", "config", root.colorKeys[key], color])
        root.lastError = ""
        return true
    }

    function applyPreset(index) {
        const preset = root.colorPresets[index]
        if (!preset)
            return
        root.colors = root.cloneGroup(preset.colors, root.defaults.colors)
        for (const key in preset.colors)
            root.enqueue(["bspc", "config", root.colorKeys[key], preset.colors[key]])
        root.markDirty()
        root.lastAction = preset.name + " toegepast"
    }

    // --- Setters: gedrag en layout ---------------------------------------

    function setBehavior(key, value) {
        if (!(key in root.defaults.behavior))
            return
        if (root.behavior[key] === value)
            return
        const next = root.cloneGroup(root.behavior, root.defaults.behavior)
        next[key] = value
        root.behavior = next
        root.queueChange(["bspc", "config", root.behaviorKeys[key],
            root.formatValue(value)])
    }

    function setLayout(key, value) {
        if (!(key in root.defaults.layout))
            return
        if (root.layout[key] === value)
            return
        const next = root.cloneGroup(root.layout, root.defaults.layout)
        next[key] = value
        root.layout = next
        root.queueChange(["bspc", "config", root.layoutKeys[key],
            root.formatValue(value)])
    }

    // --- Setters: weergave ------------------------------------------------

    // Weergavewijzigingen moeten direct zichtbaar zijn: Theme leest
    // settings.json met watchChanges, dus schrijf meteen in plaats van na de
    // debounce.
    function persistUi() {
        root.markDirty()
        if (root.loaded) {
            saveTimer.stop()
            root.saveNow()
        }
    }

    function setUiScale(value) {
        const next = Math.round(root.clamp(value, 0.8, 1.5) * 100) / 100
        if (next === root.ui.scale)
            return

        const ui = root.cloneGroup(root.ui, root.defaults.ui)
        ui.scale = next
        root.ui = ui
        root.persistUi()
    }

    // Dekking van de barachtergrond: 1.0 is volledig dekkend, 0.3 is de
    // ondergrens zodat de bar leesbaar blijft.
    function setBarOpacity(value) {
        const next = Math.round(root.clamp(value, 0.3, 1.0) * 100) / 100
        if (Math.abs(next - root.ui.bar_opacity) < 0.001)
            return

        const ui = root.cloneGroup(root.ui, root.defaults.ui)
        ui.bar_opacity = next
        root.ui = ui
        root.persistUi()
    }

    // --- Alles toepassen / reset -----------------------------------------

    function applyAll() {
        root.enqueue(["bspc", "config", "window_gap", String(root.windowGap)])
        root.enqueue(["bspc", "config", "border_width", String(root.borderWidth)])
        root.enqueue(["bspc", "config", "split_ratio", root.splitRatio.toFixed(2)])

        for (const key in root.colors)
            root.enqueue(["bspc", "config", root.colorKeys[key], root.colors[key]])
        for (const key in root.behavior)
            root.enqueue(["bspc", "config", root.behaviorKeys[key],
                root.formatValue(root.behavior[key])])
        for (const key in root.layout)
            root.enqueue(["bspc", "config", root.layoutKeys[key],
                root.formatValue(root.layout[key])])

        for (const side in root.padding)
            root.applyPadding(side, root.padding[side])
    }

    function reset() {
        const text = defaultFile.text()
        const data = root.parseJson(text)
        if (data === null) {
            root.lastError = "Standaardwaarden niet leesbaar: " + root.defaultSettingsPath
            return false
        }

        root.applyData(data)
        root.applyAll()
        root.flushApply()
        root.dirty = true
        saveTimer.stop()
        root.saveNow()
        root.lastAction = "Standaardwaarden hersteld"
        root.lastError = ""
        return true
    }

    // --- Layout van het hele bureaublad bewaren/herstellen (optioneel) ----

    function saveLayoutState() {
        if (!layoutDumpProcess.running)
            layoutDumpProcess.running = true
    }

    function restoreLayoutState() {
        if (layoutRestoreProcess.running)
            return
        layoutRestoreProcess.command = ["bspc", "wm", "-l", root.layoutStatePath]
        layoutRestoreProcess.running = true
    }

    // --- Diagnostiek ------------------------------------------------------

    function status() {
        return JSON.stringify({
            settingsPath: root.settingsPath,
            defaultSettingsPath: root.defaultSettingsPath,
            layoutStatePath: root.layoutStatePath,
            loaded: root.loaded,
            dirty: root.dirty,
            error: root.lastError,
            action: root.lastAction,
            windowGap: root.windowGap,
            borderWidth: root.borderWidth,
            splitRatio: root.splitRatio,
            padding: root.padding,
            colors: root.colors,
            behavior: root.behavior,
            layout: root.layout,
            ui: root.ui,
            monitors: root.monitorNames,
            lastSavedAt: root.lastSavedAt ? root.lastSavedAt.toISOString() : null
        })
    }

    // --- Bestanden --------------------------------------------------------

    // Alleen bij het starten (en expliciet via openWindow) lezen. Een
    // watchChanges op dit bestand gaf een race met onze eigen atomaire
    // schrijfactie: de watcher kon vlak na het schrijven nog de oude inhoud
    // inlezen en de zojuist gezette waarde terugdraaien. Theme.qml houdt wel
    // een watcher voor de barkleuren; die schrijft nooit.
    FileView {
        id: settingsFile
        path: root.settingsPath
        blockLoading: true
        printErrors: false

        onLoaded: root.loadFromDisk(false)
    }

    FileView {
        id: defaultFile
        path: root.defaultSettingsPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: settingsWriter
        path: root.settingsPath
        atomicWrites: true
        printErrors: false

        onSaved: {
            root.lastSavedAt = new Date()
            root.lastAction = "Opgeslagen"
        }
    }

    FileView {
        id: layoutWriter
        path: root.layoutStatePath
        atomicWrites: true
        printErrors: false

        onSaved: root.lastAction = "Layout bewaard"
    }

    // --- Processen --------------------------------------------------------

    Timer {
        id: applyTimer
        interval: 120
        repeat: false
        running: false
        onTriggered: root.flushApply()
    }

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        running: false
        onTriggered: root.saveNow()
    }

    Process {
        id: applyProcess

        onExited: (exitCode) => {
            // bspwm 0.9.12 geeft exitcode 1 als een boolean al dezelfde
            // waarde heeft. Dat is geen echte fout; alleen bij een hogere
            // code melden we het.
            if (exitCode > 1) {
                root.lastError = "bspc config mislukt (" + exitCode + "): "
                    + root.lastAppliedCommand.join(" ")
            } else if (root.lastError.indexOf("bspc config") === 0) {
                root.lastError = ""
            }
            root.applying = false
            root.pumpCommands()
        }
    }

    Process {
        id: monitorsProcess
        command: ["bspc", "query", "-M", "--names"]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                const names = []
                const lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    const name = lines[i].trim()
                    if (name.length > 0)
                        names.push(name)
                }
                root.monitorNames = names
            }
        }
    }

    Process {
        id: layoutDumpProcess
        command: ["bspc", "wm", "-d"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim().length > 0)
                    layoutWriter.setText(text)
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Layout bewaren mislukt (" + exitCode + ")"
        }
    }

    Process {
        id: layoutRestoreProcess

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Layout herstellen mislukt (" + exitCode + ")"
            else
                root.lastAction = "Layout hersteld"
        }
    }

    Component.onCompleted: {
        root.loadFromDisk(true)
        // Ook zonder bestaand settings.json is de UI bruikbaar: de
        // standaardwaarden staan dan in het geheugen en de eerste wijziging
        // schrijft het bestand alsnog.
        root.loaded = true
        root.refreshMonitors()
    }
}
