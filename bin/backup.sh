#!/bin/bash

# --------------------------------------------------------
# SYS-BACKUP-V3 - BACKUP (GERÜST)
# --------------------------------------------------------

LOG="/var/log/sys-backup-v3/backup.log"
CONFIG="/etc/sys-backup-v3/config.yml"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "--------------------------------------------------------" | tee -a "$LOG"
echo "SYS-BACKUP-V3 BACKUP gestartet: $TIMESTAMP" | tee -a "$LOG"
echo "--------------------------------------------------------" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# Noch keine Funktionen, nur Testausgabe
echo "Backup-System ist bereit. Funktion folgt im nächsten Schritt." | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "Backup wurde erfolgreich als Dummy ausgeführt." | tee -a "$LOG"


# --------------------------------------------------------
# DOCKER-PROJEKTE ERKENNEN (falls verfügbar)
# --------------------------------------------------------

if command -v docker &> /dev/null; then
    echo "Starte Docker-Projekterkennung..." | tee -a "$LOG"
    /opt/sys-backup-v3/bin/docker-scan.sh | tee -a "$LOG"
    echo "Docker-Scan abgeschlossen." | tee -a "$LOG"
else
    echo "Docker ist nicht installiert. Docker-Scan übersprungen." | tee -a "$LOG"
fi

# --------------------------------------------------------
# MANIFEST ERSTELLEN (Platzhalter)
# --------------------------------------------------------

MANIFEST="/var/lib/sys-backup-v3/manifests/backup_$(date +%Y-%m-%d_%H-%M-%S).yml"

echo "Erstelle Manifest: $MANIFEST" | tee -a "$LOG"

cat <<EOM > "$MANIFEST"
backup:
  timestamp: "$(date +%Y-%m-%d\ %H:%M:%S)"
  host: "$(hostname)"
  ip: "$(hostname -I | awk '{print $1}')"
  projects_dir: "/etc/sys-backup-v3/projects"
EOM

echo "Manifest erstellt." | tee -a "$LOG"

# --------------------------------------------------------
# BACKUP-PFAD ERSTELLEN
# --------------------------------------------------------

BACKUP_FOLDER="/var/lib/sys-backup-v3/backups/backup_$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$BACKUP_FOLDER/volumes"
mkdir -p "$BACKUP_FOLDER/bind_mounts"

echo "Backup-Pfad erstellt: $BACKUP_FOLDER" | tee -a "$LOG"


# --------------------------------------------------------
# DOCKER VOLUME BACKUP
# --------------------------------------------------------

