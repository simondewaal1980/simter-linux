# Promptbibliotheek — BSPWM + Quickshell-desktop

> Deze prompts zijn afgeleid van `PLAN.md`, `README.md`, `iso/README.md` en de
> broncode. Ze zijn bedoeld om later een AI-sessie snel en zonder voorkennis
> te laten starten, zonder dat je telkens het hele project opnieuw hoeft uit te
> leggen.
>
> **Gebruik:** plak eerst prompt **00 (mastercontext)** en daarna de prompt
> voor de taak. Vul de placeholders tussen `<…>` in. Vraag de AI om eerst het
> plan te lezen en pas daarna code te wijzigen.
>
> **Herkomst:** deze versie is op 14 november 2026 samengesteld uit
> `PLAN.md`, `README.md`, `iso/README.md` en de broncode. Werk de prompts bij
> na een afgeronde fase met prompt **36**, zodat dit bestand de actuele
> werkwijze blijft weerspiegelen.

---

## Placeholders

| Placeholder | Betekenis | Voorbeeld |
|---|---|---|
| `<FASE>` | Fase uit `PLAN.md` | `Fase 11` |
| `<BESTAND>` | Pad in de repo | `src/components/Bar.qml` |
| `<DOEL>` | Gewenst resultaat | "een accu-widget" |
| `<DISTRO>` | Distributie of familie | `Debian sid`, `Fedora`, `Arch` |
| `<VARIANT>` | Profielnaam | `debian-sid`, `fedora-kde` |
| `<COMMANDO>` | Exact commando | `qs ipc call updates status` |
| `<FOUT>` | Letterlijke foutmelding/logregel | `TypeError: …` |

---

## 00 — Mastercontext (altijd eerst plakken)

```text
Je werkt aan een persoonlijk Linux-desktopproject in
/home/simon/projecten/quickshell.

Doel: een complete X11-desktop met bspwm als window manager en Quickshell voor
de bar, notificaties, tray, instellingen, sneltoetsen, wallpapers,
systeembeheer en een installer-ISO.

Vaste omgeving:
- Debian sid (forky), X11, SDDM, 1920×1080.
- Quickshell 0.3.2, bspwm 0.9.12, sxhkd 0.6.3, Qt 6.11.
- Projectpad: /home/simon/projecten/quickshell.
- Starten: qs -p /home/simon/projecten/quickshell.
- De installer-ISO gebruikt /opt/quickshell en maakt daarnaast een symlink
  vanaf ~/projecten/quickshell.
- IPC altijd met -p; zonder -p vindt de client de draaiende instantie niet.

Bronnen van waarheid:
- ~/.config/bspwm/settings.json voor BSPWM, kleuren, ui.scale en
  ui.bar_opacity. De repo bevat settings.default.json.
- ~/.config/bspwm/theme.generated.json voor het matugen-palet.
- ~/.config/sxhkd/sxhkdrc voor alle sneltoetsen en het overzicht.
- ~/.config/bspwm/wallpaper voor de actieve wallpaper.
- De repo blijft de bron; configuratie wordt via symlinks gedeployed.

Belangrijke architecturele regels:
- Eén bron per gegeven; geen tweede keybindinglijst of tweede kleurenbron.
- Wijzigingen in settings.json worden direct met bspc config toegepast en
  atomair opgeslagen (BspwmSettings.qml).
- X11-beperkingen: PopupWindow krijgt geen toetsenbordfocus (issue #794);
  gebruik FloatingWindow voor tekstinvoer. Een klik buiten een popup wordt
  niet gedetecteerd.
- Tray ondersteunt alleen SNI, geen legacy XEmbed.
- Notificaties lopen uitsluitend via Quickshell
  (org.freedesktop.Notifications); start geen andere daemon.
- De bar gebruikt PanelWindow met EWMH-struts; padding in settings.json staat
  standaard op 0 om dubbele ruimte te voorkomen.
- De installer gebruikt BTRFS met @rootfs, @home, @log, @cache, @tmp,
  @spool, snapper en overlayroot voor snapshot-boots.

Werkwijze:
1. Lees eerst PLAN.md en de relevante bronbestanden.
2. Benoem aannames en onzekerheden; verzin geen paden of API's.
3. Wijzig alleen wat nodig is; houd stijl, naming en structuur consistent.
4. Geef bij elke wijziging: doel, bestanden, exacte stappen, verificatie.
5. Test met qs -p … of een geneste Xephyr; controleer
   /tmp/quickshell-$USER.log.
6. Raak de LXQt-fallback en persoonlijke data niet aan.
7. Als iets niet getest kan worden, zeg dat expliciet en geef het commando
   dat de gebruiker moet draaien.

Antwoord in het Nederlands, compact en met concrete commando's.
```

