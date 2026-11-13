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
- grub-btrfs in het doelssysteem: de snapper-momentopnamen staan na de
  eerste momentopname in een eigen GRUB-submenu;
- geen swap, net als de bronmachine;
- SDDM, BSPWM en de Quickshell-bar na de eerste login.

## Bouwen

### Native op Debian sid/testing

Vereisten (Debian sid):

```bash
sudo apt update
sudo apt install live-build debootstrap squashfs-tools xorriso \
  grub-pc-bin grub-efi-amd64-bin grub-common isolinux syslinux-common \
  syslinux-utils dosfstools mtools rsync zstd imagemagick \
  fonts-jetbrains-mono file uuid-runtime bc curl
```

### Vanaf Ubuntu of een andere distributie

Ubuntu levert `live-build` 3.0~a57 uit 2013; die kent de opties in
`iso/live-build/auto/config` niet. Op zo'n host maakt `iso/build.sh`
eenmalig een Debian-sid-omgeving met `debootstrap` en bouwt daarin. Op de
host is alleen dit nodig:

```bash
sudo apt update
sudo apt install debootstrap debian-archive-keyring
sudo iso/build.sh
```

De omgeving komt in `/var/cache/quickshell-iso/builder-sid` (circa 1 GB) en
wordt bij volgende builds hergebruikt; de eerste build duurt daardoor extra.
Met deze variabelen pas je het gedrag aan:

| Variabele | Betekenis |
| --- | --- |
| `QS_BUILDER_DIR=/pad` | andere locatie voor de Debian-sid-omgeving |
| `QS_BUILDER_REFRESH=1` | pakketten in de omgeving bijwerken |
| `QS_BUILDER_MIRROR=...` | andere Debian-mirror voor de omgeving |
| `QS_ISO_FORCE_BUILDER=1` | ook op Debian in de sid-omgeving bouwen |
| `QS_ISO_HOST_BUILD=1` | nooit de sid-omgeving gebruiken; bouw native |

Verwijderen kan met `sudo rm -rf /var/cache/quickshell-iso`; de volgende
build maakt de omgeving opnieuw aan. De live-build-pakketcache blijft in
`iso/cache/` staan en wordt gedeeld tussen native en chroot-builds.

Matugen staat niet in Debian. Het buildscript zoekt eerst een bestaande
binary (`MATUGEN_BIN=...`, `~/.local/bin/matugen`, `/usr/local/bin`) en haalt
anders automatisch de officiële release (standaard 4.2.0) naar
`iso/cache/matugen-<versie>/`. Die download is eenmalig en wordt met de
meegeleverde sha256 gecontroleerd. Een andere versie of URL kan met
`MATUGEN_VERSION`, `MATUGEN_URL` en `MATUGEN_SHA256` (leeg = niet
controleren).

`grub-btrfs` staat evenmin in Debian. De bron van versie 4.14 staat in
`iso/vendor/` (zie `iso/vendor/README.md`); `iso/build.sh` controleert de
sha256 en een live-build-hook installeert hem in de chroot. Daardoor heeft
zowel de live-omgeving als het geïnstalleerde systeem `grub-btrfsd` en
`/etc/grub.d/41_snapshots-btrfs`. Een andere tarball kan met
`GRUB_BTRFS_TARBALL=/pad/naar.tar.gz` en `GRUB_BTRFS_VERSION=...`; zet
`GRUB_BTRFS_SHA256` leeg om niet te controleren.

Google Chrome staat niet in Debian. `iso/live-build/config/archives/` voegt
de officiële Google-repo met sleutel toe, zodat de chroot `google-chrome-stable`
kan installeren. De build heeft daarvoor eenmalig toegang tot
`dl.google.com` nodig; de pakketten zelf worden daarna in `iso/cache/`
bewaard. De NVIDIA-driver komt uit `non-free` en wordt tijdens de build met
DKMS gecompileerd; ook daarvoor is geen NVIDIA-hardware in de buildmachine
nodig. De driver wordt in een aparte, niet-fatale chroot-stap geïnstalleerd
(`0350-nvidia`). Daardoor stopt een Ubuntu-build niet meer als de
DKMS-compilatie op die machine mislukt: de ISO bouwt door met Mesa/nouveau en
het buildlog bevat de reden. `parallel_jobs=2` in
`overlay/etc/dkms/framework.conf.d/quickshell.conf` voorkomt daarnaast
geheugengebrek op kleine build-VM's.

