#!/bin/sh
# apply-wallpaper-theme.sh — post_hook van matugen (config/matugen/config.toml).
#
# Neemt de BSPWM-kleuren uit het zojuist gegenereerde palet over in
# ~/.config/bspwm/settings.json en past ze direct toe met bspc. Zo blijven
# wallpaper-palet, BSPWM-randen en de Quickshell-bar dezelfde kleuren gebruiken
# zonder dat er een tweede kleurenbron ontstaat.
#
# Faalt zacht: zonder bspwm of settings.json gebeurt er niets.

set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bspwm"
GENERATED="$CONFIG_DIR/theme.generated.json"
SETTINGS="$CONFIG_DIR/settings.json"

[ -r "$GENERATED" ] || exit 0
[ -r "$SETTINGS" ] || exit 0

if ! jq -e '.bspwm and (.palette | type == "object")' "$GENERATED" >/dev/null 2>&1; then
    echo "apply-wallpaper-theme: $GENERATED bevat geen geldig palet" >&2
    exit 0
fi

tmp="$(mktemp "$CONFIG_DIR/.settings.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

jq --slurpfile generated "$GENERATED" '
    .colors = (.colors // {}) |
    .colors.focused = $generated[0].bspwm.focused |
    .colors.active = $generated[0].bspwm.active |
    .colors.normal = $generated[0].bspwm.normal |
    .colors.presel_feedback = $generated[0].bspwm.presel_feedback
' "$SETTINGS" >"$tmp" \
    && chmod 644 "$tmp" \
    && mv "$tmp" "$SETTINGS"

# Pas alleen de randkleuren toe. Niet apply-settings.sh aanroepen: dat zet ook
# de monitor-padding op de waarde uit settings.json (0) en zou daarmee de
# gereserveerde ruimte van de Quickshell-strut wissen.
if command -v bspc >/dev/null 2>&1 && bspc query -M --names >/dev/null 2>&1; then
    bspc config focused_border_color "$(jq -r '.bspwm.focused' "$GENERATED")" || true
    bspc config normal_border_color "$(jq -r '.bspwm.normal' "$GENERATED")" || true
    bspc config active_border_color "$(jq -r '.bspwm.active' "$GENERATED")" || true
    bspc config presel_feedback_color "$(jq -r '.bspwm.presel_feedback' "$GENERATED")" || true
fi

# Qt-apps (qt6ct) lezen hetzelfde palet. De post-hook is de plek waar alle
# consumenten van theme.generated.json worden bijgewerkt; zo lopen de
# Quickshell-bar, BSPWM-randen, GTK en Qt na een wallpaperwissel gelijk.
if [ -x "$REPO/scripts/apply-qt-theme.sh" ]; then
    "$REPO/scripts/apply-qt-theme.sh" \
        || echo "apply-wallpaper-theme: Qt-thema bijwerken mislukt" >&2
fi
