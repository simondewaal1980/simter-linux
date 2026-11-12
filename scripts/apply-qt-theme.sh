#!/bin/sh
# apply-qt-theme.sh — schrijft het Qt 6-palet en de qt6ct-configuratie.
#
# Bron van de kleuren is ~/.config/bspwm/theme.generated.json, hetzelfde
# matugen-palet dat de Quickshell-bar gebruikt. Ontbreekt dat bestand, dan
# gebruikt dit script de Catppuccin Mocha-terugval uit Theme.qml, zodat Qt-apps
# ook zonder matugen een donker thema houden.
#
# Aangeroepen door:
#   - apply-wallpaper-theme.sh (post-hook van matugen, na elke wallpaper);
#   - bspwmrc (bij elke login, ook zonder matugen).
#
# De stylesheet staat in de repository en wordt naar ~/.config/qt6ct/qss
# gesymlinkt. Qt-apps krijgen het thema via QT_QPA_PLATFORMTHEME=qt6ct.

set -eu

CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
GENERATED="$CONFIG_HOME/bspwm/theme.generated.json"
SETTINGS="$CONFIG_HOME/bspwm/settings.json"
QT_DIR="$CONFIG_HOME/qt6ct"
COLORS="$QT_DIR/colors/quickshell-dark.conf"
QSS="$QT_DIR/qss/quickshell.qss"
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

command -v jq >/dev/null 2>&1 || {
    echo "apply-qt-theme: jq ontbreekt" >&2
    exit 1
}

mkdir -p "$QT_DIR/colors" "$QT_DIR/qss"

# Eén stylesheet, rechtstreeks uit de repo; aanpassen gebeurt daar.
ln -sf "$REPO/config/qt6ct/qss/quickshell.qss" "$QSS"

# De kleurrollen volgen QPalette::ColorRole (Qt 6.11), in deze volgorde:
# WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText, ButtonText,
# Base, Window, Shadow, Highlight, HighlightedText, Link, LinkVisited,
# AlternateBase, NoRole, ToolTipBase, ToolTipText, PlaceholderText, Accent.
#
# Semantiek, afgestemd op Theme.qml:
#   Window=base, Base=mantle, Button/AlternateBase=surface0,
#   Mid/Midlight=surface1, Light=surface2, Highlight=accent.
# Met palette(...) in quickshell.qss veranderen die kleuren automatisch mee.
JQ_PROGRAM='
def c: ltrimstr("#") | "#ff" + .;

(.palette // {}) as $p
| (if $accent_override != "" then $accent_override
   else (.bspwm.focused // $p.blue // "#89b4fa") end) as $accent
| ($p.text      // "#cdd6f4") as $text
| ($p.subtext0  // "#a6adc8") as $subtext0
| ($p.overlay0  // "#6c7086") as $overlay0
| ($p.overlay1  // "#7f849c") as $overlay1
| ($p.base      // "#1e1e2e") as $base
| ($p.mantle    // "#181825") as $mantle
| ($p.crust     // "#11111b") as $crust
| ($p.surface0  // "#313244") as $surface0
| ($p.surface1  // "#45475a") as $surface1
| ($p.surface2  // "#585b70") as $surface2
| ($p.red       // "#f38ba8") as $red
| ($p.blue      // "#89b4fa") as $blue
| ($p.mauve     // "#cba6f7") as $mauve
| {
    active: ([
        $text, $surface0, $surface2, $surface1, $crust, $surface1,
        $text, $red, $text, $mantle, $base, $crust,
        $accent, $crust, $blue, $mauve, $surface0, $base,
        $mantle, $text, $overlay1, $accent
    ] | map(c) | join(", ")),
    inactive: ([
        $subtext0, $surface0, $surface2, $surface1, $crust, $surface1,
        $subtext0, $red, $subtext0, $mantle, $base, $crust,
        $accent, $crust, $blue, $mauve, $surface0, $base,
        $mantle, $subtext0, $overlay0, $accent
    ] | map(c) | join(", ")),
    disabled: ([
        $overlay1, $surface0, $surface2, $surface1, $crust, $surface1,
        $overlay1, $overlay1, $overlay1, $mantle, $base, $crust,
        $surface1, $subtext0, $overlay1, $overlay1, $surface0, $base,
        $mantle, $overlay1, $overlay1, $surface1
    ] | map(c) | join(", "))
  }
| "[ColorScheme]\nactive_colors=\(.active)\ninactive_colors=\(.inactive)\ndisabled_colors=\(.disabled)"
'

tmp_colors=$(mktemp "$QT_DIR/colors/.quickshell-dark.XXXXXX")
tmp_conf=$(mktemp "$QT_DIR/.qt6ct.conf.XXXXXX")
trap 'rm -f "$tmp_colors" "$tmp_conf"' EXIT

# De accentkleur volgt BSPWM/Theme.accent (settings.json) als die bestaat;
# zo nemen ook handmatige kleurpresets uit het instellingenvenster het Qt-thema
# mee. Zonder settings.json valt het terug op het wallpaper-palet.
ACCENT_OVERRIDE=""
if [ -r "$SETTINGS" ]; then
    ACCENT_OVERRIDE=$(jq -r '.colors.focused // empty' "$SETTINGS" 2>/dev/null || true)
fi

if [ -r "$GENERATED" ]; then
    jq -r --arg accent_override "$ACCENT_OVERRIDE" "$JQ_PROGRAM" "$GENERATED" >"$tmp_colors"
else
    printf '{}' | jq -r --arg accent_override "$ACCENT_OVERRIDE" "$JQ_PROGRAM" >"$tmp_colors"
fi

# qt6ct leest de paden als absolute paden; daarom wordt de config bij elke
# login/verandering opnieuw geschreven in plaats van als symlink beheerd.
cat >"$tmp_conf" <<EOF
# Gegenereerd door scripts/apply-qt-theme.sh. Niet handmatig aanpassen:
# wijzigingen worden bij de volgende wallpaper of login overschreven.
[Appearance]
style=Fusion
custom_palette=true
color_scheme_path=$COLORS
icon_theme=Papirus-Dark
standard_dialogs=default

[Fonts]
general="JetBrains Mono,10.5,-1,5,50,0,0,0,0,0"
fixed="JetBrains Mono,10.5,-1,5,50,0,0,0,0,0"

[Interface]
stylesheets=$QSS
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
wheel_scroll_lines=3
EOF

chmod 644 "$tmp_colors" "$tmp_conf"
mv "$tmp_colors" "$COLORS"
mv "$tmp_conf" "$QT_DIR/qt6ct.conf"
trap - EXIT
