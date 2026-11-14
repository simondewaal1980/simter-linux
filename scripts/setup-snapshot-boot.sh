#!/bin/sh
# setup-snapshot-boot.sh — maak van een alleen-lezen snapshot een bruikbare boot.
#
# Snapper bewaart momentopnamen als alleen-lezen btrfs-subvolumes. Zo'n
# snapshot start wel, maar /var en de gebruikersmap blijven read-only:
# systemd kan de root niet opnieuw mounten, SDDM kan zijn status niet
# wegschrijven en de sessie komt niet verder dan een zwart scherm of
# noodmodus.
#
# Dit script installeert overlayroot en zet in de grub-btrfs-configuratie de
# kernelparameter overlayroot=tmpfs. Die parameter geldt alleen voor de
# snapshot-entries in GRUB. Bij zo'n boot komt er een tijdelijke schrijfbare
# laag in RAM bovenop de snapshot; wijzigingen verdwijnen bij het afsluiten en
# de snapshot zelf blijft onaangeroerd.
#
# Gebruik:
#   sudo scripts/setup-snapshot-boot.sh [--create]
#
#   --create  maak na afloop direct een nieuwe momentopname. Alleen snapshots
#             die na deze stap zijn gemaakt, bevatten de nieuwe initramfs met
#             overlayroot; oudere snapshots blijven bedoeld voor rollback.

set -eu

PROG=${0##*/}
CREATE=0
GRUB_BTRFS_CONFIG=${GRUB_BTRFS_CONFIG:-/etc/default/grub-btrfs/config}

usage() {
    cat <<EOF
Gebruik: sudo $PROG [--create]

  --create  maak na afloop een nieuwe momentopname om mee te testen
  -h, --help  toon deze uitleg

Zonder --create geldt de nieuwe initramfs pas voor snapshots die je daarna
maakt (bijvoorbeeld de automatische boot-snapshot na een herstart).
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        --create)
            CREATE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "$PROG: onbekende optie: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            echo "$PROG: onbekende parameter: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "$PROG: root-rechten nodig om overlayroot en GRUB te wijzigen." >&2
    echo "Draai: sudo $0 --create" >&2
    exit 1
fi

command -v snapper >/dev/null 2>&1 || {
    echo "$PROG: snapper is niet geïnstalleerd." >&2
    exit 1
}

if [ "$(findmnt -no FSTYPE / 2>/dev/null || true)" != "btrfs" ]; then
    echo "$PROG: / is geen btrfs; dit script is alleen voor de btrfs-root." >&2
    exit 1
fi

if [ ! -f "$GRUB_BTRFS_CONFIG" ]; then
    echo "$PROG: $GRUB_BTRFS_CONFIG ontbreekt." >&2
    echo "Installeer eerst grub-btrfs (het GRUB-snapshotmenu)." >&2
    exit 1
fi

# --- overlayroot ----------------------------------------------------------
if [ "$(dpkg-query -W -f='${Status}' overlayroot 2>/dev/null || true)" = \
        "install ok installed" ]; then
    echo "overlayroot is al geïnstalleerd."
else
    echo "overlayroot installeren..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        overlayroot || {
        echo "$PROG: installatie van overlayroot mislukt." >&2
        exit 1
    }
fi

# --- kernelparameter alleen voor snapshot-entries -------------------------
# Een nieuwe installatie heeft aparte subvolumes voor /home, /var/log,
# /var/cache, /var/tmp en /var/spool. Die blijven dan writable en alleen /
# krijgt de tijdelijke overlay. Op een oudere installatie zonder die
# subvolumes moet de hele root in de overlay, anders blijven /var en /home
# read-only.
missing_subvolumes=""
for dir in /home /var/log /var/cache /var/tmp /var/spool; do
    if ! awk -v mp="$dir" \
            '$2 == mp && $3 == "btrfs" && $4 ~ /subvol=/ { found = 1 }
             END { exit !found }' /etc/fstab 2>/dev/null; then
        missing_subvolumes="$missing_subvolumes $dir"
    fi
done
if [ -z "$missing_subvolumes" ]; then
    OVERLAY="overlayroot=tmpfs:recurse=0"
    echo "Aparte subvolumes gevonden; alleen / krijgt de tijdelijke overlay."
else
    OVERLAY="overlayroot=tmpfs"
    echo "Geen volledige subvolume-indeling ($missing_subvolumes);" \
        "de hele root krijgt de tijdelijke overlay."
fi

current=$(sed -n \
    's/^GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' \
    "$GRUB_BTRFS_CONFIG" | tail -n 1)
kept=""
for param in $current; do
    case $param in
        overlayroot=*) ;;
        *) kept="${kept:+$kept }$param" ;;
    esac
done
current="${kept:+$kept }$OVERLAY"
sed -i '/^GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=/d' "$GRUB_BTRFS_CONFIG"
printf 'GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="%s"\n' "$current" \
    >>"$GRUB_BTRFS_CONFIG"
echo "Snapshot-parameters: $current"

# --- initramfs en GRUB opnieuw genereren ----------------------------------
echo "Initramfs vernieuwen..."
update-initramfs -u -k all

if command -v lsinitramfs >/dev/null 2>&1; then
    newest=$(ls -1 /boot/initrd.img-* 2>/dev/null | sort -V | tail -n 1)
    if [ -n "$newest" ] && \
            lsinitramfs "$newest" 2>/dev/null \
            | grep -q 'scripts/init-bottom/overlayroot'; then
        echo "OK: overlayroot zit in ${newest##*/}."
    else
        echo "$PROG: waarschuwing: overlayroot-hook niet in de initramfs" \
            "gevonden." >&2
    fi
fi

if [ -x /etc/grub.d/41_snapshots-btrfs ]; then
    echo "GRUB-snapshotmenu opnieuw genereren..."
    update-grub >/dev/null
else
    echo "$PROG: waarschuwing: /etc/grub.d/41_snapshots-btrfs ontbreekt;" \
        "het GRUB-menu is niet vernieuwd." >&2
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now grub-btrfsd >/dev/null 2>&1 || true
fi

if grep -qs 'overlayroot=tmpfs' /boot/grub/grub-btrfs.cfg; then
    echo "OK: de snapshot-entries gebruiken overlayroot=tmpfs."
else
    echo "$PROG: waarschuwing: nog geen snapshot-entry met overlayroot" \
        "gevonden; maak een nieuwe snapshot en controleer opnieuw." >&2
fi

# --- optioneel meteen een testmomentopname --------------------------------
if [ "$CREATE" -eq 1 ]; then
    CONFIG=${SNAPPER_CONFIG:-root}
    echo "Testmomentopname maken in configuratie '$CONFIG'..."
    snapper -c "$CONFIG" create -d "snapshot-boot test" || {
        echo "$PROG: momentopname maken mislukt." >&2
        exit 1
    }
fi

cat <<EOF

Klaar. Herstart en kies in GRUB een snapshot die na deze stap is gemaakt.
Oudere snapshots hebben nog de oude initramfs en zijn alleen voor rollback.
Een snapshot-boot is tijdelijk: wijzigingen worden niet bewaard.
EOF
