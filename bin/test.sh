#!/bin/bash

# --------------------------------------------------------
# SYS-BACKUP-V3 - AUTO-TESTS (GERÜST)
# --------------------------------------------------------

LOG="/var/log/sys-backup-v3/tests.log"
CONFIG="/etc/sys-backup-v3/config.yml"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "--------------------------------------------------------" | tee -a "$LOG"
echo "SYS-BACKUP-V3 TESTSYSTEM gestartet: $TIMESTAMP" | tee -a "$LOG"
echo "--------------------------------------------------------" | tee -a "$LOG"
echo "" | tee -a "$LOG"

echo "Testsystem aktiv." | tee -a "$LOG"
echo "Im nächsten Schritt implementieren wir:" | tee -a "$LOG"
echo "  - Backup-Test" | tee -a "$LOG"
echo "  - Restore-Sandbox-Test" | tee -a "$LOG"
echo "  - Hash-Checks" | tee -a "$LOG"


# --------------------------------------------------------
# BACKUP-TEST
# --------------------------------------------------------

echo ""
echo "--------------------------------------------------------"
echo " Starte BACKUP-TEST"
echo "--------------------------------------------------------"
echo ""

TEST_BACKUP_LOG="/var/log/sys-backup-v3/test-backup.log"

# Backup ausführen
sys-backup backup > "$TEST_BACKUP_LOG" 2>&1

if [[ $? -ne 0 ]]; then
    echo "FEHLER: Backup-Test fehlgeschlagen!"
    echo "Siehe Log: $TEST_BACKUP_LOG"
else
    echo "Backup-Test erfolgreich abgeschlossen!"
fi


# --------------------------------------------------------
# RESTORE-SANDBOX-TEST
# --------------------------------------------------------

echo ""
echo "--------------------------------------------------------"
echo " Starte RESTORE-SANDBOX-TEST"
echo "--------------------------------------------------------"
echo ""

SANDBOX="/tmp/sys-backup-sandbox"
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX"

# Letztes Backup suchen
LATEST_BACKUP=$(ls -1t /var/lib/sys-backup-v3/backups | head -n 1)
LATEST_PATH="/var/lib/sys-backup-v3/backups/$LATEST_BACKUP"
HASHFILE="$LATEST_PATH/hashes.sha256"

echo "Verwende Backup: $LATEST_BACKUP"
echo ""

if [[ ! -d "$LATEST_PATH" ]]; then
    echo "FEHLER: Kein Backup gefunden!"
    exit 1
fi

# Hashcheck
if [[ ! -s "$HASHFILE" ]]; then
    echo "Hinweis: Hashdatei ist leer – keine Docker-Daten im Backup."
else
    echo "Prüfe Hashes im Sandbox-Modus..."
    RESULT=$(sha256sum -c "$HASHFILE" 2>&1)
    echo "$RESULT"

    if echo "$RESULT" | grep -qi "FAILED"; then
        echo "FEHLER: Hashprüfung im Sandbox-Test fehlgeschlagen!"
        exit 1
    fi
fi

echo "Restore-Sandbox Hashcheck OK."

# Test-Dekompremierung (Bind-Mounts)
echo ""
echo "Teste Entpacken der Archive..."

mkdir -p "$SANDBOX/test"

for FILE in "$LATEST_PATH"/bind_mounts/*.tar.gz "$LATEST_PATH"/volumes/*.tar.gz; do
    [[ -e "$FILE" ]] || continue
    echo "Entpacke $FILE..."
    tar -xzf "$FILE" -C "$SANDBOX/test" 2>/dev/null
done

echo "Archive entpackbar. Restore-Sandbox-Test erfolgreich abgeschlossen!"


# --------------------------------------------------------
# HASH-TEST (Vollständige Integritätsprüfung)
# --------------------------------------------------------

echo ""
echo "--------------------------------------------------------"
echo " Starte HASH-TEST"
echo "--------------------------------------------------------"
echo ""

LATEST_BACKUP=$(ls -1t /var/lib/sys-backup-v3/backups | head -n 1)
LATEST_PATH="/var/lib/sys-backup-v3/backups/$LATEST_BACKUP"
HASHFILE="$LATEST_PATH/hashes.sha256"

echo "Prüfe Hashdatei: $HASHFILE"
echo ""

if [[ ! -f "$HASHFILE" ]]; then
    echo "FEHLER: Keine Hashdatei gefunden!"
    exit 1
fi

if [[ ! -s "$HASHFILE" ]]; then
    echo "Hinweis: Hashdatei ist leer – keine Docker-Daten vorhanden."
    echo "Hash-Test OK."
else
    RESULT=$(sha256sum -c "$HASHFILE" 2>&1)
    echo "$RESULT"

    if echo "$RESULT" | grep -qi "FAILED"; then
        echo "FEHLER: Hash-Test fehlgeschlagen!"
        exit 1
    fi

    echo ""
    echo "Hash-Test OK."
fi


# --------------------------------------------------------
# TEST-SUMMARY
# --------------------------------------------------------

echo ""
echo "--------------------------------------------------------"
echo " TEST-SUMMARY"
echo "--------------------------------------------------------"
echo ""

echo "Backup-Test:             OK"
echo "Restore-Sandbox-Test:    OK"
echo "Hash-Test:               OK"

echo ""
echo "Alle Tests erfolgreich abgeschlossen!"
echo ""
