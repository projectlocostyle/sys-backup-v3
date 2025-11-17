#!/bin/bash
set -e

CONFIG="/etc/sys-backup-v3/config.yml"
ENVFILE="/etc/sys-backup-v3/.env"
VERSIONFILE="/opt/sys-backup-v3/version"
CHANGELOG="/opt/sys-backup-v3/CHANGELOG.md"
SETUP_GUIDE="/opt/sys-backup-v3/docs/setup-guide.txt"

source "$ENVFILE"

# GitHub Config
GH_USER=$(grep username: "$CONFIG" | awk '{print $2}' | tr -d '"')
GH_REPO=$(grep repository: "$CONFIG" | awk '{print $2}' | tr -d '"')

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ FEHLER: Kein GitHub Token gefunden!"
    exit 1
fi

if [[ -z "$GH_USER" || -z "$GH_REPO" ]]; then
    echo "❌ FEHLER: GitHub Username/Repo fehlt!"
    exit 1
fi

# Version lesen
CUR_VERSION=$(grep VERSION= "$VERSIONFILE" | cut -d'"' -f2)
TAG="v$CUR_VERSION"

echo "--------------------------------------------------------"
echo " AUTO-RELEASE"
echo "--------------------------------------------------------"
echo "Version: $CUR_VERSION"
echo "Tag:     $TAG"
echo ""

LATEST_TAG=$(curl -s https://api.github.com/repos/$GH_USER/$GH_REPO/releases/latest | jq -r '.tag_name')

if [[ "$LATEST_TAG" == "$TAG" ]]; then
    echo "⚠️ Release existiert — Version wird erhöht..."
    sys-backup bump alpha
    CUR_VERSION=$(grep VERSION= "$VERSIONFILE" | cut -d'"' -f2)
    TAG="v$CUR_VERSION"
fi

# Changelog aktualisieren
/opt/sys-backup-v3/bin/changelog.sh

# Release-Ordner vorbereiten
TMP_DIR="/tmp/sys-backup-release"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/sys-backup-v3"

# Projekt kopieren
cp -r /opt/sys-backup-v3/* "$TMP_DIR/sys-backup-v3/"

# Setup-Guide sicherstellen
mkdir -p "$TMP_DIR/sys-backup-v3/docs/"
cp "$SETUP_GUIDE" "$TMP_DIR/sys-backup-v3/docs/"

# ZIP erstellen
ZIP="sys-backup-$CUR_VERSION.zip"
pushd "$TMP_DIR" >/dev/null
zip -r "$ZIP" sys-backup-v3 >/dev/null
popd >/dev/null

SHA_FILE="$ZIP.sha256"
sha256sum "$TMP_DIR/$ZIP" | awk '{print $1}' > "$TMP_DIR/$SHA_FILE"

echo "📦 ZIP erstellt: $ZIP"
echo "📦 SHA erstellt: $SHA_FILE"

# Neues Release auf GitHub erstellen
JSON_PAYLOAD=$(jq -n \
  --arg tag "$TAG" \
  --arg name "Release $TAG" \
  --arg body "Release bereitgestellt am $(date +%Y-%m-%d)" \
  '{ tag_name: $tag, name: $name, body: $body }')

RESPONSE=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  https://api.github.com/repos/$GH_USER/$GH_REPO/releases)

UPLOAD_URL=$(echo "$RESPONSE" | jq -r '.upload_url' | sed 's/{?name,label}//')

if [[ "$UPLOAD_URL" == "null" ]]; then
    echo "❌ FEHLER: Release konnte nicht erstellt werden!"
    echo "$RESPONSE"
    exit 1
fi

echo "🠉 Lade ZIP hoch..."
curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary @"$TMP_DIR/$ZIP" \
  "$UPLOAD_URL?name=$ZIP" >/dev/null

echo "🠉 Lade SHA256 hoch..."
curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary @"$TMP_DIR/$SHA_FILE" \
  "$UPLOAD_URL?name=$SHA_FILE" >/dev/null

echo ""
echo "--------------------------------------------------------"
echo " 🎉 Release erfolgreich!"
echo " ZIP:    $ZIP"
echo " SHA256: $SHA_FILE"
echo "--------------------------------------------------------"
