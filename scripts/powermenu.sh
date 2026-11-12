#!/bin/sh
# powermenu.sh — sessiemenu voor de BSPWM-desktop.
#
# Draait Quickshell, dan opent dit script het powermenu in de bar via IPC.
# Is de bar niet bereikbaar, dan volgt dit rofi-menu als terugval. De acties
# lopen via systemd/logind, zodat ze ook werken als de desktop opnieuw wordt
# gestart. Vergrendelen gebruikt lock-session.sh uit deze map.

QUICKSHELL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Voorkeur: het powermenu in de bar (aan/uit-knop rechts).
if command -v qs >/dev/null 2>&1; then
    if qs -p "$QUICKSHELL_DIR" ipc call power toggle >/dev/null 2>&1; then
        exit 0
    fi
fi

choice=$(printf '%s\n' \
    "Vergrendelen" \
    "Uitloggen" \
    "Opschorten" \
    "Herstarten" \
    "Afsluiten" \
    | rofi -dmenu -i -p "Sessie")

[ -n "$choice" ] || exit 0

case "$choice" in
Vergrendelen)
    "$QUICKSHELL_DIR/scripts/lock-session.sh"
    ;;
Uitloggen)
    bspc quit
    ;;
Opschorten)
    systemctl suspend
    ;;
Herstarten)
    systemctl reboot
    ;;
Afsluiten)
    systemctl poweroff
    ;;
esac
