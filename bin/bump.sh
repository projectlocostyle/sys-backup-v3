#!/bin/bash

VERSION_FILE="/opt/sys-backup-v3/version"
MODE="$1"

if [[ -z "$MODE" ]]; then
    echo "Bitte Modus angeben:"
    echo "  sys-backup bump alpha"
    echo "  sys-backup bump beta"
    echo "  sys-backup bump patch"
    echo "  sys-backup bump minor"
    echo "  sys-backup bump major"
    exit 1
fi

CURRENT=$(grep 'VERSION=' "$VERSION_FILE" | cut -d'"' -f2)

# Teile trennen
BASE="${CURRENT%%-*}"        # 3.0.0
SUFFIX="${CURRENT#*-}"       # alpha3

MAJOR=$(echo $BASE | cut -d. -f1)
MINOR=$(echo $BASE | cut -d. -f2)
PATCH=$(echo $BASE | cut -d. -f3)

# ---- Funktionen ----

bump_alpha() {
    if [[ "$SUFFIX" =~ alpha([0-9]+) ]]; then
        NUM="${BASH_REMATCH[1]}"
        NUM=$((NUM+1))
        NEW="${BASE}-alpha${NUM}"
    else
        NEW="${BASE}-alpha1"
    fi
}

bump_beta() {
    NEW="${BASE}-beta1"
}

bump_patch() {
    PATCH=$((PATCH+1))
    NEW="${MAJOR}.${MINOR}.${PATCH}"
}

bump_minor() {
    MINOR=$((MINOR+1))
    PATCH=0
    NEW="${MAJOR}.${MINOR}.${PATCH}"
}

bump_major() {
    MAJOR=$((MAJOR+1))
    MINOR=0
    PATCH=0
    NEW="${MAJOR}.${MINOR}.${PATCH}"
}

# ---- Modus wählen ----

case "$MODE" in
  alpha)
      bump_alpha
      ;;
  beta)
      bump_beta
      ;;
  patch)
      bump_patch
      ;;
  minor)
      bump_minor
      ;;
  major)
      bump_major
      ;;
  *)
      echo "Unbekannter Modus: $MODE"
      exit 1
      ;;
esac

# ---- Build-Date ----
BUILD_DATE=$(date +%Y-%m-%d)

# ---- Version speichern ----
echo "VERSION=\"${NEW}\"" > "$VERSION_FILE"
echo "BUILD_DATE=\"${BUILD_DATE}\"" >> "$VERSION_FILE"

echo "Neue Version gesetzt:"
echo "  $NEW"
