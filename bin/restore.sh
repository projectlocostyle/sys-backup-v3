#!/bin/bash

# --------------------------------------------------------
# SYS-BACKUP-V3 - RESTORE SYSTEM (V1 CLEAN BASE)
# --------------------------------------------------------

LOG="/var/log/sys-backup-v3/restore.log"
BACKUP_BASE="/var/lib/sys-backup-v3/backups"
MANIFEST_BASE="/var/lib/sys-backup-v3/manifests"

echo "--------------------------------------------------------"
echo " SYS-BACKUP-V3 – RESTORE SYSTEM"
echo "--------------------------------------------------------"
echo ""

# --------------------------------------------------------
# BACKUPS AUFLISTEN
# --------------------------------------------------------

echo "Verfügbare Backups:"
echo ""

i=1
declare -A OPTIONS

for DIR in "$BACKUP_BASE"/backup_*; do
    if [[ -d "$DIR" ]]; then
        OPTIONS[$i]="$DIR"
        echo "  $i) $(basename "$DIR")"
        ((i++))
    fi
done

if [[ $i -eq 1 ]]; then
    echo "Keine Backups gefunden!"
    exit 1
fi

echo ""
read -p "Bitte Backup-Nummer wählen: " CHOICE

SELECTED="${OPTIONS[$CHOICE]}"

if [[ -z "$SELECTED" ]]; then
    echo "Ungültige Auswahl!"
    exit 1
fi

BACKUP_NAME=$(basename "$SELECTED")

echo ""
echo "Backup gewählt: $SELECTED"

# --------------------------------------------------------
# MANIFEST RICHTIG SUCHEN
# --------------------------------------------------------

MANIFEST="$MANIFEST_BASE/${BACKUP_NAME}.yml"

echo ""
echo "Manifest wird gesucht unter:"
echo "  $MANIFEST"
echo ""

if [[ ! -f "$MANIFEST" ]]; then
    echo "FEHLER: Manifest NICHT gefunden!"
    exit 1
fi

echo "Manifest gefunden!"
echo ""

# --------------------------------------------------------
# BACKUP-INFO AUS MANIFEST LADEN
# --------------------------------------------------------

BACKUP_HOST=$(grep 'host:' "$MANIFEST" | awk '{print $2}' | tr -d '"')
BACKUP_IP=$(grep 'ip:' "$MANIFEST" | awk '{print $2}' | tr -d '"')
BACKUP_TS=$(grep 'timestamp:' "$MANIFEST" | awk -F': ' '{print $2}' | tr -d '"')

CURRENT_HOST=$(hostname)
CURRENT_IP=$(hostname -I | awk '{print $1}')

echo "Backup-Informationen:"
echo "  Original Host : $BACKUP_HOST"
echo "  Original IP   : $BACKUP_IP"
echo "  Backup Zeit   : $BACKUP_TS"
echo ""
echo "Aktuelles System:"
echo "  Host          : $CURRENT_HOST"
echo "  IP            : $CURRENT_IP"
echo ""

# --------------------------------------------------------
# HOST-SICHERHEITSPRÜFUNG
# --------------------------------------------------------

if [[ "$BACKUP_HOST" != "$CURRENT_HOST" ]]; then
    echo "WARNUNG: Hostname stimmt NICHT überein!"
    echo "Backup stammt von einem anderen Server!"
    read -p "Restore trotzdem fortsetzen? (y/N): " FORCE
    if [[ "$FORCE" != "y" ]]; then
        echo "Restore abgebrochen."
        exit 1
    fi
fi

echo "Hostprüfung bestanden."
echo ""


# --------------------------------------------------------
# HASH-INTEGRITÄTSPRÜFUNG
# --------------------------------------------------------

HASHFILE="$SELECTED/hashes.sha256"

echo ""
echo "Prüfe Integrität..."
echo "Hash-Datei: $HASHFILE"
echo ""

if [[ ! -f "$HASHFILE" ]]; then
    echo "WARNUNG: Keine Hash-Datei gefunden!"
    read -p "Trotzdem fortfahren? (y/N): " FORCEHASH
    if [[ "$FORCEHASH" != "y" ]]; then
        echo "Restore abgebrochen."
        exit 1
    fi
