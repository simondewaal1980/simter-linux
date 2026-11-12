#!/bin/sh
# setup-snapper-access.sh — geef een gewone gebruiker toegang tot snapper.
#
# Snapper beheert btrfs-momentopnamen via de root-daemon snapperd. Een gewone
# gebruiker mag een configuratie pas lezen en beheren als hij in ALLOW_USERS
# staat. Die instelling vereist eenmalig root-rechten; daarna werken de
# Snapper-widget en `snapper list` zonder sudo of polkit-agent.
#
# Gebruik:
#   sudo scripts/setup-snapper-access.sh [-c CONFIG] [GEBRUIKER]
#
# Zonder GEBRUIKER gebruikt het script de aanroeper (SUDO_USER). Zonder -c
# kiest het de configuratie 'root', of anders de eerste die snapper kent.

set -eu

PROG=${0##*/}
CONFIG=${SNAPPER_CONFIG:-}
TARGET_USER=${SNAPPER_USER:-}

usage() {
    cat <<EOF
Gebruik: sudo $PROG [-c CONFIG] [GEBRUIKER]

  -c, --config CONFIG  snapper-configuratie (standaard: root of de eerste)
  -h, --help           toon deze uitleg

Voorbeeld:
  sudo $PROG
  sudo $PROG -c root simon
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        -c|--config)
            [ $# -ge 2 ] || {
                echo "$PROG: -c verwacht een configuratienaam" >&2
                exit 2
            }
            CONFIG=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "$PROG: onbekende optie: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            TARGET_USER=$1
            shift
            ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    HINT="sudo $0"
    if [ -n "$CONFIG" ]; then
        HINT="$HINT -c $CONFIG"
    fi
    if [ -n "$TARGET_USER" ]; then
        HINT="$HINT $TARGET_USER"
    fi
    echo "$PROG: root-rechten nodig om ALLOW_USERS te wijzigen." >&2
    echo "Draai: $HINT" >&2
    exit 1
fi

command -v snapper >/dev/null 2>&1 || {
    echo "$PROG: snapper is niet geïnstalleerd." >&2
    exit 1
}

if [ -z "$CONFIG" ]; then
    if snapper --jsonout list-configs 2>/dev/null \
            | grep -q '"config"[[:space:]]*:[[:space:]]*"root"'; then
        CONFIG=root
    else
        CONFIG=$(snapper --jsonout list-configs 2>/dev/null \
            | sed -n 's/.*"config"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            | head -n 1)
    fi
fi

if [ -z "$CONFIG" ]; then
    echo "$PROG: geen snapper-configuratie gevonden." >&2
    exit 1
fi

if [ -z "$TARGET_USER" ]; then
    TARGET_USER=${SUDO_USER:-}
fi

if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = root ]; then
    echo "$PROG: geef de gebruiker op die toegang krijgt." >&2
    echo "Voorbeeld: sudo $0 -c $CONFIG simon" >&2
    exit 1
fi

id "$TARGET_USER" >/dev/null 2>&1 || {
    echo "$PROG: onbekende gebruiker: $TARGET_USER" >&2
    exit 1
}

CONFIG_JSON=$(snapper --jsonout -c "$CONFIG" get-config) || {
    echo "$PROG: kon de configuratie '$CONFIG' niet lezen." >&2
    exit 1
}

json_string() {
    printf '%s\n' "$CONFIG_JSON" \
        | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
        | head -n 1
}

ALLOW_USERS=$(json_string ALLOW_USERS)

case " $ALLOW_USERS " in
    *" $TARGET_USER "*)
        NEW_ALLOW_USERS=$ALLOW_USERS
        ;;
    *)
        if [ -n "$ALLOW_USERS" ]; then
            NEW_ALLOW_USERS="$ALLOW_USERS $TARGET_USER"
        else
            NEW_ALLOW_USERS=$TARGET_USER
        fi
        ;;
esac

echo "Configuratie '$CONFIG': ALLOW_USERS=\"$NEW_ALLOW_USERS\", SYNC_ACL=yes"

# Eén configdata-argument, zoals de snapper-manpage voorschrijft.
snapper -c "$CONFIG" set-config \
    "ALLOW_USERS=$NEW_ALLOW_USERS SYNC_ACL=yes"

# SYNC_ACL werkt de ACL normaal meteen bij; doe het expliciet als setfacl
# aanwezig is, zodat leestoegang ook op oudere snapper-versies klopt.
SUBVOLUME=$(json_string SUBVOLUME)
case $SUBVOLUME in
    ""|/) SNAPSHOTS=/.snapshots ;;
    *) SNAPSHOTS=${SUBVOLUME%/}/.snapshots ;;
esac

if [ -d "$SNAPSHOTS" ] && command -v setfacl >/dev/null 2>&1; then
    setfacl -m "u:$TARGET_USER:rx" "$SNAPSHOTS" || {
        echo "$PROG: waarschuwing: kon de ACL van $SNAPSHOTS niet bijwerken." >&2
    }
fi

echo "Controleren of '$TARGET_USER' nu mag lezen..."
if command -v runuser >/dev/null 2>&1; then
    if runuser -u "$TARGET_USER" -- snapper -c "$CONFIG" \
            list --columns number >/dev/null 2>&1; then
        echo "OK: 'snapper -c $CONFIG list' werkt als $TARGET_USER."
        echo "Herstart de widget of gebruik de verversenknop in de popup."
        exit 0
    fi
elif su -s /bin/sh "$TARGET_USER" -c \
        "snapper -c '$CONFIG' list --columns number" >/dev/null 2>&1; then
    echo "OK: 'snapper -c $CONFIG list' werkt als $TARGET_USER."
    echo "Herstart de widget of gebruik de verversenknop in de popup."
    exit 0
fi

echo "$PROG: waarschuwing: lezen als '$TARGET_USER' mislukt nog." >&2
echo "Controleer handmatig met: snapper -c $CONFIG list" >&2
exit 1
