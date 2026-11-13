#!/bin/sh
# build.sh — bouw de Quickshell Desktop installatie-ISO.
#
# Gebruik (als root):
#   sudo iso/build.sh
#
# De repo wordt schoon naar /opt/quickshell gekopieerd in de live-omgeving.
# Persoonlijke bestanden uit $HOME (behalve de wallpaper en de Griekse
# wallpapers) gaan niet mee. Matugen is niet in Debian en wordt als binary
# meegebundeld; ontbreekt de binary, dan haalt dit script de officiële release
# één keer naar iso/cache. De bron blijft het project in deze repo.
#
# Uitvoer: iso/out/quickshell-desktop-amd64.iso + .sha256

set -eu

ISO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$ISO_DIR/.." && pwd)
BUILD_DIR=$ISO_DIR/build
OUT_DIR=$ISO_DIR/out
CACHE_DIR=$ISO_DIR/cache
LOG=$ISO_DIR/build.log

if [ "$(id -u)" -ne 0 ]; then
    echo "build.sh: root-rechten nodig (live-build werkt in een chroot)." >&2
    echo "Draai: sudo $ISO_DIR/build.sh" >&2
    exit 1
fi

RUN_USER=${SUDO_USER:-$(id -un)}
RUN_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
MATUGEN_VERSION=${MATUGEN_VERSION:-4.2.0}
MATUGEN_URL=${MATUGEN_URL:-https://github.com/InioX/matugen/releases/download/v$MATUGEN_VERSION/matugen-$MATUGEN_VERSION-x86_64.tar.gz}
# sha256 van matugen-4.2.0-x86_64.tar.gz; leeg laten om niet te controleren
# (bijvoorbeeld bij een zelf gekozen MATUGEN_VERSION).
MATUGEN_SHA256=${MATUGEN_SHA256-a2e3b50e49ed6439999ba3c252ed04fabd98ee4e9d12e5e5dff2e66370569751}
WALLPAPER=${WALLPAPER:-$RUN_HOME/Pictures/wallpaper.jpg}
WALLPAPER_DIR=${WALLPAPER_DIR:-$RUN_HOME/Pictures/Wallpapers}

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "build.sh: '$1' ontbreekt; installeer de build-afhankelijkheden." >&2
        exit 1
    }
}

