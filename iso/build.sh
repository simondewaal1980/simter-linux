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
# één keer naar iso/cache. grub-btrfs staat ook niet in Debian en wordt uit de
# meegeleverde bron in iso/vendor gebouwd. De bron blijft het project in deze
# repo.
#
# Op Debian sid/testing wordt native gebouwd. Op Ubuntu of een andere host
# met een te oude live-build maakt het script eenmalig een Debian-sid-
# omgeving met debootstrap en bouwt daarin (zie iso/README.md).
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
# Debian heeft geen grub-btrfs-pakket. De bron staat in iso/vendor en wordt
# in de live-build-chroot geïnstalleerd, zodat het doelssysteem het
# snapshot-submenu in GRUB krijgt.
GRUB_BTRFS_VERSION=${GRUB_BTRFS_VERSION:-4.14}
GRUB_BTRFS_TARBALL=${GRUB_BTRFS_TARBALL:-$ISO_DIR/vendor/grub-btrfs-$GRUB_BTRFS_VERSION.tar.gz}
GRUB_BTRFS_SHA256=${GRUB_BTRFS_SHA256-4fe2f8a49b39e3e561fc51bbc5a0f81a7222c1e9ef8672e014e0ba3bedad20c6}
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

# ---------------------------------------------------------------------------
# Bouwen vanaf Ubuntu (of een andere niet-Debian-host)
#
# Ubuntu levert live-build 3.0~a57 uit 2013, dat de opties in
# iso/live-build/auto/config niet kent. In plaats van de host aan te passen
# maakt dit script eenmalig een Debian-sid-omgeving met debootstrap en bouwt
# daarin. De omgeving blijft bewaard, dus alleen de eerste build is traag.
# ---------------------------------------------------------------------------
BUILDER_DIR=${QS_BUILDER_DIR:-/var/cache/quickshell-iso/builder-sid}
BUILDER_ROOT=$BUILDER_DIR/rootfs
BUILDER_MARKER=$BUILDER_DIR/.ready
BUILDER_MIRROR=${QS_BUILDER_MIRROR:-http://deb.debian.org/debian}
BUILDER_STAGE=$CACHE_DIR/chroot-inputs
DEBIAN_KEYRING=${QS_DEBIAN_KEYRING:-/usr/share/keyrings/debian-archive-keyring.gpg}
BUILDER_PACKAGES="live-build debootstrap squashfs-tools xorriso rsync
imagemagick isolinux syslinux-common syslinux-utils dosfstools mtools zstd
grub-pc-bin grub-efi-amd64-bin grub-common fonts-jetbrains-mono
fonts-dejavu-core ca-certificates curl wget file xz-utils cpio bzip2
uuid-runtime bc gettext-base"

# Een Debian-host met een recente live-build (epoch 1:) kan native bouwen.
# Ubuntu's 3.0~a57 heeft die epoch niet en is te oud.
host_can_build_native() {
    grep -q '^ID=debian$' /etc/os-release 2>/dev/null || return 1
    [ -r /etc/debian_version ] || return 1
    lb_version=$(dpkg-query -W -f='${Version}' live-build 2>/dev/null || true)
    case $lb_version in
        1:*) return 0 ;;
    esac
    return 1
}

# Kopieer de wallpaper(s) van de aanroeper naar de cache, zodat de chroot ze
# kan gebruiken zonder de hele homemap te binden.
stage_chroot_inputs() {
    rm -rf "$BUILDER_STAGE"
    mkdir -p "$BUILDER_STAGE/Wallpapers"

    wp=${WALLPAPER:-$RUN_HOME/Pictures/wallpaper.jpg}
    wpdir=${WALLPAPER_DIR:-$RUN_HOME/Pictures/Wallpapers}

    if [ -n "${MATUGEN_BIN:-}" ] && [ -x "$MATUGEN_BIN" ]; then
        cp "$MATUGEN_BIN" "$BUILDER_STAGE/matugen"
    fi
    if [ -r "$wp" ]; then
        cp "$wp" "$BUILDER_STAGE/wallpaper.jpg"
    fi
    if [ -d "$wpdir" ]; then
        find "$wpdir" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
               -o -iname '*.webp' \) \
            -exec cp -a {} "$BUILDER_STAGE/Wallpapers/" \;
    fi
}

bootstrap_builder() {
    if [ -r "$BUILDER_ROOT/etc/debian_version" ]; then
        return 0
    fi
    need debootstrap
    [ -r "$DEBIAN_KEYRING" ] || {
        echo "build.sh: Debian-archiefsleutel ontbreekt ($DEBIAN_KEYRING)." >&2
        echo "Installeer hem eenmalig: sudo apt install debootstrap debian-archive-keyring" >&2
        exit 1
    }
    echo "== Debian-sid buildomgeving aanmaken in $BUILDER_ROOT =="
    echo "   (eenmalig; dit downloadt ongeveer 300 MB)"
    rm -rf "$BUILDER_ROOT"
    mkdir -p "$BUILDER_DIR"
    if ! debootstrap --arch=amd64 --variant=minbase \
            --keyring="$DEBIAN_KEYRING" \
            --include=ca-certificates,curl,debian-archive-keyring \
            sid "$BUILDER_ROOT" "$BUILDER_MIRROR"; then
        echo "build.sh: debootstrap van Debian sid is mislukt." >&2
        rm -rf "$BUILDER_ROOT"
        exit 1
    fi
}