---

## 01 — Een nieuwe fase starten

```text
Lees PLAN.md. We beginnen aan <FASE>: <DOEL>.

Geef mij:
1. de huidige status van deze fase (klaar/gedeeltelijk/open);
2. de minimale stappen in uitvoerorde;
3. per stap de bestanden die waarschijnlijk wijzigen;
4. de verificatiecommando's;
5. de risico's en de rollback.

Wijzig nog niets. Wacht op mijn akkoord.
```

---

## 02 — Fase 1 reconstrueren of verifiëren

```text
Reconstrueer Fase 1 van PLAN.md: pakketten, bspwm-sessie, sxhkd, wallpaper,
picom en de JSON-instellingen.

Controleer in de huidige repo:
- config/bspwm/bspwmrc
- config/bspwm/settings.default.json
- config/sxhkd/sxhkdrc
- scripts/apply-bspwm-settings.sh

Geef de exacte installatie- en symlinkcommando's, de verificatie
(bspc query, pgrep, bspc config, bspc wm -r) en de bekende valkuilen
(xrender/picom, boolean-exitcode, sleutelnamen). Voer niets destructief uit.
```

---

## 03 — Fase 2 reconstrueren of verifiëren

```text
Reconstrueer Fase 2: Quickshell-skelet, Theme.qml, Bar.qml, Clock.qml en de
bar-IPC.

Leg uit:
- hoe PanelWindow met drie ankers zijn strut berekent;
- waarom JsonAdapter in Theme.qml zit en waarom watchChanges daar veilig is;
- hoe je de strut controleert (xprop -id <bar-window>, bspc query -T -m);
- waarom de datum via Qt.locale("nl_NL") gaat.

Geef een testplan voor fullscreen, resolutiewissel en qs ipc call bar toggle.
```

---

## 04 — Fase 3 reconstrueren of verifiëren

```text
Reconstrueer Fase 3: Bspwm.qml, ReportParser.js, Workspaces.qml en
ActiveWindow.qml.

Gebruik het echte bspwm-reportformaat:
- status_prefix + eerste monitor;
- per monitor desktops O/o/F/f/U/u, L(T|M), T(...) en G(...);
- T@ = receptacle; G = S/P/L/M.

Leg uit waarom bspc desktop -f <monitor>:<naam> niet werkt en waarom de bar
een index gebruikt. Beschrijf het herverbinden na bspc wm -r en de urgentie-
test via WM_HINTS. Geef de IPC-diagnostiek.
```

---

## 05 — Fase 4 reconstrueren of verifiëren

```text
Reconstrueer Fase 4: Weather.qml, WeatherCodes.js, WeatherWidget.qml en
WeatherPopup.qml.

Controleer:
- de Open-Meteo-endpoint en forecast_days=4;
- de cache in Quickshell.cachePath("weather-eindhoven.json");
- de 10-minutentimer, 60s-retry en offline-gedrag;
- de Nederlandse WMO-teksten en Font Awesome-iconen;
- waarom de popup onder X11 niet op een klik buiten sluit.

Geef een offline-test met WEATHER_ENDPOINT en de IPC-statuscommando's.
```

---

## 06 — Fase 5 reconstrueren of verifiëren

```text
Reconstrueer Fase 5: TrayWidget.qml.

Leg uit:
- waarom alleen SNI wordt ondersteund en XEmbed niet;
- waarom //@ pragma UseQApplication nodig is voor QMenu;
- waarom anchor.window + anchor.rect wordt gebruikt in plaats van anchor.item;
- hoe klikken, scrollen, tooltip en menu's worden getest met een fake-SNI.

Geef een testplan in een geneste Xephyr met eigen dbus-run-session.
```

---

## 07 — Fase 6 reconstrueren of verifiëren

```text
Reconstrueer Fase 6: NotificationDaemon.qml, NotificationStack.qml,
NotificationCenter.qml en NotificationBell.qml.

Leg uit:
- waarom tracked = true nodig is;
- dat expireTimeout in milliseconden is;
- waarom de stack xdotool pollt voor hover-pauze;
- hoe de conflictcontrole met org.freedesktop.Notifications werkt;
- waarom app-iconen zonder platformthema terugvallen op de bel.

Geef tests voor basic, critical, action, DND, transient, afbeelding,
vervanging, wissen en herladen.
```

