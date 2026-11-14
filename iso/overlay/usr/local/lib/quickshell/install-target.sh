#!/bin/sh
# install-target — eenmalige configuratie van het geïnstalleerde systeem.
#
# Wordt door Calamares (shellprocess, in de chroot van het doelssysteem)
# aangeroepen met de gekozen gebruikersnaam. Regelt:
#   - snapper-configuratie en de geneste .snapshots-subvolume;
#   - fstab/GRUB-controleren (BTRFS-subvolume @rootfs);
#   - systemd-diensten inschakelen;
#   - de gebruikersconfiguratie vastleggen (zonder persoonlijke data).

set -eu

TARGET_USER=${1:-}
if [ -z "$TARGET_USER" ] || ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "install-target: ongeldige gebruiker: $TARGET_USER" >&2
    exit 1
fi

USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[ -n "$USER_HOME" ] || USER_HOME=/home/$TARGET_USER

# --- apt-bron voor het doelssysteem --------------------------------------
mkdir -p /etc/apt/sources.list.d
cat >/etc/apt/sources.list <<'EOF'
# Debian unstable (sid)
deb http://deb.debian.org/debian sid main contrib non-free non-free-firmware
EOF
rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true

# Chrome komt uit Google's eigen repository, niet uit Debian. De sleutel is
# bij de build in de squashfs gezet; laat de repo staan zodat Chrome op het
# geïnstalleerde systeem via apt bijgewerkt kan worden.
cat >/etc/apt/sources.list.d/google-chrome.list <<'EOF'
deb [signed-by=/etc/apt/trusted.gpg.d/google-chrome.key.asc] https://dl.google.com/linux/chrome/deb/ stable main
EOF
chmod 644 /etc/apt/sources.list.d/google-chrome.list 2>/dev/null || true

# --- fstab: normaliseer de BTRFS-root en de EFI-fsck-pass ----------------
# Calamares schrijft subvol=/@rootfs; de bronmachine gebruikt subvol=@rootfs.
# Verwijder dubbele subvol=*-opties en zet de root exact goed.
if [ -f /etc/fstab ]; then
    awk '
        $2 == "/" && $3 == "btrfs" {
            n = split($4, a, ",")
            opts = ""
            for (i = 1; i <= n; i++) {
                if (a[i] ~ /^subvol=/) continue
                opts = opts (opts ? "," : "") a[i]
            }
            $4 = "subvol=@rootfs" (opts ? "," opts : "")
        }
        $2 == "/boot/efi" && $3 == "vfat" { $6 = 1 }
        { print }
    ' /etc/fstab >/etc/fstab.new && mv /etc/fstab.new /etc/fstab
fi

# --- Extra BTRFS-subvolumes: rechten gelijk aan een normale root ----------
# Calamares mount deze subvolumes als lege btrfs-roots. De squashfs-inhoud
# wordt er tijdens unpackfs in gezet, maar de root van zo'n subvolume krijgt
# niet altijd de juiste mode. /var/tmp moet bijvoorbeeld sticky zijn.
for dir in /home /var/log /var/cache /var/spool; do
    if [ -d "$dir" ]; then
        chown root:root "$dir" 2>/dev/null || true
        chmod 0755 "$dir" 2>/dev/null || true
    fi
done
if [ -d /var/tmp ]; then
    chown root:root /var/tmp 2>/dev/null || true
    chmod 1777 /var/tmp 2>/dev/null || true
fi

# Controleer dat de indeling echt in fstab staat; zonder deze regels mount een
# snapshot-boot de schrijfbare subvolumes niet en blijft /var/log read-only.
missing_subvolumes=""
for dir in /home /var/log /var/cache /var/tmp /var/spool; do
    if ! awk -v mp="$dir" \
            '$2 == mp && $3 == "btrfs" && $4 ~ /subvol=/ { found = 1 }
             END { exit !found }' /etc/fstab 2>/dev/null; then
        missing_subvolumes="$missing_subvolumes $dir"
    fi
