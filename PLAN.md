# Plan: BSPWM + Quickshell desktop (Debian sid)

> Uitvoerbaar per fase. Elke fase heeft een doel, stappen met checkboxes, commando's en een verificatie.
> Vink af wat klaar is en werk fase voor fase naar beneden.

**Projectmap:** `/home/simon/projecten/quickshell`
**Quickshell starten:** `qs -p /home/simon/projecten/quickshell`
**Doelomgeving:** Debian sid (forky), X11, SDDM, 1920×1080

---

## Voortgang

- [x] Fase 1 — Pakketten, bspwm-sessie en basisconfiguratie
- [ ] Fase 2 — Quickshell-skelet, thema en bar met workspaces/klok
- [ ] Fase 3 — BSPWM-integratie (report-parser, klikbare workspaces)
- [ ] Fase 4 — Weer Eindhoven
- [ ] Fase 5 — Systemtray
- [ ] Fase 6 — Notificatieserver, popups en centrum
- [ ] Fase 7 — Instellingenvenster voor BSPWM
- [ ] Fase 8 — Sneltoetsenoverzicht + definitieve sxhkdrc
- [ ] Fase 9 — Polijsten, optionele widgets, documentatie

---

## 0. Uitgangspunten en standaardkeuzes

Deze keuzes zijn als default vastgelegd zodat de fasen uitvoerbaar zijn. Ze zijn later eenvoudig te wijzigen.

| Onderwerp | Default |
|---|---|
| Terminal | `alacritty` (wijzigbaar in `config/sxhkd/sxhkdrc`) |
| Launcher | `rofi` |
| Thema | Catppuccin Mocha, volle-breedte bar |
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
    ├── feh ────────────────► wallpaper
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

- [ ] `shell.qml` met `ShellRoot`, `Variants { model: Quickshell.screens }` en één `Bar` per scherm.
- [ ] `src/theme/Theme.qml` (singleton) + `qmldir`; leest `~/.config/bspwm/settings.json` via `FileView` met `watchChanges: true` en bevat het kleurenpalet.
- [ ] `src/components/Bar.qml`: `PanelWindow`, hoogte ±34 px, `anchors { top; left; right }`, automatische `exclusiveZone`, `aboveWindows: true`, `focusable: false`.
- [ ] Indeling: links workspaces (tijdelijk statisch), midden klok/datum, rechts tijdelijke iconen.
- [ ] `src/components/Clock.qml` met `SystemClock`.
- [ ] IPC-handlers toevoegen (`bar` met `reload`/`toggle`).
- [ ] `.qmlls.ini` aanmaken voor editor/LSP.

### Verificatie

- [ ] `qs -p ~/projecten/quickshell` start zonder fouten; bar staat boven.
- [ ] `xprop -root _NET_WM_STRUT_PARTIAL` toont gereserveerde ruimte.
- [ ] Een getiled venster overlapt de bar niet.
- [ ] Fullscreen testen (`Super+f`): blijft de bar zichtbaar? Zo niet, noteer dit en test de mitigatie `bspc config ignore_ewmh_fullscreen enter`.
- [ ] `qs ipc show` toont de handler(s).

**Klaar als:** de bar stabiel draait, struts kloppen en de klok loopt. Dit is ook het moment om te controleren of de bar boven fullscreen blijft; leg de uitkomst vast.

---

## Fase 3 — BSPWM-integratie

**Doel:** live workspaces, layoutindicator en (optioneel) venstertitel in de bar.

### Stappen

- [ ] `src/services/Bspwm.qml`:
  - [ ] `bspc wm -g` bij startup voor de beginstatus.
  - [ ] `Process { command: ["bspc", "subscribe", "report"] }` met `SplitParser`.
  - [ ] `src/utils/ReportParser.js` parseert `M/m`, `O/o`, `F/f`, `U/u`, `L(T|M)`, `T(...)`, `G(...)`.
  - [ ] Properties: `monitors`, `desktops`, `focusedDesktop`, `layout`, `activeNodeState`, `activeNodeFlags`.
  - [ ] Commando's: `focusDesktop(name)`, `focusNext/Prev`, `toggleLayout()`.
  - [ ] Foutpad: "bspwm niet actief" tonen als `bspc` ontbreekt of faalt.
- [ ] `src/components/Workspaces.qml`: 1–9, focus/bezet/urgent-styling, layoutindicator (T/M), klikken en scrollen.
- [ ] `src/components/ActiveWindow.qml` (optioneel): `xdotool getactivewindow getwindowname`, verversen op `node_focus`.
- [ ] Werkt ook zonder bspwm (voor testen in LXQt).

### Verificatie

