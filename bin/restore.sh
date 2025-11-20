#!/bin/bash

# --------------------------------------------------------
# SYS-BACKUP-V3 - RESTORE SYSTEM (mit Nextcloud-Unterstützung)
# --------------------------------------------------------

LOG="/var/log/sys-backup-v3/restore.log"
LOCAL_BASE="/var/lib/sys-backup-v3/backups"
REMOTE_BASE="backup:Server-Backups"

echo "--------------------------------------------------------"
echo " SYS-BACKUP-V3 – RESTORE SYSTEM (CLOUD READY)"
echo "--------------------------------------------------------"
echo ""

mkdir -p /var/log/sys-backup-v3

# --------------------------------------------------------
# QUELLE AUSWÄHLEN
# --------------------------------------------------------

echo "Backup-Quelle auswählen:"
echo "  1) Lokale Backups"
echo "  2) Nextcloud (Remote: backup)"
echo ""

read -p "Auswahl: " SRC

# --------------------------------------------------------
# NEXTCLOUD BACKUPS
# --------------------------------------------------------
if [[ "$SRC" == "2" ]]; then
    echo ""
    echo "Lese Backups aus Nextcloud..."
    echo ""

    mapfile -t REMOTE_LIST < <(rclone lsd "$REMOTE_BASE" | awk '{print $5}')

    if [[ ${#REMOTE_LIST[@]} -eq 0 ]]; then
        echo "Keine Backups in Nextcloud gefunden!"
        exit 1
    fi

    i=1
    declare -A OPTIONS

    for B in "${REMOTE_LIST[@]}"; do
        OPTIONS[$i]="$B"
        echo "  $i) $B"
        ((i++))
    done

    echo ""
    read -p "Bitte Backup-Nummer wählen: " CHOICE

    SELECTED="${OPTIONS[$CHOICE]}"

    if [[ -z "$SELECTED" ]]; then
        echo "Ungültige Auswahl!"
        exit 1
    fi

    echo ""
    echo "Lade Backup aus Nextcloud: $SELECTED"
    echo ""

    TMP="/tmp/sys-restore"
    rm -rf "$TMP"
    mkdir -p "$TMP"

    rclone copy "$REMOTE_BASE/$SELECTED" "$TMP" -P

    BACKUP_PATH="$TMP"
    MANIFEST=$(find "$TMP" -name "*.yml" | head -n 1)

    if [[ ! -f "$MANIFEST" ]]; then
        echo "FEHLER: Manifest nicht gefunden!"
        exit 1
    fi

# --------------------------------------------------------
# LOKALE BACKUPS
# --------------------------------------------------------
else
    echo ""
    echo "Verfügbare lokale Backups:"
    echo ""

    i=1
    declare -A OPTIONS_LOCAL

    for DIR in "$LOCAL_BASE"/backup_*; do
        [[ -d "$DIR" ]] || continue
        OPTIONS_LOCAL[$i]="$DIR"
        echo "  $i) $(basename "$DIR")"
        ((i++))
    done

    if [[ $i -eq 1 ]]; then
        echo "Keine lokalen Backups gefunden!"
        exit 1
    fi

    echo ""
    read -p "Bitte Backup-Nummer wählen: " CHOICE

    SELECTED="${OPTIONS_LOCAL[$CHOICE]}"

    if [[ -z "$SELECTED" ]]; then
        echo "Ungültige Auswahl!"
        exit 1
    fi

    BACKUP_PATH="$SELECTED"
    MANIFEST=$(find "$SELECTED" -name "*.yml" | head -n 1)
fi

echo ""
echo "Backup-Verzeichnis:"
echo "  $BACKUP_PATH"
echo ""
echo "Manifest:"
echo "  $MANIFEST"
echo ""

# --------------------------------------------------------
# BACKUP-INFO LADEN
# --------------------------------------------------------

BACKUP_HOST=$(grep 'host:' "$MANIFEST" | awk '{print $2}' | tr -d '"')
BACKUP_IP=$(grep 'ip:' "$MANIFEST" | awk '{print $2}' | tr -d '"')
BACKUP_TS=$(grep 'timestamp:' "$MANIFEST" | awk -F': ' '{print $2}' | tr -d '"')

echo "Backup-Details:"
echo "  Host:   $BACKUP_HOST"
echo "  IP:     $BACKUP_IP"
echo "  Zeit:   $BACKUP_TS"
echo ""

# --------------------------------------------------------
# DOCKER STOPPEN
# --------------------------------------------------------

echo "Stoppe laufende Docker-Container..."
docker stop $(docker ps -q) 2>/dev/null || true
echo ""

# --------------------------------------------------------
# RESTORE VON VOLUMES
# --------------------------------------------------------

echo "Starte Volume-Restore..."
echo ""

for TAR in "$BACKUP_PATH"/volumes/*.tar.gz; do
    VOL=$(basename "$TAR" .tar.gz)

    echo "  Volume: $VOL"
    docker volume create "$VOL" >/dev/null

    docker run --rm \
        -v "$VOL":/restore \
        -v "$TAR":/backup.tar.gz \
        alpine sh -c "rm -rf /restore/* && tar -xzf /backup.tar.gz -C /restore"

    echo "  ✔ Wiederhergestellt: $VOL"
done

echo ""

# --------------------------------------------------------
# RESTORE VON BIND-MOUNTS
# --------------------------------------------------------

echo "Starte Bind-Mount Restore..."
echo ""

for TAR in "$BACKUP_PATH"/bind_mounts/*.tar.gz; do
    NAME=$(basename "$TAR" .tar.gz)
    DEST=$(echo "$NAME" | sed 's/_/\//g')

    echo "  Bind-Mount: $DEST"
    mkdir -p "$DEST"
    tar -xzf "$TAR" -C "$DEST"

    echo "  ✔ Wiederhergestellt: $DEST"
done

echo ""

# --------------------------------------------------------
# ABSCHLUSS
# --------------------------------------------------------

echo "Restore erfolgreich abgeschlossen!"
echo ""
echo "Backup verwendet: $(basename "$BACKUP_PATH")"
echo ""
