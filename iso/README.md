# Quickshell Desktop — installatie-ISO

Deze map bouwt een hybride ISO (BIOS + UEFI) met Debian sid, een LXQt-
live-sessie en de Calamares-installer. De installer zet dezelfde desktop en
BTRFS-configuratie neer als de bronmachine:

- GPT bij UEFI met een EFI-partitie van 1 GiB op `/boot/efi`;
- één BTRFS-rootpartitie met subvolume `@rootfs` (de ongebruikte
  top-level subvolumes `@`, `@home`, `@log` en `@pkg` van de bronmachine
  worden niet overgenomen; `/home` zit in `@rootfs`);
- mountopties `noatime,compress=zlib:3,discard=async,space_cache=v2`;
- snapper-configuratie `root` met geneste `/.snapshots` en ACL voor de
  gekozen gebruiker;
- geen swap, net als de bronmachine;
- SDDM, BSPWM en de Quickshell-bar na de eerste login.

## Bouwen

Vereisten (Debian sid):

```bash
sudo apt update
sudo apt install live-build debootstrap squashfs-tools xorriso \
  grub-pc-bin isolinux syslinux-common dosfstools mtools rsync zstd \
  imagemagick
```

Matugen staat niet in Debian. Het buildscript zoekt eerst een bestaande
binary (`MATUGEN_BIN=...`, `~/.local/bin/matugen`, `/usr/local/bin`) en haalt
anders automatisch de officiële release (standaard 4.2.0) naar
`iso/cache/matugen-<versie>/`. Die download is eenmalig en wordt met de
meegeleverde sha256 gecontroleerd. Een andere versie of URL kan met
`MATUGEN_VERSION`, `MATUGEN_URL` en `MATUGEN_SHA256` (leeg = niet
controleren).

De wallpaper komt uit `~/Pictures/wallpaper.jpg` en de map
`~/Pictures/Wallpapers`; beide zijn overschrijfbaar met `WALLPAPER=...` en
`WALLPAPER_DIR=...`. Ontbreekt de wallpaper, dan pakt het script de eerste
afbeelding uit `WALLPAPER_DIR` of genereert het een donkere
standaardwallpaper in `iso/cache/`.

```bash
sudo iso/build.sh
```

Het resultaat staat in `iso/out/`:

```
quickshell-desktop-amd64.iso
quickshell-desktop-amd64.iso.sha256
```

Het buildlog staat in `iso/build.log`. De eerste build duurt lang (de volledige
Debian-sid-desktop wordt in een chroot geïnstalleerd en gecomprimeerd).
`iso/cache/` bewaart zowel de live-build-pakketten als de gedownloade
matugen-binary, zodat een volgende build geen netwerk meer nodig heeft voor
die onderdelen.

## Problemen oplossen

- **`matugen niet gevonden`** — het script downloadt matugen nu zelf. Lukt
  dat niet (geen netwerk, proxy), installeer de release dan handmatig in
  `~/.local/bin` of geef `sudo MATUGEN_BIN=/pad/naar/matugen iso/build.sh`
  mee. Controleer bij een handmatige binary dat hij voor amd64 is.
- **`libssl`/`GLIBC`-fout bij matugen in de live-omgeving** — gebruik de
  officiële x86_64-release; die is tegen de Debian-sid-bibliotheken gebouwd.
- **`sha256 van matugen klopt niet`** — verwijder
  `iso/cache/matugen-*` en probeer opnieuw, of zet `MATUGEN_SHA256` leeg als
  je bewust een andere versie gebruikt.

## Wat er in de live-omgeving zit

- LXQt met SDDM-autologin (`user` / wachtwoord `live`, wachtwoordloos sudo);
- Calamares start automatisch; ook te openen via het menu en de
  bureaubladsnelkoppeling;
- de volledige desktopstack, zodat de installatie zonder netwerk werkt;
- `matugen`, de standaardwallpaper en de Griekse wallpaperselectie.

## Wat de installer doet

1. Partitioneren: EFI + BTRFS-root (geen swap).
2. `unpackfs`: de squashfs naar het doelssysteem.
3. Live-pakketten (live-boot, live-config, Calamares) verwijderen vóór de
   initramfs wordt gemaakt.
