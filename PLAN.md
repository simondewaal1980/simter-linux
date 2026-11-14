# Plan — BSPWM + Quickshell-desktop (Debian sid)

> Dit is het werkplan en het technische logboek van de desktop. Elke fase heeft
> een **doel**, **stappen**, **verificatie** en de belangrijkste **lessen**.
> Vink af wat klaar is en werk fase voor fase naar beneden.
>
> Het project staat in `/home/simon/projecten/quickshell` en wordt gestart met
> `qs -p /home/simon/projecten/quickshell`. De installer-ISO gebruikt
> `/opt/quickshell` en maakt daarnaast een symlink vanaf
> `~/projecten/quickshell`, zodat dezelfde paden blijven werken.

**Doelomgeving:** Debian sid (forky), X11, SDDM, 1920×1080
**Kernversies:** Quickshell 0.3.2, bspwm 0.9.12, sxhkd 0.6.3, Qt 6.11
**Laatst bijgewerkt:** 14 november 2026

---

## Statusoverzicht

| Fase | Onderwerp | Status |
|---|---|---|
| 1 | Pakketten, bspwm-sessie en basisconfiguratie | klaar |
| 2 | Quickshell-skelet, thema en bar met workspaces/klok | klaar |
| 3 | BSPWM-integratie (report-parser, klikbare workspaces) | klaar |
| 4 | Weer Eindhoven | klaar |
| 5 | Systemtray | klaar |
| 6 | Notificatieserver, popups en centrum | klaar |
| 7 | Instellingenvenster voor BSPWM | klaar |
| 8 | Sneltoetsenoverzicht + definitieve sxhkdrc | klaar |
| 9 | Polijsten, optionele widgets en documentatie | klaar |
| 10 | Wallpaperbeheer, thema's en interface-schaal | klaar |
| 11 | Systeembeheer in de bar: Snapper, updates en sessiemenu | klaar |
| 12 | Documentatie, codebook en acceptatietest | klaar |
| 13 | Installer-ISO met Calamares en BTRFS | klaar — handmatig gebouwd en getest |
| 14 | Toekomst: meerdere Linux-distributies maken | leerpad / gepland |

### Laatste ISO-verificatie

De uitgebreide ISO is op 14 november 2026 handmatig gebouwd en getest. Er zijn
geen openstaande checks meer voor fase 13.

- [x] De ISO is opnieuw gebouwd (3,4 GiB,
      `quickshell-desktop-amd64.iso`) en `iso/verify-iso.sh` meldt dat alle
      controles zijn geslaagd, inclusief de zes BTRFS-subvolumes en
      `overlayroot=tmpfs:recurse=0`.
- [x] De handmatige installatie- en snapshot-boottest zijn uitgevoerd. De
      installatie gebruikt `@rootfs` met de aparte subvolumes; een snapshot
      uit het GRUB-submenu start met een tijdelijke overlay op `/`.

---

## 0. Uitgangspunten en standaardkeuzes

| Onderwerp | Default |
|---|---|
| Terminal | `alacritty` |
| Launcher | `rofi` |
| Browser | Google Chrome (ISO), Firefox als terugval |
| Thema | Donker; Material You-palet uit de wallpaper (matugen), Catppuccin Mocha als terugval |
| Extra widgets | volume, MPRIS, accu (alleen op laptop), Snapper, updates |
| Sessiemenu | eigen powermenu in de bar, met rofi-terugval |
| LXQt | blijft als fallback-sessie |
| Polkit | `lxqt-policykit-agent` uit de LXQt-fallback |
| Multi-monitor | code per scherm, getest met één scherm |
| Bestandssysteem | BTRFS met `@rootfs`, snapper en `/.snapshots` |

### Haalbaarheid (gecontroleerd)

| Onderdeel | Status |
|---|---|
| `quickshell` 0.3.2 in sid | geïnstalleerd (0.3.2-1) |
| `bspwm` 0.9.12 + `sxhkd` 0.6.3 | geïnstalleerd |
| `qs`-binary | symlink naar `quickshell` in het Debian-pakket |
| X11-sessiebestand | `/usr/share/xsessions/bspwm.desktop` |
| Qt / OpenGL | Qt 6.11, `/dev/dri` aanwezig |
| Snapper / BTRFS | aanwezig op de bronmachine en in de ISO |
| Calamares / live-build | in de ISO; native of via Debian-sid-chroot |

Quickshell 0.3.2 ondersteunt X11: `PanelWindow` gebruikt EWMH-struts
(`_NET_WM_STRUT_PARTIAL`) en blijft op alle desktops. Notificaties en tray
lopen via D-Bus.

**Bekende X11-beperkingen:**

- **Issue #290**: `aboveWindows` werkt niet altijd betrouwbaar onder bspwm;
  fullscreen kan de bar bedekken. Mitigatie: testen; noodoplossing is
  `bspc config ignore_ewmh_fullscreen enter` (kost EWMH-fullscreen voor apps).
  In deze sessie bleef de bar zichtbaar boven fullscreen.
- **Issue #794**: `PopupWindow` vraagt onder X11 geen toetsenbordfocus. Daarom
  zijn instellingen, sneltoetsen, wallpapers en het momentopname-formulier
  `FloatingWindow`s; popups bevatten geen tekstinvoer.
- Een klik buiten een popup wordt onder X11 niet gedetecteerd. Popups sluiten
  via de X-knop, een tweede klik op de widget, een klik op de bar of IPC.

---

## 1. Architectuur

```text
SDDM → bspwm-sessie
└── bspwm (X11, EWMH)
    ├── sxhkd ─────────────► bspc / qs ipc / applicaties
    ├── picom (optioneel) ──► transparantie, schaduwen
    ├── wallpaper-theme.sh ─► feh + matugen + qt6ct
    └── qs -p ~/projecten/quickshell
        ├── Bar (PanelWindow per scherm, struts)
        │   ├── workspaces + layoutindicator
        │   ├── actief venster
        │   ├── klok
        │   ├── weer Eindhoven ← Open-Meteo
        │   ├── Snapper-teller ← snapper --jsonout
        │   ├── updates-teller ← apt + flatpak
        │   ├── MPRIS / volume / accu
        │   ├── notificatiebel + DND
        │   ├── tray ← StatusNotifierItem/DBusMenu
        │   └── knoppen: sneltoetsen, wallpapers, instellingen, power
        ├── NotificationServer + popups + notificatiecentrum
        ├── SettingsWindow (FloatingWindow) ── bspc config
        ├── ShortcutsWindow (FloatingWindow) ← sxhkdrc-parser
        ├── WallpaperWindow (FloatingWindow) ← Wallpaper-service
        ├── SnapperCreateWindow (FloatingWindow)
        ├── popups: weer, Snapper, updates, powermenu
        └── IPC: bar, settings, shortcuts, notifications, weather, snapper,
                 updates, wallpaper, power, bspwm, tray
```

**Eén bron van waarheid:**

- `~/.config/bspwm/settings.json` voor BSPWM-instellingen, kleuren,
  `ui.scale` en `ui.bar_opacity`. Quickshell schrijft dit bestand en past
  wijzigingen direct toe met `bspc config`. `bspwmrc` past het bij elke
  (her)start opnieuw toe via `scripts/apply-bspwm-settings.sh`.
- `~/.config/bspwm/theme.generated.json` voor het volledige wallpaper-palet.
  `Theme.qml` leest dit live; de BSPWM-randkleuren worden uit dezelfde bron
  in `settings.json` bijgewerkt.
- `~/.config/sxhkd/sxhkdrc` voor alle sneltoetsen én het overzicht. Er is geen
  tweede keybindinglijst.
- `~/.config/bspwm/wallpaper` voor de actieve wallpaper; het wallpapervenster
  en `Super+W` gebruiken hetzelfde script.

---

## 2. Bestandsstructuur