if command -v docker &> /dev/null; then
    echo "Starte Volume-Backup..." | tee -a "$LOG"

    for PROFILE in /etc/sys-backup-v3/projects/*.yml; do
        [[ -e "$PROFILE" ]] || continue

        PROJECT=$(grep '^project:' "$PROFILE" | awk '{print $2}' | tr -d '"')
        echo "Projekt: $PROJECT" | tee -a "$LOG"

        # Volume-Liste laden
        VOLUMES=$(grep '  - ' "$PROFILE" | grep -v ':' | sed 's/  - //')

        for VOL in $VOLUMES; do
            echo "  Sichere Volume: $VOL" | tee -a "$LOG"
            ARCHIVE="$BACKUP_FOLDER/volumes/${VOL}.tar.gz"

            docker run --rm \
                -v ${VOL}:/volume \
                alpine tar -czf - -C /volume . > "$ARCHIVE"

            if [[ $? -eq 0 ]]; then
                echo "  Volume gesichert: $ARCHIVE" | tee -a "$LOG"
            else
                echo "  FEHLER beim Sichern von Volume $VOL" | tee -a "$LOG"
            fi
        done
    done
else
    echo "Docker nicht installiert. Volume-Backup übersprungen." | tee -a "$LOG"
fi


# --------------------------------------------------------
# BIND-MOUNT BACKUP
# --------------------------------------------------------

if command -v docker &> /dev/null; then
    echo "Starte Bind-Mount-Backup..." | tee -a "$LOG"

    for PROFILE in /etc/sys-backup-v3/projects/*.yml; do
        [[ -e "$PROFILE" ]] || continue

        PROJECT=$(grep '^project:' "$PROFILE" | awk '{print $2}' | tr -d '"')
        echo "Projekt: $PROJECT" | tee -a "$LOG"

        MOUNTS=$(grep ':' "$PROFILE" | sed 's/  - //')

        for ENTRY in $MOUNTS; do
            SRC=$(echo "$ENTRY" | cut -d':' -f1)
            DST=$(echo "$ENTRY" | cut -d':' -f2)

            NAME=$(echo "$SRC" | sed 's/\//_/g')
            ARCHIVE="$BACKUP_FOLDER/bind_mounts/${NAME}.tar.gz"

            echo "  Sichere Bind-Mount: $SRC -> $DST" | tee -a "$LOG"

            tar -czf "$ARCHIVE" -C "$SRC" . 2>> "$LOG"

            if [[ $? -eq 0 ]]; then
                echo "  Bind-Mount gesichert: $ARCHIVE" | tee -a "$LOG"
            else
                echo "  FEHLER beim Sichern von $SRC" | tee -a "$LOG"
            fi
        done
    done
else
    echo "Docker nicht installiert. Bind-Mount-Backup übersprungen." | tee -a "$LOG"
fi


# --------------------------------------------------------
# HASHING-SYSTEM (SHA256)
# --------------------------------------------------------

echo "Starte Hash-Berechnung..." | tee -a "$LOG"

HASHFILE="$BACKUP_FOLDER/hashes.sha256"
touch "$HASHFILE"

# Volumes hashen
if [[ -d "$BACKUP_FOLDER/volumes" ]]; then
    for FILE in "$BACKUP_FOLDER"/volumes/*.tar.gz; do
        [[ -e "$FILE" ]] || continue
        sha256sum "$FILE" >> "$HASHFILE"
        echo "  Hash für Volume erstellt: $FILE" | tee -a "$LOG"
    done
fi

# Bind-Mounts hashen
if [[ -d "$BACKUP_FOLDER/bind_mounts" ]]; then
    for FILE in "$BACKUP_FOLDER"/bind_mounts/*.tar.gz; do
        [[ -e "$FILE" ]] || continue
        sha256sum "$FILE" >> "$HASHFILE"
        echo "  Hash für Bind-Mount erstellt: $FILE" | tee -a "$LOG"
    done
fi

echo "Hash-Berechnung abgeschlossen." | tee -a "$LOG"
echo "Hash-Datei gespeichert unter: $HASHFILE" | tee -a "$LOG"


# --------------------------------------------------------
# ABSCHLUSSBERICHT
# --------------------------------------------------------

echo "" | tee -a "$LOG"
echo "--------------------------------------------------------" | tee -a "$LOG"
echo "Backup erfolgreich abgeschlossen!" | tee -a "$LOG"
echo "--------------------------------------------------------" | tee -a "$LOG"
echo "" | tee -a "$LOG"

echo "Backup-Details:" | tee -a "$LOG"
echo "  Hostname:      $(hostname)" | tee -a "$LOG"
echo "  IP:            $(hostname -I | awk '{print $1}')" | tee -a "$LOG"
echo "  Manifest:      $(basename "$MANIFEST")" | tee -a "$LOG"
echo "  Hash-Datei:    $(basename "$HASHFILE")" | tee -a "$LOG"
echo "  Speicherort:   $BACKUP_FOLDER" | tee -a "$LOG"

# Zähle Dateien
VOL_COUNT=$(find "$BACKUP_FOLDER/volumes" -type f | wc -l)
BIND_COUNT=$(find "$BACKUP_FOLDER/bind_mounts" -type f | wc -l)

echo "  Volumes:       $VOL_COUNT" | tee -a "$LOG"
echo "  Bind Mounts:   $BIND_COUNT" | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "Backup-Log gespeichert unter: $LOG" | tee -a "$LOG"
echo "" | tee -a "$LOG"

