pragma Singleton

// Theme.qml — kleuren, maten en lettertypen voor de hele shell.
//
// De BSPWM-kleuren komen uit ~/.config/bspwm/settings.json, dezelfde bron die
// apply-bspwm-settings.sh gebruikt. FileView.watchChanges zorgt ervoor dat een
// wijziging in dat bestand direct doorwerkt in de bar (en vanaf fase 7 in het
// instellingenvenster).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- Configuratiepad ---------------------------------------------------

    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME")
        if (xdg && xdg.length > 0)
            return xdg
        return Quickshell.env("HOME") + "/.config"
    }

    readonly property string bspwmSettingsPath: configHome + "/bspwm/settings.json"

    FileView {
        id: settingsFile
        path: root.bspwmSettingsPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()

        // JsonAdapter houdt de waarden reactief: wijzigingen op schijf werken
        // na reload() direct door in de bindings hieronder.
        JsonAdapter {
            id: settingsAdapter

            property var colors: ({})
            property var padding: ({})
            property var behavior: ({})
            property var layout: ({})
            property int window_gap: 8
            property int border_width: 2
            property real split_ratio: 0.52
        }
    }

    readonly property var settings: ({
        "colors": settingsAdapter.colors,
        "padding": settingsAdapter.padding,
        "behavior": settingsAdapter.behavior,
        "layout": settingsAdapter.layout,
        "window_gap": settingsAdapter.window_gap,
        "border_width": settingsAdapter.border_width,
        "split_ratio": settingsAdapter.split_ratio
    })

    function configuredColor(section, key, fallback) {
        const group = root.settings[section]
        if (!group || typeof group !== "object")
            return fallback
        const value = group[key]
        return typeof value === "string" && value.length > 0 ? value : fallback
    }

    // --- Catppuccin Mocha-palet -------------------------------------------

    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color subtext0: "#a6adc8"
    readonly property color subtext1: "#bac2de"
    readonly property color text: "#cdd6f4"

    readonly property color blue: "#89b4fa"
    readonly property color lavender: "#b4befe"
    readonly property color mauve: "#cba6f7"
    readonly property color pink: "#f5c2e7"
    readonly property color red: "#f38ba8"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color teal: "#94e2d5"
    readonly property color sky: "#89dceb"

    // --- Semantische kleuren (BSPWM + bar) --------------------------------

    // Accent = focused_border_color van BSPWM.
    readonly property color accent: configuredColor("colors", "focused", blue)
    // Gedempte accentkleur = active_border_color.
    readonly property color accentMuted: configuredColor("colors", "active", overlay0)
    // Randkleur van niet-gefocuste vensters; ook de subtiele balkrand.
    readonly property color borderNormal: configuredColor("colors", "normal", surface0)
    readonly property color preselFeedback: configuredColor("colors", "presel_feedback", teal)

    readonly property color barBackground: mantle
    readonly property color barForeground: text
    readonly property color barMuted: subtext0
    readonly property color workspaceEmpty: overlay1
    readonly property color workspaceOccupied: subtext1
    readonly property color urgent: red

    // --- Maten en typografie ----------------------------------------------

    readonly property int barHeight: 34
    readonly property int barPadding: 10
    readonly property int radiusSmall: 6
    readonly property int spacing: 8
    readonly property int spacingSmall: 4

    readonly property string fontFamily: "JetBrains Mono"
    readonly property string iconFamily: "Font Awesome 6 Free Solid"

    readonly property int fontSmall: 10
    readonly property int fontNormal: 12
    readonly property int fontLarge: 13
    readonly property int iconSize: 13
}
