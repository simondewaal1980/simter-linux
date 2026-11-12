#!/bin/sh
# wallpaper-theme.sh — wallpaper zetten én een donker kleurenpalet genereren.
#
# Gebruik:
#   wallpaper-theme.sh [--quiet]             huidige wallpaper (of standaard)
#   wallpaper-theme.sh [--quiet] <afbeelding> specifieke afbeelding
#   wallpaper-theme.sh [--quiet] next         volgende wallpaper uit de map
#
# Het palet komt van matugen (Material You, donkere variant) en wordt toegepast
# op Quickshell (Theme.qml), BSPWM-randen, GTK 3/4, Qt 6 (qt6ct), alacritty en
# rofi. De wallpaper zelf wordt met feh gezet (via [config.wallpaper] in
# matugen).
#
# Vereist: matugen (user-local in ~/.local/bin mag), feh, jq.

set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MATUGEN_CONFIG="$REPO/config/matugen/config.toml"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bspwm"
STATE_FILE="$CONFIG_DIR/wallpaper"
DEFAULT_WALLPAPER="$HOME/Pictures/wallpaper.jpg"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

QUIET=0
usage() {
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

matugen_bin() {
    if command -v matugen >/dev/null 2>&1; then
        command -v matugen
    elif [ -x "$HOME/.local/bin/matugen" ]; then
        echo "$HOME/.local/bin/matugen"
    else
        return 1
    fi
}

wallpaper_list() {
    {
        [ -r "$DEFAULT_WALLPAPER" ] && printf '%s\n' "$DEFAULT_WALLPAPER"
        if [ -d "$WALLPAPER_DIR" ]; then
            find "$WALLPAPER_DIR" -maxdepth 1 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                   -o -iname '*.webp' \) | sort
        fi
    } | awk '!seen[$0]++'
}

next_wallpaper() {
    list=$(wallpaper_list)
    [ -n "$list" ] || return 1
    current=""
    [ -r "$STATE_FILE" ] && current=$(cat "$STATE_FILE")
    printf '%s\n' "$list" | awk -v cur="$current" '
        { line[NR] = $0; if ($0 == cur) found = NR }
        END {
            if (found && found < NR) print line[found + 1]
            else print line[1]
        }
    '
}

# --- Argumenten -----------------------------------------------------------

TARGET=""
for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=1 ;;
        -h|--help) usage; exit 0 ;;
        *) TARGET=$arg ;;
    esac
done

# --- Wallpaper kiezen -----------------------------------------------------

if [ "$TARGET" = "next" ]; then
    image=$(next_wallpaper) || {
        echo "wallpaper-theme: geen wallpapers gevonden in $WALLPAPER_DIR" >&2
        exit 1
    }
elif [ -n "$TARGET" ]; then
    image=$TARGET
else
    image=""
    [ -r "$STATE_FILE" ] && image=$(cat "$STATE_FILE")
    [ -n "$image" ] || image="$DEFAULT_WALLPAPER"
fi

if [ ! -r "$image" ]; then
    echo "wallpaper-theme: afbeelding niet gevonden: $image" >&2
    exit 1
fi

MATUGEN=$(matugen_bin) || {
    echo "wallpaper-theme: matugen ontbreekt (installeer het in ~/.local/bin)" >&2
    exit 1
}

# --- Donker thema aanzetten ----------------------------------------------
# Adwaita-dark en Papirus-Dark zijn op deze machine al geïnstalleerd; dit
# activeert ze voor GTK3/GTK4 en libadwaita-apps.

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" \
    "$HOME/.config/alacritty" "$HOME/.config/rofi" "$CONFIG_DIR"

cat >"$HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrains Mono 10
gtk-application-prefer-dark-theme=1
EOF

cat >"$HOME/.config/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrains Mono 10
gtk-application-prefer-dark-theme=1
EOF

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 10' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 10' 2>/dev/null || true
fi

# --- Palet genereren en toepassen ----------------------------------------

if [ "$QUIET" = "1" ]; then
    "$MATUGEN" image "$image" -m dark -c "$MATUGEN_CONFIG" --quiet
else
    echo "Wallpaper: $image"
    "$MATUGEN" image "$image" -m dark -c "$MATUGEN_CONFIG"
fi

# De post_hook hierboven werkt Qt al bij; deze expliciete aanroep houdt het
# Qt-palet ook actueel als iemand de post_hook uit config.toml haalt.
if [ -x "$REPO/scripts/apply-qt-theme.sh" ]; then
    "$REPO/scripts/apply-qt-theme.sh" \
        || echo "wallpaper-theme: Qt-thema bijwerken mislukt" >&2
fi

printf '%s\n' "$image" >"$STATE_FILE"

# De post_hook van matugen heeft settings.json + BSPWM al bijgewerkt. Meld
# alleen nog welke bestanden zijn geschreven.
if [ "$QUIET" != "1" ]; then
    echo "Palet:     $CONFIG_DIR/theme.generated.json"
    echo "Toegepast: Quickshell, BSPWM, GTK 3/4, Qt 6 (qt6ct), alacritty, rofi"
fi
