#!/bin/sh
# test-notifications.sh — stuur testmeldingen naar de Quickshell-daemon.
#
# Op dit systeem is notify-send (libnotify-bin) niet geïnstalleerd; daarom
# gebruikt dit script gdbus, dat dezelfde org.freedesktop.Notifications-API
# aanspreekt. Is notify-send wél aanwezig, dan wordt die gebruikt (kortere
# commando's, dezelfde resultaten).
#
# Gebruik:
#   scripts/test-notifications.sh basic
#   scripts/test-notifications.sh critical
#   scripts/test-notifications.sh action
#   scripts/test-notifications.sh all
#
# De shell moet draaien (qs -p ~/projecten/quickshell) en eigenaar zijn van
# org.freedesktop.Notifications; controleer met:
#   qs ipc call notifications status

set -e

if ! gdbus call --session \
        --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.GetNameOwner \
        org.freedesktop.Notifications >/dev/null 2>&1; then
    echo "Geen notificatiedaemon op org.freedesktop.Notifications." >&2
    echo "Start Quickshell met: qs -p $(dirname "$0")/.." >&2
    exit 1
fi

# mode summary body
send() {
    mode=$1
    summary=$2
    body=$3

    if command -v notify-send >/dev/null 2>&1; then
        case "$mode" in
            critical) notify-send -u critical "$summary" "$body" ;;
            action) notify-send -A "open=Open" "$summary" "$body" ;;
            *) notify-send "$summary" "$body" ;;
        esac
        return
    fi

    case "$mode" in
        critical)
            actions="[]"
            hints="{'urgency': <byte 2>}"
            ;;
        action)
            actions='["open", "Open"]'
            hints="{}"
            ;;
        *)
            actions="[]"
            hints="{}"
            ;;
    esac

    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        -- "Quickshell-test" 0 "dialog-information" "$summary" "$body" \
        "$actions" "$hints" -1 >/dev/null
}

case "${1:-basic}" in
    basic)
        send basic "Test" "Hallo"
        ;;
    critical)
        send critical "Belangrijk" "Blijft staan"
        ;;
    action)
        send action "Actie" "Klik op de knop"
        ;;
    all)
        send basic "Test" "Hallo"
        sleep 1
        send critical "Belangrijk" "Blijft staan"
        sleep 1
        send action "Actie" "Klik op de knop"
        ;;
    *)
        echo "Onbekende modus: $1 (gebruik basic, critical, action of all)" >&2
        exit 1
        ;;
esac
