#!/bin/bash

set -e

CONFIG="/etc/sys-backup-v3/config.yml"
ENVFILE="/etc/sys-backup-v3/.env"
VERSIONFILE="/opt/sys-backup-v3/version"

source "$ENVFILE"

GH_USER=$(grep username: "$CONFIG" | awk '{print $2}' | tr -d '"')
GH_REPO=$(grep repository: "$CONFIG" | awk '{print $2}' | tr -d '"')

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ FEHLER: Kein GitHub Token!"
    exit 1
fi

VERSION=$(grep VERSION= "$VERSIONFILE" | cut -d'"' -f2)
TAG="v$VERSION"

echo "--------------------------------------------------------"
echo " AUTO-RELEASE"
echo "--------------------------------------------------------"
echo "Version: $VERSION"
echo "Tag:     $TAG"
echo ""

# Release erstellen
echo "📦 Erstelle Release..."
RELEASE_RESPONSE=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"Release $VERSION\"}" \
    https://api.github.com/repos/$GH_USER/$GH_REPO/releases)

UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | jq -r .upload_url | sed 's/{?name,label}//')

if [[ "$UPLOAD_URL" == "null" ]]; then
    echo "⚠️ Release schon vorhanden – Version wird erhöht"
    sys-backup bump alpha
    exit 1
fi

TMP="/tmp/sys-backup-v3-release"
rm -rf "$TMP"
mkdir -p "$TMP"

ZIP="$TMP/sys-backup-$VERSION.zip"

echo "📦 Erstelle ZIP..."
cd /opt
zip -qr "$ZIP" sys-backup-v3/

ZIP_SIZE=$(stat -c%s "$ZIP")

if [[ "$ZIP_SIZE" -lt 5000 ]]; then
    echo "❌ FEHLER: ZIP ist beschädigt (nur $ZIP_SIZE bytes)"
    exit 1
fi

echo "✔ ZIP OK ($ZIP_SIZE bytes)"

# SHA erzeugen
SHA_FILE="$ZIP.sha256"
sha256sum "$ZIP" | awk '{print $1}' > "$SHA_FILE"

echo "🠉 Lade ZIP hoch..."
ASSET_RESPONSE=$(curl -s \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/zip" \
    --data-binary @"$ZIP" \
    "$UPLOAD_URL?name=$(basename $ZIP)")

if echo "$ASSET_RESPONSE" | grep -q '"errors"'; then
    echo "❌ FEHLER beim Hochladen der ZIP!"
    echo "$ASSET_RESPONSE"
    exit 1
fi

echo "✔ ZIP erfolgreich hochgeladen"

echo "🠉 Lade SHA256 hoch..."
SHA_RESPONSE=$(curl -s \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: text/plain" \
    --data-binary @"$SHA_FILE" \
    "$UPLOAD_URL?name=$(basename $SHA_FILE)")

if echo "$SHA_RESPONSE" | grep -q '"errors"'; then
    echo "❌ FEHLER beim Hochladen der SHA!"
    echo "$SHA_RESPONSE"
    exit 1
fi

echo ""
echo "--------------------------------------------------------"
echo " 🎉 Release erfolgreich!"
echo " ZIP:    $(basename "$ZIP")"
echo " SHA256: $(basename "$SHA_FILE")"
echo "--------------------------------------------------------"
