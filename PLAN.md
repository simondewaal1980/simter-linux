# Plan: BSPWM + Quickshell desktop (Debian sid)

> Uitvoerbaar per fase. Elke fase heeft een doel, stappen met checkboxes, commando's en een verificatie.
> Vink af wat klaar is en werk fase voor fase naar beneden.

**Projectmap:** `/home/simon/projecten/quickshell`
**Quickshell starten:** `qs -p /home/simon/projecten/quickshell`
**Doelomgeving:** Debian sid (forky), X11, SDDM, 1920×1080

---

## Voortgang

- [x] Fase 1 — Pakketten, bspwm-sessie en basisconfiguratie
- [x] Fase 2 — Quickshell-skelet, thema en bar met workspaces/klok
- [x] Fase 3 — BSPWM-integratie (report-parser, klikbare workspaces)
- [x] Fase 4 — Weer Eindhoven
- [x] Fase 5 — Systemtray
- [x] Fase 6 — Notificatieserver, popups en centrum
- [x] Fase 7 — Instellingenvenster voor BSPWM
- [x] Fase 8 — Sneltoetsenoverzicht + definitieve sxhkdrc
- [x] Fase 9 — Polijsten, optionele widgets, documentatie
- [x] Aanvullend — Donker thema en wallpaper-palet (matugen)
- [x] Aanvullend — Eigen sneltoetsen toevoegen/bewerken in het overzicht
- [x] Aanvullend — Snapper-widget voor btrfs-momentopnamen
- [x] Aanvullend — Installer-ISO met Calamares en de BTRFS-configuratie

---

## 0. Uitgangspunten en standaardkeuzes

Deze keuzes zijn als default vastgelegd zodat de fasen uitvoerbaar zijn. Ze zijn later eenvoudig te wijzigen.

| Onderwerp | Default |
|---|---|
| Terminal | `alacritty` (wijzigbaar in `config/sxhkd/sxhkdrc`) |
| Launcher | `rofi` |
| Thema | Donker; Material You-palet uit de wallpaper (matugen), Catppuccin Mocha als terugval |
| Extra widgets | volume + actieve venstertitel (accu alleen op laptop) |
| LXQt | blijft als fallback-sessie |
| Polkit | Quickshell-agent optioneel in fase 9; anders `lxpolkit` |
| Multi-monitor | code per scherm, nu één scherm |

### Haalbaarheid (gecontroleerd)

| Onderdeel | Status |
|---|---|
| `quickshell` 0.3.2 in sid | geïnstalleerd (0.3.2-1) |
| `bspwm` 0.9.12 + `sxhkd` 0.6.3 | geïnstalleerd (0.9.12-1, 0.6.3-1) |
| `qs`-binary | symlink naar `quickshell` in het Debian-pakket |
| X11-sessiebestand | `/usr/share/xsessions/bspwm.desktop` zit in het bspwm-pakket |
| Qt / OpenGL | Qt 6.11, `/dev/dri` aanwezig |

Quickshell 0.3.2 ondersteunt X11: `PanelWindow` gebruikt EWMH-struts (`_NET_WM_STRUT_PARTIAL`) en blijft op alle desktops. Notificaties en tray lopen via D-Bus.

**Bekende X11-beperkingen:**

- **Issue #290**: `aboveWindows` werkt niet betrouwbaar onder bspwm; fullscreen kan de bar bedekken. Mitigatie: testen in fase 2; noodoplossing `bspc config ignore_ewmh_fullscreen enter`.
- **Issue #794**: `PopupWindow` vraagt onder X11 geen toetsenbordfocus. Daarom zijn instellingen en sneltoetsen `FloatingWindow`s; popups bevatten geen tekstinvoer.

---

## 1. Architectuur

```
SDDM → bspwm-sessie
└── bspwm (X11, EWMH)
    ├── sxhkd ─────────────► bspc / qs ipc / applicaties
    ├── picom (optioneel) ──► transparantie, schaduwen
    ├── wallpaper-theme.sh ─► feh + matugen (wallpaper en kleuren)
    └── qs -p ~/projecten/quickshell
        ├── Bar (PanelWindow per scherm, struts)
        │   ├── workspaces  ← bspc subscribe report
        │   ├── actief venster (optioneel, xdotool)
        │   ├── klok
        │   ├── weer Eindhoven ← Open-Meteo
        │   ├── systemtray ← StatusNotifierItem/DBusMenu
        │   └── notificatiebel + DND
        ├── NotificationServer + popups + notificatiecentrum
        ├── SettingsWindow (FloatingWindow) ── bspc config
        └── ShortcutsWindow (FloatingWindow) ← sxhkdrc-parser
```

**Eén bron van waarheid:** `~/.config/bspwm/settings.json`.
Quickshell schrijft dit bestand en past wijzigingen direct toe met `bspc config`. `bspwmrc` past het bij elke (her)start opnieuw toe via `scripts/apply-bspwm-settings.sh`. De bar leest dezelfde kleuren, zodat BSPWM-randen en Quickshell-thema synchroon blijven.

---

## 2. Bestandsstructuur

```
/home/simon/projecten/quickshell/
├── PLAN.md                      # dit bestand
├── shell.qml                    # root: bar(s), vensters, services, IPC
├── README.md                    # installatie, sneltoetsen, troubleshooting
├── .gitignore                   # o.a. .qmlls.ini
├── src/
│   ├── theme/
│   │   ├── Theme.qml            # singleton, leest settings.json
│   │   └── qmldir
│   ├── services/
│   │   ├── Bspwm.qml            # report-parser + commando's
│   │   ├── Weather.qml          # Open-Meteo + cache
│   │   ├── NotificationDaemon.qml
│   │   ├── BspwmSettings.qml    # in-memory state + opslaan
│   │   └── qmldir
│   ├── components/
│   │   ├── Bar.qml
│   │   ├── Workspaces.qml
│   │   ├── ActiveWindow.qml
│   │   ├── Clock.qml
│   │   ├── WeatherWidget.qml
│   │   ├── TrayWidget.qml
│   │   ├── NotificationBell.qml
│   │   └── Keycap.qml
│   ├── popups/
│   │   ├── WeatherPopup.qml
│   │   ├── NotificationStack.qml
│   │   └── NotificationCenter.qml
│   ├── windows/
│   │   ├── SettingsWindow.qml
│   │   └── ShortcutsWindow.qml
│   └── utils/
│       ├── ReportParser.js
│       ├── SxhkdParser.js
│       └── WeatherCodes.js
├── scripts/
│   └── apply-bspwm-settings.sh
├── config/
│   ├── bspwm/bspwmrc
│   ├── bspwm/settings.default.json
│   ├── sxhkd/sxhkdrc
│   └── picom/picom.conf        # optioneel
└── docs/
    └── keybindings.md          # optioneel
```

**Deployment:** de repo blijft de bron. `~/.config/bspwm/bspwmrc` en `~/.config/sxhkd/sxhkdrc` worden symlinks naar `config/…`. Quickshell start met `qs -p /home/simon/projecten/quickshell`, dus geen kopieer- of installatiestap.

---

## Fase 1 — Pakketten, bspwm-sessie en basisconfiguratie

**Doel:** een werkende bspwm-sessie met sxhkd, wallpaper en de mapstructuur. Quickshell hoeft nog niet te werken.

### Stappen

- [x] Pakketten installeren:

  ```bash
  sudo apt update
  sudo apt install quickshell bspwm sxhkd jq curl xdotool \
    fonts-jetbrains-mono fonts-font-awesome papirus-icon-theme \
    picom feh rofi maim slop alacritty \
    network-manager-applet blueman pavucontrol playerctl brightnessctl
  ```

  > `network-manager-gnome` bestaat niet meer in sid; de opvolger is
  > `network-manager-applet` (levert `nm-applet`). `alacritty` is toegevoegd
  > omdat het de standaardterminal is (ontbrak in de oorspronkelijke lijst).

- [x] Optioneel voor veilig testen in een geneste X-server:

  ```bash
  sudo apt install xserver-xephyr
  ```

- [x] Mapstructuur aanmaken (zie sectie 2) en `git init` (met `.gitignore`).

- [x] `config/bspwm/bspwmrc` geschreven (executable gemaakt):

  ```sh
  #!/bin/sh
  "$HOME/.config/bspwm/apply-settings.sh"
  bspc monitor -d 1 2 3 4 5 6 7 8 9
  bspc config focus_follows_pointer true
  bspc config border_width 2
  bspc rule -a quickshell-bspwm state=floating center=on
  pgrep -x sxhkd >/dev/null || sxhkd &
  feh --bg-fill "$HOME/Pictures/wallpaper.jpg" &
  picom --config "$HOME/.config/picom/picom.conf" &
  qs -p "$HOME/projecten/quickshell" &
  ```

  > Afwijkingen: `presel_feedback_color` i.p.v. niet-bestaande presel-kleuren,
  > en hulptools worden alleen gestart als ze nog niet op dít scherm draaien
  > (voorkomt dubbele processen na `bspc wm -r`). `qs` start pas als
  > `shell.qml` bestaat, dus vanaf fase 2.

- [x] `config/bspwm/settings.default.json` met startwaarden (gaps, randen, padding, kleuren, gedrag, layout).

- [x] `scripts/apply-bspwm-settings.sh` geschreven: leest `~/.config/bspwm/settings.json` met `jq` en past `bspc config`, per-monitor padding en kleuren toe. Gedeployed als symlink `~/.config/bspwm/apply-settings.sh` (één bron, geen kopie).

- [x] Symlinks aanmaken:

  ```bash
  mkdir -p ~/.config/bspwm ~/.config/sxhkd ~/.config/picom
  ln -sf ~/projecten/quickshell/config/bspwm/bspwmrc ~/.config/bspwm/bspwmrc
  chmod +x ~/projecten/quickshell/config/bspwm/bspwmrc
  ln -sf ~/projecten/quickshell/config/sxhkd/sxhkdrc ~/.config/sxhkd/sxhkdrc
  ln -sf ~/projecten/quickshell/config/picom/picom.conf ~/.config/picom/picom.conf
  ```

  Aanvullend: `~/.config/bspwm/apply-settings.sh` en
  `~/.config/bspwm/settings.default.json` zijn symlinks naar de repo, en
  `~/.config/bspwm/settings.json` is een kopie van de default (het
  gebruikersbestand dat Quickshell in fase 7 schrijft).