- [ ] Desktop wisselen via toetsen én via de bar; status klopt direct.
- [ ] Een venster openen/sluiten kleurt de juiste workspace.
- [ ] Urgent-hint testen: `bspc node -g urgent` op een venster.
- [ ] Layout wisselen (`Super+m`) toont M/T in de bar.
- [ ] `bspc wm -r` laat de bar netjes herstarten of opnieuw verbinden.

**Klaar als:** de bar de BSPWM-status foutloos en zonder merkbare vertraging volgt.

---

## Fase 4 — Weer Eindhoven

**Doel:** actueel weer met 3-daagse verwachting, cache en foutafhandeling.

### Stappen

- [ ] `src/services/Weather.qml`:
  - [ ] Open-Meteo-endpoint:
    `https://api.open-meteo.com/v1/forecast?latitude=51.4416&longitude=5.4697&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Europe%2FAmsterdam&forecast_days=4&temperature_unit=celsius&wind_speed_unit=kmh`
  - [ ] Ophalen met `curl -fsS --max-time 10`, parsen met `JSON.parse`.
  - [ ] Timer: elke 10 minuten; bij fout na 60 s opnieuw.
  - [ ] Cache laatste goede respons in `Quickshell.cachePath("weather-eindhoven.json")`.
  - [ ] `src/utils/WeatherCodes.js`: WMO-code → Nederlandse tekst + icoon.
- [ ] `src/components/WeatherWidget.qml`: icoon + temperatuur; foutstatus "—".
- [ ] `src/popups/WeatherPopup.qml`: gevoelstemperatuur, luchtvochtigheid, wind, neerslagkans, min/max, 3 dagen, "laatst bijgewerkt".

### Verificatie

- [ ] Temperatuur komt overeen met een externe bron.
- [ ] Na 10 minuten (of handmatige refresh) verandert de data.
- [ ] Netwerk uitschakelen → laatst bekende waarde + "laatst bijgewerkt" blijft zichtbaar.
- [ ] `curl`-fout levert geen QML-fouten of crash op.

**Klaar als:** het weer betrouwbaar is, ook zonder netwerk, en de popup alle gewenste informatie toont.

---

## Fase 5 — Systemtray

**Doel:** StatusNotifierItem-iconen met werkende menu's.

### Stappen

- [ ] `src/components/TrayWidget.qml` met `SystemTray.items` en een `Repeater`.
- [ ] `Image { source: item.icon }`, fallback-icoon bij ontbreken.
- [ ] Klik → `item.activate()`; middenklik → `item.secondaryActivate()`; scroll → `item.scroll(delta, horizontal)`.
- [ ] Menu → `item.display(barWindow, x, y)`; fallback `QsMenuAnchor` met `item.menu`.
- [ ] Tooltip met `tooltipTitle` / `tooltipDescription`.
- [ ] Alleen tonen als er items zijn; geen lege ruimte.

### Verificatie

- [ ] `nm-applet` of `blueman-applet` starten; icoon verschijnt.
- [ ] Menu opent op de juiste positie en is bruikbaar.
- [ ] App sluiten → icoon verdwijnt.
- [ ] Tooltip toont de juiste tekst.

**Klaar als:** gangbare SNI-apps correct verschijnen en hun menu's werken. Documenteer dat legacy XEmbed-icons niet worden ondersteund.

---

## Fase 6 — Notificatieserver

**Doel:** Quickshell is de enige notificatiedaemon, met popups, geschiedenis, acties en DND.

### Stappen

- [ ] `src/services/NotificationDaemon.qml`:
  - [ ] `NotificationServer { actionsSupported: true; imageSupported: true; bodyMarkupSupported: false; keepOnReload: true }`.
  - [ ] Inkomende notificatie: `tracked = true`; geschiedenis max. 50 (oudste eruit).
  - [ ] DND-state; badge-teller.
- [ ] `src/popups/NotificationStack.qml`: één `PopupWindow` rechtsboven onder de bar, max. 4 kaarten.
  - [ ] App-icoon, appnaam, samenvatting, body, actieknoppen (`action.invoke()`), sluitknop.
  - [ ] Time-out op basis van `expireTimeout`; low 4 s, normal 8 s, critical nooit automatisch; hover pauzeert.
- [ ] `src/popups/NotificationCenter.qml`: geschiedenis, "wis alles", per-item sluiten/openen.
- [ ] `src/components/NotificationBell.qml`: bel + DND-schakelaar + badge.
- [ ] Controle dat `lxqt-notificationd` niet in de bspwm-sessie start; logwaarschuwing bij een D-Bus-conflict.
- [ ] Notificatiepopups zonder `grabFocus` (X11-beperking); klikken blijft werken.

### Verificatie

