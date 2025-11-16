#!/bin/bash

set -e

CONFIG="/etc/sys-backup-v3/config.yml"
VERSIONFILE="/opt/sys-backup-v3/version"
ENVFILE="/etc/sys-backup-v3/.env"

source "$ENVFILE"

GH_USER=$(grep username: "$CONFIG" | awk '{print $2}' | tr -d '"')
GH_REPO=$(grep repository: "$CONFIG" | awk '{print $2}' | tr -d '"')

LOCAL_VERSION=$(grep VERSION= "$VERSIONFILE" | cut -d'"' -f2)

echo "--------------------------------------------------------"
echo " SYS-BACKUP-V3 - UPDATE"
echo "--------------------------------------------------------"

echo "Lokal:  $LOCAL_VERSION"

# Online Version ermitteln
ONLINE_VERSION=$(curl -s https://api.github.com/repos/$GH_USER/$GH_REPO/releases/latest \
  | jq -r .tag_name | sed 's/^v//')

echo "Online: $ONLINE_VERSION"

# Wenn identisch → fertig
if [[ "$LOCAL_VERSION" == "$ONLINE_VERSION" ]]; then
    echo "💚 Bereits aktuell."
else
    echo "🔄 Update gefunden → $ONLINE_VERSION"
fi

# Asset URLs holen
ZIP_URL=$(curl -s https://api.github.com/repos/$GH_USER/$GH_REPO/releases/latest | jq -r '.assets[] | select(.name|endswith(".zip")) | .browser_download_url')
SHA_URL=$(curl -s https://api.github.com/repos/$GH_USER/$GH_REPO/releases/latest | jq -r '.assets[] | select(.name|endswith(".sha256")) | .browser_download_url')

TMP_DIR="/tmp/sys-backup-update"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

ZIP_FILE="$TMP_DIR/update.zip"
SHA_FILE="$TMP_DIR/update.sha256"

echo ""
echo "📥 Lade ZIP herunter..."
curl -L --fail -o "$ZIP_FILE" "$ZIP_URL"

# ZIP Größe prüfen
ZIP_SIZE=$(stat -c%s "$ZIP_FILE")

if [[ "$ZIP_SIZE" -lt 5000 ]]; then
    echo "❌ FEHLER: ZIP-Datei ist zu klein oder beschädigt!"
    echo "Größe: $ZIP_SIZE bytes"
    exit 1
fi

echo "✔ ZIP Größe OK ($ZIP_SIZE bytes)"

# SHA herunterladen
echo "📥 Lade SHA256..."
curl -L --fail -o "$SHA_FILE" "$SHA_URL"

echo "🔐 Prüfe SHA256..."
cd "$TMP_DIR"

if ! sha256sum --status -c "$SHA_FILE"; then
    echo "❌ FEHLER: SHA256 Hash stimmt NICHT!"
    exit 1
fi

echo "✔ SHA256 OK"

# Entpacktest
echo "📦 Teste Entpacken..."
mkdir "$TMP_DIR/unpack"
if ! unzip -q "$ZIP_FILE" -d "$TMP_DIR/unpack"; then
    echo "❌ FEHLER: ZIP konnte NICHT entpackt werden!"
    exit 1
fi

echo "✔ Entpack-Test erfolgreich"

echo ""
echo "--------------------------------------------------------"
echo " 💚 Update-Paket ist vollständig und gültig!"
echo "   (Installation folgt im nächsten Schritt)"
echo "--------------------------------------------------------"
