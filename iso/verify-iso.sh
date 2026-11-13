#!/bin/sh
# verify-iso.sh — controleer de inhoud van de gebouwde ISO zonder hem te
# booten. Controleert BIOS/UEFI-bootimages, de squashfs en de belangrijkste
# Quickshell/Calamares-bestanden.
#
# Gebruik: iso/verify-iso.sh [pad-naar.iso]

set -eu

ISO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ISO=${1:-$ISO_DIR/out/quickshell-desktop-amd64.iso}
[ -r "$ISO" ] || {
    echo "verify-iso: ISO niet gevonden: $ISO" >&2
    exit 1
}

# /tmp is op dit systeem een tmpfs; de squashfs is ~2 GB. Gebruik daarom
# standaard /var/tmp (op de echte schijf) voor de tijdelijke extractie.
TMP=$(mktemp -d "${TMPDIR:-/var/tmp}/quickshell-iso-verify.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "== ISO =="
ls -lh "$ISO"
if [ -r "$ISO.sha256" ]; then
    (cd "$(dirname "$ISO")" && sha256sum -c "$(basename "$ISO").sha256")
else
    sha256sum "$ISO"
fi

echo "== Bootimages =="
xorriso -indev "$ISO" -report_el_torito plain 2>/dev/null \
    | grep -E 'El Torito|Boot record|UEFI|EFI' || true

echo "== Squashfs uitlezen =="
xorriso -osirrox on -indev "$ISO" \
    -extract /live/filesystem.squashfs "$TMP/filesystem.squashfs" >/dev/null 2>&1
unsquashfs -l "$TMP/filesystem.squashfs" >"$TMP/list.txt"
unsquashfs -ll "$TMP/filesystem.squashfs" >"$TMP/list-long.txt"

check() {
    rel=${1#/}
    if grep -qx "squashfs-root/$rel" "$TMP/list.txt"; then
        echo "OK   $1"
    else
        echo "FOUT $1 ontbreekt" >&2
        failures=$((failures + 1))
    fi
}

failures=0
check "/opt/quickshell/shell.qml"
check "/opt/quickshell/config/bspwm/bspwmrc"
check "/etc/calamares/settings.conf"
check "/etc/calamares/modules/mount.conf"
check "/etc/calamares/branding/quickshell/branding.desc"
check "/usr/local/bin/matugen"
check "/usr/local/bin/quickshell-session"
check "/usr/local/bin/quickshell-user-setup"
check "/usr/local/lib/quickshell/install-target.sh"
check "/usr/share/xsessions/bspwm.desktop"
check "/usr/share/backgrounds/quickshell/wallpaper.jpg"
check "/usr/lib/live/config/9999-calamares"
check "/usr/bin/setfacl"
check "/usr/local/bin/quickshell-session"
check "/etc/X11/default-display-manager"

echo "== Displaymanager en GLX =="
if grep -q 'display-manager.service -> /lib/systemd/system/sddm.service' "$TMP/list-long.txt"; then
    echo "OK   display-manager.service -> sddm"
else
    echo "FOUT display-manager.service wijst niet naar sddm" >&2
    failures=$((failures + 1))
fi
if unsquashfs -cat "$TMP/filesystem.squashfs" etc/X11/default-display-manager 2>/dev/null \
        | grep -qx '/usr/bin/sddm'; then
    echo "OK   default-display-manager = sddm"
else
    echo "FOUT default-display-manager is niet sddm" >&2
    failures=$((failures + 1))
fi
if grep -qE 'squashfs-root/usr/(s?bin)/lightdm$' "$TMP/list.txt"; then
    echo "FOUT lightdm zit nog in de squashfs" >&2
    failures=$((failures + 1))
else
    echo "OK   geen lightdm"
fi
if grep -q 'squashfs-root/usr/lib/x86_64-linux-gnu/libGLX_nvidia' "$TMP/list.txt"; then
    echo "FOUT NVIDIA-GLX-bibliotheek zit nog in de squashfs" >&2
    failures=$((failures + 1))
else
    echo "OK   geen NVIDIA-GLX"
fi

echo "== Calamares BTRFS-configuratie =="
for file in settings.conf modules/mount.conf modules/partition.conf; do
    unsquashfs -cat "$TMP/filesystem.squashfs" "etc/calamares/$file" \
        >"$TMP/$(basename "$file")" 2>/dev/null
done
grep -q '@rootfs' "$TMP/mount.conf" && echo "OK   subvolume @rootfs" || {
    echo "FOUT subvolume @rootfs ontbreekt" >&2
    failures=$((failures + 1))
}
for opt in 'compress=zlib:3' 'discard=async' 'space_cache=v2' 'umask=0077'; do
    if grep -q "$opt" "$TMP/mount.conf"; then
        echo "OK   mountoptie $opt"
    else
        echo "FOUT mountoptie $opt ontbreekt" >&2
        failures=$((failures + 1))
    fi
done
grep -q 'btrfs' "$TMP/partition.conf" && echo "OK   BTRFS-standaard" || {
    echo "FOUT BTRFS-standaard ontbreekt" >&2
    failures=$((failures + 1))
}

echo "== Snapper-registratie =="
if unsquashfs -cat "$TMP/filesystem.squashfs" \
        usr/local/lib/quickshell/install-target.sh 2>/dev/null \
        | grep -q 'SNAPPER_CONFIGS'; then
    echo "OK   install-target registreert de configuratie in /etc/default/snapper"
else
    echo "FOUT install-target registreert SNAPPER_CONFIGS niet" >&2
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    echo "verify-iso: $failures controle(s) mislukt" >&2
    exit 1
fi

echo "verify-iso: alle controles geslaagd."