else
    # Prüfe ob das Hashfile leer ist
    if [[ ! -s "$HASHFILE" ]]; then
        echo "Hinweis: Hash-Datei ist leer (keine Docker-Daten vorhanden)."
        echo "Integrität OK."
    else
        echo "Hashcheck läuft..."
        RESULT=$(sha256sum -c "$HASHFILE" 2>&1)

        echo "$RESULT"

        BAD=$(echo "$RESULT" | grep -i "FAILED")

        if [[ -n "$BAD" ]]; then
            echo ""
            echo "FEHLER: Integritätsprüfung ist FEHLGESCHLAGEN!"
            echo "$BAD"
            read -p "Restore trotzdem erzwingen? (y/N): " FORCE2
            if [[ "$FORCE2" != "y" ]]; then
                echo "Restore abgebrochen."
                exit 1
            fi
        else
            echo ""
            echo "Integrität OK."
        fi
    fi
fi

echo ""


# --------------------------------------------------------
# VOLUME RESTORE
# --------------------------------------------------------

echo "Starte Volume-Restore..."
echo ""

if ! command -v docker &> /dev/null; then
    echo "Docker nicht installiert – Volume-Restore übersprungen."
else
    for PROFILE in /etc/sys-backup-v3/projects/*.yml; do
        [[ -e "$PROFILE" ]] || continue

        PROJECT=$(grep '^project:' "$PROFILE" | awk '{print $2}' | tr -d '"')
        echo "Projekt: $PROJECT"
        
        VOLUMES=$(grep '  - ' "$PROFILE" | grep -v ':' | sed 's/  - //')

        for VOL in $VOLUMES; do
            FILE="$SELECTED/volumes/${VOL}.tar.gz"
            if [[ ! -f "$FILE" ]]; then
                echo "  WARNUNG: Volume-Backup fehlt: $FILE"
                continue
            fi

            echo "  Restore Volume: $VOL"
            docker volume create "$VOL" >/dev/null

            docker run --rm \
                -v "$VOL":/restore \
                -v "$FILE":/backup.tar.gz \
                alpine sh -c "rm -rf /restore/* && tar -xzf /backup.tar.gz -C /restore"

            echo "  ✔ Volume wiederhergestellt: $VOL"
        done
    done
fi

echo ""

# --------------------------------------------------------
# BIND-MOUNT RESTORE
# --------------------------------------------------------

echo "Starte Bind-Mount Restore..."
echo ""

if ! command -v docker &> /dev/null; then
    echo "Docker nicht installiert – Bind-Mount Restore übersprungen."
else
    for PROFILE in /etc/sys-backup-v3/projects/*.yml; do
        [[ -e "$PROFILE" ]] || continue

        PROJECT=$(grep '^project:' "$PROFILE" | awk '{print $2}' | tr -d '"')
        echo "Projekt: $PROJECT"

        MOUNTS=$(grep ':' "$PROFILE" | sed 's/  - //')

        for ENTRY in $MOUNTS; do
            SRC=$(echo "$ENTRY" | cut -d':' -f1)
            NAME=$(echo "$SRC" | sed 's/\//_/g')
            FILE="$SELECTED/bind_mounts/${NAME}.tar.gz"

            if [[ ! -f "$FILE" ]]; then
                echo "  WARNUNG: Bind-Mount fehlt: $FILE"
                continue
            fi

            echo "  Restore Bind-Mount: $SRC"
            mkdir -p "$SRC"
            tar -xzf "$FILE" -C "$SRC"

            echo "  ✔ Bind-Mount wiederhergestellt: $SRC"
        done
    done
fi

echo ""
echo "Restore-Vorgang abgeschlossen!"
echo ""


# --------------------------------------------------------
# ABSCHLUSSBERICHT – RESTORE SUMMARY
# --------------------------------------------------------

echo ""
echo "--------------------------------------------------------"
echo "Restore erfolgreich abgeschlossen!"
echo "--------------------------------------------------------"
echo ""

echo "Restore-Details:"
echo "  Hostname:      $(hostname)"
echo "  IP:            $(hostname -I | awk '{print $1}')"
echo "  Backup:        $BACKUP_NAME"
echo "  Manifest:      $(basename "$MANIFEST")"

# Zählen der Restore-Dateien
RESTORE_VOL_COUNT=$(find "$SELECTED/volumes" -type f | wc -l)
RESTORE_BIND_COUNT=$(find "$SELECTED/bind_mounts" -type f | wc -l)

echo "  Volumes:       $RESTORE_VOL_COUNT"
echo "  Bind Mounts:   $RESTORE_BIND_COUNT"

echo ""
echo "Restore-Log gespeichert unter: $LOG"
echo ""
