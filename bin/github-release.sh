#!/bin/bash

CONFIG="/etc/sys-backup-v3/config.yml"
ENVFILE="/etc/sys-backup-v3/.env"
VERSIONFILE="/opt/sys-backup-v3/version"

# ENV Variablen laden
source "$ENVFILE"

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "FEHLER: Kein GitHub Token gefunden!"
    exit 1
fi

# GitHub Daten aus config.yml lesen
GH_USER=$(grep 'username:' "$CONFIG" | awk '{print $2}' | tr -d '"')
GH_REPO=$(grep 'repository:' "$CONFIG" | awk '{print $2}' | tr -d '"')

if [[ -z "$GH_USER" || -z "$GH_REPO" ]]; then
    echo "FEHLER: GitHub-Daten fehlen in config.yml!"
    exit 1
fi

# Version auslesen
VERSION=$(grep 'VERSION=' "$VERSIONFILE" | cut -d'"' -f2)
DATE=$(date +%Y-%m-%d)

# Release-Paket erstellen
TMP="/tmp/sys-backup-v3-release"
rm -rf "$TMP"
mkdir "$TMP"

cp -r /opt/sys-backup-v3 "$TMP/"

cd "$TMP"
tar -czf sys-backup-v3-$VERSION.tar.gz sys-backup-v3/
cd -

# API Upload
echo "Erstelle GitHub Release $VERSION ..."
API_JSON=$(printf '{"tag_name": "%s","name": "Release %s","body": "Automatisches Release am %s"}' "$VERSION" "$VERSION" "$DATE")

RELEASE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$API_JSON" \
  https://api.github.com/repos/$GH_USER/$GH_REPO/releases)

UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | grep upload_url | cut -d'"' -f4 | sed 's/{?name,label}//')

if [[ -z "$UPLOAD_URL" ]]; then
    echo "FEHLER: Release konnte nicht erstellt werden!"
    echo "$RELEASE_RESPONSE"
    exit 1
fi

# Datei hochladen
echo "Lade Release-Datei hoch ..."
curl -s --data-binary @"$TMP/sys-backup-v3-$VERSION.tar.gz" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/gzip" \
  "$UPLOAD_URL?name=sys-backup-v3-$VERSION.tar.gz"

echo "GitHub Release erfolgreich erzeugt!"

