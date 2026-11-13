# Sneltoetsen

> Momentopname van `config/sxhkd/sxhkdrc`. De live, doorzoekbare versie staat in Quickshell met **Super+/**.
> Eigen bindingen voeg je daar toe met **Nieuwe sneltoets**; die komen als
> `@qs-shortcut`-blok in dezelfde sxhkdrc en staan niet in deze momentopname.

## Algemeen

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Super+Return` | Terminal openen | `alacritty` |
| `Super+D` | Applicatielauncher openen | `rofi -show drun` |
| `Super+Shift+B` | Webbrowser openen | `x-www-browser` (Chrome) |
| `Super+Shift+F` | Bestandsbeheer openen | `pcmanfm-qt` |
| `Super+W` | Volgende wallpaper (past ook het kleurenpalet aan) | `$HOME/projecten/quickshell/scripts/wallpaper-theme.sh next` |
| `Super+Shift+W` | Wallpapervenster openen/sluiten (preview, toevoegen, verwijderen) | `qs -p "$HOME/projecten/quickshell" ipc call wallpaper toggle` |

## Vensters

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Super+H` | Focus naar links/onder/boven/rechts | `bspc node -f west` |
| `Super+J` | Focus naar links/onder/boven/rechts | `bspc node -f south` |
| `Super+K` | Focus naar links/onder/boven/rechts | `bspc node -f north` |
| `Super+L` | Focus naar links/onder/boven/rechts | `bspc node -f east` |
| `Super+Shift+H` | Venster verplaatsen naar links/onder/boven/rechts | `bspc node -s west` |
| `Super+Shift+J` | Venster verplaatsen naar links/onder/boven/rechts | `bspc node -s south` |
| `Super+Shift+K` | Venster verplaatsen naar links/onder/boven/rechts | `bspc node -s north` |
| `Super+Shift+L` | Venster verplaatsen naar links/onder/boven/rechts | `bspc node -s east` |
| `Super+Q` | Venster sluiten | `bspc node -c` |
| `Super+Shift+Q` | Venster geforceerd beëindigen | `bspc node -k` |
| `Super+F` | Fullscreen aan/uit | `bspc node -t ~fullscreen` |
| `Super+T` | Venster weer betegelen | `bspc node -t tiled` |
| `Super+S` | Venster zwevend maken | `bspc node -t floating` |

## Workspaces

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Super+1` | Desktop 1-9 focussen | `bspc desktop -f '^1'` |
| `Super+2` | Desktop 1-9 focussen | `bspc desktop -f '^2'` |
| `Super+3` | Desktop 1-9 focussen | `bspc desktop -f '^3'` |
| `Super+4` | Desktop 1-9 focussen | `bspc desktop -f '^4'` |
| `Super+5` | Desktop 1-9 focussen | `bspc desktop -f '^5'` |
| `Super+6` | Desktop 1-9 focussen | `bspc desktop -f '^6'` |
| `Super+7` | Desktop 1-9 focussen | `bspc desktop -f '^7'` |
| `Super+8` | Desktop 1-9 focussen | `bspc desktop -f '^8'` |
| `Super+9` | Desktop 1-9 focussen | `bspc desktop -f '^9'` |
| `Super+Shift+1` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^1' --follow` |
| `Super+Shift+2` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^2' --follow` |
| `Super+Shift+3` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^3' --follow` |
| `Super+Shift+4` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^4' --follow` |
| `Super+Shift+5` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^5' --follow` |
| `Super+Shift+6` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^6' --follow` |
| `Super+Shift+7` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^7' --follow` |
| `Super+Shift+8` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^8' --follow` |
| `Super+Shift+9` | Venster naar desktop 1-9 verplaatsen (en volgen) | `bspc node -d '^9' --follow` |
| `Super+Tab` | Vorige desktop | `bspc desktop -f last` |

## Layout

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Super+M` | Monocle-layout op de gefocuste desktop | `bspc desktop -l monocle` |
| `Super+Shift+T` | Volgende layout (tiled/monocle) op de gefocuste desktop | `bspc desktop -l next` |
| `Super+Shift+R` | Boom 90 graden roteren | `bspc node -R 90` |
| `Super+Shift+Space` | Boom balanceren | `bspc node -B` |
| `Super+Shift+E` | Bomen gelijkmatig verdelen | `bspc node -E` |

## Preselect

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Super+Ctrl+H` | Preselectie aanmaken aan links/onder/boven/rechts | `bspc node -p west` |
| `Super+Ctrl+J` | Preselectie aanmaken aan links/onder/boven/rechts | `bspc node -p south` |
| `Super+Ctrl+K` | Preselectie aanmaken aan links/onder/boven/rechts | `bspc node -p north` |
| `Super+Ctrl+L` | Preselectie aanmaken aan links/onder/boven/rechts | `bspc node -p east` |
| `Super+Escape` | Preselectie annuleren | `bspc node -p cancel` |

## Quickshell

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Super+Shift+S` | BSPWM-instellingen openen/sluiten | `qs -p "$HOME/projecten/quickshell" ipc call settings toggle` |
| `Super+/` | Sneltoetsenoverzicht openen/sluiten | `qs -p "$HOME/projecten/quickshell" ipc call shortcuts toggle` |
| `Super+Shift+N` | Notificatiecentrum openen/sluiten | `qs -p "$HOME/projecten/quickshell" ipc call notifications toggle` |
| `Super+Shift+D` | Niet storen aan/uit | `qs -p "$HOME/projecten/quickshell" ipc call notifications toggleDnd` |

## Media

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `XF86AUDIORAISEVOLUME` | Volume harder | `pactl set-sink-volume @DEFAULT_SINK@ +5%` |
| `XF86AUDIOLOWERVOLUME` | Volume zachter | `pactl set-sink-volume @DEFAULT_SINK@ -5%` |
| `XF86AUDIOMUTE` | Geluid dempen/aanzetten | `pactl set-sink-mute @DEFAULT_SINK@ toggle` |
| `XF86AUDIOMICMUTE` | Microfoon dempen/aanzetten | `pactl set-source-mute @DEFAULT_SOURCE@ toggle` |
| `XF86MONBRIGHTNESSUP` | Scherm helderder | `brightnessctl set +5%` |
| `XF86MONBRIGHTNESSDOWN` | Scherm dimmen | `brightnessctl set 5%-` |
| `XF86AUDIOPLAY` | Muziek afspelen/pauzeren | `playerctl play-pause` |
| `XF86AUDIONEXT` | Volgende track | `playerctl next` |
| `XF86AUDIOPREV` | Vorige track | `playerctl previous` |
| `XF86AUDIOSTOP` | Muziek stoppen | `playerctl stop` |

## Screenshots

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Print` | Volledig scherm naar ~/Pictures/screenshots | `sh -c 'mkdir -p "$HOME/Pictures/screenshots" && maim -u "$HOME/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"'` |
| `Shift+Print` | Regio selecteren en opslaan | `sh -c 'mkdir -p "$HOME/Pictures/screenshots" && maim -s -u "$HOME/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"'` |
| `Super+Print` | Actief venster opslaan | `sh -c 'mkdir -p "$HOME/Pictures/screenshots" && maim -i "$(xdotool getactivewindow)" -u "$HOME/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"'` |

## Sessie

| Toetsen | Omschrijving | Commando |
|---|---|---|
| `Super+Alt+L` | Sessie vergrendelen | `"$HOME/projecten/quickshell/scripts/lock-session.sh"` |
| `Super+Ctrl+R` | BSPWM herstarten (settings.json wordt opnieuw toegepast) | `bspc wm -r` |
| `Super+Ctrl+S` | Sxhkd herladen | `pkill -USR1 sxhkd` |
| `Super+Alt+E` | BSPWM afsluiten (terug naar de display manager) | `bspc quit` |
| `Super+Shift+P` | Sessiemenu in de bar (rofi-terugval) | `"$HOME/projecten/quickshell/scripts/powermenu.sh"` |

