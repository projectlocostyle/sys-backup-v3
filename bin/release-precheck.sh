#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

echo "--------------------------------------------------------"
echo " SYS-BACKUP-V3 – RELEASE PRECHECK"
echo "--------------------------------------------------------"

# Aktuelle Version
VERSIONFILE="/opt/sys-backup-v3/version"
CUR_VERSION=$(grep 'VERSION=' "$VERSIONFILE" | cut -d'"' -f2)

echo -e "✔ Version OK: ${GREEN}${CUR_VERSION}${RESET}"

# Git sauber?
if [[ -n "$(git status --porcelain)" ]]; then
    echo -e "${RED}❌ FEHLER: Git-Repository ist nicht sauber!${RESET}"
    echo ""
    git status
    exit 99
fi

echo -e "${GREEN}✔ Git sauber${RESET}"
exit 0
