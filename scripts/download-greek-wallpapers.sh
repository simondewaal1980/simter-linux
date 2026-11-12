#!/bin/sh
# download-greek-wallpapers.sh — haalt de tien Griekse wallpapers op.
#
# Gebruik:
#   scripts/download-greek-wallpapers.sh [--force] [doelmap]
#
# Zonder doelmap wordt ~/Pictures/Wallpapers gebruikt, dezelfde map die
# wallpaper-theme.sh en het wallpapervenster lezen. Bestaande bestanden worden
# overgeslagen; met --force opnieuw gedownload.
#
# Bron: Wikimedia Commons. De afbeeldingen zijn verkleind naar 1920 px breed;
# auteur, licentie en bronpagina staan in docs/wallpaper-credits.md.

set -eu

FORCE=0
TARGET="$HOME/Pictures/Wallpapers"

for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) TARGET=$arg ;;
    esac
done

mkdir -p "$TARGET"

download() {
    name=$1
    url=$2
    dest="$TARGET/$name"

    if [ -s "$dest" ] && [ "$FORCE" != "1" ]; then
        printf 'bestaat al: %s\n' "$dest"
        return 0
    fi

    printf 'downloaden: %s\n' "$name"
    curl -fsSL --retry 3 --max-time 120 \
        -A 'quickshell-greek-wallpapers/1.0 (local user)' \
        -o "$dest.part" "$url"
    mv "$dest.part" "$dest"
}

# Let op: tussen naam en URL staat een tab.
while IFS='	' read -r name url; do
    [ -n "$name" ] || continue
    [ -n "$url" ] || continue
    download "$name" "$url"
done <<'EOF'
griekenland-01-santorini-oia.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/b/b3/07-17-2012_-_Oia_-_Santorini_-_Greece_-_26.jpg/1920px-07-17-2012_-_Oia_-_Santorini_-_Greece_-_26.jpg
griekenland-02-athene-acropolis.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/2/2c/1029_Acropolis_of_Athens_in_Greece_at_night_Photo_by_Giles_Laurent.jpg/1920px-1029_Acropolis_of_Athens_in_Greece_at_night_Photo_by_Giles_Laurent.jpg
griekenland-03-meteora.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/e/e8/Meteora_Moni_Agias_Triados_%28231663019%29.jpeg/1920px-Meteora_Moni_Agias_Triados_%28231663019%29.jpeg
griekenland-04-mykonos.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/8/8c/Sunset_sur_les_moulins_de_mykonos_%2848997134487%29.jpg/1920px-Sunset_sur_les_moulins_de_mykonos_%2848997134487%29.jpg
griekenland-05-zakynthos-navagio.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/3/3c/Navagio_beach_Zakynthos_1.jpg/1920px-Navagio_beach_Zakynthos_1.jpg
griekenland-06-rhodes.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/4/4f/Aerial_view_of_Rhodes_Old_Town%2C_Greece_%2851698566526%29.jpg/1920px-Aerial_view_of_Rhodes_Old_Town%2C_Greece_%2851698566526%29.jpg
griekenland-07-nafplio.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/9/95/2005-07-08_-_NAFPLIO_-_PALAMIDI_050.jpg/1920px-2005-07-08_-_NAFPLIO_-_PALAMIDI_050.jpg
griekenland-08-delphi.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/9/99/Delphi_BW_2017-10-08_11-25-43.jpg/1920px-Delphi_BW_2017-10-08_11-25-43.jpg
griekenland-09-crete-elafonissi.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/3/3d/Aerial_view_of_Elafonisi_Lagoon_on_the_south-west_coast_of_Crete%2C_Greece.jpg/1920px-Aerial_view_of_Elafonisi_Lagoon_on_the_south-west_coast_of_Crete%2C_Greece.jpg
griekenland-10-thessaloniki.jpg	https://thumb.wikimedia.org/wikipedia/commons/thumb/6/66/The_White_Tower_of_Thessaloniki_-_1.jpg/1920px-The_White_Tower_of_Thessaloniki_-_1.jpg
EOF

printf '\nKlaar. Wallpapers staan in %s\n' "$TARGET"
printf 'Toepassen: %s/scripts/wallpaper-theme.sh next\n' "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
