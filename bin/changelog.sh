#!/bin/bash

set -e

CHANGELOG="/opt/sys-backup-v3/CHANGELOG.md"
VERSIONFILE="/opt/sys-backup-v3/version"

# Aktuelle Version
VERSION=$(grep VERSION= "$VERSIONFILE" | cut -d'"' -f2)
DATE=$(date +%Y-%m-%d)

echo "--------------------------------------------------------"
echo " SYS-BACKUP-V3 - CHANGELOG GENERATOR"
echo "--------------------------------------------------------"
echo ""

# Manuelle Notiz
echo "Optional: kurze manuelle Release-Notiz (Enter für leer):"
read -r MANUAL_NOTE

# Letzten Git Tag holen
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Git Commits einlesen
if [[ -z "$LAST_TAG" ]]; then
    COMMITS=$(git log --pretty=format:"- %s" || true)
else
    COMMITS=$(git log "$LAST_TAG"..HEAD --pretty=format:"- %s" || true)
fi

# Kategorien erkennen
ADDED=$(echo "$COMMITS"    | grep -Ei "(add|added|create)" || true)
IMPROVED=$(echo "$COMMITS" | grep -Ei "(improv|enhanc)" || true)
FIXED=$(echo "$COMMITS"    | grep -Ei "(fix|bug)" || true)

# Änderungen zusammenbauen
CONTENT="## $VERSION – $DATE\n\n"

if [[ -n "$MANUAL_NOTE" ]]; then
    CONTENT+="$MANUAL_NOTE\n\n"
fi

if [[ -n "$ADDED" ]]; then
    CONTENT+="### Added\n$ADDED\n\n"
fi

if [[ -n "$IMPROVED" ]]; then
    CONTENT+="### Improved\n$IMPROVED\n\n"
fi

if [[ -n "$FIXED" ]]; then
    CONTENT+="### Fixed\n$FIXED\n\n"
fi

# Falls keine Inhalte: nur Überschrift erstellen
if [[ -z "$ADDED$IMPROVED$FIXED$MANUAL_NOTE" ]]; then
    CONTENT+="(No changes documented)\n\n"
fi

# Alten Changelog lesen (ohne Header)
OLD=$(tail -n +2 "$CHANGELOG")

# Neuen Changelog generieren
{
    echo "# Sys-Backup-V3 – Changelog"
    echo ""
    echo -e "$CONTENT"
    echo -e "$OLD"
} > "$CHANGELOG"

echo "Changelog aktualisiert!"
