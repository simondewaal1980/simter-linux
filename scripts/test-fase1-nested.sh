#!/bin/sh
# test-fase1-nested.sh — verifieert fase 1 in een geneste bspwm-sessie op :1.
# De echte sessie (:0) blijft ongemoeid. Vereist xserver-xephyr en xdotool.
#
# Gebruik:  ./scripts/test-fase1-nested.sh
#
# Let op: toetsen worden met `xdotool key` verstuurd zonder --clearmodifiers;
# met die optie worden synthetische Super-combinaties niet door sxhkd opgepakt.
set -u

DISP=:1
HOST_DISPLAY=${HOST_DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime-simon}
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

SETTINGS=$HOME/.config/bspwm/settings.json
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fase1-test.XXXXXX")
cp "$SETTINGS" "$TMPROOT/settings-backup.json"

XEPHYR_PID=""
kill_on_display() { # naam... — beëindig processen die op de geneste display draaien
  for name in "$@"; do
    for pid in $(pgrep -x "$name" 2>/dev/null); do
      tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | grep -qx "DISPLAY=$DISP" && kill "$pid" 2>/dev/null
    done
  done
}
cleanup() {
  DISPLAY=$DISP bspc quit >/dev/null 2>&1
  [ -n "$XEPHYR_PID" ] && kill "$XEPHYR_PID" 2>/dev/null
  sleep 0.5
  kill_on_display sxhkd picom alacritty rofi
  cp "$TMPROOT/settings-backup.json" "$SETTINGS"
}
trap cleanup EXIT INT TERM

rm -f "/tmp/.X${DISP#:}-lock"
DISPLAY=$HOST_DISPLAY Xephyr -screen 1280x800 -nolisten tcp "$DISP" >"$TMPROOT/xephyr.log" 2>&1 &
XEPHYR_PID=$!
sleep 2

export DISPLAY=$DISP
bspwm >"$TMPROOT/bspwm-nested.log" 2>&1 &
sleep 3

fail=0
check() { # omschrijving verwacht werkelijk
  if [ "$2" = "$3" ]; then
    printf 'OK    %-46s %s\n' "$1" "$3"
  else
    printf 'FAIL  %-46s %s (verwacht %s)\n' "$1" "$3" "$2"
    fail=$((fail + 1))
  fi
}

echo "== sessie =="
check "monitor" "default" "$(bspc query -M --names)"
check "desktops" "1 2 3 4 5 6 7 8 9" "$(bspc query -D --names | tr '\n' ' ' | sed 's/ $//')"
for p in bspwm sxhkd picom; do
  check "proces $p draait" "ja" "$(pgrep -x "$p" >/dev/null && echo ja || echo nee)"
done
check "picom-instanties (>=1)" "ja" "$(ps -C picom -o pid= | grep -qc . && echo ja || echo nee)"
check "aantal sxhkd-instanties" "1" "$(pgrep -xc sxhkd)"

echo "== instellingen uit settings.json =="
check "window_gap" "$(jq -r .window_gap "$SETTINGS")" "$(bspc config window_gap)"
check "border_width" "$(jq -r .border_width "$SETTINGS")" "$(bspc config border_width)"
check "focused_border_color" "$(jq -r .colors.focused "$SETTINGS")" "$(bspc config focused_border_color)"
check "normal_border_color" "$(jq -r .colors.normal "$SETTINGS")" "$(bspc config normal_border_color)"
check "top_padding" "$(jq -r .padding.top "$SETTINGS")" "$(bspc config top_padding)"
check "pointer_modifier" "$(jq -r .behavior.pointer_modifier "$SETTINGS")" "$(bspc config pointer_modifier)"

echo "== wallpaper =="
check "root pixmap gezet" "ja" "$(xprop -root _XROOTPMAP_ID >/dev/null 2>&1 && echo ja || echo nee)"

echo "== sneltoetsen =="
xdotool key super+2; sleep 0.5
check "Super+2 focus desktop 2" "2" "$(bspc query -D -d focused --names)"
xdotool key super+3; sleep 0.5
xdotool key super+3; sleep 0.5
check "Super+3 focus desktop 3" "3" "$(bspc query -D -d focused --names)"

xdotool key super+Return; sleep 2.5
check "Super+Return opent venster" "1" "$(bspc query -N -d focused | wc -l | tr -d ' ')"
check "terminal is alacritty" "ja" "$(pgrep -x alacritty >/dev/null && echo ja || echo nee)"

xdotool key super+shift+1; sleep 1
check "Super+Shift+1 verplaatst venster" "1 0" "$(bspc query -N -d '^1' | wc -l | tr -d ' ') $(bspc query -N -d '^3' | wc -l | tr -d ' ')"

xdotool key super+q; sleep 1
check "Super+q sluit venster" "0" "$(bspc query -N | wc -l | tr -d ' ')"

xdotool key super+d; sleep 2
check "Super+d opent rofi" "ja" "$(pgrep -x rofi >/dev/null && echo ja || echo nee)"
xdotool key Escape; sleep 0.5

xdotool key super+m; sleep 0.6
check "Super+m wisselt layout" "monocle" "$(bspc query -T -d | jq -r .layout)"
xdotool key super+m; sleep 0.6

echo "== herstart bspc wm -r =="
jq '.window_gap = 20 | .border_width = 4' "$SETTINGS" > "$TMPROOT/settings-20.json"
cp "$TMPROOT/settings-20.json" "$SETTINGS"
bspc wm -r
sleep 3
check "window_gap na herstart (uit json)" "20" "$(bspc config window_gap)"
check "border_width na herstart (uit json)" "4" "$(bspc config border_width)"
check "sxhkd na herstart" "ja" "$(pgrep -x sxhkd >/dev/null && echo ja || echo nee)"
check "picom na herstart" "ja" "$(pgrep -x picom >/dev/null && echo ja || echo nee)"

echo "== logs =="
grep -i "mislukt\|error" "$TMPROOT/bspwm-nested.log" | head -5
echo "quickshell gestart? $(pgrep -x quickshell >/dev/null && echo ja || echo 'nee (shell.qml ontbreekt nog, fase 2)')"

echo
if [ "$fail" -eq 0 ]; then
  echo "RESULTAAT: alle controles geslaagd"
else
  echo "RESULTAAT: $fail controle(s) mislukt"
fi