```text
/home/simon/projecten/quickshell/
├── PLAN.md                      # dit bestand
├── PROMPTS.md                   # promptbibliotheek voor later gebruik
├── README.md                    # installatie, gebruik, troubleshooting
├── shell.qml                    # root: bars, vensters, services, IPC
├── .gitignore                   # o.a. .qmlls.ini, iso/build, iso/cache
├── src/
│   ├── theme/
│   │   ├── Theme.qml            # singleton: settings + wallpaper-palet
│   │   └── qmldir
│   ├── services/
│   │   ├── Bspwm.qml            # report-parser + commando's
│   │   ├── BspwmSettings.qml    # in-memory state + opslaan
│   │   ├── Weather.qml          # Open-Meteo + cache
│   │   ├── NotificationDaemon.qml
│   │   ├── Snapper.qml          # btrfs-momentopnamen
│   │   ├── Updates.qml          # APT + Flatpak
│   │   ├── Wallpaper.qml        # lijst, toepassen, toevoegen, verwijderen
│   │   ├── Power.qml            # sessieacties
│   │   └── qmldir
│   ├── components/
│   │   ├── Bar.qml
│   │   ├── Workspaces.qml
│   │   ├── ActiveWindow.qml
│   │   ├── Clock.qml
│   │   ├── WeatherWidget.qml
│   │   ├── SnapperWidget.qml
│   │   ├── UpdatesWidget.qml
│   │   ├── MprisWidget.qml
│   │   ├── VolumeWidget.qml
│   │   ├── BatteryWidget.qml
│   │   ├── NotificationBell.qml
│   │   ├── TrayWidget.qml
│   │   └── Keycap.qml
│   ├── popups/
│   │   ├── WeatherPopup.qml
│   │   ├── NotificationStack.qml
│   │   ├── NotificationCenter.qml
│   │   ├── SnapperPopup.qml
│   │   ├── UpdatesPopup.qml
│   │   └── PowerMenu.qml
│   ├── windows/
│   │   ├── SettingsWindow.qml
│   │   ├── ShortcutsWindow.qml
│   │   ├── WallpaperWindow.qml
│   │   └── SnapperCreateWindow.qml
│   └── utils/
│       ├── ReportParser.js
│       ├── SxhkdParser.js
│       └── WeatherCodes.js
├── scripts/
│   ├── apply-bspwm-settings.sh
│   ├── apply-wallpaper-theme.sh
│   ├── apply-qt-theme.sh
│   ├── wallpaper-theme.sh
│   ├── install-qt6ct-user.sh
│   ├── setup-snapper-access.sh
│   ├── setup-snapshot-boot.sh
│   ├── download-greek-wallpapers.sh
│   ├── lock-session.sh
│   ├── powermenu.sh
│   ├── test-fase1-nested.sh
│   └── test-notifications.sh
├── config/
│   ├── bspwm/                   # bspwmrc, settings.default.json
│   ├── sxhkd/sxhkdrc
│   ├── picom/picom.conf
│   ├── rofi/config.rasi
│   ├── alacritty/alacritty.toml
│   ├── qt6ct/qss/quickshell.qss
│   └── matugen/                 # config.toml + templates
├── docs/
│   ├── keybindings.md
│   ├── wallpaper-credits.md
│   ├── codebook.html
│   └── screenshot-*.png
└── iso/
    ├── build.sh
    ├── verify-iso.sh
    ├── test-qemu.sh
    ├── live-build/
    ├── calamares/
    ├── overlay/
    ├── vendor/
    └── out/                     # ISO + sha256 (niet in git)
```

**Deployment:** de repo blijft de bron. `~/.config/bspwm/bspwmrc`,
`~/.config/sxhkd/sxhkdrc`, de scripts en de themaconfiguratie worden
symlinks naar de repo. Quickshell start met
`qs -p /home/simon/projecten/quickshell`, dus er is geen kopieer- of
installatiestap. Alleen `settings.json` is een gebruikerskopie die Quickshell
zelf schrijft.

---

## 3. Werkwijze per fase

Elke fase doorloopt dezelfde cyclus:

1. **Lezen** — lees het doel en de verificatie van de fase.
2. **Uitvoeren** — voer de stappen uit; wijzig bij voorkeur één oorzaak per
   keer.
3. **Verifiëren** — gebruik de genoemde commando's en controleer het gedrag in
   een echte of geneste sessie.
4. **Vastleggen** — noteer afwijkingen en lessen onder de fase, zodat een
   volgende sessie niet opnieuw tegen hetzelfde probleem aanloopt.
5. **Afvinken** — pas daarna de checkbox en het statusoverzicht aan.

**Conventies:**

- Elke wijziging in de bron wordt getest met `qs -p …` of een geneste Xephyr;
  destructieve tests (afsluiten, rollback) alleen na een expliciete check.
- Shellscripts worden met `sh -n` gecontroleerd.
- QML-fouten staan in `/tmp/quickshell-$USER.log`.
- IPC gebruikt altijd `-p /home/simon/projecten/quickshell`; zonder `-p`
  vindt de client de draaiende instantie niet.
- Nieuwe paden of instellingen komen in `README.md` én in dit plan.

---

## Fase 1 — Pakketten, bspwm-sessie en basisconfiguratie

**Doel:** een werkende bspwm-sessie met sxhkd, wallpaper en de
mapstructuur. Quickshell hoeft nog niet te werken.
**Status:** klaar.

### Stappen

- [x] Pakketten installeren:

  ```bash
  sudo apt update
  sudo apt install quickshell bspwm sxhkd jq curl xdotool \
    fonts-jetbrains-mono fonts-font-awesome papirus-icon-theme \
    picom feh rofi maim slop alacritty qt6ct \
    network-manager-applet blueman pavucontrol playerctl brightnessctl \
    pulseaudio-utils snapper btrfs-progs
  ```

- [x] Optioneel voor genest testen: `sudo apt install xserver-xephyr`.
- [x] Mapstructuur en `git init` met `.gitignore`.
- [x] `config/bspwm/bspwmrc` met `settings.json`, desktops 1–9, sxhkd,
      wallpaper/thema, picom en Quickshell.
- [x] `config/bspwm/settings.default.json` met startwaarden.
- [x] `scripts/apply-bspwm-settings.sh` leest `settings.json` met `jq` en past
      `bspc config`, padding en kleuren toe.
- [x] Symlinks voor `bspwmrc`, `apply-settings.sh`, `settings.default.json`,
      `sxhkdrc` en `picom.conf`.
- [x] Eerste `config/sxhkd/sxhkdrc`.
- [x] Wallpaper op `~/Pictures/wallpaper.jpg`.
- [x] Inloggen via SDDM met de **bspwm**-sessie (LXQt blijft fallback).

### Verificatie

- [x] `bspc query -M --names` geeft de monitor.
- [x] `pgrep -x bspwm`, `sxhkd` en `picom` draaien.
- [x] `Super+Return` en `Super+d` werken.
- [x] `bspc config window_gap` geeft de waarde uit `settings.json`.
- [x] `bspc wm -r` behoudt de instellingen.

### Belangrijke lessen

- Testen in een geneste Xerver (Xephyr op `:1`) laat de echte sessie met rust;
  `scripts/test-fase1-nested.sh` doet dit opnieuw.
- `xdotool key` zonder `--clearmodifiers` is nodig om synthetische
  Super-combinaties door sxhkd te laten oppakken.
- picom staat op deze VM op `xrender`, `vsync = false` en
  `xrender-sync-fence = true`; de GLX-backend trok meer dan 300% CPU.
- bspwm 0.9.12 geeft exitcode 1 als je een boolean op dezelfde waarde zet;
  `apply-bspwm-settings.sh` vergelijkt daarom eerst.
- Geldige sleutelnamen: `presel_feedback_color`, `pointer_modifier mod4`,
  `ignore_ewmh_fullscreen none|all|enter|exit`.

**Klaar als:** bspwm, sxhkd, wallpaper en picom draaien en de JSON-instellingen
bij herstart worden toegepast.

---

## Fase 2 — Quickshell-skelet, thema en bar met workspaces/klok

**Doel:** Quickshell draait met een bar die via struts ruimte reserveert en
workspaces + klok toont.
**Status:** klaar.

### Stappen

- [x] `shell.qml` met `ShellRoot`, `Variants { model: Quickshell.screens }` en
      één `Bar` per scherm.
- [x] `src/theme/Theme.qml` (singleton) + `qmldir`; leest
      `~/.config/bspwm/settings.json` met `FileView` en `JsonAdapter`.
- [x] `src/components/Bar.qml`: `PanelWindow`, ±34 px hoog, drie ankers,
      automatische `exclusiveZone`, `aboveWindows: true`, `focusable: false`.
- [x] Indeling: links workspaces (eerst statisch), midden klok/datum, rechts
      tijdelijke iconen.
- [x] `src/components/Clock.qml` met `SystemClock`.
- [x] IPC-handlers `bar reload` en `bar toggle`.
- [x] `.qmlls.ini` voor editor/LSP.

### Verificatie

- [x] `qs -p ~/projecten/quickshell` start zonder fouten; de bar staat boven.
- [x] `xprop -id <bar-window> _NET_WM_STRUT_PARTIAL` toont de strut; bspwm
      vertaalt die naar `padding.top` van de monitor.
- [x] Een getiled venster overlapt de bar niet.
- [x] Fullscreen: de bar blijft zichtbaar.
- [x] `qs ipc show` toont de handlers.

### Belangrijke lessen

- De strut staat op het Quickshell-paneelvenster, niet op de root. Controleer
  met `xprop -id <bar-window>` of `bspc query -T -m`, niet met
  `xprop -root`.
- `JsonAdapter` is reactief zonder bindingslus; een kleurwijziging in
  `settings.json` werkt direct door.
- `Qt.formatDateTime()` volgde de C-locale; de datum gebruikt daarom
  `Date.toLocaleDateString(Qt.locale("nl_NL"), …)`.
- Workspaces zijn in deze fase bewust nog statisch; fase 3 koppelt ze aan
  `bspc subscribe report`.

**Klaar als:** de bar stabiel draait, struts kloppen en de klok loopt.

---

## Fase 3 — BSPWM-integratie

**Doel:** live workspaces, layoutindicator en een venstertitel in de bar.
**Status:** klaar.

### Stappen

- [x] `src/services/Bspwm.qml`:
  - [x] `bspc wm -g` bij startup.
  - [x] `Process { command: ["bspc", "subscribe", "report"] }` met
        `SplitParser`.
  - [x] `src/utils/ReportParser.js` parseert `M/m`, `O/o`, `F/f`, `U/u`,
        `L(T|M)`, `T(...)`, `G(...)`.
  - [x] Properties: `monitors`, `desktops`, `focusedDesktop`, `layout`,
        `activeNodeState`, `activeNodeFlags`.
  - [x] Commando's: `focusDesktop`, `focusNext/Prev`, `toggleLayout`.
  - [x] Foutpad: "bspwm niet actief" als `bspc` ontbreekt of faalt.