- [ ] `notify-send "Test" "Hallo"` toont een popup met de juiste app-info.
- [ ] `notify-send -u critical "Belangrijk" "Blijft staan"` verdwijnt niet automatisch.
- [ ] `notify-send -A "Open=open" "Actie" "Klik"` toont een werkende actieknop.
- [ ] DND aan → geen popups, wel geschiedenis en badge.
- [ ] `qs ipc call notifications clear` (of vergelijkbaar) wist de geschiedenis.
- [ ] `qs ipc call notifications dnd true` schakelt DND.
- [ ] Quickshell herladen behoudt notificaties (`keepOnReload`).

**Klaar als:** notificaties volledig via Quickshell lopen en er geen andere daemon actief is.

---

## Fase 7 — Instellingenvenster voor BSPWM

**Doel:** gaps, randen, layouts, kleuren en gedrag live aanpassen en persistent opslaan.

### Stappen

- [ ] `src/services/BspwmSettings.qml`:
  - [ ] Bij startup `settings.json` lezen (`FileView`, `blockLoading`).
  - [ ] Wijzigingen direct toepassen met `bspc config` (120 ms debounce voor sliders).
  - [ ] Opslaan met `FileView.setText()` (500 ms debounce, atomair).
  - [ ] `reset()` naar `settings.default.json`.
- [ ] `src/windows/SettingsWindow.qml` als `FloatingWindow` (±900×640, titel "BSPWM-instellingen"), verborgen tot `visible = true`.
- [ ] Tabs:
  - [ ] **Gaps & randen**: `window_gap`, `border_width`, per-monitor padding, monocle-opties.
  - [ ] **Lay-outs**: `tiled`/`monocle` per desktop, `automatic_scheme`, `initial_polarity`, `split_ratio`, rotate/flip/balance/equalize/circulate, `single_monocle`, `borderless_singleton`.
  - [ ] **Kleuren & thema**: focused/normal/active/presel-kleuren, hex-invoer, presets (Catppuccin, Nord, Gruvbox, Tokyo Night).
  - [ ] **Gedrag**: `focus_follows_pointer`, `pointer_follows_focus`, `click_to_focus`, `pointer_modifier`, `swallow_first_click`, `ignore_ewmh_fullscreen`, `remove_unplugged_monitors`, `merge_overlapping_monitors`.
  - [ ] **Info/acties**: versies, paden, "BSPWM herstarten", "Sxhkd herladen", "Quickshell herladen".
- [ ] Waarschuwing in de UI: bar-struts + bspwm-padding kunnen dubbel ruimte innemen; standaard padding 0.
- [ ] `IpcHandler` target `settings`: `open()`, `close()`, `toggle()`.
- [ ] Koppeling met de bar: tandwiel-icoon opent het venster; kleurwijzigingen werken direct door in `Theme`.
- [ ] bspwm-regel voor float/centreren controleren.
- [ ] Optioneel: layout opslaan/herstellen met `bspc wm -d` en `bspc wm -l <absoluut pad>`.

### Verificatie

- [ ] `Super+Shift+S` en het tandwiel openen het venster; toetsenbordfocus werkt.
- [ ] Gaps/randen wijzigen is direct zichtbaar in getilde vensters.
- [ ] Kleur wijzigen verandert zowel BSPWM-randen als de bar.
- [ ] Na `bspc wm -r` zijn alle waarden behouden.
- [ ] "Standaardwaarden" herstelt de default-JSON en past dit toe.
- [ ] Layoutknoppen werken op de gefocuste desktop.

**Klaar als:** alle gevraagde BSPWM-instellingen via de GUI te wijzigen zijn, live werken en een herstart overleven.

---

## Fase 8 — Sneltoetsenoverzicht + definitieve sxhkdrc

**Doel:** een doorzoekbaar overzicht dat exact de sxhkdrc volgt, plus een complete sneltoetsenset.

### Stappen

- [ ] `src/utils/SxhkdParser.js`: comments, hotkeys, ingesprongen commando's, regelcontinutie (`\`), chord-chains (`;`/`:`), brace-expansie.
- [ ] Conventie vastleggen: comment direct boven een hotkey = omschrijving; `# --- Sectie ---` = groepskop.
- [ ] `src/windows/ShortcutsWindow.qml` als `FloatingWindow` (±900×640, titel "Sneltoetsen"):
  - [ ] `FileView` op `~/.config/sxhkd/sxhkdrc` met `watchChanges: true`.
  - [ ] Zoekveld (werkt door `FloatingWindow`), keycaps, commando in monospace.
  - [ ] Groepen: Algemeen, Vensters, Workspaces, Layout, Media, Screenshots, Sessie, Quickshell.