---

## 08 — Fase 7 reconstrueren of verifiëren

```text
Reconstrueer Fase 7: BspwmSettings.qml en SettingsWindow.qml.

Leg uit:
- waarom BspwmSettings geen watchChanges heeft en Theme.qml wel;
- de debounce (120 ms naar bspc, 500 ms naar schijf) en atomaire writes;
- waarom FloatingWindow nodig is voor tekstinvoer;
- waarom bspwmrc op venstertitels matcht in plaats van WM_CLASS;
- hoe kleurpresets zowel bspc als de bar bijwerken;
- hoe ui.scale en ui.bar_opacity werken.

Geef verificatie voor gaps, kleuren, reset, setScale, setBarOpacity en
bspc wm -r.
```

---

## 09 — Fase 8 reconstrueren of verifiëren

```text
Reconstrueer Fase 8: SxhkdParser.js, ShortcutsWindow.qml en
config/sxhkd/sxhkdrc.

Leg uit:
- de comment/sectie-conventie;
- brace-expansie, chord-chains en regelcontinuties;
- waarom het overzicht de sxhkdrc zelf leest en geen tweede lijst heeft;
- hoe @qs-shortcut-blokken worden toegevoegd, aangepast en verwijderd;
- waarom qs ipc call shortcuts … altijd -p nodig heeft.

Geef tests voor zoeken, groepen, toevoegen, bewerken, verwijderen en
pkill -USR1 sxhkd.
```

---

## 10 — Fase 9 reconstrueren of verifiëren

```text
Reconstrueer Fase 9: VolumeWidget, BatteryWidget, MprisWidget, polkit-agent
en de Quickshell-watchdog.

Leg uit:
- de PipeWire-api met pactl-terugval;
- waarom BatteryWidget en MprisWidget zich verbergen zonder hardware/speler;
- waarom lxqt-policykit-agent en niet lxpolkit;
- waarom de watchdog standaard uit staat (QUICKSHELL_WATCHDOG=1).

Geef een acceptatietest voor een desktop zonder accu/backlight/locker.
```

---

## 11 — Fase 10: wallpapers, thema en schaal

```text
Reconstrueer Fase 10: matugen, wallpaper-theme.sh, apply-wallpaper-theme.sh,
apply-qt-theme.sh, Theme.qml, Wallpaper.qml en WallpaperWindow.qml.

Leg uit:
- waarom het matugen-template custom_colors gebruikt in plaats van base16;
- de twee kleurbronnen (theme.generated.json en settings.json) en de
  eenrichtingsstroom;
- waarom de post-hook geen apply-settings.sh aanroept;
- hoe qt6ct, de QSS en de gegenereerde QPalette samenhangen;
- hoe wallpapers toevoegen/verwijderen en de actieve wallpaper beschermd
  worden;
- hoe ui.scale en ui.bar_opacity doorwerken in de bar en popups.

Geef tests voor een nieuwe wallpaper, een ontbrekend palet, een Qt-app en
een niet-bestaande wallpaper.
```

---

## 12 — Fase 11: Snapper, updates en power

```text
Reconstrueer Fase 11: Snapper.qml, SnapperPopup.qml, Updates.qml,
UpdatesPopup.qml, Power.qml en PowerMenu.qml.

Leg uit:
- lezen via snapperd met ALLOW_USERS/SYNC_ACL en de pkexec-terugval;
- waarom een rollback pas na een herstart actief wordt;
- waarom opruimen maximaal 10 momentopnamen aanhoudt en standaard/actieve
  momentopnamen beschermt;
- waarom apt list --upgradable de lokale index leest en waarom alleen een
  expliciete refresh apt-get update draait;
- waarom full-upgrade nodig is voor kept-back pakketten;
- hoe het powermenu de sessie losgekoppeld beëindigt.

Geef IPC-tests en een test met een fake-snapper.
```

---

## 13 — Fase 12: documentatie en acceptatie