- [x] `Workspaces.qml`: 1–9, focus/bezet/urgent, layoutindicator, klikken en
      scrollen.
- [x] `ActiveWindow.qml`: titel van de gefocuste node, verversen op
      `node_focus` en een poll van 5 s.
- [x] Werkt ook zonder bspwm (LXQt).

### Verificatie

- [x] Desktop wisselen via toetsen en via de bar.
- [x] Een venster openen/sluiten kleurt de juiste workspace.
- [x] Urgent-hint via ICCCM `WM_HINTS` op een niet-gefocuste desktop.
- [x] Layout wisselen toont M/T.
- [x] `bspc wm -r` laat de bar herstarten of opnieuw verbinden.

### Belangrijke lessen

- Het report begint met de status_prefix (`W`) en de eerste monitor. Per
  monitor volgen de desktops, één `L(T|M)` en alleen bij een gefocuste node
  `T(...)` en `G(...)`. Ontbreken die, dan is de desktop leeg.
- `T@` is een receptacle zonder client. `G` gebruikt S=sticky, P=private,
  L=locked, M=marked.
- `bspc desktop -f <monitor>:<naam>` is geen geldige selector;
  `monitor:^n` (de n-de desktop) wel. De bar geeft daarom de index mee.
- `bspc node -g urgent` bestaat niet in 0.9.12; urgentie komt extern via
  `WM_HINTS`.
- `xdotool getactivewindow` geeft op een lege desktop soms een verborgen
  venster terug. ActiveWindow vraagt daarom eerst
  `bspc query -N -n focused`.
- Als `bspc subscribe report` stopt, zet de service `available` op false en
  probeert elke 5 s opnieuw verbinding te maken.
- Diagnostiek: `qs ipc call bspwm status` geeft de volledig geparseerde status.

**Klaar als:** de bar de BSPWM-status foutloos en zonder merkbare vertraging
volgt.

---

## Fase 4 — Weer Eindhoven

**Doel:** actueel weer met driedaagse verwachting, cache en foutafhandeling.
**Status:** klaar.

### Stappen

- [x] `Weather.qml`: Open-Meteo met `curl -fsS --max-time 10`, timer van
      10 minuten, retry na 60 s, cache in
      `Quickshell.cachePath("weather-eindhoven.json")`.
- [x] `WeatherCodes.js`: WMO-code → Nederlandse tekst + Font Awesome-icoon.
- [x] `WeatherWidget.qml`: icoon + temperatuur; foutstatus "—".
- [x] `WeatherPopup.qml`: gevoelstemperatuur, vocht, wind, neerslagkans,
      min/max, drie dagen en "laatst bijgewerkt".

### Verificatie

- [x] Temperatuur komt overeen met een externe bron.
- [x] Na 10 minuten of handmatige refresh verandert de data.
- [x] Netwerk uitschakelen → laatst bekende waarde + tijd blijft zichtbaar.
- [x] Een `curl`-fout geeft geen QML-fouten of crash.

### Belangrijke lessen

- De cache bewaart `{ "fetchedAt": <epoch-ms>, "response": <ruwe JSON> }`.
  Bij het starten leest `blockLoading` de cache synchroon.
- De endpoint gebruikt `forecast_days=4` (vandaag + 3 dagen).
- Een klik buiten de popup wordt onder X11 niet gedetecteerd; de popup sluit
  via de X, een tweede klik op de widget, een klik op de bar of IPC.
- `weather status` toont alle genormaliseerde velden, fout, cachepad en
  laatst-bijgewerkt; `weather refresh` forceert een fetch.
- Offline getest met `WEATHER_ENDPOINT=http://127.0.0.1:9/forecast`.

**Klaar als:** het weer betrouwbaar is, ook zonder netwerk, en de popup alle
gewenste informatie toont.

---

## Fase 5 — Systemtray

**Doel:** StatusNotifierItem-iconen met werkende menu's.
**Status:** klaar.

### Stappen

- [x] `TrayWidget.qml` met `SystemTray.items` en een `Repeater`.
- [x] `Image { source: item.icon }` met fallback-icoon.
- [x] Klik → `activate()`; middenklik → `secondaryActivate()`;
      scroll → `scroll(delta, horizontal)`.
- [x] Menu → `item.display(barWindow, x, y)`; fallback `QsMenuAnchor`.
- [x] Tooltip met `tooltipTitle` / `tooltipDescription`.
- [x] Alleen tonen als er items zijn.

### Verificatie

- [x] `nm-tray` of een tijdelijke fake-SNI verschijnt.
- [x] Menu opent op de juiste positie en is bruikbaar.
- [x] App sluiten → icoon verdwijnt.
- [x] Tooltip toont de juiste tekst.

### Belangrijke lessen

- Alleen SNI wordt ondersteund; legacy XEmbed (zoals `nm-applet` op deze
  build) verschijnt niet. `nm-tray` (Qt/SNI) werkt wel.
- Voor tray-menu's is `//@ pragma UseQApplication` boven aan `shell.qml`
  nodig; zonder die pragma weigert Quickshell platformmenu's.
- `anchor.item` werkte in 0.3.2 niet betrouwbaar. Gebruik
  `anchor.window` + `anchor.rect` met venstercoördinaten.
- De tooltip is een aparte `PopupWindow` met 350 ms vertraging en verdwijnt
  bij het verlaten van het icoon, een menu, een verborgen bar of een
  verdwijnend tray-item.
- Testen kan met een eigen Xephyr en `dbus-run-session`, zodat de echte
  sessie ongemoeid blijft.

**Klaar als:** gangbare SNI-apps verschijnen en hun menu's werken.

---

## Fase 6 — Notificatieserver

**Doel:** Quickshell is de enige notificatiedaemon, met popups, geschiedenis,
acties en DND.
**Status:** klaar.

### Stappen

- [x] `NotificationDaemon.qml` met `NotificationServer`:
      `actionsSupported: true`, `imageSupported: true`,
      `bodyMarkupSupported: false`, `keepOnReload: true`.
- [x] Inkomende melding: `tracked = true`; geschiedenis max. 50; DND-state;
      badge-teller.
- [x] `NotificationStack.qml`: één `PopupWindow` rechtsboven, max. 4 kaarten,
      app-icoon, acties, sluitknop en time-out.
- [x] `NotificationCenter.qml`: geschiedenis, "wis alles", per-item sluiten.
- [x] `NotificationBell.qml`: bel + DND-schakelaar + badge.
- [x] `lxqt-notificationd` start niet in de bspwm-sessie; logwaarschuwing bij
      een D-Bus-conflict.
- [x] Popups zonder `grabFocus`.

### Verificatie

- [x] `scripts/test-notifications.sh` toont een popup met de juiste app-info.
- [x] Critical blijft staan.
- [x] Een actieknop werkt.
- [x] DND aan → geen popups, wel geschiedenis en badge.
- [x] `notifications clear` en `notifications dnd true` werken.
- [x] Herladen behoudt notificaties (`keepOnReload`).

### Belangrijke lessen

- Elke melding moet `tracked = true` krijgen, anders ruimt de server het
  object direct op.
- Quickshell 0.3.2 levert `expireTimeout` in **milliseconden**, ook al zegt de
  documentatie seconden. Kritiek nooit automatisch, `0` nooit, `-1` is de
  standaardkeuze (laag 4 s, normaal 8 s).
- Onder X11 krijgt een popup geen leave-event als de muis naar een ander
  venster gaat. De stack pollt daarom elke 250 ms
  `xdotool getmouselocation --shell` zolang een popup met time-out zichtbaar
  is. Zonder `xdotool` werkt de time-out, maar zonder hover-pauze.
- De conflictcontrole vraagt 1,2 s na de start de PID van de eigenaar van
  `org.freedesktop.Notifications` op en vergelijkt die met
  `Quickshell.processId`.
- Zonder Qt-platformthema resolven app-icoonnaamnamen niet; de popups vallen
  dan terug op de bel. Met `QT_QPA_PLATFORMTHEME=qt6ct` (of `gtk3`) werkt het
  icoonthema wel.
- `scripts/test-notifications.sh basic|critical|action|all` gebruikt `gdbus`
  en is de vervanger van `notify-send` als dat niet geïnstalleerd is.

**Klaar als:** notificaties volledig via Quickshell lopen en er geen andere
daemon actief is.

---

## Fase 7 — Instellingenvenster voor BSPWM

**Doel:** gaps, randen, layouts, kleuren, gedrag en de interface-schaal live
aanpassen en persistent opslaan.
**Status:** klaar.

### Stappen

- [x] `BspwmSettings.qml`: `settings.json` lezen (`FileView`,
      `blockLoading`), wijzigingen direct toepassen met `bspc config`
      (120 ms debounce), opslaan met 500 ms debounce (atomair) en `reset()`
      naar `settings.default.json`.
