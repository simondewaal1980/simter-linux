#!/bin/sh
# lock-session.sh — vergrendel de X11-sessie met het eerste beschikbare
# lock-programma. Dit project installeert bewust geen locker; op een echte
# desktop is i3lock, xsecurelock of swaylock voldoende.
#
# Ontbreekt er een locker, dan blijft de sessie bewust ontgrendeld en verschijnt
# er een melding via Quickshell. Zo doet de sneltoets toch iets zichtbaars en
# suggereren we geen valse veiligheid.

for locker in i3lock xsecurelock swaylock physlock; do
    if command -v "$locker" >/dev/null 2>&1; then
        case "$locker" in
        i3lock)
            exec i3lock -n
            ;;
        *)
            exec "$locker"
            ;;
        esac
    fi
done

if command -v dm-tool >/dev/null 2>&1; then
    exec dm-tool lock
fi

summary="Sessie vergrendelen"
body="Er is geen schermvergrendeling geïnstalleerd. Installeer bijvoorbeeld i3lock of xsecurelock en probeer opnieuw."

if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "Quickshell" 0 "" "$summary" "$body" "[]" "{}" 8000 \
        >/dev/null 2>&1 || true
fi

exit 1