builder_mounts() {
    mkdir -p "$BUILDER_ROOT/proc" "$BUILDER_ROOT/sys" "$BUILDER_ROOT/dev/pts" \
             "$BUILDER_ROOT$REPO_DIR"
    mountpoint -q "$BUILDER_ROOT/proc" || mount -t proc proc "$BUILDER_ROOT/proc"
    mountpoint -q "$BUILDER_ROOT/sys" || mount -t sysfs sysfs "$BUILDER_ROOT/sys"
    mountpoint -q "$BUILDER_ROOT/dev" || mount --rbind /dev "$BUILDER_ROOT/dev"
    mountpoint -q "$BUILDER_ROOT/dev/pts" || mount --bind /dev/pts "$BUILDER_ROOT/dev/pts"
    mountpoint -q "$BUILDER_ROOT$REPO_DIR" || mount --bind "$REPO_DIR" "$BUILDER_ROOT$REPO_DIR"
}

builder_cleanup() {
    for dir in "$BUILDER_ROOT$REPO_DIR" "$BUILDER_ROOT/dev/pts" \
               "$BUILDER_ROOT/dev" "$BUILDER_ROOT/sys" "$BUILDER_ROOT/proc"; do
        if mountpoint -q "$dir" 2>/dev/null; then
            umount "$dir" 2>/dev/null || umount -R "$dir" 2>/dev/null \
                || umount -l "$dir" 2>/dev/null || true
        fi
    done
}

prepare_builder_packages() {
    cp /etc/resolv.conf "$BUILDER_ROOT/etc/resolv.conf" 2>/dev/null || true
    cat > "$BUILDER_ROOT/etc/apt/sources.list" <<EOF
deb $BUILDER_MIRROR sid main contrib non-free non-free-firmware
EOF
    if [ -e "$BUILDER_MARKER" ] && [ "${QS_BUILDER_REFRESH:-0}" != 1 ]; then
        return 0
    fi
    echo "== Buildpakketten in de Debian-sid-omgeving installeren =="
    chroot "$BUILDER_ROOT" env DEBIAN_FRONTEND=noninteractive \
        apt-get update -q || {
        echo "build.sh: apt-get update in de buildomgeving is mislukt." >&2
        exit 1
    }
    # shellcheck disable=SC2086
    chroot "$BUILDER_ROOT" env DEBIAN_FRONTEND=noninteractive \
        apt-get -y -q --no-install-recommends \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        install $BUILDER_PACKAGES || {
        echo "build.sh: buildpakketten installeren in de buildomgeving is mislukt." >&2
        exit 1
    }
    touch "$BUILDER_MARKER"
}

build_in_builder() {
    command -v debootstrap >/dev/null 2>&1 || {
        echo "build.sh: debootstrap ontbreekt; dat is nodig om de Debian-sid-omgeving te maken." >&2
        echo "Installeer eenmalig: sudo apt install debootstrap debian-archive-keyring" >&2
        exit 1
    }
    need mount umount chroot mountpoint
    builder_arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    if [ "$builder_arch" != amd64 ]; then
        echo "build.sh: waarschuwing: host is $builder_arch; de Debian-sid-omgeving en ISO zijn amd64." >&2
        echo "Op een andere architectuur is qemu-binfmt nodig." >&2
    fi
    trap 'builder_cleanup' EXIT INT TERM
    stage_chroot_inputs
    bootstrap_builder
    builder_mounts
    prepare_builder_packages

    echo "== Bouwen in de Debian-sid-omgeving ($BUILDER_ROOT) =="
    if [ -x "$BUILDER_STAGE/matugen" ]; then
        MATUGEN_IN_CHROOT=$BUILDER_STAGE/matugen
    else
        MATUGEN_IN_CHROOT=
    fi
    status=0
    chroot "$BUILDER_ROOT" /usr/bin/env \
        -u WALLPAPER -u WALLPAPER_DIR \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        HOME=/root TERM="${TERM:-dumb}" \
        DEBIAN_FRONTEND=noninteractive \
        QS_ISO_BUILDER=1 SUDO_USER=root \
        MATUGEN_BIN="$MATUGEN_IN_CHROOT" \
        WALLPAPER="$BUILDER_STAGE/wallpaper.jpg" \
        WALLPAPER_DIR="$BUILDER_STAGE/Wallpapers" \
        /bin/sh "$REPO_DIR/iso/build.sh" || status=$?

    builder_cleanup
    trap - EXIT INT TERM
    chown "$RUN_USER:$RUN_USER" "$LOG" 2>/dev/null || true
    if [ "$status" -ne 0 ]; then
        echo "build.sh: build in de Debian-sid-omgeving is mislukt (exit $status)." >&2
        return "$status"
    fi
    chown -R "$RUN_USER:$RUN_USER" "$OUT_DIR" 2>/dev/null || true
    return 0
}