```text
Reconstrueer Fase 12: README.md, docs/keybindings.md, docs/codebook.html,
docs/wallpaper-credits.md en de screenshots.

Controleer of de documentatie nog klopt met de bron:
- paden, IPC-doelen, sneltoetsen, widgets en beperkingen;
- de installatie-ISO en de BTRFS/snapper-configuratie;
- de nieuwste features (wallpapervenster, updates, powermenu, schaal).

Geef een lijst met verouderde of ontbrekende stukken. Wijzig alleen
documentatie, geen code.
```

---

## 14 — Een nieuwe widget toevoegen

```text
Voeg een nieuwe widget toe aan de bar: <DOEL>.

Werk als volgt:
1. Lees Bar.qml, Theme.qml en een vergelijkbare widget (bijv. VolumeWidget).
2. Bepaal of een service nodig is of dat een bestaande service volstaat.
3. Maak de widget zelfstandig: implicitWidth/implicitHeight, Theme.scaled(),
   alleen zichtbaar als er data is, klikgedrag via een signaal.
4. Voeg de widget op de juiste plaats in Bar.qml toe, met scheidingslijn
   alleen als dat nodig is.
5. Voeg een popup toe als er details nodig zijn; gebruik FloatingWindow als
   er tekstinvoer is.
6. Voeg IPC toe voor status/open/close/toggle.
7. Werk README.md en PLAN.md bij.
8. Geef tests en controleer /tmp/quickshell-$USER.log.

Wijzig geen bestaande widgets zonder noodzaak.
```

---

## 15 — Een nieuwe service toevoegen

```text
Voeg een Quickshell-service toe voor <DOEL>.

Eisen:
- singleton in src/services/, met pragma Singleton en een qmldir-entry;
- uitleg bovenaan: bron, verversing, fouten en elevatie;
- geen blokkerende calls in de UI-thread;
- duidelijke properties voor loading/error/lastUpdated;
- Process/FileView met blockLoading alleen waar nodig;
- een fallback als een programma ontbreekt;
- een IPC-handler in shell.qml met status en eventueel refresh;
- tests met een fake-commando via een environment-variabele;
- documentatie in README.md en PLAN.md.

Gebruik Snapper.qml of Updates.qml als stijlvoorbeeld.
```

---

## 16 — Een popup of FloatingWindow toevoegen

```text
Maak een <popup|FloatingWindow> voor <DOEL>.

Regels:
- PopupWindow voor informatie en muisbediening, verankerd met
  anchor.window + anchor.rect (niet anchor.item);
- FloatingWindow voor tekstinvoer, zoeken of formulieren (issue #794);
- geen grabFocus in popups;
- sluiten via X, tweede klik op de widget, klik op de bar en IPC;
- Theme.scaled() voor alle maten;
- een bspwm-regel op venstertitel als het een FloatingWindow is;
- geen vaste hexkleuren; gebruik Theme;
- test met een geneste Xephyr en controleer de focus.

Geef de bestanden, de bspwm-regel en de IPC-functies.
```

---

## 17 — Een IPC-handler toevoegen

```text
Voeg een IPC-handler toe voor <DOEL>.

Eisen:
- target in shell.qml, functies open/close/toggle/status;
- status geeft JSON met de belangrijkste toestand en fouten;
- destructieve acties alleen na bevestiging in de GUI;
- documenteer de commando's in README.md;
- gebruik qs -p /home/simon/projecten/quickshell ipc call … in alle
  voorbeelden;
- test met qs ipc show en een echte call.

Geef de exacte functies en een testcommando per functie.
```

---

## 18 — Een sneltoets toevoegen of wijzigen

```text
Voeg een sneltoets toe of wijzig er een in config/sxhkd/sxhkdrc.

Eisen:
- zoek eerst naar conflicten met bestaande combinaties;
- elke hotkey krijgt een comment direct erboven;
- gebruik de juiste sectie (# --- … ---);
- gebruik qs -p "$HOME/projecten/quickshell" ipc call … voor Quickshell;
- test met sxhkd -c config/sxhkd/sxhkdrc op een eigen display;
- daarna pkill -USR1 sxhkd;
- controleer het overzicht met Super+/ en de parserstatus.

Geef de oude regel, de nieuwe regel, het conflictonderzoek en de test.
```

---

## 19 — Thema of kleuren aanpassen