- [x] `SettingsWindow.qml` als `FloatingWindow`.
- [x] Tabs:
  - [x] **Gaps & randen**: `window_gap`, `border_width`, per-monitor padding,
        monocle-opties.
  - [x] **Lay-outs**: `tiled`/`monocle`, `automatic_scheme`,
        `initial_polarity`, `split_ratio`, rotate/flip/balance/equalize/
        circulate, `single_monocle`, `borderless_singleton`.
  - [x] **Kleuren & thema**: focused/normal/active/presel, hex-invoer en
        acht presets.
  - [x] **Gedrag**: focus/pointer-opties, `ignore_ewmh_fullscreen`,
        `remove_unplugged_monitors`, `merge_overlapping_monitors`.
  - [x] **Weergave**: `ui.scale` (80–150%) en `ui.bar_opacity` (0,3–1,0).
  - [x] **Info/acties**: versies, paden, BSPWM herstarten, sxhkd herladen,
        Quickshell herladen.
- [x] Waarschuwing in de UI: bar-struts + bspwm-padding kunnen dubbel ruimte
      innemen; standaard padding 0.
- [x] IPC `settings open|close|toggle|status|reset|setGap|setBorder|setColor|
      setScale|setBarOpacity|save`.
- [x] Koppeling met de bar: tandwiel opent het venster; kleurwijzigingen
      werken direct door in `Theme`.
- [x] Layout opslaan/herstellen met `bspc wm -d` / `bspc wm -l`.

### Verificatie

- [x] `Super+Shift+S` en het tandwiel openen het venster; toetsenbordfocus
      werkt.
- [x] Gaps/randen wijzigen is direct zichtbaar.
- [x] Een kleur wijzigen verandert zowel BSPWM-randen als de bar.
- [x] Na `bspc wm -r` zijn alle waarden behouden.
- [x] "Standaardwaarden" herstelt de default-JSON.
- [x] Layoutknoppen werken op de gefocuste desktop.
- [x] `setScale 125` en `setBarOpacity 85` werken via IPC.

### Belangrijke lessen

- `BspwmSettings` heeft bewust géén `watchChanges`: een watcher kon vlak na
  een eigen atomaire schrijfactie de oude inhoud inlezen en de zojuist
  gezette waarde terugdraaien. `Theme.qml` houdt wel een watcher, want die
  schrijft nooit.
- Sliders coalesceren gelijke `bspc`-commando's; het bestand wordt 500 ms later
  atomair geschreven.
- Quickshell 0.3.2 zet onder X11 geen `WM_CLASS` op een `FloatingWindow`.
  `bspwmrc` matcht daarom op venstertitels:
  `bspc rule -a '*:*:BSPWM-instellingen' state=floating center=on`, met
  dezelfde regels voor `Sneltoetsen`, `Wallpapers` en
  `Nieuwe momentopname`.
- `settings.json` is een gebruikerskopie, geen symlink; de repo blijft de bron
  voor `settings.default.json` en de scripts.

**Klaar als:** alle gevraagde BSPWM-instellingen via de GUI te wijzigen zijn,
live werken en een herstart overleven.

---

## Fase 8 — Sneltoetsenoverzicht + definitieve sxhkdrc

**Doel:** een doorzoekbaar overzicht dat exact de sxhkdrc volgt, plus een
complete sneltoetsenset en een editor voor eigen bindingen.
**Status:** klaar.

### Stappen