# Zoek matugen zonder meteen te falen: eerst een expliciete MATUGEN_BIN, dan
# de gebruikelijke locaties (ook die van de aanroeper als we via sudo draaien).
find_matugen() {
    for candidate in \
        "$RUN_HOME/.local/bin/matugen" \
        "/home/$RUN_USER/.local/bin/matugen" \
        /home/*/.local/bin/matugen \
        /usr/local/bin/matugen \
        /usr/bin/matugen
    do
        [ -x "$candidate" ] && {
            echo "$candidate"
            return 0
        }
    done
    command -v matugen 2>/dev/null && return 0
    return 1
}

# Haal de officiële release naar de cache. Zo bouwt een schone machine ook
# zonder handmatige matugen-installatie; de binary wordt daarna gewoon
# meegebundeld.
download_matugen() {
    dest_dir=$CACHE_DIR/matugen-$MATUGEN_VERSION
    dest=$dest_dir/matugen
    if [ -x "$dest" ]; then
        echo "$dest"
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        fetch="curl -fL --retry 3 --connect-timeout 20 -o"
    elif command -v wget >/dev/null 2>&1; then
        fetch="wget -O"
    else
        echo "build.sh: curl of wget nodig om matugen te downloaden." >&2
        return 1
    fi

    echo "== matugen $MATUGEN_VERSION downloaden ==" >&2
    mkdir -p "$dest_dir"
    tmp=$dest_dir/matugen.tar.gz.part
    # shellcheck disable=SC2086
    if ! $fetch "$tmp" "$MATUGEN_URL"; then
        echo "build.sh: downloaden van $MATUGEN_URL mislukt." >&2
        rm -f "$tmp"
        return 1
    fi
    if [ -n "$MATUGEN_SHA256" ]; then
        if ! printf '%s  %s\n' "$MATUGEN_SHA256" "$tmp" | sha256sum -c - >/dev/null 2>&1; then
            echo "build.sh: sha256 van matugen klopt niet; verwijder $tmp en probeer opnieuw." >&2
            rm -f "$tmp"
            return 1
        fi
    fi
    if ! tar -xzf "$tmp" -C "$dest_dir" matugen; then
        echo "build.sh: matugen.tar.gz bevat geen bruikbare binary." >&2
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
    chmod 755 "$dest"
    echo "$dest"
}

for tool in lb debootstrap mksquashfs xorriso rsync convert; do
    need "$tool"
done

# Bewaar de live-build-pakketcache tussen builds; dat scheelt bij een
# herstart veel download- en debootstrap-tijd. Doe dit vóór de matugen- en
# wallpaper-stappen, want die kunnen iso/cache al aanmaken.
if [ -d "$BUILD_DIR/cache" ] && [ ! -e "$CACHE_DIR" ]; then
    mv "$BUILD_DIR/cache" "$CACHE_DIR"
fi

if [ -n "${MATUGEN_BIN:-}" ]; then
    [ -x "$MATUGEN_BIN" ] || {
        echo "build.sh: MATUGEN_BIN staat op '$MATUGEN_BIN', maar dat is geen uitvoerbaar bestand." >&2
        exit 1
    }
else
    MATUGEN_BIN=$(find_matugen || true)
    if [ -z "$MATUGEN_BIN" ]; then
        MATUGEN_BIN=$(download_matugen || true)
    fi
    [ -n "$MATUGEN_BIN" ] || {
        echo "build.sh: matugen niet gevonden en automatisch downloaden mislukt." >&2
        echo "Installeer matugen in ~/.local/bin of geef MATUGEN_BIN=/pad/naar/matugen op." >&2
        exit 1
    }
fi
echo "matugen: $MATUGEN_BIN"

if [ ! -r "$WALLPAPER" ]; then
    if [ -d "$WALLPAPER_DIR" ]; then
        WALLPAPER=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
               -o -iname '*.webp' \) | sort | head -n 1)
    fi
fi
if [ -z "${WALLPAPER:-}" ] || [ ! -r "$WALLPAPER" ]; then
    WALLPAPER=$CACHE_DIR/default-wallpaper.jpg
    if [ ! -r "$WALLPAPER" ]; then
        echo "== Geen wallpaper gevonden; standaardwallpaper genereren ==" >&2
        mkdir -p "$CACHE_DIR"
        convert -size 1920x1080 gradient:'#1e1e2e-#45475a' "$WALLPAPER" || {
            echo "build.sh: standaardwallpaper genereren mislukt." >&2
            exit 1
        }
        [ -r "$WALLPAPER" ] || {
            echo "build.sh: standaardwallpaper is niet aangemaakt." >&2
            exit 1
        }
    fi
fi
echo "wallpaper: $WALLPAPER"

echo "== Buildmap voorbereiden =="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR" "$CACHE_DIR"
cp -a "$ISO_DIR/live-build/." "$BUILD_DIR/"
ln -s "$CACHE_DIR" "$BUILD_DIR/cache"

INCLUDE=$BUILD_DIR/config/includes.chroot
mkdir -p "$INCLUDE/opt" "$INCLUDE/etc" "$INCLUDE/usr/local/bin" \
         "$INCLUDE/usr/local/lib/quickshell" \
         "$INCLUDE/usr/share/backgrounds/quickshell/Wallpapers" \
         "$INCLUDE/usr/share/applications" \
         "$INCLUDE/usr/lib/live/config"

echo "== Project naar /opt/quickshell stagen =="
rsync -a --delete \
    --exclude '.git' \
    --exclude 'iso' \
    --exclude '.qmlls.ini' \
    --exclude '.opencode' \
    "$REPO_DIR/" "$INCLUDE/opt/quickshell/"

echo "== Calamares-configuratie =="
cp -a "$ISO_DIR/calamares/." "$INCLUDE/etc/calamares/"
BRANDING=$INCLUDE/etc/calamares/branding/quickshell
mkdir -p "$BRANDING"
cp -a "$REPO_DIR/docs/screenshot-settings.png" "$BRANDING/slide1.png"
cp -a "$REPO_DIR/docs/screenshot-shortcuts.png" "$BRANDING/slide2.png"
cp -a "$REPO_DIR/docs/screenshot-settings.png" "$BRANDING/welcome.png"
convert -size 256x256 xc:'#1e1e2e' \
    -fill '#89b4fa' -font JetBrains-Mono-Bold -pointsize 96 \
    -gravity center -annotate +0+0 'QS' \
    "$BRANDING/productLogo.png"
cp -a "$BRANDING/productLogo.png" "$BRANDING/productIcon.png"

echo "== Matugen, wallpapers en live-config =="
install -m755 "$MATUGEN_BIN" "$INCLUDE/usr/local/bin/matugen"
install -m644 "$WALLPAPER" "$INCLUDE/usr/share/backgrounds/quickshell/wallpaper.jpg"
if [ -d "$WALLPAPER_DIR" ]; then
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' \) -exec cp -a {} "$INCLUDE/usr/share/backgrounds/quickshell/Wallpapers/" \;
fi

# Statische live-bestanden uit de repo (skel, scripts, live-config component).
if [ -d "$ISO_DIR/overlay" ]; then
    cp -a "$ISO_DIR/overlay/." "$INCLUDE/"
fi

# Bestanden die pas tijdens de build in de repo ontstaan (settings.json).
mkdir -p "$INCLUDE/etc/skel/.config/bspwm"
if [ ! -e "$INCLUDE/etc/skel/.config/bspwm/settings.json" ]; then
    cp "$REPO_DIR/config/bspwm/settings.default.json" \
       "$INCLUDE/etc/skel/.config/bspwm/settings.json"
fi

# Rechten: scripts moeten uitvoerbaar zijn, ook in de squashfs.
find "$INCLUDE/opt/quickshell/scripts" -type f -name '*.sh' -exec chmod 755 {} +
chmod 755 "$INCLUDE/opt/quickshell/config/bspwm/bspwmrc"
find "$INCLUDE/usr/local" -type f -exec chmod 755 {} + 2>/dev/null || true
find "$INCLUDE/usr/lib/live/config" -type f -exec chmod 755 {} + 2>/dev/null || true

echo "== Live-config =="
cd "$BUILD_DIR"
sh auto/config

echo "== ISO bouwen (dit kan lang duren) =="
lb build 2>&1 | tee "$LOG"

ISO=$(find "$BUILD_DIR" -maxdepth 1 -type f \( -name '*.hybrid.iso' -o -name '*.iso' \) | head -n 1)
[ -n "$ISO" ] || {
    echo "build.sh: geen ISO gevonden in $BUILD_DIR" >&2
    exit 1
}

TARGET=$OUT_DIR/quickshell-desktop-amd64.iso
cp "$ISO" "$TARGET"
chown "$RUN_USER:$RUN_USER" "$TARGET" "$LOG" 2>/dev/null || true
(cd "$OUT_DIR" && sha256sum "$(basename "$TARGET")" >"$(basename "$TARGET").sha256")
chown "$RUN_USER:$RUN_USER" "$TARGET.sha256" 2>/dev/null || true

echo
echo "ISO:    $TARGET"
echo "SHA256: $OUT_DIR/$(basename "$TARGET").sha256"
ls -lh "$TARGET"
