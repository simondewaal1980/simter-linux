#!/bin/sh
# install-qt6ct-user.sh — qt6ct zonder root installeren (fallback).
#
# De voorkeursroute is het systeempakket:
#   sudo apt install qt6ct
#
# Op deze machine is dat niet altijd mogelijk (geen sudo). Dit script haalt
# daarom het Debian-pakket op met `apt-get download` en pakt het uit in
# ~/.local/opt/qt6ct. bspwmrc zet QT_PLUGIN_PATH en LD_LIBRARY_PATH als die map
# bestaat, zodat Qt-apps de plugin toch vinden.
#
# Gebruik:
#   scripts/install-qt6ct-user.sh [--force]
#
# Let op: dit is een noodoplossing. Na een Qt-update kan een systeempakket
# nodig zijn; verwijder dan ~/.local/opt/qt6ct en installeer qt6ct systeemwijd.

set -eu

PREFIX=${QT6CT_PREFIX:-$HOME/.local/opt/qt6ct}
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# Een systeeminstallatie heeft altijd de voorkeur.
if find /usr/lib -path '*/qt6/plugins/platformthemes/libqt6ct.so' -print -quit 2>/dev/null | grep -q .; then
    echo "qt6ct is al systeemwijd geïnstalleerd; niets te doen."
    exit 0
fi

if [ -e "$PREFIX/plugins/platformthemes/libqt6ct.so" ] && [ "$FORCE" != "1" ]; then
    echo "qt6ct staat al user-local in $PREFIX (gebruik --force om te vervangen)."
    exit 0
fi

for tool in apt-get dpkg-deb find; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "install-qt6ct-user: $tool ontbreekt" >&2
        exit 1
    }
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "qt6ct-pakket ophalen..."
(cd "$TMP" && apt-get download -qq qt6ct) || {
    echo "install-qt6ct-user: kon qt6ct niet downloaden (APT-lijsten bijwerken?)" >&2
    exit 1
}

DEB=$(find "$TMP" -maxdepth 1 -name 'qt6ct_*.deb' -print -quit)
[ -n "$DEB" ] || {
    echo "install-qt6ct-user: geen qt6ct-pakket gevonden" >&2
    exit 1
}

ROOT="$TMP/root"
dpkg-deb -x "$DEB" "$ROOT"

GUI=$(find "$ROOT" -path '*/bin/qt6ct' -type f -print -quit)
COMMON=$(find "$ROOT" -name 'libqt6ct-common.so.*' -type f -print -quit)
PLATFORM=$(find "$ROOT" -path '*/platformthemes/libqt6ct.so' -type f -print -quit)
STYLE=$(find "$ROOT" -path '*/styles/libqt6ct-style.so' -type f -print -quit)

for file in "$GUI" "$COMMON" "$PLATFORM" "$STYLE"; do
    [ -n "$file" ] || {
        echo "install-qt6ct-user: onverwachte pakketinhoud" >&2
        exit 1
    }
done

# Oude installatie volledig vervangen, zodat geen verouderde libs blijven staan.
rm -rf "$PREFIX"
mkdir -p "$PREFIX/lib" "$PREFIX/plugins/platformthemes" \
    "$PREFIX/plugins/styles" "$PREFIX/bin" "$HOME/.local/bin"

install -m755 "$COMMON" "$PREFIX/lib/$(basename "$COMMON")"
ln -sf "$(basename "$COMMON")" "$PREFIX/lib/libqt6ct-common.so"
install -m755 "$PLATFORM" "$PREFIX/plugins/platformthemes/libqt6ct.so"
install -m755 "$STYLE" "$PREFIX/plugins/styles/libqt6ct-style.so"
install -m755 "$GUI" "$PREFIX/qt6ct-bin"

# De GUI buiten de sessie om kan dezelfde paden nodig hebben als de plugin.
cat >"$PREFIX/bin/qt6ct" <<EOF
#!/bin/sh
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_PLUGIN_PATH="$PREFIX/plugins\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}"
export LD_LIBRARY_PATH="$PREFIX/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$PREFIX/qt6ct-bin" "\$@"
EOF
chmod 755 "$PREFIX/bin/qt6ct"
ln -sf "$PREFIX/bin/qt6ct" "$HOME/.local/bin/qt6ct"

# Laat de configurator ook in de applicatielijst van de sessie staan.
DESKTOP=$(find "$ROOT" -path '*/applications/qt6ct.desktop' -type f -print -quit)
if [ -n "$DESKTOP" ]; then
    mkdir -p "$HOME/.local/share/applications"
    sed "s|^Exec=.*|Exec=$PREFIX/bin/qt6ct|" "$DESKTOP" \
        >"$HOME/.local/share/applications/qt6ct.desktop"
fi

echo "qt6ct is user-local geïnstalleerd in $PREFIX."
echo "Log opnieuw in (of herstart de bspwm-sessie) zodat Qt-apps de plugin vinden."