done
if [ -n "$missing_subvolumes" ]; then
    echo "install-target: waarschuwing: subvolume(s) ontbreken in /etc/fstab:" \
        "$missing_subvolumes" >&2
fi

# Met alle aparte subvolumes is alleen / tijdelijk; zonder die subvolumes
# moet de hele root in de overlay, anders blijven /var en /home read-only.
if [ -z "$missing_subvolumes" ]; then
    SNAPSHOT_OVERLAY="overlayroot=tmpfs:recurse=0"
else
    SNAPSHOT_OVERLAY="overlayroot=tmpfs"
fi

# --- Snapshot-boot: tijdelijke schrijfbare laag ---------------------------
# Snapper bewaart momentopnamen read-only. De aparte subvolumes houden
# /home, /var/log en de caches schrijfbaar, maar /etc, /usr en /var/lib
# blijven read-only. overlayroot legt daarom alleen bij de snapshot-entries
# in GRUB een tmpfs-overlay over /. Met recurse=0 blijven de aparte
# subvolumes writable gemount en is alleen de systeemroot tijdelijk; zonder
# die subvolumes wordt de hele root geoverlayd. Een normale boot blijft
# ongewijzigd.
GRUB_BTRFS_CONFIG=/etc/default/grub-btrfs/config
if [ -f "$GRUB_BTRFS_CONFIG" ]; then
    if [ "$(dpkg-query -W -f='${Status}' overlayroot 2>/dev/null || true)" = \
            "install ok installed" ]; then
        current=$(sed -n \
            's/^GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' \
            "$GRUB_BTRFS_CONFIG" | tail -n 1)
        # Vervang een eventueel bestaande overlayroot=... door de gewenste
        # waarde en laat andere snapshot-parameters staan.
        kept=""
        for param in $current; do
            case $param in
                overlayroot=*) ;;
                *) kept="${kept:+$kept }$param" ;;
            esac
        done
        current="${kept:+$kept }$SNAPSHOT_OVERLAY"
        sed -i '/^GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=/d' \
            "$GRUB_BTRFS_CONFIG"
        printf 'GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="%s"\n' "$current" \
            >>"$GRUB_BTRFS_CONFIG"
    else
        echo "install-target: waarschuwing: overlayroot ontbreekt;" \
            "snapshot-boots blijven read-only." >&2
    fi
fi

# --- GRUB: bewaar de BTRFS-rootflags en houd os-prober bruikbaar ----------
if [ -f /etc/default/grub ]; then
    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
    else
        printf 'GRUB_TIMEOUT=5\n' >>/etc/default/grub
    fi
    if grep -q '^#*GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
        sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    else
        printf 'GRUB_DISABLE_OS_PROBER=false\n' >>/etc/default/grub
    fi
    update-grub >/dev/null 2>&1 || true

    # Debian's 10_linux voegt rootflags normaal zelf toe. Controleer het
    # resultaat en val terug op een expliciete kernelparameter als dat niet
    # is gebeurd; zonder deze flag start de kernel niet vanaf @rootfs.
    if [ -f /boot/grub/grub.cfg ] && \
       ! grep -q 'rootflags=subvol=@rootfs' /boot/grub/grub.cfg; then
        if grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
            sed -i 's#^GRUB_CMDLINE_LINUX=.*#GRUB_CMDLINE_LINUX="rootflags=subvol=@rootfs"#' \
                /etc/default/grub
        else
            printf 'GRUB_CMDLINE_LINUX="rootflags=subvol=@rootfs"\n' \
                >>/etc/default/grub
        fi
        update-grub >/dev/null 2>&1 || true
    fi
fi