De wallpaper komt uit `~/Pictures/wallpaper.jpg` en de map
`~/Pictures/Wallpapers`; beide zijn overschrijfbaar met `WALLPAPER=...` en
`WALLPAPER_DIR=...`. Ontbreekt de wallpaper, dan pakt het script de eerste
afbeelding uit `WALLPAPER_DIR` of genereert het een donkere
standaardwallpaper in `iso/cache/`.

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
- **`lb build is mislukt` of `geen ISO gevonden`** — het script toont nu de
  laatste 60 regels van `iso/build.log`. Controleer verder:
  - minimaal ~12 GiB vrije ruimte op de schijf van de repo (chroot, squashfs
    en ISO);
  - een amd64-host; op arm64 is qemu-binfmt nodig;
  - genoeg rechten: live-build moet kunnen mounten en chrooten. In een
    container of WSL zonder die rechten stopt de build in de log.
- **Oude `live-build` (bijvoorbeeld Ubuntu)** — gebruik je
  `QS_ISO_HOST_BUILD=1` terwijl de host te oud is, dan faalt `lb config` op
  onbekende opties. Laat die variabele weg: het script gebruikt dan
  automatisch de Debian-sid-omgeving.
- **Google Chrome wordt niet gevonden tijdens de build** — de chroot heeft
  toegang tot `dl.google.com` nodig. Controleer de proxy/netwerktoegang en of
  `iso/live-build/config/archives/google-chrome.key` en
  `google-chrome.list.chroot` aanwezig zijn. De repo gebruikt bewust http
  (met APT-handtekening), omdat ca-certificates in de bootstrap-chroot nog
  niet aanwezig is.
- **`0350-nvidia: NVIDIA-kernelmodule ontbreekt`** — DKMS kon de module niet
  bouwen. De ISO-build gaat nu door en gebruikt Mesa/nouveau; zoek in
  `iso/build.log` naar de fout van `nvidia-kernel-dkms` om de driver alsnog
  te laten werken. Vaak is er te weinig RAM (zet `parallel_jobs=1` in
  `overlay/etc/dkms/framework.conf.d/quickshell.conf`), ontbreken de
  kernelheaders of is de NVIDIA-driver te oud voor de kernelversie in sid.
  Op de doel-PC kun je later `sudo apt install --reinstall
  nvidia-kernel-dkms` uitvoeren.

## Wat er in de live-omgeving zit

- LXQt met SDDM-autologin (`user` / wachtwoord `live`, wachtwoordloos sudo);
- Calamares start automatisch; ook te openen via het menu en de
  bureaubladsnelkoppeling;
- de volledige desktopstack, zodat de installatie zonder netwerk werkt;
- Google Chrome met propriëtaire codecs en Widevine, en NVIDIA-ondersteuning
  met automatische terugval op Mesa;
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
   - schakelt SDDM, NetworkManager, bluetooth, snapper-timers, fstrim en
     `grub-btrfsd` in;
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
sudo ls -l /mnt/etc/grub.d/41_snapshots-btrfs /mnt/usr/bin/grub-btrfsd
sudo ls -l /mnt/etc/systemd/system/multi-user.target.wants/grub-btrfsd.service
sudo cat /mnt/boot/grub/grub-btrfs.cfg 2>/dev/null | head
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
- `grub-btrfsd` en `/etc/grub.d/41_snapshots-btrfs` zitten in het
  doelssysteem en de daemon is ingeschakeld. Zodra snapper een momentopname
  maakt, werkt de daemon `grub-btrfs.cfg` bij en verschijnt het
  snapshot-submenu in GRUB.
- Op de geïnstalleerde schijf zijn `Super+/` (71 bindingen),
  `Super+Shift+S` (BSPWM-instellingen) en een D-Bus-notificatie (popup +
  badge) getest; de Snapper-teller staat in de bar.

De Chrome/NVIDIA-versie (2,9 GiB) is opnieuw in QEMU met OVMF geboot:

- De LXQt-live-sessie start en Calamares opent automatisch; het GRUB-menu
  start na 10 seconden zonder toetsaanslag door.
- `google-chrome-stable --version` geeft `Google Chrome 157.0.8103.78`;
  Chrome start ook grafisch (eenmalige ToS-dialoog).
- `xdg-settings get default-web-browser` geeft `google-chrome.desktop`.
- `quickshell-gpu-setup.service` is `enabled` en actief; in de VM zonder
  NVIDIA staat in het journal `geen NVIDIA-GPU; GLX op Mesa` en
  `/etc/alternatives/glx` wijst naar `/usr/lib/mesa-diverted`.
- De NVIDIA-DKMS-module is tijdens de build voor
  `7.3.4+deb14-amd64` gebouwd en in de squashfs geïnstalleerd; op echte
  NVIDIA-hardware is dat de route die de bootservice selecteert.

## Aanpassen

- **Pakketten:** `live-build/config/package-lists/quickshell.list.chroot`.
- **Google Chrome/codecs:** `live-build/config/archives/` (repo en
  GPG-sleutel) en de pakketlijst.
- **NVIDIA/Mesa:** `overlay/usr/local/bin/quickshell-gpu-setup` en
  `overlay/usr/lib/systemd/system/quickshell-gpu-setup.service`.