- [x] Eerste `config/sxhkd/sxhkdrc` met basisbindings (`Super+Return` terminal, `Super+d` rofi, `Super+q` sluiten, workspaces).

- [x] Wallpaper gekozen en op `~/Pictures/wallpaper.jpg` gezet (gegenereerd met `ffmpeg`: donkere Catppuccin-gradient, 1920×1080).

- [ ] Inloggen via SDDM met de **bspwm**-sessie (LXQt blijft als fallback).
      → vraagt een handmatige logout/login; `bspwm.desktop` staat klaar in
      `/usr/share/xsessions/`.

### Verificatie

- [x] `bspc query -M --names` geeft je monitor. (Genest: `default`; in de echte sessie `Virtual-1`.)
- [x] `pgrep -x bspwm`, `pgrep -x sxhkd` en `pgrep -x picom` draaien.
- [x] `Super+Return` opent een terminal; `Super+d` opent rofi.
- [x] `bspc config window_gap` geeft de waarde uit `settings.json`.
- [x] Herstarten van bspwm (`bspc wm -r`) behoudt de instellingen.

### Uitvoeringsnotities (fase 1)

- Getest in een geneste X-server (Xephyr op `:1`), zodat de LXQt-sessie op `:0`
  ongemoeid bleef. Herhaalbaar met `scripts/test-fase1-nested.sh` (vereist
  `xserver-xephyr`; start bspwm met de echte config en test de sneltoetsen).
  Toetsen gesimuleerd met `xdotool key` **zonder**
  `--clearmodifiers` (met die optie worden de synthetische Super-combinaties
  niet door sxhkd opgepakt). Op echte hardware speelt dat niet.
- **picom afgestemd op de VM-GPU:** de GLX-backend met vsync trok >300% CPU en
  maakte de sessie ~16 s onresponsief (`Failed to enable vsync`). Daarom staat
  de config op `backend = "xrender"`, `vsync = false`, `xrender-sync-fence = true`
  — 0% CPU bij stilstand. Op echte hardware is `glx` te heroverwegen (fase 9).
- bspwm 0.9.12 geeft exitcode 1 als je een boolean op dezelfde waarde zet;
  `apply-bspwm-settings.sh` vergelijkt daarom eerst met de huidige waarde en
  waarschuwt alleen bij een echte afwijking.
- bspwm 0.9.12-sleutelnamen: `presel_feedback_color` (geen presel-focus/norm),
  `pointer_modifier mod4` (kent geen `none`), `ignore_ewmh_fullscreen none|all|enter|exit`
  (dus `all`, niet `both`).


**Klaar als:** je een werkende bspwm-sessie hebt waarin sxhkd, wallpaper en picom draaien, en de JSON-instellingen bij herstart worden toegepast.

---

## Fase 2 — Quickshell-skelet, thema en bar met workspaces/klok

**Doel:** Quickshell draait met een bar die via struts ruimte reserveert en workspaces + klok toont.

### Stappen

- [x] `shell.qml` met `ShellRoot`, `Variants { model: Quickshell.screens }` en één `Bar` per scherm.
- [x] `src/theme/Theme.qml` (singleton) + `qmldir`; leest `~/.config/bspwm/settings.json` via `FileView` met `watchChanges: true` en bevat het kleurenpalet.
- [x] `src/components/Bar.qml`: `PanelWindow`, hoogte ±34 px, `anchors { top; left; right }`, automatische `exclusiveZone`, `aboveWindows: true`, `focusable: false`.
- [x] Indeling: links workspaces (tijdelijk statisch), midden klok/datum, rechts tijdelijke iconen.
- [x] `src/components/Clock.qml` met `SystemClock`.
- [x] IPC-handlers toevoegen (`bar` met `reload`/`toggle`).
- [x] `.qmlls.ini` aanmaken voor editor/LSP.

### Verificatie

- [x] `qs -p ~/projecten/quickshell` start zonder fouten; bar staat boven.
- [x] `xprop -root _NET_WM_STRUT_PARTIAL` toont gereserveerde ruimte.
      → Let op: EWMH zet de strut op het *barvenster*, niet op de root. Correcte
      controle: `xprop -id <bar-window> _NET_WM_STRUT_PARTIAL` (of
      `xprop -root _NET_SUPPORTED` voor ondersteuning). BSPWM vertaalt de strut
      naar `padding.top` van de monitor; `bspc query -T -m` bevestigt dat.
- [x] Een getiled venster overlapt de bar niet.
- [x] Fullscreen testen (`Super+f`): blijft de bar zichtbaar? Zo niet, noteer dit en test de mitigatie `bspc config ignore_ewmh_fullscreen enter`.
- [x] `qs ipc show` toont de handler(s).

**Klaar als:** de bar stabiel draait, struts kloppen en de klok loopt. Dit is ook het moment om te controleren of de bar boven fullscreen blijft; leg de uitkomst vast.

### Uitvoeringsnotities (fase 2)

- Getest op de echte sessie (`DISPLAY=:0`, bspwm) op 1280×800 én na een
  resolutiewijziging naar 1920×1080. De bar schaalt automatisch mee; de strut
  wordt op beide resoluties bijgewerkt (34 px, breedte = schermbreedte).
