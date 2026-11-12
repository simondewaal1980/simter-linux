pragma Singleton

// Theme.qml — kleuren, maten en lettertypen voor de hele shell.
//
// Het volledige palet komt uit ~/.config/bspwm/theme.generated.json, dat
// scripts/wallpaper-theme.sh met matugen uit de wallpaper genereert. Ontbreekt
// dat bestand, dan blijft Catppuccin Mocha de terugval.
//
// De BSPWM-kleuren komen uit ~/.config/bspwm/settings.json, dezelfde bron die
// apply-bspwm-settings.sh gebruikt; de wallpaper-post-hook houdt die kleuren
// gelijk aan het gegenereerde palet. FileView.watchChanges zorgt ervoor dat
// wijzigingen direct doorwerken in de bar (en in het instellingenvenster).

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
            property var ui: ({})
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
        "ui": settingsAdapter.ui,
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

    // --- Wallpaper-palet (matugen) ----------------------------------------

    // scripts/wallpaper-theme.sh schrijft dit bestand op basis van de huidige
    // wallpaper. Ontbreekt het (of is het ongeldig), dan blijft het
    // Catppuccin-palet hieronder de terugval. watchChanges zorgt dat een
    // nieuwe wallpaper zonder herstart van de shell doorwerkt.
    readonly property string generatedThemePath: configHome + "/bspwm/theme.generated.json"

    FileView {
        id: generatedThemeFile
        path: root.generatedThemePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: generatedTheme

            property bool generated: false
            property string wallpaper: ""
            property var palette: ({})
        }
    }

    readonly property bool wallpaperThemed: generatedTheme.generated
    readonly property string wallpaperPath: generatedTheme.wallpaper

    function paletteColor(key, fallback) {
        const palette = generatedTheme.palette
        if (palette && typeof palette === "object") {
            const value = palette[key]
            if (typeof value === "string" && value.length > 0)
                return value
        }
        return fallback
    }

    // --- Kleurenpalet ------------------------------------------------------
    // Bron: wallpaper-palet hierboven; Catppuccin Mocha als terugval.

    readonly property color base: paletteColor("base", "#1e1e2e")
    readonly property color mantle: paletteColor("mantle", "#181825")
    readonly property color crust: paletteColor("crust", "#11111b")
    readonly property color surface0: paletteColor("surface0", "#313244")
    readonly property color surface1: paletteColor("surface1", "#45475a")
    readonly property color surface2: paletteColor("surface2", "#585b70")
    readonly property color overlay0: paletteColor("overlay0", "#6c7086")
    readonly property color overlay1: paletteColor("overlay1", "#7f849c")
    readonly property color subtext0: paletteColor("subtext0", "#a6adc8")
    readonly property color subtext1: paletteColor("subtext1", "#bac2de")
    readonly property color text: paletteColor("text", "#cdd6f4")

    readonly property color blue: paletteColor("blue", "#89b4fa")
    readonly property color lavender: paletteColor("lavender", "#b4befe")
    readonly property color mauve: paletteColor("mauve", "#cba6f7")
    readonly property color pink: paletteColor("pink", "#f5c2e7")
    readonly property color red: paletteColor("red", "#f38ba8")
    readonly property color peach: paletteColor("peach", "#fab387")
    readonly property color yellow: paletteColor("yellow", "#f9e2af")
    readonly property color green: paletteColor("green", "#a6e3a1")
    readonly property color teal: paletteColor("teal", "#94e2d5")
    readonly property color sky: paletteColor("sky", "#89dceb")

    // --- Semantische kleuren (BSPWM + bar) --------------------------------

    // Accent = focused_border_color van BSPWM.
    readonly property color accent: configuredColor("colors", "focused", blue)
    // Gedempte accentkleur = active_border_color.
    readonly property color accentMuted: configuredColor("colors", "active", overlay0)
    // Randkleur van niet-gefocuste vensters; ook de subtiele balkrand.
    readonly property color borderNormal: configuredColor("colors", "normal", surface0)
    readonly property color preselFeedback: configuredColor("colors", "presel_feedback", teal)

    // De barachtergrond is standaard semi-transparant; het dekkingsniveau
    // staat in settings.json → ui.bar_opacity (0.3–1.0) en is instelbaar op
    // het tabblad Weergave. barBackground blijft de volledig dekkende kleur.
    readonly property color barBackground: mantle
    readonly property color barBackgroundTransparent: Qt.rgba(
        barBackground.r, barBackground.g, barBackground.b, barOpacity)
    readonly property color barForeground: text
    readonly property color barMuted: subtext0
    readonly property color workspaceEmpty: overlay1
    readonly property color workspaceOccupied: subtext1
    readonly property color urgent: red

    // --- Maten en typografie ----------------------------------------------
    //
    // De schaal is instelbaar in het instellingenvenster (settings.json →
    // ui.scale). Alle maten hieronder schalen mee, zodat de bar, de widgets
    // en de popups leesbaar blijven. De standaard is bewust groter dan
    // voorheen: 14 px normale tekst en 16 px iconen.

    readonly property real uiScale: {
        const ui = settingsAdapter.ui
        const value = ui && typeof ui === "object" ? ui.scale : undefined
        if (typeof value !== "number" || !isFinite(value))
            return 1
        return Math.min(1.5, Math.max(0.8, value))
    }

    // Dekking van de barachtergrond (1.0 = volledig dekkend). De ondergrens
    // van 0.3 voorkomt dat de bar onleesbaar wordt.
    readonly property real barOpacity: {
        const ui = settingsAdapter.ui
        const value = ui && typeof ui === "object" ? ui.bar_opacity : undefined
        if (typeof value !== "number" || !isFinite(value))
            return 0.8
        return Math.min(1.0, Math.max(0.3, value))
    }

    function scaled(value) {
        return Math.round(value * root.uiScale)
    }

    readonly property int barHeight: scaled(42)
    readonly property int barPadding: scaled(10)
    readonly property int radiusSmall: scaled(6)
    readonly property int spacing: scaled(8)
    readonly property int spacingSmall: scaled(4)

    readonly property string fontFamily: "JetBrains Mono"
    readonly property string iconFamily: "Font Awesome 6 Free Solid"

    readonly property int fontTiny: scaled(10)
    readonly property int fontSmall: scaled(12)
    readonly property int fontNormal: scaled(14)
    readonly property int fontLarge: scaled(16)
    readonly property int iconSize: scaled(16)

    // Vaste maten van de bar en widgets; deze schalen ook mee.
    readonly property int widgetHeight: scaled(28)
    readonly property int iconButtonSize: scaled(28)
    readonly property int workspaceWidth: scaled(26)
    readonly property int barSpacing: scaled(14)
    readonly property int separatorHeight: scaled(16)
}