4. fstab, locale, toetsenbord, gebruiker, SDDM, GRUB en initramfs configureren.
5. `install-target.sh`:
   - schrijft de Debian-sid-bron;
   - controleert/herstelt GRUB (`rootflags=subvol=@rootfs` via update-grub);
   - maakt de snapper-configuratie en `/.snapshots`;
   - registreert die configuratie in `/etc/default/snapper`
     (`SNAPPER_CONFIGS="root"`), want zonder die regel kent snapper hem niet;
   - zet `ALLOW_USERS` en de ACL;
   - schakelt SDDM, NetworkManager, bluetooth, snapper-timers en fstrim in;
   - draait `quickshell-user-setup` voor de nieuwe gebruiker.
6. Opruimen en ontkoppelen.

## Testen

```bash
iso/verify-iso.sh                       # inhoud en checksum
iso/test-qemu.sh                        # UEFI-VM met lege 24 GiB-schijf
```

In de VM start Calamares automatisch. Kies in de partitioneringsstap
"Schijf wissen" (het BTRFS-rootformaat staat al voor), vul een gebruiker in
en installeer. Onder bspwm wordt het QEMU-venster betegeld; maak het zwevend
en minstens 1280×800, anders past het Calamares-venster niet op het scherm. Na de installatie kun je de qcow2 offline controleren:

```bash
sudo qemu-nbd --connect=/dev/nbd0 iso/test/disk.qcow2
sudo mount -o subvol=@rootfs /dev/nbd0p2 /mnt
findmnt -no OPTIONS /mnt
sudo btrfs subvolume list /mnt
sudo cat /mnt/etc/fstab
sudo cat /mnt/boot/grub/grub.cfg | grep rootflags
grep SNAPPER_CONFIGS /mnt/etc/default/snapper
sudo chroot /mnt snapper -c root list
sudo umount /mnt
sudo qemu-nbd --disconnect /dev/nbd0
```

Het seriële log staat in `iso/test/serial.log`; de QEMU-monitor in
`iso/test/monitor.sock`.

### Getest resultaat

De referentie-ISO is in QEMU met OVMF (UEFI) getest:

- Calamares start automatisch in de LXQt-live-sessie en toont de
  Quickshell-branding.
- Installatie op een lege 24 GiB-schijf maakt EFI 1 GiB + BTRFS-root
  (23 GiB), subvolume `@rootfs` en geneste `.snapshots`.
- fstab: `subvol=@rootfs,noatime,compress=zlib:3,discard=async,space_cache=v2`.
- GRUB: `rootflags=subvol=@rootfs`; de EFI-entry `Quickshell` start via
  `shimx64.efi`.
- SDDM is de displaymanager; de bspwm-sessie is standaard en na login draait
  de Quickshell-bar.
- Snapper-configuratie `root` staat klaar met `ALLOW_USERS` voor de gekozen
  gebruiker en `SYNC_ACL=yes`; `/.snapshots` is een geneste subvolume met de
  juiste ACL. De configuratie is in `/etc/default/snapper` geregistreerd, dus
  `snapper list-configs` en de widget zien hem; zonder registratie bleef de
  lijst leeg.
- Op de geïnstalleerde schijf zijn `Super+/` (71 bindingen),
  `Super+Shift+S` (BSPWM-instellingen) en een D-Bus-notificatie (popup +
  badge) getest; de Snapper-teller staat in de bar.

## Aanpassen

- **Pakketten:** `live-build/config/package-lists/quickshell.list.chroot`.
- **BTRFS/mounts:** `calamares/modules/partition.conf` en
  `calamares/modules/mount.conf`.
- **Gebruikers/sessie:** `calamares/modules/users.conf`,
  `calamares/modules/displaymanager.conf` en `calamares/modules/services-systemd.conf`.
- **Branding:** `calamares/branding/quickshell/` (`branding.desc`, `show.qml`).
- **Live-autostart:** `overlay/usr/lib/live/config/9999-calamares`.
- **Eerste-loginconfiguratie:** `overlay/usr/local/bin/quickshell-user-setup`
  en `overlay/usr/local/lib/quickshell/install-target.sh`.

## Beperkingen

- Google Chrome wordt niet meegeleverd (derde-partijrepo, proprietary). De
  desktopstack en de handmatig geïnstalleerde applicaties zitten in de ISO;
  alleen oude, niet in sid bestaande bibliotheekpakketten zijn weggelaten en
  worden door hun dependencies vervangen.
- De ISO is alleen voor amd64.
- Secure Boot is in de live-ISO uitgeschakeld. Het doelssysteem krijgt
  `shim-signed` en `grub-efi-amd64`; Secure Boot kan na de installatie
  afzonderlijk worden ingericht.
- De bronmachine heeft geen swap; de installer maakt er ook geen. Voor
  hibernation is een aparte swap-partitie of -file nodig.