```text
Pas het thema aan: <DOEL>.

Houd de keten intact:
wallpaper → matugen → theme.generated.json → Theme.qml + apply-qt-theme.sh
→ bspwm-randen in settings.json → bar/Qt/GTK/rofi/alacritty.

Eisen:
- geen vaste kleuren in QML of QSS als een paletrol bestaat;
- de post-hook mag geen monitor-padding wissen;
- Catppuccin Mocha blijft de fallback;
- controleer theme.generated.json, bspc config, gsettings, rofi -dump-theme
  en een Qt-app;
- documenteer de nieuwe presets of templates.

Geef de bestanden en de volledige verificatie.
```

---

## 20 — Debuggen: QML of de bar

```text
Debug deze QML-fout in <BESTAND>: <FOUT>.

Werk als volgt:
1. Vraag om de volledige logregel uit /tmp/quickshell-$USER.log.
2. Controleer op ontbrekende imports, qmldir-entries en verkeerde paden.
3. Test met qs -p … ipc call bar reload; herstart alleen als dat nodig is.
4. Isoleer de component in een geneste Xephyr als de fout alleen daar
   optreedt.
5. Geef de kleinste fix en een regressietest.

Verander geen architectuur om een symptoom te verbergen.
```

---

## 21 — Debuggen: bspwm of workspaces

```text
Debug dit bspwm-probleem: <FOUT>.

Controleer achtereenvolgens:
- pgrep -x bspwm en echo $BSPWM_SOCKET;
- bspc query -M --names, bspc query -D --names, bspc wm -g;
- qs -p … ipc call bspwm status;
- het ruwe report van bspc subscribe report;
- de report-parser (T/G, lege desktop, tweede monitor);
- herverbinden na bspc wm -r.

Geef per stap het commando en de verwachte uitvoer.
```

---

## 22 — Debuggen: tray, notificaties of popups

```text
Debug dit probleem: <FOUT> (tray / notificaties / popup).

Gebruik de juiste checklist:
- tray: SNI vs XEmbed, SystemTray.items, UseQApplication, menu-anchor,
  tooltip;
- notificaties: eigenaar van org.freedesktop.Notifications, tracked,
  expireTimeout in ms, DND, hover-poll;
- popup: anchor.window + anchor.rect, grabFocus, klik buiten, FloatingWindow
  voor tekstinvoer.

Test in een geneste Xephyr met een eigen dbus-run-session als de echte sessie
niet verstoord mag worden. Geef de kleinste fix en een test.
```

---

## 23 — Debuggen: thema, wallpaper of Qt

```text
Debug dit themaprobleem: <FOUT>.

Controleer:
- command -v matugen of ~/.local/bin/matugen;
- scripts/wallpaper-theme.sh en ~/.config/bspwm/theme.generated.json;
- ~/.config/bspwm/settings.json en bspc config;
- scripts/apply-qt-theme.sh, ~/.config/qt6ct/qt6ct.conf en het kleurbestand;
- QT_QPA_PLATFORMTHEME (qt6ct of gtk3);
- gsettings color-scheme, GTK settings.ini, rofi en alacritty;
- of bestaande vensters pas na een herstart meebewegen.

Geef de kleinste fix en de controlecommando's.
```

---

## 24 — Debuggen: Snapper of updates

```text
Debug dit probleem: <FOUT> (Snapper of updates).

Voor Snapper:
- snapper list-configs en snapper -c <config> list als de gebruiker;
- ALLOW_USERS/SYNC_ACL en de ACL op /.snapshots;
- snapperd, pkexec en de polkit-agent;
- of de configuratie in /etc/default/snapper staat;
- of rollback alleen voor de root-subvolume bedoeld is.

Voor updates:
- apt list --upgradable en de leeftijd van /var/lib/apt/lists;
- of de refresh echt apt-get update heeft gedraaid;
- kept-back pakketten en full-upgrade;
- flatpak remote-ls --updates;
- UPDATES_ELEVATE en de polkit-agent.

Geef per oorzaak het bewijs en de fix.
```

---

## 25 — Testen en acceptatie

```text
Stel een testplan op voor <FASE of FEATURE>.

Gebruik de testmatrix uit PLAN.md:
- QML-log, sxhkd-syntax, geneste sessie;
- IPC-status per doel;
- echte sessie en geneste Xephyr;
- offline- en foutpaden;
- voor de ISO: verify-iso.sh, QEMU, qemu-nbd, BTRFS, snapper, snapshot-boot.

Geef per test: commando, verwachte uitkomst, bewijs (log/uitvoer) en wat je
doet als de test faalt. Vink pas af als het bewijs is vastgelegd.
```

