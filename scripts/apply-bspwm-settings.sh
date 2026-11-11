#!/bin/sh
# apply-bspwm-settings.sh — past de JSON-instellingen toe op een draaiende bspwm.
#
# Bron van waarheid: ~/.config/bspwm/settings.json (of settings.default.json als
# die nog niet bestaat). Wordt aangeroepen door config/bspwm/bspwmrc bij elke
# start en bij `bspc wm -r`, en kan handmatig worden gedraaid:
#
#   apply-bspwm-settings.sh                 # settings.json, of default
#   apply-bspwm-settings.sh -f bestand.json # expliciet bestand
#   apply-bspwm-settings.sh --dry-run       # alleen tonen wat er zou gebeuren
#
# Zonder draaiende bspwm (of zonder bspc) stopt het script met een melding op
# stderr en exitcode 1; het crasht dus nooit de sessie.
#
# Let op: deze bspwm-versie (0.9.12) geeft exitcode 1 als je een boolean op
# dezelfde waarde zet. Daarom vergelijkt het script eerst met de huidige waarde
# en waarschuwt het alleen bij een echte afwijking.

set -u

PROG=${0##*/}
DRY_RUN=0
SETTINGS=""

usage() {
  cat <<EOF
Gebruik: $PROG [-f BESTAND] [-n|--dry-run] [-h|--help]

  -f, --file BESTAND  lees instellingen uit BESTAND
  -n, --dry-run       toon de bspc-commando's zonder ze uit te voeren
  -h, --help          deze tekst
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--file)
      [ $# -ge 2 ] || { echo "$PROG: -f heeft een bestand nodig" >&2; exit 2; }
      SETTINGS=$2
      shift 2
      ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "$PROG: onbekende optie '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/bspwm
REPO_DIR=${QUICKSHELL_DIR:-$HOME/projecten/quickshell}

if [ -z "$SETTINGS" ]; then
  for candidate in \
    "$CONFIG_DIR/settings.json" \
    "$CONFIG_DIR/settings.default.json" \
    "$REPO_DIR/config/bspwm/settings.default.json"
  do
    if [ -r "$candidate" ]; then
      SETTINGS=$candidate
      break
    fi
  done
fi

if [ -z "$SETTINGS" ] || [ ! -r "$SETTINGS" ]; then
  echo "$PROG: geen leesbaar settings-bestand gevonden" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "$PROG: jq ontbreekt (apt install jq)" >&2; exit 1; }

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "$PROG: $SETTINGS is geen geldige JSON; niets toegepast" >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 0 ]; then
  command -v bspc >/dev/null 2>&1 || { echo "$PROG: bspc ontbreekt; bspwm niet actief" >&2; exit 1; }
  if ! bspc query -M >/dev/null 2>&1; then
    echo "$PROG: bspwm niet actief; instellingen niet toegepast" >&2
    exit 1
  fi
fi

say() { printf '%s\n' "$*"; }
warn() { printf '%s: %s\n' "$PROG" "$*" >&2; }

# run COMMAND... — voert uit, of print bij --dry-run.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    say "$*"
    return 0
  fi
  "$@" >/dev/null 2>&1 || warn "mislukt: $*"
}

# get JSONPAD — waarde uit het settings-bestand, mislukt bij ontbreken.
# Let op: geen `// empty`, want dan verdwijnen false en 0 ook.
get() {
  value=$(jq -r "$1" "$SETTINGS" 2>/dev/null) || return 1
  case "$value" in
    ''|null) return 1 ;;
  esac
  printf '%s\n' "$value"
}

# current [SCOPE...] KEY — huidige waarde volgens bspc (leeg bij twijfel).
current() {
  bspc config "$@" 2>/dev/null
}

# apply BSPC_KEY JSONPAD — zet één globale bspc config-waarde.
apply() {
  value=$(get "$2") || return 0
  if [ "$DRY_RUN" -eq 0 ] && [ "$(current "$1")" = "$value" ]; then
    return 0
  fi
  run bspc config "$1" "$value"
}

# apply_monitor MONITOR BSPC_KEY VALUE — zet een per-monitor waarde.
apply_monitor() {
  if [ "$DRY_RUN" -eq 0 ] && [ "$(current -m "$1" "$2")" = "$3" ]; then
    return 0
  fi
  run bspc config -m "$1" "$2" "$3"
}

say "$PROG: instellingen uit $SETTINGS"

# --- Gaps, randen en layout -----------------------------------------------

apply window_gap            '.window_gap'
apply border_width          '.border_width'
apply split_ratio           '.split_ratio'
apply automatic_scheme      '.layout.automatic_scheme'
apply initial_polarity      '.layout.initial_polarity'
apply single_monocle        '.layout.single_monocle'
apply borderless_singleton  '.layout.borderless_singleton'
apply borderless_monocle    '.layout.borderless_monocle'
apply gapless_monocle       '.layout.gapless_monocle'

# --- Kleuren ---------------------------------------------------------------
# bspwm 0.9.12 kent alleen presel_feedback_color voor het preselectiegebied.

apply focused_border_color   '.colors.focused'
apply normal_border_color    '.colors.normal'
apply active_border_color    '.colors.active'
apply presel_feedback_color  '.colors.presel_feedback'

# --- Gedrag ---------------------------------------------------------------

apply focus_follows_pointer      '.behavior.focus_follows_pointer'
apply pointer_follows_focus      '.behavior.pointer_follows_focus'
apply click_to_focus             '.behavior.click_to_focus'
apply pointer_modifier           '.behavior.pointer_modifier'
apply swallow_first_click        '.behavior.swallow_first_click'
apply ignore_ewmh_fullscreen     '.behavior.ignore_ewmh_fullscreen'
apply remove_unplugged_monitors  '.behavior.remove_unplugged_monitors'
apply merge_overlapping_monitors '.behavior.merge_overlapping_monitors'

# --- Padding per monitor --------------------------------------------------
# 0 = geen extra ruimte naast de Quickshell-struts (voorkomt dubbele ruimte).

top_padding=$(get '.padding.top') || top_padding=0
right_padding=$(get '.padding.right') || right_padding=0
bottom_padding=$(get '.padding.bottom') || bottom_padding=0
left_padding=$(get '.padding.left') || left_padding=0

if [ "$DRY_RUN" -eq 1 ]; then
  say "bspc config -m <monitor> top_padding $top_padding"
  say "bspc config -m <monitor> right_padding $right_padding"
  say "bspc config -m <monitor> bottom_padding $bottom_padding"
  say "bspc config -m <monitor> left_padding $left_padding"
else
  bspc query -M --names | while IFS= read -r monitor; do
    [ -n "$monitor" ] || continue
    apply_monitor "$monitor" top_padding "$top_padding"
    apply_monitor "$monitor" right_padding "$right_padding"
    apply_monitor "$monitor" bottom_padding "$bottom_padding"
    apply_monitor "$monitor" left_padding "$left_padding"
  done
fi

# --- Controle: padding geldt per monitor, niet globaal --------------------

say "$PROG: klaar"