# Bewaar de live-build-pakketcache tussen builds; dat scheelt bij een
# herstart veel download- en debootstrap-tijd. Doe dit vóór de matugen- en
# wallpaper-stappen, want die kunnen iso/cache al aanmaken.
if [ -d "$BUILD_DIR/cache" ] && [ ! -e "$CACHE_DIR" ]; then
    mv "$BUILD_DIR/cache" "$CACHE_DIR"
fi

# Bepaal of we native of in een Debian-sid-omgeving bouwen.
use_builder=0
if [ "${QS_ISO_BUILDER:-0}" = 1 ] || [ "${QS_ISO_HOST_BUILD:-0}" = 1 ]; then
    use_builder=0
elif [ "${QS_ISO_FORCE_BUILDER:-0}" = 1 ]; then
    use_builder=1
elif host_can_build_native; then
    use_builder=0
else
    use_builder=1
fi

if [ "$use_builder" = 1 ]; then
    echo "== Host is geen Debian met recente live-build; gebruik Debian-sid-omgeving =="
    status=0
    build_in_builder || status=$?
    exit "$status"
fi

for tool in lb debootstrap mksquashfs xorriso rsync convert; do
    need "$tool"
done

# De ISO en de meegebundelde matugen-binary zijn amd64.
if command -v dpkg >/dev/null 2>&1 && [ "$(dpkg --print-architecture 2>/dev/null)" != amd64 ]; then
    echo "build.sh: waarschuwing: deze host is $(dpkg --print-architecture), maar de ISO is amd64." >&2
    echo "Op een andere architectuur is qemu-binfmt nodig; de build kan hierdoor mislukken." >&2
fi

# live-build gebruikt veel ruimte voor de chroot, squashfs en de ISO zelf.
AVAIL_KB=$(df -Pk "$ISO_DIR" | awk 'NR==2 {print $4}')
if [ -n "$AVAIL_KB" ] && [ "$AVAIL_KB" -lt 12582912 ]; then
    echo "build.sh: waarschuwing: minder dan 12 GiB vrij op $(df -Pk "$ISO_DIR" | awk 'NR==2 {print $6}')." >&2
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

[ -r "$GRUB_BTRFS_TARBALL" ] || {
    echo "build.sh: grub-btrfs-bron niet gevonden: $GRUB_BTRFS_TARBALL" >&2
    echo "Zet GRUB_BTRFS_TARBALL=/pad/naar/grub-btrfs-$GRUB_BTRFS_VERSION.tar.gz of herstel iso/vendor/." >&2
    exit 1
}
if [ -n "$GRUB_BTRFS_SHA256" ]; then
    if ! printf '%s  %s\n' "$GRUB_BTRFS_SHA256" "$GRUB_BTRFS_TARBALL" \
            | sha256sum -c - >/dev/null 2>&1; then
        echo "build.sh: sha256 van $GRUB_BTRFS_TARBALL klopt niet." >&2
        echo "Controleer iso/vendor/README.md of zet GRUB_BTRFS_SHA256 leeg." >&2
        exit 1
    fi
fi
echo "grub-btrfs: $GRUB_BTRFS_TARBALL"

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
         "$INCLUDE/usr/src" \
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
install -m644 "$GRUB_BTRFS_TARBALL" \
    "$INCLUDE/usr/src/grub-btrfs-$GRUB_BTRFS_VERSION.tar.gz"
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
# Laat lb via een FIFO naar tee lopen: de voortgang blijft zichtbaar én het
# script houdt de echte exitstatus van lb. Met `lb build | tee` is de
# pijpstatus die van tee, waardoor een fout alleen als "geen ISO gevonden"
# zichtbaar werd.
rm -f "$LOG.fifo"
mkfifo "$LOG.fifo" || {
    echo "build.sh: kan geen fifo maken voor $LOG.fifo." >&2
    exit 1
}
trap 'rm -f "$LOG.fifo"' EXIT INT TERM
tee "$LOG" <"$LOG.fifo" &
TEE_PID=$!
LB_STATUS=0
lb build >"$LOG.fifo" 2>&1 || LB_STATUS=$?
wait "$TEE_PID" 2>/dev/null || true
rm -f "$LOG.fifo"
trap - EXIT INT TERM
if [ "$LB_STATUS" -ne 0 ]; then
    echo "build.sh: lb build is mislukt (exit $LB_STATUS). Laatste regels uit $LOG:" >&2
    tail -n 60 "$LOG" >&2 2>/dev/null || true
    exit "$LB_STATUS"
fi

ISO=$(find "$BUILD_DIR" -maxdepth 1 -type f \( -name '*.hybrid.iso' -o -name '*.iso' \) | head -n 1)
[ -n "$ISO" ] || {
    echo "build.sh: geen ISO gevonden in $BUILD_DIR; controleer $LOG." >&2
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
