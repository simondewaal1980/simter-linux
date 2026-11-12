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
for unit in sddm NetworkManager bluetooth snapper-timeline.timer \
            snapper-cleanup.timer fstrim.timer systemd-timesyncd; do
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