- **Fullscreen (#290):** de bar blijft onder bspwm zichtbaar boven een
  fullscreen-venster (`bspc node -t fullscreen`). De mitigerende
  `ignore_ewmh_fullscreen enter` is hier dus niet nodig.
- De strut staat op het Quickshell-paneelvenster, niet op de root:
  `_NET_WM_STRUT_PARTIAL = 0, 0, 34, 0, …`. BSPWM zet dit om naar
  `padding.top: 34` op de monitor, waardoor getilde vensters op y=42 beginnen
  (34 bar + 8 gap).
- `Theme` gebruikt `JsonAdapter` in plaats van `JSON.parse(FileView.text())`:
  dat is reactief zonder bindingslus. Een wijziging van
  `colors.focused` in `settings.json` kleurt de actieve workspace direct mee.
- `qs ipc call bar toggle` verbergt de bar; bij opnieuw tonen maakt Quickshell
  het native venster opnieuw aan. BSPWM laat de gereserveerde bovenruimte
  intussen staan (het werkgebied wordt niet opnieuw berekend); de bar komt wel
  netjes terug. `qs ipc call bar reload` herlaadt de QML zonder herstart.
- De datum wordt met `Date.toLocaleDateString(Qt.locale("nl_NL"), …)` geformatteerd;
  `Qt.formatDateTime()` volgde de C-locale en gaf Engelse afkortingen.
- `qmlls`/`qmllint` is niet geïnstalleerd (`qt6-declarative-dev-tools` ontbreekt);
  `.qmlls.ini` staat klaar met `importPaths` en `no-cmake-calls` voor een editor
  die de Qt-tools wel heeft. De shell zelf is gevalideerd door `qs` te starten
  en de log op QML-fouten te controleren.
- Workspaces zijn in deze fase bewust nog statisch (1 focus, 2 en 4 bezet) en
  alleen visueel klikbaar; fase 3 koppelt ze aan `bspc subscribe report`.

---

## Fase 3 — BSPWM-integratie

**Doel:** live workspaces, layoutindicator en (optioneel) venstertitel in de bar.

### Stappen

- [x] `src/services/Bspwm.qml`:
  - [x] `bspc wm -g` bij startup voor de beginstatus.
  - [x] `Process { command: ["bspc", "subscribe", "report"] }` met `SplitParser`.
  - [x] `src/utils/ReportParser.js` parseert `M/m`, `O/o`, `F/f`, `U/u`, `L(T|M)`, `T(...)`, `G(...)`.
  - [x] Properties: `monitors`, `desktops`, `focusedDesktop`, `layout`, `activeNodeState`, `activeNodeFlags`.
  - [x] Commando's: `focusDesktop(name)`, `focusNext/Prev`, `toggleLayout()`.
  - [x] Foutpad: "bspwm niet actief" tonen als `bspc` ontbreekt of faalt.
- [x] `src/components/Workspaces.qml`: 1–9, focus/bezet/urgent-styling, layoutindicator (T/M), klikken en scrollen.
- [x] `src/components/ActiveWindow.qml` (optioneel): titel van de gefocuste bspwm-node, verversen op `node_focus`.
- [x] Werkt ook zonder bspwm (voor testen in LXQt).

### Verificatie

- [x] Desktop wisselen via toetsen én via de bar; status klopt direct.
- [x] Een venster openen/sluiten kleurt de juiste workspace.
- [x] Urgent-hint testen (`bspc node -g urgent` bestaat niet in 0.9.12; getest via de ICCCM WM_HINTS-urgency op een venster op een niet-gefocuste desktop).
- [x] Layout wisselen (`Super+m`) toont M/T in de bar.
- [x] `bspc wm -r` laat de bar netjes herstarten of opnieuw verbinden.

**Klaar als:** de bar de BSPWM-status foutloos en zonder merkbare vertraging volgt.

### Uitvoeringsnotities (fase 3)

- **Reportformaat:** de regel begint met `status_prefix` (standaard `W`), direct
  gevolgd door de eerste monitor. Daarna volgen per monitor de desktops
  (`O/o/F/f/U/u`), één `L(T|M)` en — alleen als die desktop een gefocuste node
  heeft — `T(T|P|F|=|@)` en `G(S?P?L?M?)`. Ontbreekt de gefocuste node (lege
  desktop), dan ontbreken `T` en `G` volledig; de parser zet de state dan op
  leeg. `T@` betekent een receptacle zonder client. `G` gebruikt
  S=sticky, P=private, L=locked, M=marked.
- **Node-states:** `T` = tiled, `P` = pseudo_tiled, `F` = floating,
  `=` = fullscreen, `@` = receptacle. De parser bewaart de layout en node-
  status alleen van de gefocuste monitor (hoofdletter `M`), zodat een tweede
  monitor het beeld niet overschrijft.
- **Desktopselectie:** `bspc desktop -f <monitor>:<naam>` is geen geldige
  selector; `monitor:^n` (de n-de desktop van die monitor) wel. De bar geeft
  daarom de index mee. Klikken, scrollen (`next`/`prev`) en de layoutbadge
  (klik = `bspc desktop -l next`) zijn op de echte sessie getest.
- **Urgent:** `bspc node -g urgent` is in bspwm 0.9.12 geen geldige sleutel.
  Urgency wordt extern via `WM_HINTS` gezet; bovendien negeert bspwm urgentie
  op de gefocuste node van de gefocuste desktop. Getest met een xterm op
  desktop 2: het rapport werd `u2`, workspace 2 kleurde rood, en focus naar
  desktop 2 wist de urgentie weer.
- **Venstertitel:** `xdotool getactivewindow` blijft na het wisselen naar een
  lege desktop het verborgen venster teruggeven. Daarom vraagt ActiveWindow
  eerst `bspc query -N -n focused` op en haalt daarna de titel van precies die
  node op. Zonder bspwm (LXQt) valt het terug op `getactivewindow`. Naast
  `node_focus` ververst ook een wijziging van `focusedDesktop` en een poll van
  5 s (voor titelwijzigingen zonder focuswissel).
- **Herverbinden:** als `bspc subscribe report` stopt (bijvoorbeeld door
  `bspc wm -r`), zet de service `available` op false en probeert elke 5 s
  opnieuw verbinding te maken met `bspc wm -g` + een nieuw abonnement. Getest
  door het subscribe-proces te killen én met een echte `bspc wm -r`: de bar
  bleef draaien en had binnen enkele seconden weer de juiste status.
- **Zonder bspwm:** getest in een geneste Xephyr (`:1`) met een ongeldige
  `BSPWM_SOCKET`. De bar toont dan de terugvalrij 1–9 met "bspwm niet actief";
  er verschijnen geen QML-fouten en de rest van de bar blijft werken.
- **Diagnostiek:** `qs ipc call bspwm status` geeft de volledig geparseerde
  status als JSON (monitors, desktops, layout, node-state en flags). Handig om
  de bar met `bspc wm -g` te vergelijken.

---

## Fase 4 — Weer Eindhoven

**Doel:** actueel weer met 3-daagse verwachting, cache en foutafhandeling.

### Stappen

- [x] `src/services/Weather.qml`:
  - [x] Open-Meteo-endpoint:
    `https://api.open-meteo.com/v1/forecast?latitude=51.4416&longitude=5.4697&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Europe%2FAmsterdam&forecast_days=4&temperature_unit=celsius&wind_speed_unit=kmh`
  - [x] Ophalen met `curl -fsS --max-time 10`, parsen met `JSON.parse`.
  - [x] Timer: elke 10 minuten; bij fout na 60 s opnieuw.
  - [x] Cache laatste goede respons in `Quickshell.cachePath("weather-eindhoven.json")`.
  - [x] `src/utils/WeatherCodes.js`: WMO-code → Nederlandse tekst + icoon.
- [x] `src/components/WeatherWidget.qml`: icoon + temperatuur; foutstatus "—".
- [x] `src/popups/WeatherPopup.qml`: gevoelstemperatuur, luchtvochtigheid, wind, neerslagkans, min/max, 3 dagen, "laatst bijgewerkt".

### Verificatie

- [x] Temperatuur komt overeen met een externe bron.
- [x] Na 10 minuten (of handmatige refresh) verandert de data.
- [x] Netwerk uitschakelen → laatst bekende waarde + "laatst bijgewerkt" blijft zichtbaar.
- [x] `curl`-fout levert geen QML-fouten of crash op.

**Klaar als:** het weer betrouwbaar is, ook zonder netwerk, en de popup alle gewenste informatie toont.

### Uitvoeringsnotities (fase 4)

- **Service en cache:** `Weather.qml` haalt de respons op met `curl -fsS
  --max-time 10`, normaliseert `current` en `daily` naar een klein object en
  bewaart elke geslaagde respons als
  `{ "fetchedAt": <epoch-ms>, "response": <ruwe Open-Meteo-JSON> }` in
  `Quickshell.cachePath("weather-eindhoven.json")` (atomair via `FileView`).
  Bij het starten leest `blockLoading` de cache synchroon; een kale respons
  zonder wrapper wordt ook geaccepteerd. Een mislukte fetch wist `current` en
  `lastUpdated` niet, maar zet `lastError` en start de 60s-retrytimer. Na een
  geslaagde fetch (ook een handmatige) begint de 10-minutentimer opnieuw.
- **Verwachting:** de endpoint vraagt `forecast_days=4` (vandaag + 3 dagen).
  De popup toont de min/max van vandaag in de detailrij en de drie volgende
  dagen in de lijst. `weather_code` wordt via `WeatherCodes.js` omgezet naar
  Nederlandse tekst en een Font Awesome 6 Solid-icoon (codepoints
  gecontroleerd tegen `fa-6.7.2-solid-900.ttf`).
- **Widget en popup:** de widget toont icoon + temperatuur en klikt de popup
  open/dicht. Heeft de service wel cache maar geen netwerk, dan blijft de
  temperatuur staan met een geel waarschuwingsdriehoekje; zonder enige data
  staat er "—". De popup toont vocht, wind, neerslagkans, min/max, de drie
  dagen, "Laatst bijgewerkt" en een offline-label. De verversknop draait
  tijdens het ophalen.
- **Offline getest** met een tweede geneste instantie en
  `WEATHER_ENDPOINT=http://127.0.0.1:9/forecast` (alleen voor tests; zonder
  override wordt de Open-Meteo-URL gebruikt). Met cache: waarde en
  "laatst bijgewerkt" bleven zichtbaar, `error` gevuld, geen QML-fouten. Zonder
  cache: "—", "Geen gegevens", "Laatst bijgewerkt: nooit" en de foutmelding;
  daarna de cache hersteld.
- **X11 en sluiten:** een klik buiten de popup wordt onder X11 niet
  gedetecteerd (issue #794; `grabFocus` werkt hier niet). Een transparant
  schermvullend venster als klikvanger is verworpen: zonder actieve compositor
  wordt dat zwart (de picom in deze sessie heeft geen `_NET_WM_CM_S0`). De
  popup sluit daarom via de X-knop, een tweede klik op de weerwidget, een klik
  op een leeg stuk van de bar, of IPC.
- **IPC:** `qs ipc call weather status` geeft alle genormaliseerde velden,
  fout, cachepad en laatst-bijgewerkt; `weather refresh` forceert een fetch en
  `weather open|close|toggle` bedient de popup. Handmatige refresh werkte
  (tijdstempel verschoof); de temperatuurwaarde zelf kan binnen het
  15-minutenvenster van het model gelijk blijven.
- **Controle:** de live waarden (5,2 °C, gevoel 2,7 °C, 89% vocht, 7,2 km/u,
  code 51) kwamen exact overeen met een directe `curl` naar dezelfde endpoint.
  Getest in een geneste bspwm-sessie (Xephyr :1) en in de echte sessie (:0).

---

## Fase 5 — Systemtray

**Doel:** StatusNotifierItem-iconen met werkende menu's.

### Stappen

- [x] `src/components/TrayWidget.qml` met `SystemTray.items` en een `Repeater`.
- [x] `Image { source: item.icon }`, fallback-icoon bij ontbreken.
- [x] Klik → `item.activate()`; middenklik → `item.secondaryActivate()`; scroll → `item.scroll(delta, horizontal)`.
- [x] Menu → `item.display(barWindow, x, y)`; fallback `QsMenuAnchor` met `item.menu`.
- [x] Tooltip met `tooltipTitle` / `tooltipDescription`.
- [x] Alleen tonen als er items zijn; geen lege ruimte.

### Verificatie

- [x] `nm-applet` of `blueman-applet` starten; icoon verschijnt.
      → `nm-applet` valt op deze Debian-build terug op XEmbed en registreert
      geen SNI; getest met `nm-tray` (Qt/SNI) en een tijdelijke fake-SNI.
- [x] Menu opent op de juiste positie en is bruikbaar.
- [x] App sluiten → icoon verdwijnt.
- [x] Tooltip toont de juiste tekst.

**Klaar als:** gangbare SNI-apps correct verschijnen en hun menu's werken. Documenteer dat legacy XEmbed-icons niet worden ondersteund.

### Uitvoeringsnotities (fase 5)

- **Component:** `TrayWidget` toont `SystemTray.items` in een `Repeater`.
  Iconen worden met `Image` op 16×16 getekend (`sourceSize`, aspect
  behouden). Is `item.icon` leeg of laadt het plaatje niet, dan verschijnt
  een neutraal Font Awesome-icoon; levert Quickshell zelf een
  placeholder-pixmap, dan wordt die getoond. De widget én de
  scheidingslijn in de bar zijn alleen zichtbaar als `hasItems` waar is,
  dus zonder tray-apps blijft er geen lege ruimte over.
- **Klikgedrag:** links = `activate()`, midden = `secondaryActivate()`,
  rechts = menu. Bij `onlyMenu`-items opent een linkse klik het menu in
  plaats van `activate()`. Scrollen geeft `scroll(±1, verticaal/horizontaal)`.
  Getest met een fake-SNI: `Activate(0,0)`, `SecondaryActivate(0,0)`,
  `Scroll(1, vertical)` en `Scroll(-1, vertical)` kwamen exact zo binnen.
- **Menu's en `UseQApplication`:** Quickshell tekent tray-menu's met
  QtWidgets' `QMenu`. Daarvoor staat `//@ pragma UseQApplication` boven aan
  `shell.qml`; zonder die pragma weigert Quickshell zowel `item.display()`
  als `QsMenuAnchor` (met een `qCritical`). Beide paden zijn getest:
  `item.display()` op de echte sessie en `QsMenuAnchor` in een geneste
  sessie met `QS_TRAY_FALLBACK_MENU=1`. De menu's verschijnen onder de bar;
  de coördinaten komen uit `barWindow.contentItem.mapFromItem(button, …)`.
  Het menu is een native `QMenu` met het systeempalet (licht); een donker
  thema is een polijstpunt voor fase 9.
- **Anker-valkuil (X11):** `anchor.item` werkte in 0.3.2 niet betrouwbaar.
  Een `PopupWindow` met `anchor.item` bleef onzichtbaar (`visible` werd
  `true`, maar er kwam geen X-venster), en `QsMenuAnchor` met `anchor.item`
  opende het menu op y=6 over de bar heen. Beide gebruiken nu
  `anchor.window` + `anchor.rect` met venstercoördinaten; daarna stond de
  tooltip netjes gecentreerd onder het icoon en het menu op y=30.
- **Tooltip:** aparte `PopupWindow`, 350 ms vertraging, met
  `tooltipTitle` (valt terug op `title`) en `tooltipDescription`. Hij
  verdwijnt bij het verlaten van het icoon, bij openen van een menu, bij
  verbergen van de bar en als het tray-item verdwijnt. Getest met een
  fake-SNI met titel en beschrijving; de popup verscheen op de juiste
  plek en de tekst kwam overeen met de SNI-properties.
- **Testopzet:** naast de echte sessie (`:0`) is een geneste Xephyr (`:3`)
  met een eigen `dbus-daemon` gebruikt. Daarin draaiden een tweede
  Quickshell-instantie, `nm-tray` en een tijdelijk Python-fake-SNI
  (`/tmp`, niet in de repo) met ToolTip, `Activate`, `SecondaryActivate` en
  `Scroll`. Zo konden tooltip, klikken en scrollen worden gecontroleerd
  zonder de echte sessie te beïnvloeden.
- **XEmbed:** `nm-applet` is op deze Debian-build tegen
  libayatana-appindicator gelinkt, maar registreert hier geen
  StatusNotifierItem; het valt terug op XEmbed en verschijnt dus niet in de
  Quickshell-tray. `nm-tray` (Qt/SNI) werkt wel en is voor de verificatie
  gebruikt. `blueman-applet` registreerde zonder actieve `bluetoothd` geen
  item. Legacy XEmbed wordt bewust niet ondersteund; dat staat ook in de
  kop van `TrayWidget.qml`.
- **Eenmalige X-hang:** tijdens een test met `blueman-applet` (zonder
  actieve bluetoothd) liep de X-server één keer vast; dit was niet
  reproduceerbaar in de geneste sessie met een eigen fake-SNI. De sessie is
  hersteld door `qs`, `sxhkd` en `picom` opnieuw te starten. Voor volgende
  fasen is blueman als testapplet vermeden.

---

## Fase 6 — Notificatieserver

**Doel:** Quickshell is de enige notificatiedaemon, met popups, geschiedenis, acties en DND.

### Stappen

- [x] `src/services/NotificationDaemon.qml`:
  - [x] `NotificationServer { actionsSupported: true; imageSupported: true; bodyMarkupSupported: false; keepOnReload: true }`.
  - [x] Inkomende notificatie: `tracked = true`; geschiedenis max. 50 (oudste eruit).
  - [x] DND-state; badge-teller.
- [x] `src/popups/NotificationStack.qml`: één `PopupWindow` rechtsboven onder de bar, max. 4 kaarten.
  - [x] App-icoon, appnaam, samenvatting, body, actieknoppen (`action.invoke()`), sluitknop.
  - [x] Time-out op basis van `expireTimeout`; low 4 s, normal 8 s, critical nooit automatisch; hover pauzeert.
- [x] `src/popups/NotificationCenter.qml`: geschiedenis, "wis alles", per-item sluiten/openen.
- [x] `src/components/NotificationBell.qml`: bel + DND-schakelaar + badge.
- [x] Controle dat `lxqt-notificationd` niet in de bspwm-sessie start; logwaarschuwing bij een D-Bus-conflict.
- [x] Notificatiepopups zonder `grabFocus` (X11-beperking); klikken blijft werken.

### Verificatie

- [x] `notify-send "Test" "Hallo"` toont een popup met de juiste app-info.
      → `notify-send` (libnotify-bin) is hier niet geïnstalleerd; getest met
      `scripts/test-notifications.sh` (gdbus, dezelfde D-Bus-API).
- [x] `notify-send -u critical "Belangrijk" "Blijft staan"` verdwijnt niet automatisch.
- [x] `notify-send -A "Open=open" "Actie" "Klik"` toont een werkende actieknop.
- [x] DND aan → geen popups, wel geschiedenis en badge.
- [x] `qs ipc call notifications clear` (of vergelijkbaar) wist de geschiedenis.
- [x] `qs ipc call notifications dnd true` schakelt DND.
- [x] Quickshell herladen behoudt notificaties (`keepOnReload`).

**Klaar als:** notificaties volledig via Quickshell lopen en er geen andere daemon actief is.

### Uitvoeringsnotities (fase 6)

- **Service en levensduur:** `NotificationDaemon` is een singleton met
  `NotificationServer` (acties, afbeeldingen, geen body-markup,
  `keepOnReload`). Elke melding krijgt `tracked = true`; anders ruimt de
  server het object direct na het signaal op. De geschiedenis is een lijst
  van `{ notification, receivedAt }` (nieuwste eerst, max. 50); popups staan
  apart (max. 4). Transiente meldingen komen alleen als popup en niet in de
  geschiedenis. Een vervanging (`replaces_id`) of een na reload opnieuw
  aangeboden melding (`lastGeneration`) wordt op id gededupliceerd, zodat de
  geschiedenis geen dubbele regels krijgt. Bij meer dan 50 meldingen wordt de
  oudste met `tracked = false` opgeruimd.
- **Time-out:** Quickshell 0.3.2 levert `expireTimeout` in **milliseconden**
  (de D-Bus-specificatie), ook al zegt de documentatie seconden. Daarom:
  kritiek nooit automatisch, `0` nooit, een positieve waarde letterlijk in ms
  en `-1` de standaardkeuze (laag 4 s, normaal 8 s). Getest met een expliciete
  3000 ms en met critical; die bleef na 10 s staan.
- **Hover pauzeert:** onder X11 krijgt een `PopupWindow` geen leave-event als
  de aanwijzer naar een ander venster gaat. `MouseArea.containsMouse` en
  `HoverHandler.hovered` bleven daardoor hangen en de popup verdween nooit
  meer. De stack pollt daarom alleen zolang er een popup met time-out
  zichtbaar is elke 250 ms `xdotool getmouselocation --shell` en vergelijkt de
  schermcoördinaten met de kaart. Zonder `xdotool` werkt de time-out gewoon,
  alleen zonder hover-pauze. Getest: 10 s boven de kaart bleef staan, daarna
  binnen 8 s verdwenen.
- **Popups:** rechts uitgelijnd onder de bar, nieuwste bovenaan, maximaal vier
  kaarten. App-icoon via `Quickshell.iconPath` met terugval op een Font
  Awesome-bel; de body wordt als `PlainText` getoond (geen markup), een
  `image`-hint verschijnt als 56 px-afbeelding. Actieknoppen roepen
  `action.invoke()` aan en sluiten daarna de popup; de X sluit alleen de
  popup, de melding blijft in het centrum. Geen `grabFocus`, alle knoppen
  zijn `MouseArea`s.
- **Centrum:** `PopupWindow` met geschiedenis, relatieve tijd (ververst elke
  30 s), DND-schakelaar, "Wis alles" en per item een X (definitief sluiten).
  Klikken op een item klapt het open/dicht; opengeklapt verschijnen de
  volledige body en de actieknoppen. Openen markeert alles als gelezen.
- **Bel, DND en badge:** de bel opent/sluit het centrum (rechtsklik = DND);
  het maantje ernaast is de aparte DND-schakelaar (geel = aan). De badge
  toont het aantal ongelezen meldingen. DND aan verbergt bestaande popups
  maar laat ze in de geschiedenis staan; nieuwe meldingen komen wel in de
  geschiedenis en teller, niet als popup (ook critical, conform het plan).
- **Conflictcontrole:** 1,2 s na de start vraagt de service met `gdbus` de
  PID van de eigenaar van `org.freedesktop.Notifications` op en vergelijkt
  die met `Quickshell.processId`. Wijkt die af, dan verschijnt een
  `console.warn` en staat de melding in `notifications status`. Getest in een
  geneste Xephyr met eigen `dbus-run-session` en een Python-proces dat de
  naam bezit: zowel Quickshell ("Could not register…") als onze service
  ("… is eigendom van PID 34909 (Quickshell is 34920)") waarschuwden.
- **Geen tweede daemon:** `pgrep -f lxqt-notificationd` is leeg,
  `~/.config/autostart` bestaat niet en `bspwmrc` start geen
  notificatiedaemon. In de echte sessie is Quickshell de enige eigenaar van
  `org.freedesktop.Notifications`.
- **Testscript:** `scripts/test-notifications.sh basic|critical|action|all`
  gebruikt `gdbus` (of `notify-send` als dat aanwezig is). Acties zijn
  gecontroleerd met `dbus-monitor`: klikken op "Open" gaf `ActionInvoked`
  (id + `open`) en daarna `NotificationClosed` (reason 2). Getest zijn verder:
  vijf meldingen → vier popups, geschiedenis 50 bij 55 meldingen, DND,
  transient (geen geschiedenis), afbeelding, vervanging, wissen, per-item
  sluiten, herladen en de wisselwerking met de weerpopup (openen van het een
  sluit het ander).
- **IPC:** `qs ipc call notifications status | clear | dnd <bool> | getDnd |
  open | close | toggle`. `status` geeft DND, conflict, ongelezen-aantal,
  popups en geschiedenis als JSON.
- **Iconen:** in deze sessie is er geen Qt-platformthema
  (`QT_QPA_PLATFORMTHEME` leeg), waardoor `QIcon` geen Papirus-thema kent en
  app-icoonnaamnamen als "dialog-information" niet resolven. De popups
  vallen dan netjes terug op de bel. Een icon-thema instellen is een
  polijstpunt voor fase 9.

---

## Fase 7 — Instellingenvenster voor BSPWM

**Doel:** gaps, randen, layouts, kleuren en gedrag live aanpassen en persistent opslaan.

### Stappen

- [x] `src/services/BspwmSettings.qml`:
  - [x] Bij startup `settings.json` lezen (`FileView`, `blockLoading`).
  - [x] Wijzigingen direct toepassen met `bspc config` (120 ms debounce voor sliders).
  - [x] Opslaan met `FileView.setText()` (500 ms debounce, atomair).
  - [x] `reset()` naar `settings.default.json`.
- [x] `src/windows/SettingsWindow.qml` als `FloatingWindow` (±900×640, titel "BSPWM-instellingen"), verborgen tot `visible = true`.
- [x] Tabs:
  - [x] **Gaps & randen**: `window_gap`, `border_width`, per-monitor padding, monocle-opties.
  - [x] **Lay-outs**: `tiled`/`monocle` per desktop, `automatic_scheme`, `initial_polarity`, `split_ratio`, rotate/flip/balance/equalize/circulate, `single_monocle`, `borderless_singleton`.
  - [x] **Kleuren & thema**: focused/normal/active/presel-kleuren, hex-invoer, presets (Catppuccin, Nord, Gruvbox, Tokyo Night).
  - [x] **Gedrag**: `focus_follows_pointer`, `pointer_follows_focus`, `click_to_focus`, `pointer_modifier`, `swallow_first_click`, `ignore_ewmh_fullscreen`, `remove_unplugged_monitors`, `merge_overlapping_monitors`.
  - [x] **Info/acties**: versies, paden, "BSPWM herstarten", "Sxhkd herladen", "Quickshell herladen".
- [x] Waarschuwing in de UI: bar-struts + bspwm-padding kunnen dubbel ruimte innemen; standaard padding 0.
- [x] `IpcHandler` target `settings`: `open()`, `close()`, `toggle()`.
- [x] Koppeling met de bar: tandwiel-icoon opent het venster; kleurwijzigingen werken direct door in `Theme`.
- [x] bspwm-regel voor float/centreren controleren.
- [x] Optioneel: layout opslaan/herstellen met `bspc wm -d` en `bspc wm -l <absoluut pad>`.

### Verificatie

- [x] `Super+Shift+S` en het tandwiel openen het venster; toetsenbordfocus werkt.
- [x] Gaps/randen wijzigen is direct zichtbaar in getilde vensters.
- [x] Kleur wijzigen verandert zowel BSPWM-randen als de bar.
- [x] Na `bspc wm -r` zijn alle waarden behouden.
- [x] "Standaardwaarden" herstelt de default-JSON en past dit toe.
- [x] Layoutknoppen werken op de gefocuste desktop.

**Klaar als:** alle gevraagde BSPWM-instellingen via de GUI te wijzigen zijn, live werken en een herstart overleven.

### Uitvoeringsnotities (fase 7)

- **Service:** `BspwmSettings` leest `settings.json` met `FileView`
  (`blockLoading`) en gebruikt `settings.default.json` als terugval. Er staat
  bewust géén `watchChanges` op: een watcher kon vlak na onze eigen atomaire
  schrijfactie nog de oude inhoud inlezen en de zojuist gezette waarde
  terugdraaien. `Theme.qml` houdt wel een watcher voor de barkleuren; die
  schrijft nooit. Sliders gaan met 120 ms debounce naar een commandowachtrij;
  gelijke `bspc`-commando's worden gecoalesceerd. Het bestand wordt 500 ms later
  atomair geschreven. `reset()` past de default onmiddellijk toe en schrijft
  direct.
- **Venster:** `SettingsWindow` is een `FloatingWindow` van 940×680 met vijf
  tabs. De kleurvelden zijn echte `TextInput`s; onder X11 werkt dat alleen in
  een FloatingWindow (issue #794). Escape sluit het venster; een tweede klik op
  het tandwiel of `Super+Shift+S` toggelt het.
- **Bspwm-regel:** Quickshell 0.3.2 zet onder X11 geen `WM_CLASS` op een
  FloatingWindow. De regel `bspc rule -a '*:*:BSPWM-instellingen' state=floating
  center=on` matcht op de venstertitel; voor het sneltoetsenvenster staat
  dezelfde regel met `Sneltoetsen`. Zonder die regel opende het venster niet
  gecentreerd (deels buiten het scherm).
- **Kleuren en thema:** `Theme` leest dezelfde JSON met `JsonAdapter`, dus een
  preset of hex-wijziging kleurt direct zowel de BSPWM-randen als het accent in
  de bar. Getest met Dracula (`#bd93f9`): `bspc config focused_border_color`
  en de accenten in de bar veranderden mee. Er zijn acht presets.
- **Lay-outs:** de tab toont de gefocuste desktop plus T/M-knoppen per desktop
  van de gefocuste monitor. `Bspwm.refreshDesktopLayouts()` haalt daarvoor
  `bspc query -T -m` op. Roteren, flippen, balanceren, equalizen, circuleren en
  layout bewaren/herstellen zitten onder "Boom transformeren".
- **Getest:** slider van 8 naar 18 px (direct `bspc config window_gap` en in
  `settings.json`), GUI-reset naar 8/2/#89b4fa, kleurpreset Dracula,
  layoutknop T/M op desktop 1, `bspc wm -r` met gap 11 en paarse rand (waarden
  bleven behouden), en het tandwiel in de bar.
- **Let op:** `settings.json` is een gebruikerskopie, geen symlink; de repo
  blijft de bron voor `settings.default.json` en de scripts. De IPC-commando's
  hebben `qs -p /home/simon/projecten/quickshell` nodig.

---

## Fase 8 — Sneltoetsenoverzicht + definitieve sxhkdrc

**Doel:** een doorzoekbaar overzicht dat exact de sxhkdrc volgt, plus een complete sneltoetsenset.

### Stappen

- [x] `src/utils/SxhkdParser.js`: comments, hotkeys, ingesprongen commando's, regelcontinutie (`\`), chord-chains (`;`/`:`), brace-expansie.
- [x] Conventie vastleggen: comment direct boven een hotkey = omschrijving; `# --- Sectie ---` = groepskop.
- [x] `src/windows/ShortcutsWindow.qml` als `FloatingWindow` (±900×640, titel "Sneltoetsen"):
  - [x] `FileView` op `~/.config/sxhkd/sxhkdrc` met `watchChanges: true`.
  - [x] Zoekveld (werkt door `FloatingWindow`), keycaps, commando in monospace.
  - [x] Groepen: Algemeen, Vensters, Workspaces, Layout, Media, Screenshots, Sessie, Quickshell.
- [x] `IpcHandler` target `shortcuts`: `open()`, `close()`, `toggle()`.
- [x] Bar-icoon + `Super+/` koppelen.
- [x] `config/sxhkd/sxhkdrc` afmaken:

  | Categorie | Voorbeelden |
  |---|---|
  | Apps | `Super+Return` terminal, `Super+d` rofi, `Super+Shift+b` browser, `Super+Shift+f` bestandsbeheer |
  | Vensters | `Super+hjkl` focus, `Super+Shift+hjkl` verplaatsen, `Super+q` sluiten, `Super+Shift+q` kill, `Super+f` fullscreen, `Super+t` tiled, `Super+s` floating |
  | Workspaces | `Super+1..9` focus, `Super+Shift+1..9` venster meenemen |
  | Layout | `Super+m` monocle, `Super+Shift+t` toggle, `Super+Shift+r` roteren, `Super+Shift+Space` balance, `Super+Shift+e` equalize |
  | Preselect | `Super+Ctrl+hjkl`, `Super+Escape` annuleren |
  | Quickshell | `Super+Shift+S` instellingen, `Super+/` sneltoetsen, `Super+Shift+N` notificatiecentrum, `Super+Shift+D` DND |
  | Media | XF86-toetsen → `pactl` / `playerctl` / `brightnessctl` |
  | Screenshots | `Print`, `Shift+Print` (regio via maim/slop), `Super+Print` (venster) |
  | Sessie | `Super+Alt+L` lock, `Super+Alt+E` bspwm afsluiten, `Super+Shift+P` powermenu |

- [x] Elke hotkey voorzien van een beschrijvende comment.
- [x] Herladen: `pkill -USR1 sxhkd`.

### Verificatie

- [x] `Super+/` opent het overzicht; alle bindings zijn zichtbaar en gegroepeerd.
- [x] Zoeken op "terminal", "workspace" en "Super+Shift" filtert correct.
- [x] Een hotkey toevoegen aan sxhkdrc + `pkill -USR1 sxhkd` → overzicht werkt bij.
- [x] Alle sneltoetsen uit de tabel daadwerkelijk testen.
- [x] `qs ipc call shortcuts toggle` werkt.

**Klaar als:** het overzicht en de sxhkdrc aantoonbaar dezelfde bron zijn en alle sneltoetsen werken.

### Uitvoeringsnotities (fase 8)

- **Parser:** `SxhkdParser.js` (`.pragma library`) leest comments, secties
  (`# --- … ---`), ingesprongen commando's, `\`-continuties, chord-chains
  (`;`/`:`) en brace-expansie. Brace-groepen in de hotkey en het commando
  worden parallel uitgeklopt als de groepen even groot zijn; dat is precies
  wat `{h,j,k,l}` + `{west,south,north,east}` en `{1-9}` + `'^{1-9}'` nodig
  hebben. Ook bereiken (`{1-9}`, `{a-z}`) en `_` (lege optie) worden
  ondersteund.
- **Venster:** `ShortcutsWindow` is een FloatingWindow van 940×680. De
  `FileView` staat op `~/.config/sxhkd/sxhkdrc` met `watchChanges`; omdat een
  symlink onder X11 niet altijd een change-event geeft, doet de window bij
  openen ook expliciet `reload()` + een korte timer. Zo werkt het overzicht
  ook direct na `pkill -USR1 sxhkd`.
- **Zoeken en groepen:** het zoekveld filtert op omschrijving, toetsen,
  commando en groep; de groepschips kiezen een sectie. Resultaat: 69
  bindingen, 9 groepen (Algemeen, Vensters, Workspaces, Layout, Preselect,
  Quickshell, Media, Screenshots, Sessie). Getest: "terminal" → 1,
  "workspace" → 19, "Super+Shift" → 24; chip "Vensters" → 13. Testbinding
  `Super+F12` toegevoegd + `pkill -USR1 sxhkd` → 70 regels, daarna netjes
  terug naar 69.
- **Bron van waarheid:** het venster parseert het bestand zelf; er is geen
  tweede keybindinglijst. `docs/keybindings.md` is alleen een momentopname en
  verwijst naar `Super+/` voor de live versie.
- **Sxhkdrc:** alle categorieën uit de tabel zijn gevuld, inclusief media,
  screenshots en sessie. Elke hotkey heeft een comment. `Super+Alt+L`
  (vergrendelen) en `Super+Alt+E` (BSPWM afsluiten) wijken af van het plan,
  omdat `Super+Shift+L` botst met "venster naar links verplaatsen" en
  `Super+Shift+E` met equalize. Balanceren is `Super+Shift+Space`, omdat
  `Super+Shift+B` de browser is.
- **`qs ipc` en `-p`:** de sxhkdrc gebruikt
  `qs -p "$HOME/projecten/quickshell" ipc call …`; zonder `-p` kan de
  Quickshell-client de draaiende instantie niet vinden en gebeurt er niets.
- **Getest met xdotool:** `Super+Return`, `Super+D` (rofi), `Super+Shift+F`
  (pcmanfm), `Super+H/J/K/L`, `Super+Shift+H/J/K/L`, `Super+Q`,
  `Super+Shift+Q`, `Super+F` (toggle), `Super+S`, `Super+T`,
  `Super+1…9`, `Super+Shift+1…9`, `Super+M`, `Super+Shift+T`,
  `Super+Shift+R/Space/E`, preselect + Escape, volume/mute/micmute,
  `Print`/`Shift+Print`/`Super+Print`, `Super+Alt+L`, `Super+Shift+P`,
  `Super+Shift+S`, `Super+/`, `Super+Shift+N`, `Super+Shift+D`.
  `Super+Alt+E` en vergrendelen zijn bewust niet destructief getest; het
  lock-script toont een melding omdat er geen locker is geïnstalleerd.
- **Screenshots:** `Print` schrijft naar `~/Pictures/screenshots` (map wordt
  aangemaakt), `Shift+Print` opent slop voor een regio, `Super+Print` pakt het
  actieve venster via `xdotool getactivewindow`. Regio getest door slop met
  Escape te annuleren.
- **Wallpaper:** `Super+W` roept `scripts/wallpaper-theme.sh next` aan, dat de
  volgende wallpaper zet én het kleurenpalet opnieuw genereert (zie
  “Aanvullend — Donker thema en wallpaper-palet”). Zonder matugen valt
  `bspwmrc` terug op Variety of `feh`.

---

## Fase 9 — Polijsten, optionele widgets en documentatie

---

## Fase 9 — Polijsten, optionele widgets en documentatie

**Doel:** afronden, extras, en overdraagbare documentatie.

### Stappen

- [x] Volume-widget via `Quickshell.Services.Pipewire` (klik = mute, scroll = volume).
- [x] Accu-widget via `Quickshell.Services.UPower` (alleen tonen als er een accu is).
- [x] Optioneel: MPRIS-spelerwidget.
- [x] Optioneel: polkit-agent via Quickshell, of `lxpolkit` autostarten.
- [x] Optioneel: watchdog voor Quickshell in `bspwmrc`.
- [x] Optioneel: thema-presets uitbreiden en picom afstemmen op de VM-GPU.
- [x] `README.md`: installatie, starten, sneltoetsen, configpaden, troubleshooting (X11-issues, notificatieconflict, tray-beperkingen).
- [x] `docs/keybindings.md` (optioneel) als leesbare referentie.
- [x] Screenshot(s) toevoegen.
- [x] Volledige acceptatietest doorlopen.

### Verificatie

- [x] Volume en accu (indien aanwezig) werken en verversen live.
- [x] `qs -p …` start schoon na een volledige logout/login.
- [x] README is genoeg om de installatie opnieuw te doen.
- [x] Alle acceptatiecriteria hieronder zijn afgevinkt.

**Klaar als:** de desktop dagelijks bruikbaar is en de documentatie compleet is.

### Uitvoeringsnotities (fase 9)

- **Volume:** `VolumeWidget` gebruikt `Pipewire.defaultAudioSink` als
  PipeWire beschikbaar is en valt anders terug op `pactl`. Deze VM draait
  PulseAudio zonder PipeWire-daemon, dus de terugval is live getest:
  `pactl get-sink-volume` gaf 46%, klikken op de widget wisselde
  `Mute: nee/ja`, scrollen gaf 46% → 51% → 46%. Als PipeWire later
  beschikbaar komt, schakelt de widget automatisch en stopt het pollen.
- **Accu:** `BatteryWidget` leest `UPower.displayDevice` en blijft onzichtbaar
  zonder aanwezige accu (deze desktop-UPower meldt `power supply: no` en 0%).
  Op een laptop ververst UPower de waarde vanzelf.
- **MPRIS:** `MprisWidget` toont de eerste speler met een titel, linksklik =
  play/pause, scroll = volgende/vorige. Op deze VM draait geen MPRIS-speler;
  de widget is dan onzichtbaar. De code gebruikt alleen de publieke
  `MprisPlayer`-API en faalt niet zonder speler.
- **Polkit:** `polkitd` en `polkit-agent-helper.socket` draaien systeemwijd,
  maar er startte geen authenticatieagent. `lxqt-policykit-agent` is via de
  LXQt-fallback al geïnstalleerd; `bspwmrc` start hem nu één keer per sessie.
  De agent moet in de grafische sessie draaien, anders kan `pkexec` niet om een
  wachtwoord vragen. `lxpolkit` werkte op deze machine niet met polkit 128
  (GTK-agent crasht bij de eerste aanvraag).
- **Watchdog:** Quickshell wordt bij sessiestart één keer gestart en
  `bspwmrc` start hem bij een nieuwe login/`bspc wm -r` niet dubbel. Een
  optionele watchdog staat achter `QUICKSHELL_WATCHDOG=1` (pidfile in
  `/tmp`), zodat een crash standaard niet eindeloos wordt gemaskeerd. De
  README beschrijft beide modi.
- **Thema/picom:** de presets zijn uitgebreid naar acht (Catppuccin, Nord,
  Gruvbox, Tokyo Night, Dracula, One Dark, Rosé Pine, Everforest). Picom staat
  al op `xrender` zonder vsync wegens de VM-GPU (fase 1); dat is in de README
  en config gedocumenteerd.
- **Rofi:** `config/rofi/config.rasi` geeft launcher en sessiemenu hetzelfde
  thema; de kleuren komen uit de gegenereerde `colors.rasi` (zie hieronder).
  Gedeployed als `~/.config/rofi/config.rasi`.
- **Documentatie:** `README.md` bevat installatie, symlinks, sneltoetsen,
  configpaden, IPC (met `-p`), widgets, tests, troubleshooting en bekende
  beperkingen. `docs/keybindings.md` is uit de parser gegenereerd.
  Screenshots: `docs/screenshot-bar.png`, `-settings.png`, `-shortcuts.png`.
- **Acceptatie:** de bar blijft boven fullscreen, struts/padding kloppen,
  weer werkt met cache, notificaties/tray/instellingen/sneltoetsen zijn
  getest, `qs ipc` werkt met `-p`, en de LXQt-sessie is niet gewijzigd.
  Beperkingen die overblijven zijn hardware-/pakketgebonden: geen accu, geen
  backlight en geen locker op deze VM, en alleen SNI-tray. De polkit-agent
  (`lxqt-policykit-agent`) is aanwezig en wordt door `bspwmrc` gestart.

---

## Aanvullend — Donker thema en wallpaper-palet (matugen)

**Doel:** één donker thema dat automatisch de kleuren van de wallpaper volgt,
voor de hele desktop.

### Wat er is gedaan

- [x] matugen 4.2.0 user-local in `~/.local/bin` (geen sudo; zit niet in Debian).
- [x] `config/matugen/config.toml` + templates voor Quickshell, GTK 3/4,
      alacritty en rofi; donkere modus, bronkleur = wallpaper.
- [x] `scripts/wallpaper-theme.sh`: zet de wallpaper (feh), genereert het palet,
      activeert Adwaita-dark + Papirus-Dark (GTK3/4 en libadwaita) en schrijft
      `~/.config/gtk-3.0/settings.ini` en `~/.config/gtk-4.0/settings.ini`.
- [x] `scripts/apply-wallpaper-theme.sh` (matugen-post-hook): neemt de
      BSPWM-kleuren over in `settings.json` en past ze direct toe met `bspc`.
- [x] `Theme.qml` leest `~/.config/bspwm/theme.generated.json` met `FileView`
      en `watchChanges`; zonder dat bestand blijft Catppuccin Mocha de terugval.
- [x] alacritty-config met import van de gegenereerde kleuren; rofi importeert
      `colors.rasi`; GTK krijgt `@define-color`-overschrijvingen voor accent-,
      venster- en kaartkleuren.
- [x] `bspwmrc` draait het script bij login, `Super+W` gaat naar de volgende
      wallpaper, en `QT_QPA_PLATFORMTHEME=gtk3` liet Qt-apps het GTK-thema en
      Papirus-iconen volgen (lost het ontbrekende icoonthema uit fase 6 op).
      Later vervangen door qt6ct, zie de volgende sectie.

### Verificatie

- [x] `scripts/wallpaper-theme.sh` → exit 0; `theme.generated.json` is geldige
      JSON met een `palette`- en `bspwm`-object.
- [x] `bspc config focused_border_color` = `colors.focused` uit
      `settings.json` = `palette.blue` uit het gegenereerde palet.
- [x] Bar-screenshot toont het nieuwe palet; het workspace-accent volgt de
      wallpaper.
- [x] `gsettings get … color-scheme` = `prefer-dark`, gtk-theme
      `Adwaita-dark`, icon-theme `Papirus-Dark`.
- [x] `rofi -dump-theme -config ~/.config/rofi/config.rasi` leest
      `colors.rasi`; alacritty parseert de gegenereerde `colors.toml`.

**Klaar als:** een nieuwe wallpaper via `Super+W` binnen een seconde de bar,
BSPWM-randen, terminal, rofi en GTK-apps in het bijpassende donkere palet zet.

### Uitvoeringsnotities

- **Waarom geen base16:** de base16-uitvoer van matugen kwam bij deze donkere
  gradient volledig bijna-zwart uit (alle `base08`–`base0f` ≈ `#10101x`).
  Daarom gebruikt het template `[config.custom_colors]` (`term_red`,
  `term_green`, …); matugen harmoniseert die met de bronkleur, zodat
  rood/groen/geel herkenbaar blijven én bij de wallpaper passen.
- **Twee kleurbronnen, één richting:** het volledige palet staat in
  `theme.generated.json` (Quickshell), terwijl `settings.json` de bron blijft
  voor `bspc` en het instellingenvenster. De post-hook schrijft alleen de vier
  BSPWM-kleuren over. Een handmatige preset of hex-waarde in het
  instellingenvenster overschrijft daarom alleen de randkleuren (en het accent
  in de bar) tot de volgende wallpaperwissel; het overige palet blijft van de
  wallpaper.
- **Wallpaperbeheer:** Variety is vervangen door het script, omdat Variety de
  wallpaper buiten de pijplijn om wisselt en het palet dan stil veroudert.
  `bspwmrc` gebruikt Variety alleen als matugen ontbreekt.
- **X11:** de wallpaper wordt met `feh --bg-fill` gezet (matugen doet dit via
  `[config.wallpaper]`). De bar hoeft niet te herstarten: `Theme` herlaadt het
  palet via `FileView.watchChanges`, ook na de atomische `mv` van
  `settings.json`. De post-hook past de randkleuren rechtstreeks met
  `bspc config` toe en roept bewust **niet** `apply-settings.sh` aan: dat zet
  de monitor-padding op 0 en zou de gereserveerde ruimte van de bar-strut
  wissen.
- **Getest op deze machine:** wallpaper `~/Pictures/wallpaper.jpg`
  (1920×1080, donkere gradient) → bron `#363253`, accent `#c7bfff`,
  achtergrond `#141318`. Bar en BSPWM-randen gebruikten direct de nieuwe
  waarden; `rofi -dump-theme` en de TOML-parser van alacritty accepteerden de
  gegenereerde bestanden.

---

## Aanvullend — Qt 6-thema dat aansluit bij Quickshell (qt6ct)

**Doel:** Qt-apps dezelfde donkere ontwerptaal geven als de bar: het
wallpaper-palet, JetBrains Mono, 6px-hoeken, surface-hovers en een
accentkleur voor selecties.

### Wat er is gedaan

- [x] qt6ct als Qt-platformplugin (`Fusion`), geactiveerd met
      `QT_QPA_PLATFORMTHEME=qt6ct` in `bspwmrc`; als qt6ct ontbreekt, blijft
      `gtk3` de terugval.
- [x] `scripts/apply-qt-theme.sh` leest `theme.generated.json` en schrijft het
      volledige QPalette (22 kleurrollen, inclusief `Accent` op Qt 6.6+) naar
      `~/.config/qt6ct/colors/quickshell-dark.conf` en de qt6ct-configuratie
      met JetBrains Mono 10,5 pt en Papirus-Dark. Zonder gegenereerd palet
      gebruikt het script dezelfde Catppuccin Mocha-terugval als `Theme.qml`.
- [x] `config/qt6ct/qss/quickshell.qss`: 6px-hoeken, surface0/surface1-hovers,
      accent-onderstreping bij tabs, slanke schuifbalken, menu's en tooltips
      in de popup-kleuren. De stylesheet gebruikt `palette(...)`, zodat hij
      automatisch meebeweegt met de wallpaper.
- [x] `apply-wallpaper-theme.sh` (matugen-post-hook) en `wallpaper-theme.sh`
      werken het Qt-palet direct bij; `bspwmrc` doet dit ook bij elke login,
      ook als matugen ontbreekt.
- [x] `scripts/install-qt6ct-user.sh`: fallback die het Debian-pakket met
      `apt-get download` uitpakt in `~/.local/opt/qt6ct` als er geen sudo is;
      `bspwmrc` zet dan `QT_PLUGIN_PATH` en `LD_LIBRARY_PATH`.
- [x] GTK krijgt dezelfde JetBrains Mono 10, zodat Qt- en GTK-apps naast
      elkaar dezelfde typografie houden.
- [x] README bijgewerkt (vereisten, installatie, paden, probleemoplossing) en
      `docs/screenshot-qt-theme.png` toegevoegd.

### Verificatie

- [x] PyQt6-testvenster met de user-local plugin: `style = qt6ct-style`,
      `font = JetBrains Mono 10.5`, `Window #1d2024`, `Base #181c20`,
      `Highlight #9dcbfb` (accent uit de actieve wallpaper).
- [x] qterminal en pcmanfm-qt in een geneste Xephyr tonen het donkere palet,
      JetBrains Mono, Papirus-Dark en hetzelfde accent; het contextmenu van
      pcmanfm-qt gebruikt de surface-hover uit de QSS.
- [x] Fallback zonder `theme.generated.json` levert het Catppuccin-palet
      (`#1e1e2e`, `#181825`, `#89b4fa`) en een geldige qt6ct-configuratie.
- [x] `sh -n` op alle gewijzigde shellscripts; `wallpaper-theme.sh` en de
      post-hook draaien zonder fouten.

### Uitvoeringsnotities

- **Kleurrollen:** qt6ct schrijft `QPalette::ColorRole` in enumvolgorde. Op
  Qt 6.11 is dat WindowText, Button, Light, Midlight, Dark, Mid, Text,
  BrightText, ButtonText, Base, Window, Shadow, Highlight, HighlightedText,
  Link, LinkVisited, AlternateBase, NoRole, ToolTipBase, ToolTipText,
  PlaceholderText en Accent. `NoRole` (index 17) wordt gevuld maar genegeerd.
- **Fontquoting:** QSettings leest een ongequote waarde met komma's als
  QStringList; daarom staat het font als
  `general="JetBrains Mono,10.5,-1,5,50,…"` in `qt6ct.conf`. Zonder quotes
  blijft de standaardfont staan.
- **Één bron:** de post-hook werkt zowel BSPWM als Qt bij. De QSS bevat geen
  vaste hexkleuren; alleen het gegenereerde QPalette verandert per wallpaper.
- **Sessie:** `QT_QPA_PLATFORMTHEME` wordt bij login gezet. In een al
  draaiende sessie moeten Qt-apps opnieuw starten (of de sessie opnieuw
  inloggen) voordat ze de plugin gebruiken.
- **Geen sudo op deze machine:** qt6ct is via `apt-get download` + `dpkg-deb`
  in `~/.local/opt/qt6ct` geplaatst. Dat werkt, maar een systeempakket heeft de
  voorkeur omdat het met Qt-updates meelift; de README noemt beide routes.

**Klaar als:** een Qt-app na login hetzelfde donkere palet, dezelfde mono-
typografie en dezelfde accentkleur toont als de Quickshell-bar, en na een
wallpaperwissel nieuwe Qt-vensters automatisch meebewegen.

---

## Aanvullende uitbreiding — Eigen sneltoetsen bewerken

**Doel:** vanuit het sneltoetsenoverzicht zelf nieuwe bindingen toevoegen,
bestaande eigen bindingen aanpassen of verwijderen, zonder een tweede lijst naast
de sxhkdrc te onderhouden.

- [x] Formulier in `ShortcutsWindow` (`Nieuwe sneltoets`): toetsen, omschrijving,
  groep en commando, met modifier-chips en validatie.
- [x] `SxhkdParser.js`: normaliseren/valideren van toetsen, dubbele combinaties
  detecteren en `@qs-shortcut`-blokken toevoegen, vervangen en verwijderen.
- [x] Eigen blokken staan achteraan `~/.config/sxhkd/sxhkdrc`; handmatige regels
  en secties worden nooit herschreven.
- [x] Na opslaan: atomaire schrijfactie, directe parse en `pkill -USR1 sxhkd`.
- [x] IPC: `shortcuts add`, `update`, `remove`, `reload`; `status` toont
  `customCount`.
- [x] README, `docs/keybindings.md` en deze notitie bijgewerkt.

**Klaar als:** een toegevoegde binding direct in het overzicht staat, door sxhkd
wordt gebruikt en via potlood/prullenbak weer aan te passen of te verwijderen is.

---

## Aanvullende uitbreiding — Snapper-widget

**Doel:** btrfs-momentopnamen vanuit de bar bekijken en beheren.

- [x] `Snapper.qml`: configuraties en momentopnamen via `snapper --jsonout`,
  normalisatie, automatische verversing (2 min), fout- en toegangspaden.
- [x] `SnapperWidget.qml`: icoon + aantal in de bar; klik opent de popup.
- [x] `SnapperPopup.qml`: configuratiekeuze, lijst (nieuwste eerst), type,
  datum, gebruiker, beschrijving, aanmaken en verwijderen met bevestiging.
- [x] Opruimactie: verwijdert de oudste momentopnamen tot er maximaal 10
  overblijven; standaard- en actieve momentopnamen blijven beschermd.
- [x] Rollback per momentopname met bevestiging en waarschuwing dat de
  wijziging pas na een herstart actief wordt.
- [x] `SnapperCreateWindow.qml`: FloatingWindow met beschrijvingsveld, omdat
  een PopupWindow onder X11 geen toetsenbordfocus krijgt.
- [x] Mutaties via `pkexec` als de gebruiker alleen leesrechten heeft;
  `SNAPPER_ELEVATE` maakt dat commando configureerbaar.
- [x] `scripts/setup-snapper-access.sh`: eenmalige root-handeling die
  `ALLOW_USERS` en `SYNC_ACL` zet en de ACL van `.snapshots` controleert.
  Zonder toegang toont de popup het exacte commando; met `ALLOW_USERS` lopen
  lezen én beheren via `snapperd`, dus zonder pkexec of polkit-agent.
- [x] IPC: `snapper status | list | refresh | open | close | toggle | config |
  editor | create | remove | cleanup | rollback`.
- [x] bspwm-regel voor het nieuwe FloatingWindow en README-documentatie.

**Verificatie:** met een fake-snapper zijn laden, configuratie wisselen,
aanmaken, verwijderen, opruimen, rollback en het openen van het invoervenster
getest. Met de echte
snapper op deze machine (zonder `ALLOW_USERS`) verscheen de toegangsfout zonder
QML-fouten in het log; de popup toont daarbij het eenmalige setup-commando.
`scripts/setup-snapper-access.sh` is met `sh -n` gecontroleerd en de
JSON-ontleding is apart getest.

**Klaar als:** de widget zonder fouten start, de lijst toont wanneer de
gebruiker leesrechten heeft, en aanmaken/verwijderen via de service werkt.

---

## Aanvullend — Installer-ISO met Calamares en de BTRFS-configuratie

**Doel:** één hybride ISO (BIOS + UEFI) die deze desktop installeert met
Calamares en daarbij de BTRFS-indeling van de bronmachine overneemt.

### Ontwerp

De ISO wordt met `live-build` op Debian sid gebouwd. De live-omgeving is een
volledige LXQt-sessie (zodat Calamares een echte X11-sessie heeft); Calamares
start automatisch en is ook via het menu en een bureaubladsnelkoppeling te
openen. De squashfs bevat de volledige desktopstack, zodat de installatie
offline werkt.

De bronmachine gebruikt op `/dev/vda2` één BTRFS-filesystem met root-subvolume
`@rootfs` (geen aparte `@home`), `noatime,compress=zlib:3,discard=async,
space_cache=v2` en snapper met een geneste `/.snapshots`-subvolume. De
top-level subvolumes `@`, `@home`, `@log` en `@pkg` op die schijf zijn
restanten van een eerdere indeling: ze staan niet in `fstab` en worden niet
overgenomen. De installer maakt daarom:

| Onderdeel | Calamares-configuratie |
|---|---|
| Partitionering | EFI 1 GiB (`/boot/efi`, `umask=0077`) + één BTRFS-root, GPT bij UEFI |
| Root-subvolume | `btrfsSubvolumes: /@rootfs` via `mount.conf` |
| fstab | `noatime,compress=zlib:3,discard=async,space_cache=v2` |
| GRUB | `rootflags=subvol=@rootfs`, EFI-fallback ingeschakeld |
| Snapper | `snapper -c root create-config /`, `ALLOW_USERS=<gekozen gebruiker>`, ACL op `/.snapshots` |
| Swap | geen, net als de bronmachine |
| Diensten | SDDM, NetworkManager, bluetooth, snapper-timeline/cleanup, fstrim |

### Bestanden

```
iso/
├── build.sh                 # root-buildscript, staget repo + assets, draait live-build
├── README.md                # build- en installatie-uitleg
├── live-build/
│   ├── auto/config          # lb config: sid, amd64, iso-hybrid, syslinux+grub-efi
│   ├── auto/build
│   └── config/
│       ├── package-lists/quickshell.list.chroot
│       ├── hooks/live/0100-quickshell.hook.chroot
│       └── includes.chroot/... (via overlay)
├── overlay/
│   ├── etc/skel/...         # symlinks naar /opt/quickshell en settings.json
│   ├── usr/local/bin/quickshell-session
│   ├── usr/local/bin/quickshell-user-setup
│   ├── usr/local/lib/quickshell/install-target.sh
│   ├── usr/lib/live/config/9999-calamares
│   └── usr/share/applications/install-quickshell.desktop
├── calamares/
│   ├── settings.conf        # sequence + shellprocess-instanties
│   ├── modules/*.conf
│   └── branding/quickshell/ # branding.desc, show.qml, afbeeldingen
└── out/                     # ISO + sha256 (niet in git)
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
- [x] Google Chrome en persoonlijke bestanden gaan niet mee; de rest van de
      handmatig geïnstalleerde pakketten wel.
- [x] De LiveCalamares-configuratie verwijdert live-boot/live-config en
      Calamares vóór de initramfs wordt gegenereerd.

### Verificatie

- [x] `sudo iso/build.sh` eindigt met een ISO en een `.sha256`
      (2,2 GiB, `quickshell-desktop-amd64.iso`).
- [x] `iso/verify-iso.sh` controleert de BIOS- en UEFI-bootimages, de
      squashfs, `/opt/quickshell`, Calamares, matugen, SDDM (geen LightDM),
      geen NVIDIA-GLX, en de BTRFS-mountopties.
- [x] De ISO boot in QEMU (UEFI, OVMF) in LXQt; Calamares opent automatisch
      en toont de Quickshell-branding.
- [x] Een installatie op een lege 24 GiB virtuele schijf levert:
      `findmnt /` met `subvol=/@rootfs` en de juiste mountopties;
      `btrfs subvolume list /` met `@rootfs` en `.snapshots`;
      `snapper`-configuratie `root` met `ALLOW_USERS` en `SYNC_ACL`;
      `grub.cfg` met `rootflags=subvol=@rootfs`;
      SDDM als displaymanager en de bspwm-sessie als standaard.
- [x] Na de eerste login start de Quickshell-bar met workspaces, klok, weer,
      volume, meldingen, Snapper-teller, instellingen en de powerknop.
- [x] `Super+/` (sneltoetsenoverzicht, 71 bindingen), `Super+Shift+S`
      (BSPWM-instellingen), een D-Bus-notificatie (popup + badge) en de
      Snapper-teller in de bar getest op de geïnstalleerde schijf.

**Klaar als:** de ISO op echte hardware of in QEMU installeert en het
geïnstalleerde systeem dezelfde BTRFS-root, snapper-configuratie en
Quickshell-desktop heeft als de bronmachine.

---

## Risico's en mitigaties

| Risico | Mitigatie |
|---|---|
| X11-stacking (#290): fullscreen bedekt de bar | Testen in fase 2; noodoplossing `bspc config ignore_ewmh_fullscreen enter` (kost EWMH-fullscreen voor apps) |
| PopupWindow geen toetsenbordfocus (#794) | Geen tekstinvoer in popups; instellingen/sneltoetsen als `FloatingWindow` |
| Dubbele ruimte door struts + bspwm-padding | Standaard padding 0; waarschuwing in de instellingen-UI |
| Notificatiedaemon-conflict | Alleen Quickshell starten als `org.freedesktop.Notifications`-eigenaar; `lxqt-notificationd` niet autostarten |
| Alleen SNI-tray, geen XEmbed | Documenteren; moderne apps gebruiken SNI |
| Weer-API offline | Cache + foutstatus, geen crash |
| Debian sid-updates breken Qt/Quickshell | LXQt-fallback behouden; opnieuw starten/herbouwen mogelijk |
| Multi-monitor struts | Code per scherm; later testen met twee outputs |

---

## Acceptatiecriteria

- [x] Na login start bspwm met sxhkd, picom (optioneel), wallpaper en Quickshell; de bar staat boven en de gereserveerde ruimte klopt.
- [x] De bar toont workspaces (focus/bezet/urgent), klok en weer voor Eindhoven; weer ververst automatisch en werkt offline met cache.
- [x] `notify-send` toont een popup; het centrum toont geschiedenis; acties en DND werken; geen andere notificatiedaemon actief.
      → `notify-send` is hier niet geïnstalleerd; getest met `scripts/test-notifications.sh` (gdbus).
- [x] SNI-trayiconen verschijnen en hun menu's openen.
      → Legacy XEmbed (zoals `nm-applet` op deze build) wordt bewust niet ondersteund.
- [x] `Super+Shift+S` opent het instellingenvenster; gaps, randen, layouts, kleuren en gedrag zijn live aan te passen en blijven na `bspc wm -r` behouden; barkleuren lopen mee.
- [x] `Super+/` opent het sneltoetsenoverzicht; het komt exact overeen met `sxhkdrc`, is doorzoekbaar en actualiseert na herladen van sxhkd.
- [x] De Snapper-widget toont momentopnamen, wisselt van configuratie en kan aanmaken/verwijderen; zonder rechten toont hij een uitleg en gebruikt hij `pkexec` voor acties.
- [x] Alle sneltoetsen uit de tabel werken; `qs ipc call …` werkt voor instellingen, sneltoetsen en DND.
      → Voor deze deployment met `-p /home/simon/projecten/quickshell`; destructieve sessietoetsen zijn via het script/de commandoregel gecontroleerd.
- [x] De LXQt-sessie blijft selecteerbaar en ongewijzigd.

---

## Referenties

- Quickshell docs: <https://quickshell.org/docs/v0.3.2/>
- `PanelWindow`: <https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow>
- `NotificationServer`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Notifications/NotificationServer>
- `SystemTray`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/SystemTray>
- `IpcHandler`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/IpcHandler>
- `FileView`: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/FileView>
- `FloatingWindow`: <https://quickshell.org/docs/v0.3.2/types/Quickshell/FloatingWindow>
- bspwm(1) report-formaat en `bspc config`: <https://manpages.debian.org/sid/bspwm/bspwm.1.en.html>
- sxhkd(1) config en SIGUSR1: <https://manpages.debian.org/sid/sxhkd/sxhkd.1.en.html>
- Open-Meteo: <https://open-meteo.com/en/docs>
- Quickshell issue #290: <https://github.com/quickshell-mirror/quickshell/issues/290>
- Quickshell issue #794: <https://github.com/quickshell-mirror/quickshell/issues/794>