- **BTRFS/mounts:** `calamares/modules/partition.conf` en
  `calamares/modules/mount.conf`.
- **Gebruikers/sessie:** `calamares/modules/users.conf`,
  `calamares/modules/displaymanager.conf` en `calamares/modules/services-systemd.conf`.
- **Branding:** `calamares/branding/quickshell/` (`branding.desc`, `show.qml`).
- **Live-autostart:** `overlay/usr/lib/live/config/9999-calamares`.
- **Eerste-loginconfiguratie:** `overlay/usr/local/bin/quickshell-user-setup`
  en `overlay/usr/local/lib/quickshell/install-target.sh`.

## Chrome, codecs en NVIDIA

De ISO is bedoeld als kant-en-klare desktop en bevat daarom bewust een aantal
niet-vrije onderdelen:

- **Google Chrome** (`google-chrome-stable`) uit de officiële Google-repo.
  De stabiele Chrome-build bevat H.264, AAC en MP3 plus Widevine (DRM voor
  onder meer Netflix en Spotify). Chrome is de standaardbrowser; Firefox blijft
  als terugval geïnstalleerd. De repo en sleutel staan in
  `live-build/config/archives/`; bij het bouwen is dus toegang tot
  `dl.google.com` nodig. Het geïnstalleerde systeem houdt de repo, zodat
  Chrome via `apt` bijgewerkt kan worden.
- **Codecs** voor andere toepassingen: `libavcodec-extra` en de
  GStreamer-plugins `gstreamer1.0-libav`, `-plugins-bad` en `-plugins-ugly`.
- **Hardwarematige videodecodering**: `intel-media-va-driver-non-free`,
  `mesa-va-drivers`, `mesa-vdpau-drivers` en `vainfo` (diagnose).
- **NVIDIA**: de propriëtaire `nvidia-driver` met DKMS-module,
  `nvidia-settings`, `nvidia-smi`, `nvidia-detect` en `firmware-misc-nonfree`.
  `linux-headers-amd64` zit erbij, zodat een latere kernelupdate de module
  opnieuw kan bouwen. De versie is die van Debian sid op het moment van
  bouwen; zeer nieuwe GPU's kunnen een nieuwere driver nodig hebben.

De buildmachine hoeft geen NVIDIA-GPU te hebben: DKMS compileert de module
uit de bron voor de kernel in de ISO. De hook `0350-nvidia` installeert de
driver in een aparte stap en probeert de module voor elke geïnstalleerde
kernel te bouwen. Lukt dat niet, dan waarschuwt de hook en bouwt de ISO door
met Mesa/nouveau; `0350-nvidia` laat de build dus niet meer met exit 1
stoppen. `iso/verify-iso.sh` meldt in dat geval een waarschuwing in plaats
van een fout.

Bij het opstarten kiest `quickshell-gpu-setup.service` de GLX-implementatie:

- NVIDIA-GPU met werkende driver → NVIDIA-GLX;
- NVIDIA-GPU zonder werkende driver → Mesa met nouveau als terugval;
- geen NVIDIA-GPU → Mesa.

Daardoor werkt dezelfde ISO op de bouw-VM (zonder NVIDIA) en op een desktop
met NVIDIA. De keuze wordt bij iedere boot opnieuw gemaakt en geldt ook voor
het geïnstalleerde systeem.

Na een rebuild controleert `iso/verify-iso.sh` of Chrome, de Google-sleutel,
de NVIDIA-kernelmodule en de Mesa-terugval in de squashfs zitten. Test de
NVIDIA-route daarna op echte hardware; in QEMU zonder doorgifte van een
GPU wordt uiteraard Mesa gebruikt.

## Beperkingen

- Google Chrome en de NVIDIA-driver zijn propriëtaire software. De ISO is
  daardoor niet geschikt voor distributie waarbij alleen vrije software is
  toegestaan.
- De ISO is alleen voor amd64.
- Secure Boot is in de live-ISO uitgeschakeld. Het doelssysteem krijgt
  `shim-signed` en `grub-efi-amd64`; Secure Boot kan na de installatie
  afzonderlijk worden ingericht. De NVIDIA-DKMS-module is niet ondertekend en
  wordt door Secure Boot geweigerd zolang de eigen sleutel niet is
  geregistreerd.
- De bronmachine heeft geen swap; de installer maakt er ook geen. Voor
  hibernation is een aparte swap-partitie of -file nodig.
- De GRUB-snapshotvermelding is een reddingsmenu: snapper maakt
  alleen-lezen momentopnamen en `/var/log` zit in dezelfde `@rootfs`. Een
  momentopname start daarom read-only; schrijvende diensten kunnen tijdens
  zo'n sessie klagen. Voor volledig schrijfbare snapshot-sessies zijn aparte
  subvolumes voor `/var/log` (en eventueel `/home`) nodig.