---

## 26 — Documentatie genereren of bijwerken

```text
Werk de documentatie bij voor <WIJZIGING>.

Eisen:
- README.md: gebruikersgerichte installatie, gebruik, paden, IPC,
  probleemoplossing en beperkingen;
- PLAN.md: fase, status, verificatie en lessen;
- docs/keybindings.md alleen als momentopname, niet als tweede bron;
- docs/codebook.html bijwerken als de architectuur of bestanden veranderen;
- iso/README.md voor build, installatie en testen;
- geen verouderde commando's of paden achterlaten.

Geef een diff-overzicht en controleer alle commando's op uitvoerbaarheid.
```

---

## 27 — Code review en refactor

```text
Review <BESTAND of FASE> op:

- correctheid en X11-beperkingen;
- één bron van waarheid;
- dubbele code of dubbele lijsten;
- foutafhandeling en fallbacks;
- reactiviteit zonder bindingslussen;
- prestaties (processen, timers, polls);
- veiligheid (pkexec, paden, quoting);
- consistentie met Theme.scaled() en de bestaande stijl;
- tests en documentatie.

Geef bevindingen op severity, met bestand/regel en een minimale fix.
Verander niets zonder mijn akkoord.
```

---

## 28 — Installer-ISO bouwen en verifiëren

```text
Bouw en verifieer de installer-ISO.

Context:
- hybride BIOS + UEFI, Debian sid, LXQt-live, Calamares;
- BTRFS met @rootfs, @home, @log, @cache, @tmp, @spool;
- snapper, grub-btrfs, overlayroot voor snapshot-boots;
- Chrome, codecs en NVIDIA-DKMS met Mesa-terugval;
- live-build, eventueel via een Debian-sid-chroot op Ubuntu.

Geef:
1. de vereisten en het buildcommando;
2. de variabelen (MATUGEN_BIN, GRUB_BTRFS_TARBALL, QS_BUILDER_*);
3. de verificatie met iso/verify-iso.sh;
4. de QEMU-test met iso/test-qemu.sh;
5. de qemu-nbd-controles voor BTRFS, fstab, snapper en GRUB;
6. de bekende fouten (xz-geheugen, oude live-build, NVIDIA-DKMS,
   ontbrekende subvolumes) met oplossing.

Voer geen build uit zonder mijn akkoord; de build duurt lang en vraagt root.
```

---

## 29 — BTRFS, snapper en snapshot-boot

```text
Leg de BTRFS/snapper-opzet uit en controleer die.

Onderdelen:
- @rootfs op /, @home, @log, @cache, @tmp, @spool;
- /.snapshots als geneste subvolume;
- mountopties noatime,compress=zlib:3,discard=async,space_cache=v2;
- snapper-configuratie root, ALLOW_USERS, SYNC_ACL en
  /etc/default/snapper;
- grub-btrfs en het snapshot-submenu;
- overlayroot=tmpfs:recurse=0 alleen voor snapshot-entries;
- rollback is pas na een herstart actief.

Geef de controles met findmnt, btrfs subvolume list, cat /etc/fstab,
snapper list-configs, grep in grub.cfg en een test waarbij een bestand in /
na een snapshot-boot verdwijnt maar in /home blijft.
```

---

## 30 — Een tweede Linux-distributie kiezen

```text
Ik wil een tweede Linux-distributie maken naast de bestaande Debian-desktop.
Help mij een route te kiezen.

Vergelijk:
A. remaster/live-ISO;
B. derivative op een bestaande basis;
C. from scratch.

Voor mijn situatie:
- ervaring: <NIVEAU>;
- doel: <LEREN / UITBRENGEN / EIGEN GEBRUIK>;
- tijd: <UREN PER WEEK>;
- hardware: <HARDWARE>;
- gewenste basis: <DEBIAN / FEDORA / ARCH / ANDERS>.

Geef een aanbevolen route, de eerste drie mijlpalen en de belangrijkste
risico's. Verwijs naar de leerstappen in PLAN.md fase 14.
```

---

## 31 — Een minimale live-ISO bouwen

```text
Bouw een minimale live-ISO voor <DISTRO> met <TOOL>.

Doel: boot naar een console, geen desktop, geen installer.

Geef:
1. de packages en de buildcommando's;
2. de directorystructuur;
3. hoe je één extra package toevoegt;
4. hoe je de squashfs en de bootimages controleert;
5. hoe je in QEMU test (BIOS en UEFI);
6. de checksum en het buildlog.

Houd het script klein en reproduceerbaar. Geen persoonlijke data.
```