- [ ] `IpcHandler` target `shortcuts`: `open()`, `close()`, `toggle()`.
- [ ] Bar-icoon + `Super+/` koppelen.
- [ ] `config/sxhkd/sxhkdrc` afmaken:

  | Categorie | Voorbeelden |
  |---|---|
  | Apps | `Super+Return` terminal, `Super+d` rofi, `Super+Shift+b` browser, `Super+Shift+f` bestandsbeheer |
  | Vensters | `Super+hjkl` focus, `Super+Shift+hjkl` verplaatsen, `Super+q` sluiten, `Super+Shift+q` kill, `Super+f` fullscreen, `Super+t` tiled, `Super+s` floating |
  | Workspaces | `Super+1..9` focus, `Super+Shift+1..9` venster meenemen |
  | Layout | `Super+m` monocle, `Super+Shift+t` toggle, `Super+Shift+r` roteren, `Super+Shift+b` balance, `Super+Shift+e` equalize |
  | Preselect | `Super+Ctrl+hjkl`, `Super+Escape` annuleren |
  | Quickshell | `Super+Shift+S` instellingen, `Super+/` sneltoetsen, `Super+Shift+N` notificatiecentrum, `Super+Shift+D` DND |
  | Media | XF86-toetsen → `pactl` / `playerctl` / `brightnessctl` |
  | Screenshots | `Print`, `Shift+Print` (regio via maim/slop), `Super+Print` (venster) |
  | Sessie | `Super+Shift+L` lock, `Super+Shift+E` bspwm afsluiten, `Super+Shift+P` powermenu |

- [ ] Elke hotkey voorzien van een beschrijvende comment.
- [ ] Herladen: `pkill -USR1 sxhkd`.

### Verificatie

- [ ] `Super+/` opent het overzicht; alle bindings zijn zichtbaar en gegroepeerd.
- [ ] Zoeken op "terminal", "workspace" en "Super+Shift" filtert correct.
- [ ] Een hotkey toevoegen aan sxhkdrc + `pkill -USR1 sxhkd` → overzicht werkt bij.
- [ ] Alle sneltoetsen uit de tabel daadwerkelijk testen.
- [ ] `qs ipc call shortcuts toggle` werkt.

**Klaar als:** het overzicht en de sxhkdrc aantoonbaar dezelfde bron zijn en alle sneltoetsen werken.

---

## Fase 9 — Polijsten, optionele widgets en documentatie

**Doel:** afronden, extras, en overdraagbare documentatie.

### Stappen

- [ ] Volume-widget via `Quickshell.Services.Pipewire` (klik = mute, scroll = volume).
- [ ] Accu-widget via `Quickshell.Services.UPower` (alleen tonen als er een accu is).
- [ ] Optioneel: MPRIS-spelerwidget.
- [ ] Optioneel: polkit-agent via Quickshell, of `lxpolkit` autostarten.
- [ ] Optioneel: watchdog voor Quickshell in `bspwmrc`.
- [ ] Optioneel: thema-presets uitbreiden en picom afstemmen op de VM-GPU.
- [ ] `README.md`: installatie, starten, sneltoetsen, configpaden, troubleshooting (X11-issues, notificatieconflict, tray-beperkingen).
- [ ] `docs/keybindings.md` (optioneel) als leesbare referentie.
- [ ] Screenshot(s) toevoegen.
- [ ] Volledige acceptatietest doorlopen.

### Verificatie

- [ ] Volume en accu (indien aanwezig) werken en verversen live.
- [ ] `qs -p …` start schoon na een volledige logout/login.
- [ ] README is genoeg om de installatie opnieuw te doen.
- [ ] Alle acceptatiecriteria hieronder zijn afgevinkt.

**Klaar als:** de desktop dagelijks bruikbaar is en de documentatie compleet is.

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

- [ ] Na login start bspwm met sxhkd, picom (optioneel), wallpaper en Quickshell; de bar staat boven en de gereserveerde ruimte klopt.
- [ ] De bar toont workspaces (focus/bezet/urgent), klok en weer voor Eindhoven; weer ververst automatisch en werkt offline met cache.
- [ ] `notify-send` toont een popup; het centrum toont geschiedenis; acties en DND werken; geen andere notificatiedaemon actief.
- [ ] SNI-trayiconen verschijnen en hun menu's openen.
- [ ] `Super+Shift+S` opent het instellingenvenster; gaps, randen, layouts, kleuren en gedrag zijn live aan te passen en blijven na `bspc wm -r` behouden; barkleuren lopen mee.
- [ ] `Super+/` opent het sneltoetsenoverzicht; het komt exact overeen met `sxhkdrc`, is doorzoekbaar en actualiseert na herladen van sxhkd.
- [ ] Alle sneltoetsen uit de tabel werken; `qs ipc call …` werkt voor instellingen, sneltoetsen en DND.
- [ ] De LXQt-sessie blijft selecteerbaar en ongewijzigd.

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
