#!/bin/bash

VERSION_FILE="/opt/sys-backup-v3/version"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Version-Datei nicht gefunden!"
    exit 1
fi

VERSION=$(grep 'VERSION=' "$VERSION_FILE" | cut -d'"' -f2)
BUILD_DATE=$(grep 'BUILD_DATE=' "$VERSION_FILE" | cut -d'"' -f2)

echo "--------------------------------------------------------"
echo " SYS-BACKUP-V3 - VERSION"
echo "--------------------------------------------------------"
echo ""
echo "Version:      $VERSION"
echo "Build-Date:   $BUILD_DATE"
echo "Git-Tag:      v$VERSION"
echo ""
