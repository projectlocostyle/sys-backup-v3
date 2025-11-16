#!/bin/bash

# --------------------------------------------------------
# SYS-BACKUP-V3 - RCLONE SETUP
# --------------------------------------------------------

CONFIG="/etc/sys-backup-v3/config.yml"
ENVFILE="/etc/sys-backup-v3/.env"
LOG="/var/log/sys-backup-v3/rclone-setup.log"

echo "--------------------------------------------------------" | tee -a "$LOG"
echo "SYS-BACKUP-V3 RCLONE SETUP" | tee -a "$LOG"
echo "--------------------------------------------------------" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# Prüfen ob rclone installiert ist
if ! command -v rclone &> /dev/null; then
    echo "Rclone ist nicht installiert. Installiere..." | tee -a "$LOG"
    apt update && apt install -y rclone >> "$LOG" 2>&1

    if ! command -v rclone &> /dev/null; then
        echo "FEHLER: Rclone konnte nicht installiert werden!" | tee -a "$LOG"
        exit 1
    fi
else
    echo "Rclone ist bereits installiert." | tee -a "$LOG"
fi

# Aus der config.yml den Speicher-Typ lesen
STORAGE_TYPE=$(grep 'type:' /etc/sys-backup-v3/config.yml | awk '{print $2}' | tr -d '"')

echo "Speichertyp erkannt: $STORAGE_TYPE" | tee -a "$LOG"

# Remote-Namen aus der config
REMOTE=$(grep 'rclone_remote:' /etc/sys-backup-v3/config.yml | awk '{print $2}' | tr -d '"')

if [[ "$REMOTE" == "null" || -z "$REMOTE" ]]; then
    echo "Kein Remote definiert. Abbruch." | tee -a "$LOG"
    exit 0
fi

echo "Remote-Name: $REMOTE" | tee -a "$LOG"

mkdir -p /root/.config/rclone

RCLONE_CONF="/root/.config/rclone/rclone.conf"

echo "" >> "$LOG"
echo "Erzeuge Rclone-Config: $RCLONE_CONF" | tee -a "$LOG"

# FALL 1: NEXTCLOUD --------------------------------------
if [[ "$STORAGE_TYPE" == "nextcloud" ]]; then

    source $ENVFILE

    NC_USER=$(grep 'user:' $CONFIG | head -1 | awk '{print $2}' | tr -d '"')
    NC_WEBDAV=$(grep 'webdav_url:' $CONFIG | awk '{print $2}' | tr -d '"')

    cat <<EOC > $RCLONE_CONF
[$REMOTE]
type = webdav
url = $NC_WEBDAV
vendor = nextcloud
user = $NC_USER
pass = $NEXTCLOUD_PASS
EOC

    echo "Nextcloud Remote wurde erstellt." | tee -a "$LOG"
fi

# Remote testen
echo "" | tee -a "$LOG"
echo "Teste Remote..." | tee -a "$LOG"

if rclone ls $REMOTE: &>> "$LOG"; then
    echo "Remote funktioniert erfolgreich!" | tee -a "$LOG"
else
    echo "FEHLER: Remote konnte nicht getestet werden!" | tee -a "$LOG"
    echo "Bitte prüfe deine Zugangsdaten." | tee -a "$LOG"
    exit 1
fi

echo ""
echo "Rclone wurde erfolgreich eingerichtet."
echo "Log unter: $LOG"