---

## 32 — Een distributieprofiel ontwerpen

```text
Ontwerp een distributieprofiel voor <DISTRO>/<VARIANT>.

Het profiel beschrijft:
- basis en architectuur;
- package manager en repo's;
- kernel en firmware;
- bootloader en installer;
- displaymanager en sessie;
- bestandssysteem en snapshots;
- desktopstack en Quickshell-paden;
- branding en defaults;
- testmatrix en releaseprocedure.

Houd gedeelde desktopcode herbruikbaar; alleen profielspecifieke verschillen
horen in het profiel. Geef een mapstructuur en een voorbeeldconfiguratie.
Wijzig de bestaande Debian-desktop niet.
```

---

## 33 — Een eigen package en repo maken

```text
Maak een eigen package en APT-repo voor <PAKKET>.

Geef:
1. de minimale Debian-packaging (debian/control, rules, changelog, install);
2. het buildcommando;
3. een met reprepro of aptly opgezette repo;
4. GPG-ondertekening en de clientconfiguratie;
5. een test waarbij je het pakket installeert en upgradet;
6. het equivalent in RPM of pacman, als ik die route kies.

Waarschuw voor versiebeleid, sleutelbeheer en het verwijderen van oude
pakketten.
```

---

## 34 — CI voor de ISO

```text
Ontwerp een CI-pipeline voor de installer-ISO.

Eisen:
- schone buildomgeving (container of VM);
- package-cache en download-cache;
- buildlog en sha256 als artifact;
- verify-iso.sh als verplichte stap;
- QEMU-smoketest;
- geen publicatie bij een rode test;
- secrets voor GPG en eventuele tokens.

Geef een concreet pipeline-bestand en de benodigde runner-eisen (root,
mount, chroot, KVM).
```

---

## 35 — Release voorbereiden

```text
Bereid een release voor van <DISTRO> <VERSIE>.

Lever:
- release notes (nieuw, gewijzigd, bekende problemen, upgrade-pad);
- checksums en ondertekening;
- testbewijs uit de matrix;
- een rollbackplan (snapper, vorige ISO, rescue-USB);
- een onderhoudsplan voor kernel, NVIDIA, Chrome, Quickshell en Calamares;
- een lijst met juridische aandachtspunten (proprietary codecs, Chrome,
  NVIDIA, handelsmerken).

Geen release zonder groene acceptatietest.
```

---

## 36 — Een AI-sessie afsluiten en vastleggen

```text
Vat deze sessie samen voor PLAN.md en PROMPTS.md.

Geef:
1. wat is uitgevoerd en geverifieerd;
2. welke bestanden zijn gewijzigd;
3. welke aannames en afwijkingen er waren;
4. welke tests nog openstaan;
5. een nieuwe of aangepaste prompt voor PROMPTS.md, zodat een volgende
   sessie hetzelfde werk kan herhalen.

Houd de tekst feitelijk; geen verzonnen testresultaten.
```

---

## Snelle index

| Prompt | Gebruik |
|---|---|
| 00 | Altijd als eerste |
| 01 | Nieuwe fase starten |
| 02–10 | Fase 1–9 reconstrueren of verifiëren |
| 11–12 | Fase 10–11 (thema, Snapper, updates, power) |
| 13 | Documentatie en acceptatie |
| 14–19 | Nieuwe widget, service, popup, IPC, sneltoets, thema |
| 20–24 | Debuggen |
| 25 | Testplan |
| 26 | Documentatie bijwerken |
| 27 | Review/refactor |
| 28–29 | ISO, BTRFS en snapshot-boot |
| 30–35 | Meerdere distributies, packaging, CI en release |
| 36 | Sessie vastleggen |

---

## Tips voor betere antwoorden

- Plak nooit alleen een foutmelding; geef ook het commando, de fase en wat je
  al geprobeerd hebt.
- Vraag om **één** oorzaak per keer; grote refactors verbergen regressies.
- Laat de AI eerst de relevante bestanden lezen en een plan geven.
- Eis dat elke wijziging een verificatiecommando heeft.
- Laat destructive acties (rollback, afsluiten, ISO-build) expliciet
  bevestigen.
- Bewaar nieuwe prompts onderaan dit bestand, met datum en fase.