- [x] `SxhkdParser.js`: comments, hotkeys, ingesprongen commando's,
      regelcontinutie (`\`), chord-chains (`;`/`:`), brace-expansie.
- [x] Conventie: comment direct boven een hotkey = omschrijving;
      `# --- Sectie ---` = groepskop.
- [x] `ShortcutsWindow.qml` als `FloatingWindow`:
  - [x] `FileView` op `~/.config/sxhkd/sxhkdrc` met `watchChanges`.
  - [x] Zoekveld, keycaps, commando in monospace.
  - [x] Groepen: Algemeen, Vensters, Workspaces, Layout, Preselect,
        Quickshell, Media, Screenshots, Sessie.
- [x] IPC `shortcuts open|close|toggle|status|list|add|update|remove|reload`.
- [x] Bar-icoon + `Super+/`.
- [x] Formulier "Nieuwe sneltoets" met toetsen, omschrijving, groep en
      commando; eigen blokken achteraan de sxhkdrc met `@qs-shortcut`-marker.
- [x] Na opslaan: atomaire schrijfactie, directe parse en
      `pkill -USR1 sxhkd`.
- [x] `config/sxhkd/sxhkdrc` afmaken; elke hotkey heeft een comment.

### Verificatie

- [x] `Super+/` opent het overzicht; alle bindingen zijn gegroepeerd.
- [x] Zoeken op "terminal", "workspace" en "Super+Shift" filtert correct.
- [x] Een hotkey toevoegen + `pkill -USR1 sxhkd` → overzicht werkt bij.
- [x] Alle sneltoetsen uit de tabel zijn getest.
- [x] `qs ipc call shortcuts toggle` werkt.
- [x] Een eigen binding toevoegen, bewerken en verwijderen werkt.

### Belangrijke lessen

- Brace-groepen in de hotkey en het commando worden parallel uitgeklopt als de
  groepen even groot zijn; dat is nodig voor `{h,j,k,l}` +
  `{west,south,north,east}` en `{1-9}` + `'^{1-9}'`. Bereiken en `_` worden
  ook ondersteund.
- Een symlink geeft onder X11 niet altijd een change-event; de window doet bij
  openen daarom expliciet `reload()` + een korte timer.
- De sxhkdrc gebruikt `qs -p "$HOME/projecten/quickshell" ipc call …`; zonder
  `-p` gebeurt er niets.
- Afwijkingen van het oorspronkelijke plan: vergrendelen is `Super+Alt+L`
  (niet `Super+Shift+L`), BSPWM afsluiten `Super+Alt+E`, balanceren
  `Super+Shift+Space` (niet `Super+Shift+B`, dat is de browser).
- Screenshots: `Print` → `~/Pictures/screenshots`, `Shift+Print` → regio via
  `slop`, `Super+Print` → actief venster.
- Het overzicht parseert het bestand zelf; `docs/keybindings.md` is alleen een
  momentopname.

**Klaar als:** het overzicht en de sxhkdrc aantoonbaar dezelfde bron zijn en
alle sneltoetsen werken.

---

## Fase 9 — Polijsten en optionele widgets

**Doel:** afronden, extras en een dagelijks bruikbare desktop.
**Status:** klaar.

### Stappen

- [x] `VolumeWidget`: PipeWire via Quickshell, met `pactl`-terugval.
- [x] `BatteryWidget`: UPower, alleen zichtbaar bij een echte accu.
- [x] `MprisWidget`: eerste speler met een nummer.
- [x] Polkit-agent: `lxqt-policykit-agent` via `bspwmrc`.
- [x] Optionele watchdog voor Quickshell in `bspwmrc`
      (`QUICKSHELL_WATCHDOG=1`, pidfile in `/tmp`).
- [x] Thema-presets uitgebreid naar acht en picom afgestemd op de VM-GPU.
- [x] Rofi-thema met dezelfde kleuren als de bar.
- [x] `README.md`, `docs/keybindings.md`, screenshots en acceptatietest.

### Verificatie

- [x] Volume en accu (indien aanwezig) werken en verversen live.
- [x] `qs -p …` start schoon na een volledige logout/login.
- [x] README is genoeg om de installatie opnieuw te doen.
- [x] Alle acceptatiecriteria zijn afgevinkt.

### Belangrijke lessen

- Deze VM draait PulseAudio zonder PipeWire-daemon; de terugval via `pactl` is
  live getest. Zodra PipeWire beschikbaar is, schakelt de widget automatisch en
  stopt het pollen.
- `BatteryWidget` blijft onzichtbaar zonder accu; `MprisWidget` zonder speler.
- `lxpolkit` werkte niet met polkit 128 (GTK-agent crashte);
  `lxqt-policykit-agent` werkt wel en moet in de grafische sessie draaien.
- De watchdog staat standaard uit, zodat een crash niet eindeloos wordt
  gemaskeerd.
- Op deze VM ontbreken een echte accu, een backlight en een locker; de
  widgets/scripts degraderen zichtbaar en veilig.

**Klaar als:** de desktop dagelijks bruikbaar is en de documentatie compleet is.

---

## Fase 10 — Wallpaperbeheer, thema's en interface-schaal

**Doel:** één donker thema dat de wallpaper volgt, wallpaperbeheer in de GUI
en een schaalbare interface.
**Status:** klaar.

### Stappen

- [x] matugen 4.2.0 user-local in `~/.local/bin` (niet in Debian).
- [x] `config/matugen/config.toml` + templates voor Quickshell, GTK 3/4,
      alacritty en rofi; donkere modus, bronkleur = wallpaper.
- [x] `scripts/wallpaper-theme.sh`: wallpaper zetten (feh), palet genereren,
      Adwaita-dark + Papirus-Dark activeren en `settings.ini` schrijven.
- [x] `scripts/apply-wallpaper-theme.sh` (post-hook): BSPWM-kleuren overnemen
      in `settings.json` en direct toepassen met `bspc`.
- [x] `Theme.qml` leest `theme.generated.json` met `watchChanges`;
      Catppuccin Mocha blijft de terugval.
- [x] alacritty importeert de gegenereerde kleuren; rofi importeert
      `colors.rasi`; GTK krijgt `@define-color`-overschrijvingen.
- [x] `qt6ct` als Qt-platformplugin (`Fusion`), geactiveerd met
      `QT_QPA_PLATFORMTHEME=qt6ct`; `gtk3` is de terugval.
- [x] `scripts/apply-qt-theme.sh` schrijft het volledige QPalette (22 rollen,
      inclusief `Accent`) en de qt6ct-configuratie met JetBrains Mono 10,5 pt
      en Papirus-Dark.
- [x] `config/qt6ct/qss/quickshell.qss`: 6px-hoeken, surface-hovers,
      accent-onderstreping, slanke schuifbalken, menu's en tooltips.
- [x] `scripts/install-qt6ct-user.sh`: fallback zonder sudo naar
      `~/.local/opt/qt6ct`.
- [x] `WallpaperWindow.qml`: previews, toepassen, volgende, toevoegen via een
      ingebouwde bestandsbrowser en verwijderen.
- [x] `Wallpaper.qml`: lijst uit `~/Pictures/wallpaper.jpg` en
      `~/Pictures/Wallpapers/`; toepassen via hetzelfde script; actieve keuze
      in `~/.config/bspwm/wallpaper`.
- [x] `scripts/download-greek-wallpapers.sh` voor tien Griekse wallpapers;
      credits in `docs/wallpaper-credits.md`.
- [x] `ui.scale` (0,8–1,5) en `ui.bar_opacity` (0,3–1,0) in
      `settings.default.json`, `Theme.qml`, het instellingenvenster en IPC.
- [x] `Super+Shift+W` en het afbeeldingsicoon openen het wallpapervenster.

### Verificatie

- [x] `scripts/wallpaper-theme.sh` → exit 0; `theme.generated.json` is geldige
      JSON met `palette` en `bspwm`.
- [x] `bspc config focused_border_color` = `colors.focused` =
      `palette.blue`.
- [x] Bar-screenshot toont het nieuwe palet.
- [x] `gsettings get … color-scheme` = `prefer-dark`.
- [x] rofi en alacritty parseren de gegenereerde bestanden.
- [x] PyQt6-testvenster: `qt6ct-style`, JetBrains Mono 10.5, juiste
      Window/Base/Highlight-kleuren.
- [x] qterminal en pcmanfm-qt tonen het donkere palet in een geneste Xephyr.
- [x] Zonder `theme.generated.json` blijft Catppuccin werken.
- [x] Wallpaper toepassen, toevoegen en verwijderen werkt; de actieve
      wallpaper kan niet verwijderd worden.

### Belangrijke lessen

- Base16-uitvoer van matugen werd bij deze donkere gradient bijna zwart.
  Daarom gebruikt het template `[config.custom_colors]` (`term_red`,
  `term_green`, …); matugen harmoniseert die met de bronkleur.
- Twee kleurbronnen, één richting: het volledige palet staat in
  `theme.generated.json`, terwijl `settings.json` de bron blijft voor `bspc`
  en het instellingenvenster. De post-hook schrijft alleen de vier
  BSPWM-kleuren over.
- De post-hook roept bewust **niet** `apply-settings.sh` aan: dat zet de
  monitor-padding op 0 en zou de gereserveerde ruimte van de bar-strut wissen.
- De wallpaper wordt met `feh --bg-fill` gezet; de bar hoeft niet te
  herstarten, want `Theme` herlaadt via `watchChanges`, ook na de atomaire
  `mv`.
- qt6ct schrijft `QPalette::ColorRole` in enumvolgorde. `NoRole` (index 17)
  wordt gevuld maar genegeerd. Het font staat gequote in `qt6ct.conf`, anders
  leest QSettings het als QStringList.
- De QSS bevat geen vaste hexkleuren; alleen het gegenereerde QPalette
  verandert per wallpaper.
- Bestaande Qt-vensters nemen het nieuwe palet pas over na een herstart;
  nieuwe vensters direct.

**Klaar als:** een nieuwe wallpaper binnen een seconde de bar, BSPWM-randen,
terminal, rofi, GTK- en Qt-apps in het bijpassende donkere palet zet.

---

## Fase 11 — Systeembeheer in de bar: Snapper, updates en sessiemenu

**Doel:** momentopnamen, updates en sessieacties vanuit de bar beheren.
**Status:** klaar.

### Stappen

- [x] `Snapper.qml`: configuraties en momentopnamen via
      `snapper --jsonout list-configs` en `snapper --jsonout list`,
      normalisatie, verversing elke 2 minuten, fout- en toegangspaden.
- [x] `SnapperWidget.qml`: icoon + aantal in de bar.
- [x] `SnapperPopup.qml`: configuratiekeuze, lijst (nieuwste eerst), type,
      datum, gebruiker, beschrijving, aanmaken, verwijderen, opruimen en
      rollback.
- [x] Opruimen verwijdert de oudste momentopnamen tot er maximaal 10 over
      blijven; standaard- en actieve momentopnamen blijven beschermd.
- [x] Rollback per momentopname met bevestiging en waarschuwing dat de
      wijziging pas na een herstart actief wordt.
- [x] `SnapperCreateWindow.qml` als `FloatingWindow` met beschrijvingsveld.
- [x] Mutaties via `pkexec` als de gebruiker alleen leesrechten heeft;
      `SNAPPER_ELEVATE` maakt dat commando configureerbaar.
- [x] `scripts/setup-snapper-access.sh`: eenmalige root-handeling die
      `ALLOW_USERS` en `SYNC_ACL` zet en de ACL van `.snapshots` controleert.
- [x] `Updates.qml`: APT (`apt list --upgradable`) en Flatpak
      (`flatpak remote-ls --updates`), 30-minutencontrole, per bron een lijst
      en een bijwerkactie.
- [x] `UpdatesWidget.qml` en `UpdatesPopup.qml`: aantal, lijst per bron, oude
      en nieuwe versie, verversknop en "Bijwerken" met tweede klik.
- [x] Expliciete verversing draait eerst `pkexec apt-get update` en leest
      daarna opnieuw; openen van de popup leest alleen de bestaande index.
- [x] Bijwerken gebruikt `apt-get -y full-upgrade` (voor nieuwe
      dependencies/vervangingen) en daarna `flatpak update`.
- [x] `Power.qml` + `PowerMenu.qml`: afmelden, vergrendelen, slapen,
      herstarten en afsluiten; `Super+Shift+P` en de aan/uit-knop.
- [x] `scripts/powermenu.sh` als rofi-terugval als de bar niet draait.
- [x] IPC: `snapper …`, `updates …`, `power …`.

### Verificatie

- [x] Met een fake-snapper zijn laden, configuratie wisselen, aanmaken,
      verwijderen, opruimen en rollback getest.
- [x] Met de echte snapper verscheen zonder `ALLOW_USERS` de toegangsfout
      zonder QML-fouten; de popup toont het setup-commando.
- [x] `scripts/setup-snapper-access.sh` is met `sh -n` gecontroleerd.
- [x] `updates status`, `updates refresh` en `updates update` zijn via IPC
      getest; de verversknop vraagt om bevoegdheid, de periodecontrole niet.
- [x] De powermenu-acties zijn via de service en het menu getest;
      vergrendelen toont een melding als er geen locker is.

### Belangrijke lessen

- Lezen werkt alleen als de gebruiker in `ALLOW_USERS` staat en toegang heeft
  tot `.snapshots`; anders valt de service terug op `pkexec`.
- Een rollback wijzigt de standaard-subvolume van het hele systeem en wordt pas
  actief na een herstart; snapper ondersteunt dit alleen voor de
  root-subvolume.
- `apt list --upgradable` leest de lokale index. Zonder `apt-get update` blijven
  nieuwe pakketten onzichtbaar; daarom is de expliciete verversing een aparte,
  bewuste actie met elevatie.
- De popup opent zonder wachtwoordprompt: alleen `refresh(true)` vraagt om
  bevoegdheid.
- Flatpak is optioneel; zonder flatpak toont de widget alleen APT-updates.
- `UPDATES_ELEVATE`, `SNAPPER_ELEVATE`, `SNAPPER_BIN`, `SNAPPER_CONFIG`,
  `UPDATES_APT_BIN`, `UPDATES_APT_GET_BIN` en `UPDATES_FLATPAK_BIN` zijn
  bedoeld voor tests en afwijkende installaties.

**Klaar als:** de widget zonder fouten start, de lijst toont bij leesrechten en
aanmaken/verwijderen/opruimen/rollback via de service werken.

---

## Fase 12 — Documentatie, codebook en acceptatietest

**Doel:** overdraagbare documentatie en een complete acceptatietest.
**Status:** klaar.

### Stappen

- [x] `README.md`: installatie, starten, sneltoetsen, configuratiepaden, IPC,
      widgets, tests, probleemoplossing en bekende beperkingen.
- [x] `docs/keybindings.md` als leesbare momentopname van de sxhkdrc.
- [x] `docs/codebook.html`: interactief naslagwerk met architectuur,
      services, componenten, IPC, configuratie en volledige bron.
- [x] Screenshots: `docs/screenshot-bar.png`, `-settings.png`,
      `-shortcuts.png`, `-qt-theme.png`.
- [x] `docs/wallpaper-credits.md` voor de meegeleverde foto's.
- [x] `iso/README.md` voor build, installatie en testen van de ISO.
- [x] Volledige acceptatietest doorlopen.

### Verificatie

- [x] README is genoeg om de installatie opnieuw te doen.
- [x] Codebook opent lokaal en bevat de actuele bestanden.
- [x] Alle acceptatiecriteria hieronder zijn afgevinkt.

**Klaar als:** een nieuwe gebruiker met alleen de documentatie de desktop kan
opbouwen en testen.

---

## Fase 13 — Installer-ISO met Calamares en BTRFS

**Doel:** één hybride ISO (BIOS + UEFI) die deze desktop installeert met
Calamares en de BTRFS-indeling voor snapper en snapshot-boots overneemt.
**Status:** klaar — de ISO is handmatig gebouwd en getest, inclusief de
uitgebreide subvolume-indeling en snapshot-boot.

### Ontwerp

De ISO wordt met `live-build` op Debian sid gebouwd. De live-omgeving is een
volledige LXQt-sessie (zodat Calamares een echte X11-sessie heeft); Calamares
start automatisch en is ook via het menu en een bureaubladsnelkoppeling te
openen. De squashfs bevat de volledige desktopstack, zodat de installatie
offline werkt.

De bronmachine gebruikt op `/dev/vda2` één BTRFS-filesystem met root-subvolume
`@rootfs` en `noatime,compress=zlib:3,discard=async,space_cache=v2`, met
snapper en een geneste `/.snapshots`-subvolume. De top-level subvolumes `@`,
`@home`, `@log` en `@pkg` op die schijf zijn restanten van een eerdere
indeling en worden niet overgenomen. De installer maakt voor snapper en
snapshot-boots een uitgebreidere, schone indeling:

| Onderdeel | Calamares-configuratie |
|---|---|
| Partitionering | EFI 1 GiB (`/boot/efi`, `umask=0077`) + één BTRFS-root, GPT bij UEFI |
| Root-subvolume | `btrfsSubvolumes: /@rootfs` op `/` via `mount.conf` |
| Extra subvolumes | `/@home` → `/home`, `/@log` → `/var/log`, `/@cache` → `/var/cache`, `/@tmp` → `/var/tmp`, `/@spool` → `/var/spool` |
| fstab | `noatime,compress=zlib:3,discard=async,space_cache=v2`; `/var/lib` blijft in `@rootfs` |
| GRUB | `rootflags=subvol=@rootfs`, EFI-fallback ingeschakeld |
| Snapper | `snapper -c root create-config /`, `ALLOW_USERS=<gekozen gebruiker>`, ACL op `/.snapshots`, registratie in `/etc/default/snapper` |
| Snapshot-boot | `overlayroot=tmpfs:recurse=0` alleen voor snapshot-entries; `/` tijdelijk schrijfbaar, aparte subvolumes blijven live |
| Swap | geen, net als de bronmachine |
| Diensten | SDDM, NetworkManager, bluetooth, snapper-boot/timeline/cleanup, grub-btrfsd, fstrim |

### Bestanden

```text
iso/
├── build.sh                     # root-buildscript, staget repo + assets, draait live-build
├── README.md                    # build- en installatie-uitleg
├── verify-iso.sh                # controle van bootimages, squashfs en configuratie
├── test-qemu.sh                 # UEFI-VM met lege schijf
├── live-build/
│   ├── auto/config              # lb config: sid, amd64, iso-hybrid, syslinux+grub-efi, zstd
│   └── config/
│       ├── package-lists/quickshell.list.chroot
│       ├── archives/            # Google Chrome-repo + sleutel
│       ├── hooks/live/          # Quickshell, ACL, LightDM, NVIDIA, grub-btrfs, GRUB-timeout
│       └── preseed/
├── overlay/
│   ├── etc/skel/...             # LXQt-sessie en symlinks
│   ├── usr/local/bin/quickshell-session
│   ├── usr/local/bin/quickshell-user-setup
│   ├── usr/local/bin/quickshell-gpu-setup
│   ├── usr/local/lib/quickshell/install-target.sh
│   ├── usr/local/lib/quickshell/snapper-root.conf
│   ├── usr/lib/live/config/9999-calamares
│   └── usr/share/applications/install-quickshell.desktop
├── calamares/
│   ├── settings.conf            # sequence + shellprocess-instanties
│   ├── modules/*.conf
│   └── branding/quickshell/     # branding.desc, show.qml, afbeeldingen
├── vendor/grub-btrfs-4.14.tar.gz
└── out/                         # ISO + sha256 (niet in git)
```

### Aanpassingen aan de desktop

- [x] `config/bspwm/bspwmrc` gebruikt `$QUICKSHELL_DIR` en valt terug op
      `/opt/quickshell`; het script start `quickshell-user-setup`.
- [x] `/usr/share/xsessions/bspwm.desktop` start via
      `/usr/local/bin/quickshell-session`, dat eerst de gebruikerssetup doet.
- [x] `quickshell-user-setup` maakt symlinks, kopieert de wallpaper en de
      Griekse wallpapers, en legt `~/projecten/quickshell` aan.
- [x] `qt6ct` is als systeempakket in de ISO opgenomen (geen user-local
      fallback nodig).
- [x] Matugen 4.2.0 wordt als binary meegebundeld in `/usr/local/bin`.
- [x] Google Chrome en persoonlijke bestanden: Chrome juist wél meegeleverd
      (met eigen repo, codecs en Widevine); persoonlijke data niet.
- [x] De LiveCalamares-configuratie verwijdert live-boot/live-config en
      Calamares vóór de initramfs wordt gegenereerd.
- [x] `live-build` gebruikt `zstd` op niveau 3 voor de squashfs, zodat
      `mksquashfs` niet door geheugengebrek stopt.
- [x] `iso/build.sh` kan native op Debian sid bouwen of eenmalig een
      Debian-sid-chroot met `debootstrap` maken (voor Ubuntu en andere hosts).
- [x] Matugen wordt automatisch gevonden of gedownload; grub-btrfs komt uit
      `iso/vendor/`.
- [x] NVIDIA wordt in een aparte, niet-fatale chroot-stap geïnstalleerd;
      zonder werkende module valt de ISO terug op Mesa/nouveau.
- [x] `overlayroot` is in de pakketlijst opgenomen.
- [x] `install-target.sh` controleert de vijf extra subvolumes, zet rechten
      (waaronder `1777` op `/var/tmp`) en schrijft de overlayroot-parameter.
- [x] `scripts/setup-snapshot-boot.sh` zet snapshot-boot achteraf aan op een
      bestaande installatie.

### Verificatie

- [x] `sudo iso/build.sh` eindigt met een ISO en een `.sha256` (3,4 GiB,
      `quickshell-desktop-amd64.iso`).
- [x] `iso/verify-iso.sh` controleert BIOS- en UEFI-bootimages, de squashfs,
      `/opt/quickshell`, Calamares, matugen, SDDM (geen LightDM), Chrome,
      NVIDIA/Mesa en de BTRFS-mountopties.
- [x] De ISO boot in QEMU (UEFI, OVMF) in LXQt; Calamares opent automatisch
      en toont de Quickshell-branding.
- [x] Een installatie op een lege 24 GiB-schijf levert:
      `findmnt /` met `subvol=/@rootfs` en de juiste mountopties;
      `btrfs subvolume list /` met `@rootfs` en `.snapshots`;
      `snapper`-configuratie `root` met `ALLOW_USERS` en `SYNC_ACL`, en
      geregistreerd in `/etc/default/snapper` (`SNAPPER_CONFIGS="root"`);
      `grub.cfg` met `rootflags=subvol=@rootfs`;
      SDDM als displaymanager en de bspwm-sessie als standaard.
- [x] Na de eerste login start de Quickshell-bar met workspaces, klok, weer,
      volume, meldingen, Snapper-teller, updates, instellingen en de
      powerknop.
- [x] `Super+/` (71 bindingen), `Super+Shift+S` (BSPWM-instellingen), een
      D-Bus-notificatie (popup + badge) en de Snapper-teller zijn op de
      geïnstalleerde schijf getest.
- [x] Snapper werkt als de gekozen gebruiker (`snapper list-configs` toont
      `root`, zonder sudo); zonder de registratie in `/etc/default/snapper`
      bleef de lijst leeg.
- [x] De Chrome/NVIDIA-versie is in QEMU met OVMF geboot:
      `google-chrome-stable --version` werkt, de standaardbrowser is Chrome,
      `quickshell-gpu-setup.service` kiest Mesa zonder NVIDIA en de
      NVIDIA-DKMS-module is voor de kernel in de ISO gebouwd.
- [x] De QEMU-test is onder bspwm met een zwevend venster van 1280×800
      uitgevoerd; in een betegeld venster past het Calamares-venster niet.
- [x] De uitgebreide ISO is handmatig gebouwd en getest:
      `btrfs subvolume list /` toont `@rootfs`, `@home`, `@log`, `@cache`,
      `@tmp`, `@spool` en `.snapshots`; `/etc/fstab` bevat alle vijf extra
      mounts en
      `GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="overlayroot=tmpfs:recurse=0"`.
- [x] Een snapshot die na de installatie is gemaakt, start via het
      GRUB-submenu met een tijdelijke overlay op `/`; `/home`, `/var/log`
      en de caches blijven writable en de snapshot zelf blijft read-only.

### Belangrijke lessen

- Calamares schrijft `subvol=/@rootfs` (met slash), terwijl de bronmachine
  `subvol=@rootfs` gebruikt. `install-target.sh` normaliseert de rootregel.
- De extra subvolumes houden data buiten de root-snapshots:
  `@home` (gebruikersdata), `@log` (logs tijdens snapshot-boot),
  `@cache`/`@tmp` (tijdelijk) en `@spool` (wachtrijen). `/var/lib` blijft
  bewust in `@rootfs`, zodat dpkg/systemd bij een rollback meelopen.
- Zonder registratie in `/etc/default/snapper` kent snapper de configuratie
  niet, ook al staat `/etc/snapper/configs/root` er wel.
- `overlayroot=tmpfs:recurse=0` geldt alleen voor snapshot-entries; een
  normale boot blijft ongewijzigd. Oudere snapshots hebben de nieuwe
  initramfs niet en zijn alleen voor rollback.
- De build heeft geen NVIDIA-GPU nodig; DKMS compileert de module voor de
  kernel in de ISO. Mislukt dat, dan waarschuwt de hook en bouwt de ISO door
  met Mesa/nouveau.
- Secure Boot is in de live-ISO uitgeschakeld; de NVIDIA-module is niet
  ondertekend. Het doelssysteem krijgt `shim-signed` en
  `grub-efi-amd64`.

**Klaar als:** de ISO op echte hardware of in QEMU installeert en het
geïnstalleerde systeem dezelfde BTRFS-root, snapper-configuratie en
Quickshell-desktop heeft als de bronmachine, inclusief de nieuwe
subvolume-indeling en snapshot-boot.

---

## Fase 14 — Toekomst: meerdere Linux-distributies maken

**Doel:** van deze ene desktop een leerroute maken naar meerdere eigen
distributies of installatie-ISO's, zonder de bestaande desktop te breken.
**Status:** leerpad / gepland. Onderstaande stappen zijn bedoeld als
leerroute; ze zijn nog niet uitgevoerd.

### 14.1 Kies eerst je route

Er zijn drie realistische routes. Begin bij route A en werk daarna pas naar B
of C.

| Route | Wat het is | Geschikt als |
|---|---|---|
| **A. Remaster / live-ISO** | Je hergebruikt een bestaande distributie en voegt packages, branding en een installer toe. | Je snel een eigen installatie-ISO wilt. |
| **B. Derivative** | Je bouwt een eigen distributie op een bestaande basis (bijv. Debian sid) met eigen repo, branding en installer. | Je een onderhoudbare eigen distro wilt. |
| **C. From scratch** | Je bouwt de hele stack zelf (kernel, init, packages, repo, installer). | Je vooral wilt leren hoe een distributie intern werkt. |

**Leerdoel:** je kunt uitleggen welke route bij welk doel past en waarom de
onderhoudslast van C veel hoger is dan van A of B.

### 14.2 Leer de bootketen kennen

Bestudeer en teken één keer de volledige keten:

```text
UEFI/BIOS → GRUB → kernel + initramfs → systemd → display-manager → sessie
```

- [ ] Onderzoek wat `shim`, `grub`, `vmlinuz`, `initrd.img` en
      `rootflags=subvol=…` doen.
- [ ] Test een handmatige GRUB-entry en een rescue-shell.
- [ ] Bekijk `lsinitramfs` en voeg één hook toe (bijvoorbeeld `overlayroot`).
- [ ] Leg uit waarom Secure Boot en NVIDIA-DKMS kunnen botsen.

**Leerdoel:** je kunt een bootprobleem lokaliseren zonder meteen de ISO
opnieuw te bouwen.

### 14.3 Bouw eerst een minimale live-ISO

Begin klein: een live-systeem zonder installer, zonder desktop en zonder
branding.

- [ ] Kies een bouwtool:
      `live-build` (Debian), `debos` (Debian, reproduceerbaar),
      `mkosi` (distro-overstijgend), `archiso` (Arch), `kiwi` (openSUSE) of
      `livecd-tools` (Fedora).
- [ ] Bouw een image die alleen naar een console boot en `whoami` toont.
- [ ] Voeg één package toe en controleer dat het in de squashfs zit.
- [ ] Vergelijk buildtijd, reproducibility en benodigde rechten.
- [ ] Bewaar het buildscript en de checksum in de repo.

**Leerdoel:** je begrijpt welke laag je het beste kunt aanpassen: packages,
overlay, hooks of installer.

### 14.4 Scheid het distributieprofiel van de desktop

Deze repo is nu één geheel. Voor meerdere distro's wil je een profiel per
distro, zodat de desktop zelf herbruikbaar blijft.

- [ ] Maak (in een aparte branch of map) een profiel per distro, bijvoorbeeld
      `distros/debian-sid/`, `distros/fedora/`, `distros/arch/`.
- [ ] Zet per profiel vast: basis, package manager, kernel, displaymanager,
      installer, bootloader, bestandssysteem en branding.
- [ ] Houd gedeelde onderdelen (Quickshell, sxhkdrc, scripts, thema) op één
      plek; alleen paden en package-namen verschillen.
- [ ] Gebruik variabelen voor paden als `/opt/quickshell` en
      `~/projecten/quickshell`; hardcode ze niet in nieuwe scripts.
- [ ] Documenteer per profiel wat er anders is.

**Leerdoel:** je kunt een tweede distro toevoegen zonder de eerste te
dupliceren.

### 14.5 Maak packaging en een eigen repo

Een distributie is meer dan een ISO: pakketten moeten updatebaar zijn.

- [ ] Leer `.deb` bouwen met `dpkg-buildpackage`, `debuild` of `dh`.
- [ ] Maak een eigen APT-repo met `reprepro` of `aptly` en onderteken die met
      een GPG-sleutel.
- [ ] Zet de repo in een test-ISO en installeer/upgrade een eigen pakket.
- [ ] Doe hetzelfde conceptueel voor RPM (`rpmbuild`, `createrepo_c`) of Arch
      (`makepkg`, `repo-add`).
- [ ] Denk na over versiebeleid, changelogs en het verwijderen van oude
      pakketten.

**Leerdoel:** je kunt een update uitrollen zonder de hele ISO opnieuw te
bouwen.

### 14.6 Automatiseer de build

- [ ] Bouw in een schone container of VM, niet op je dagelijkse desktop.
- [ ] Leg de build vast in een script met duidelijke `set -eu` en logging.
- [ ] Cache pakketten en downloads (zoals `iso/cache/` nu doet).
- [ ] Genereer een `.sha256` en bewaar het buildlog.
- [ ] Maak de build herhaalbaar: dezelfde input moet dezelfde output geven
      (of op zijn minst dezelfde pakketversies).
- [ ] Overweeg CI (GitHub Actions, GitLab CI of een eigen runner) voor
      builds en `verify-iso.sh`.

**Leerdoel:** je kunt een ISO opnieuw bouwen zonder mondelinge toelichting.

### 14.7 Branding, defaults en eerste indruk

- [ ] Eigen `/etc/os-release`, hostname, wallpapers, logo en SDDM-thema.
- [ ] Calamares-branding (`branding.desc`, `show.qml`, afbeeldingen) per
      distro.
- [ ] Standaardinstallatie: browser, terminal, fonts, taal, toetsenbord en
      netwerk.
- [ ] Juridische check: proprietary codecs, Chrome, NVIDIA en handelsmerken.
- [ ] Toegankelijkheid: contrast, schaalgrootte, toetsenbordnavigatie.

**Leerdoel:** je kunt uitleggen welke keuzes branding zijn en welke keuzes
functioneel of juridisch verplicht zijn.

### 14.8 Testmatrix en kwaliteit

Test niet alleen in QEMU. Maak een matrix:

| Variabele | Minimaal testen |
|---|---|
| Firmware | BIOS en UEFI |
| Secure Boot | uit en (indien ondersteund) aan |
| GPU | Intel/AMD, NVIDIA, geen GPU/VM |
| Opslag | lege schijf, bestaande schijf, BTRFS, ext4 |
| Netwerk | online installatie en offline installatie |
| Sessie | live-sessie, geïnstalleerd systeem, snapshot-boot |
| Herstel | rollback, rescue-shell, kapotte GRUB |

- [ ] Automatiseer wat kan (`verify-iso.sh`, QEMU, `qemu-nbd`).
- [ ] Test op echte hardware voordat je een release publiceert.
- [ ] Documenteer bekende beperkingen per release.

**Leerdoel:** je weet welke fouten alleen op echte hardware of in een
specifieke bootmodus zichtbaar worden.

### 14.9 Release en onderhoud

- [ ] Versienummer en codenaam per release.
- [ ] Release notes met wijzigingen, bekende problemen en upgrade-pad.
- [ ] Onderteken ISO en checksums; publiceer via HTTPS en een spiegel.
- [ ] Plan een onderhoudsritme: pakketupdates, kernel, NVIDIA, Chrome,
      Quickshell en Calamares.
- [ ] Houd een rollbackroute: snapper, vorige ISO en een rescue-USB.
- [ ] Verouderde snapshots en oude ISO's opruimen.

**Leerdoel:** je kunt een distro na de release blijven onderhouden.

### 14.10 Andere distributiefamilies: wat verandert er?

| Familie | Bouwen | Installer | Package manager | Aandachtspunten |
|---|---|---|---|---|
| Debian/Ubuntu | `live-build`, `debos` | Calamares, preseed, subiquity | APT | Deze repo; grootste basis. |
| Fedora | `kiwi`, `livecd-tools` | Anaconda | DNF | SELinux, Wayland-standaard, signed modules. |
| Arch | `archiso` | `archinstall` of eigen script | pacman | Rolling release; reproducibility lastiger. |
| openSUSE | `kiwi` | YaST/Agama | Zypper | Snapper is hier een eersteklas burger. |
| Alpine | `alpine-make-vm-image` | eigen script | apk | Musl, OpenRC, heel andere basis. |
| NixOS | `nixos-generators` | eigen | Nix | Declaratief; ideaal om configuraties te vergelijken. |

**Leerdoel:** je kunt per familie benoemen welke drie dingen je opnieuw moet
ontwerpen: package manager, installer en bootloader.

### 14.11 Oefenopdrachten (van klein naar groot)

1. Bouw de bestaande ISO opnieuw en laat `verify-iso.sh` slagen.
2. Maak een tweede Calamares-branding met een andere naam en wallpaper.
3. Bouw een minimale Debian-live-ISO zonder desktop.
4. Voeg één eigen `.deb` toe aan een eigen APT-repo en installeer die.
5. Maak een Fedora- of Arch-variant met dezelfde Quickshell-desktop.
6. Automatiseer de build in CI en publiceer alleen bij een groene test.
7. Documenteer één distributie volledig: profiel, build, test, release en
   rollback.

**Klaar als:** je een tweede distributie kunt bouwen, testen en documenteren
zonder de bestaande Debian-desktop te wijzigen.

---

## Risico's en mitigaties

| Risico | Mitigatie |
|---|---|
| X11-stacking (#290): fullscreen bedekt de bar | Getest; noodoplossing `bspc config ignore_ewmh_fullscreen enter` |
| PopupWindow geen toetsenbordfocus (#794) | Geen tekstinvoer in popups; instellingen/sneltoetsen/wallpapers als `FloatingWindow` |
| Dubbele ruimte door struts + bspwm-padding | Standaard padding 0; waarschuwing in de instellingen-UI |
| Notificatiedaemon-conflict | Alleen Quickshell starten als `org.freedesktop.Notifications`-eigenaar; `lxqt-notificationd` niet autostarten |
| Alleen SNI-tray, geen XEmbed | Documenteren; moderne apps gebruiken SNI |
| Weer-API offline | Cache + foutstatus, geen crash |
| Debian sid-updates breken Qt/Quickshell | LXQt-fallback behouden; opnieuw starten/herbouwen mogelijk |
| Snapper zonder rechten | `ALLOW_USERS` + `SYNC_ACL` of `pkexec`; duidelijke fout in de popup |
| Updates blijven “kept back” | `apt-get full-upgrade` gebruiken en de index expliciet verversen |
| ISO-build op een oude host | Debian-sid-chroot via `debootstrap`; `zstd` voor de squashfs |
| Snapshot-boot read-only | `overlayroot` + aparte subvolumes; oudere snapshots alleen voor rollback |
| NVIDIA-DKMS faalt tijdens build | Niet-fatale hook; terugval op Mesa/nouveau; log controleren |
| Secure Boot blokkeert NVIDIA | Eigen MOK-sleutel registreren of Secure Boot uitschakelen |

---

## Acceptatiecriteria

- [x] Na login start bspwm met sxhkd, picom (optioneel), wallpaper en
      Quickshell; de bar staat boven en de gereserveerde ruimte klopt.
- [x] De bar toont workspaces (focus/bezet/urgent), klok, weer, Snapper,
      updates, MPRIS, volume, accu (indien aanwezig), meldingen, sneltoetsen,
      wallpapers, instellingen en power.
- [x] Weer ververst automatisch en werkt offline met cache.
- [x] Notificaties: popup, geschiedenis, acties en DND; geen andere daemon.
- [x] SNI-trayiconen verschijnen en hun menu's openen.
- [x] `Super+Shift+S` opent het instellingenvenster; gaps, randen, layouts,
      kleuren, gedrag, schaal en bar-dekking zijn live aan te passen en
      blijven na `bspc wm -r` behouden.
- [x] `Super+/` opent het sneltoetsenoverzicht; het komt exact overeen met
      `sxhkdrc`, is doorzoekbaar en actualiseert na herladen van sxhkd.
- [x] Eigen sneltoetsen zijn toe te voegen, te bewerken en te verwijderen.
- [x] De Snapper-widget toont momentopnamen, wisselt van configuratie en kan
      aanmaken/verwijderen/opruimen/rollback; zonder rechten toont hij een
      uitleg en gebruikt hij `pkexec`.
- [x] De update-widget toont APT- en Flatpak-updates, kan de index verversen
      en werkt bij met `full-upgrade` + `flatpak update`.
- [x] Het powermenu kan afmelden, vergrendelen, slapen, herstarten en
      afsluiten.
- [x] Het wallpapervenster kan wallpapers previewen, toepassen, toevoegen en
      verwijderen; het thema volgt de wallpaper.
- [x] Alle sneltoetsen uit de tabel werken; `qs ipc call …` werkt voor alle
      doelen.
- [x] De LXQt-sessie blijft selecteerbaar en ongewijzigd.
- [x] De installer-ISO boot op BIOS en UEFI, installeert zonder netwerk en
      levert dezelfde desktop en BTRFS/snapper-configuratie.
- [ ] De nieuwe ISO met vijf extra subvolumes en snapshot-boot is in QEMU
      getest (zie de openstaande punten bovenaan).

---

## Testmatrix

| Test | Commando / controle |
|---|---|
| QML-log | `tail -f /tmp/quickshell-$USER.log` |
| Sxhkd-syntax | `sxhkd -c config/sxhkd/sxhkdrc` (op een eigen display) |
| Geneste sessie | `scripts/test-fase1-nested.sh` |
| Notificaties | `scripts/test-notifications.sh` met `basic`, `critical`, `action` of `all` |
| BSPWM-status | `qs -p ~/projecten/quickshell ipc call bspwm status` |
| Instellingen | `qs -p … ipc call settings status` |
| Sneltoetsen | `qs -p … ipc call shortcuts status` en `list` |
| Weer | `qs -p … ipc call weather status` |
| Snapper | `qs -p … ipc call snapper status` en `list` |
| Updates | `qs -p … ipc call updates status` en `refresh` |
| Wallpaper | `qs -p … ipc call wallpaper status` en `list` |
| Power | `qs -p … ipc call power status` |
| Tray | `qs -p … ipc call tray status` |
| ISO-inhoud | `iso/verify-iso.sh` |
| ISO in QEMU | `iso/test-qemu.sh` |
| BTRFS na installatie | `findmnt /`, `btrfs subvolume list /`, `cat /etc/fstab` |
| Snapper na installatie | `snapper list-configs`, `snapper -c root list` |
| Snapshot-boot | GRUB-submenu + `findmnt /` en `touch /test` (verdwijnt na reboot) |

---

## Referenties

- Quickshell docs: <https://quickshell.org/docs/v0.3.2/>
- `PanelWindow`: <https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow>
- `NotificationServer`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Notifications/NotificationServer>
- `SystemTray`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/SystemTray>
- `IpcHandler`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/IpcHandler>
- `FileView`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/FileView>
- `FloatingWindow`: <https://quickshell.org/docs/v0.3.2/types/Quickshell/FloatingWindow>
- bspwm(1) report-formaat en `bspc config`:
  <https://manpages.debian.org/sid/bspwm/bspwm.1.en.html>
- sxhkd(1) config en SIGUSR1:
  <https://manpages.debian.org/sid/sxhkd/sxhkd.1.en.html>
- Open-Meteo: <https://open-meteo.com/en/docs>
- Quickshell issue #290:
  <https://github.com/quickshell-mirror/quickshell/issues/290>
- Quickshell issue #794:
  <https://github.com/quickshell-mirror/quickshell/issues/794>
- live-build: <https://wiki.debian.org/RepackBootableISO>
- Calamares: <https://calamares.io/docs/>
- grub-btrfs: <https://github.com/Antynea/grub-btrfs>
- overlayroot: <https://manpages.debian.org/sid/overlayroot/overlayroot.8.en.html>
- snapper: <https://snapper.io/>
- archiso: <https://wiki.archlinux.org/title/Archiso>
- kiwi: <https://osinside.github.io/kiwi/>
- debos: <https://github.com/go-debos/debos>
- mkosi: <https://github.com/systemd/mkosi>

---

## Promptbibliotheek

Voor herhaalbare AI-sessies staat in `PROMPTS.md` een complete set prompts:
context, fase-reconstructie, nieuwe widgets/services, debuggen, testen,
documentatie, ISO-bouw en het leerpad naar meerdere distributies. Gebruik die
prompts samen met dit plan; wijzig eerst het plan en pas daarna de code.