# --- Snapper: root-configuratie met toegang voor de gebruiker -------------
if command -v snapper >/dev/null 2>&1; then
    mkdir -p /etc/snapper/configs
    # Maak de geneste subvolume expliciet. snapper create-config kan in een
    # chroot via de host-snapperd terechtkomen; de bronconfiguratie staat al
    # in snapper-root.conf, dus schrijven we die deterministisch.
    if [ ! -d /.snapshots ]; then
        btrfs subvolume create /.snapshots >/dev/null 2>&1 || mkdir -p /.snapshots
    fi
    sed "s/@USER@/$TARGET_USER/" \
        /usr/local/lib/quickshell/snapper-root.conf \
        >/etc/snapper/configs/root
    chown root:root /etc/snapper/configs/root 2>/dev/null || true
    chmod 640 /etc/snapper/configs/root 2>/dev/null || true
    chmod 750 /.snapshots 2>/dev/null || true
    setfacl -m "u:$TARGET_USER:rx" /.snapshots 2>/dev/null || true

    # Debian leest de lijst met configuraties uit /etc/default/snapper
    # (SNAPPER_CONFIGS). Het bestand in /etc/snapper/configs alleen is niet
    # genoeg: zonder registratie kent snapper de configuratie niet en blijft
    # `snapper list-configs` leeg. De eerste vermelding in het bestand telt,
    # dus vervangen we die regel in plaats van een tweede toe te voegen.
    if [ -f /etc/default/snapper ]; then
        current=$(sed -n 's/^SNAPPER_CONFIGS="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' \
            /etc/default/snapper | head -n 1)
    else
        mkdir -p /etc/default
        current=""
    fi
    case " $current " in
        *" root "*) ;;
        *)
            names="${current:+$current }root"
            if grep -q '^SNAPPER_CONFIGS=' /etc/default/snapper 2>/dev/null; then
                sed -i "s/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS=\"$names\"/" \
                    /etc/default/snapper
            else
                printf 'SNAPPER_CONFIGS="%s"\n' "$names" >>/etc/default/snapper
            fi
            ;;
    esac
fi

# --- Displaymanager: SDDM is de standaard --------------------------------
if command -v sddm >/dev/null 2>&1; then
    if command -v debconf-set-selections >/dev/null 2>&1; then
        printf 'sddm shared/default-x-display-manager select sddm\n' \
            | debconf-set-selections 2>/dev/null || true
    fi
    if command -v dpkg-reconfigure >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive sddm \
            >/dev/null 2>&1 || true
    fi
    systemctl disable lightdm >/dev/null 2>&1 || true
    systemctl enable sddm >/dev/null 2>&1 || true
    mkdir -p /etc/X11
    printf '/usr/bin/sddm\n' >/etc/X11/default-display-manager
    ln -sf /lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
fi

# --- Diensten -------------------------------------------------------------
for unit in sddm NetworkManager bluetooth snapper-boot.timer \
            snapper-timeline.timer snapper-cleanup.timer grub-btrfsd \
            fstrim.timer systemd-timesyncd quickshell-gpu-setup.service; do
    systemctl enable "$unit" >/dev/null 2>&1 || true
done
systemctl set-default graphical.target >/dev/null 2>&1 || true

# --- Gebruikersconfiguratie ----------------------------------------------
if [ -d "$USER_HOME" ] && [ -x /usr/local/bin/quickshell-user-setup ]; then
    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$TARGET_USER" -- env \
            HOME="$USER_HOME" \
            XDG_CONFIG_HOME="$USER_HOME/.config" \
            /usr/local/bin/quickshell-user-setup || true
    else
        su -s /bin/sh "$TARGET_USER" -c \
            "HOME='$USER_HOME' XDG_CONFIG_HOME='$USER_HOME/.config' /usr/local/bin/quickshell-user-setup" \
            || true
    fi
fi

# De live-gebruiker bestaat normaal niet in de squashfs; ruim eventuele
# restanten op als de installateur een andere naam koos.
if [ "$TARGET_USER" != user ] && id user >/dev/null 2>&1; then
    userdel -r user >/dev/null 2>&1 || true
fi

echo "install-target: klaar voor $TARGET_USER ($USER_HOME)"
exit 0
