#!/bin/bash

# --------------------------------------------------------
# SYS-BACKUP-V3 - SETUP WIZARD (GERÜST)
# --------------------------------------------------------

CONFIG="/etc/sys-backup-v3/config.yml"
VERSION_FILE="/opt/sys-backup-v3/version"

# Farben
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Systeminformationen laden
HOSTNAME_AUTO=$(hostname)
DOMAIN_AUTO=$(hostname -d 2>/dev/null || echo "-")
IP_AUTO=$(hostname -I | awk '{print $1}')
OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

clear
echo -e "${BLUE}--------------------------------------------------------${RESET}"
echo -e "${BLUE} SYS-BACKUP-V3 - SETUP WIZARD (VORSTUFE)${RESET}"
echo -e "${BLUE}--------------------------------------------------------${RESET}"
echo ""
echo "Automatisch erkannte Systeminformationen:"
echo "  Hostname : $HOSTNAME_AUTO"
echo "  Domain   : $DOMAIN_AUTO"
echo "  IP       : $IP_AUTO"
echo "  OS       : $OS_NAME $OS_VERSION"
echo ""
echo "Diese Version von sys-backup-v3 wird installiert:"
echo ""

if [[ -f $VERSION_FILE ]]; then
    cat $VERSION_FILE
else
    echo "Version nicht gefunden!"
fi

echo ""
echo "Der Setup-Wizard ist noch nicht vollständig aktiviert."
echo "Im nächsten Schritt werden die Eingabefragen integriert."
echo ""
echo -e "${YELLOW}Drücke Enter um zurückzukehren...${RESET}"
read

# --------------------------------------------------------
# Eingabe-Helper Funktionen
# --------------------------------------------------------

ask() {
    local prompt="$1"
    local default="$2"
    local input
    read -p "$prompt" input
    if [[ -z "$input" ]]; then
        input="$default"
    fi
    echo "$input"
}

ask_required() {
    local prompt="$1"
    local input=""
    while [[ -z "$input" ]]; do
        read -p "$prompt" input
        if [[ -z "$input" ]]; then
            echo "Eingabe darf nicht leer sein!"
        fi
    done
    echo "$input"
}

ask_yesno() {
    local prompt="$1"
    local default="$2"
    local input
    read -p "$prompt" input
    input="${input:-$default}"
    case "$input" in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO) return 1 ;;
        *) return 1 ;;
    esac
}

ask_secret() {
    local prompt="$1"
    local input=""
    while [[ -z "$input" ]]; do
        read -s -p "$prompt" input
        echo
        if [[ -z "$input" ]]; then
            echo "Eingabe darf nicht leer sein!"
        fi
    done
    echo "$input"
}


# --------------------------------------------------------
# Eingabe-Helper Funktionen
# --------------------------------------------------------

ask() {
    local prompt="$1"
    local default="$2"
    local input
    read -p "$prompt" input
    if [[ -z "$input" ]]; then
        input="$default"
    fi
    echo "$input"
}

ask_required() {
    local prompt="$1"
    local input=""
    while [[ -z "$input" ]]; do
        read -p "$prompt" input
        if [[ -z "$input" ]]; then
            echo "Eingabe darf nicht leer sein!"
        fi
    done
    echo "$input"
}

ask_yesno() {
    local prompt="$1"
    local default="$2"
    local input
    read -p "$prompt" input
    input="${input:-$default}"
    case "$input" in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO) return 1 ;;
        *) return 1 ;;
    esac
}

ask_secret() {
    local prompt="$1"
    local input=""
    while [[ -z "$input" ]]; do
        read -s -p "$prompt" input
        echo
        if [[ -z "$input" ]]; then
            echo "Eingabe darf nicht leer sein!"
        fi
    done
    echo "$input"
}


# --------------------------------------------------------
# HOSTNAME / DOMAIN / IP Abfragen
# --------------------------------------------------------

echo ""
echo "Bitte bestätige oder ändere die folgenden Host-Informationen:"
echo ""

HOSTNAME_INPUT=$(ask "Hostname [$HOSTNAME_AUTO]: " "$HOSTNAME_AUTO")
DOMAIN_INPUT=$(ask "Domain (leer lassen wenn keine) [$DOMAIN_AUTO]: " "$DOMAIN_AUTO")
FQDN_INPUT="$HOSTNAME_INPUT"
if [[ -n "$DOMAIN_INPUT" ]]; then
    FQDN_INPUT="$HOSTNAME_INPUT.$DOMAIN_INPUT"
fi

echo "System-ID wird generiert..."
SYSTEM_ID=$(uuidgen || cat /proc/sys/kernel/random/uuid)

# --------------------------------------------------------
# HOST-DATEN in CONFIG schreiben
# --------------------------------------------------------

sed -i "s/^  hostname:.*/  hostname: \"$HOSTNAME_INPUT\"/" $CONFIG
sed -i "s/^  domain:.*/  domain: \"$DOMAIN_INPUT\"/" $CONFIG
sed -i "s/^  fqdn:.*/  fqdn: \"$FQDN_INPUT\"/" $CONFIG
sed -i "s/^  ip:.*/  ip: \"$IP_AUTO\"/" $CONFIG
sed -i "s/^  system_id:.*/  system_id: \"$SYSTEM_ID\"/" $CONFIG
sed -i "s/^  os:.*/  os: \"$OS_NAME\"/" $CONFIG
sed -i "s/^  os_version:.*/  os_version: \"$OS_VERSION\"/" $CONFIG

echo ""
echo "Host-Konfiguration erfolgreich gespeichert."
echo "  Hostname : $HOSTNAME_INPUT"
echo "  Domain   : $DOMAIN_INPUT"
echo "  FQDN     : $FQDN_INPUT"
echo "  IP       : $IP_AUTO"
echo "  System-ID: $SYSTEM_ID"
echo ""


# --------------------------------------------------------
# STORAGE / BACKUP-SPEICHER AUSWAHL
# --------------------------------------------------------

echo ""
echo "Welchen Speicher möchtest du für deine Backups nutzen?"
echo "1) Nextcloud"
echo "2) WebDAV"
echo "3) S3 (AWS, Wasabi, Minio)"
echo "4) Lokaler Ordner"
echo "5) Kein Speicher (nur lokal testen)"
echo ""

STORAGE_CHOICE=$(ask_required "Bitte Auswahl 1-5 eingeben: ")

case "$STORAGE_CHOICE" in

  1)
    echo ""
    echo "Nextcloud-Konfiguration:"
    NC_USER=$(ask_required "Nextcloud Benutzername: ")
    NC_UID=$(ask_required "Nextcloud User-ID: ")
    NC_FOLDER=$(ask_required "Nextcloud Backup-Ordnername: ")
    NC_WEBDAV=$(ask_required "Nextcloud WebDAV URL: ")
    NC_PASS=$(ask_secret "Nextcloud Passwort/Token: ")

    # Config schreiben
    sed -i 's/^  type:.*/  type: "nextcloud"/' $CONFIG
    sed -i 's/^  rclone_remote:.*/  rclone_remote: "nextcloud-v3"/' $CONFIG
    sed -i "s/^    user:.*/    user: \"$NC_USER\"/" $CONFIG
    sed -i "s/^    user_id:.*/    user_id: \"$NC_UID\"/" $CONFIG
    sed -i "s/^    folder:.*/    folder: \"$NC_FOLDER\"/" $CONFIG
    sed -i "s~^    webdav_url:.*~    webdav_url: \"$NC_WEBDAV\"~" $CONFIG

    # Geheimdaten speichern
    echo "NEXTCLOUD_PASS=\"$NC_PASS\"" >> /etc/sys-backup-v3/.env

    echo ""
    echo "Nextcloud wurde erfolgreich konfiguriert."
    ;;

  2)
    echo ""
    echo "WebDAV-Konfiguration:"
    WD_URL=$(ask_required "WebDAV URL: ")
    WD_USER=$(ask_required "WebDAV Benutzername: ")
    WD_PASS=$(ask_secret "WebDAV Passwort: ")

    sed -i 's/^  type:.*/  type: "webdav"/' $CONFIG
    sed -i 's/^  rclone_remote:.*/  rclone_remote: "webdav-v3"/' $CONFIG
    sed -i "s~^    url:.*~    url: \"$WD_URL\"~" $CONFIG
    sed -i "s/^    user:.*/    user: \"$WD_USER\"/" $CONFIG

    echo "WEBDAV_PASS=\"$WD_PASS\"" >> /etc/sys-backup-v3/.env

    echo ""
    echo "WebDAV wurde erfolgreich konfiguriert."
    ;;

  3)
    echo ""
    echo "S3-Konfiguration:"
    S3_ENDPOINT=$(ask_required "Endpoint (z.B. https://s3.wasabi.com): ")
    S3_BUCKET=$(ask_required "Bucket Name: ")
    S3_REGION=$(ask_required "Region: ")
    S3_KEY=$(ask_required "Access Key: ")
    S3_SECRET=$(ask_secret "Secret Key: ")

    sed -i 's/^  type:.*/  type: "s3"/' $CONFIG
    sed -i 's/^  rclone_remote:.*/  rclone_remote: "s3-v3"/' $CONFIG
    sed -i "s~^    endpoint:.*~    endpoint: \"$S3_ENDPOINT\"~" $CONFIG
    sed -i "s~^    bucket:.*~    bucket: \"$S3_BUCKET\"~" $CONFIG
    sed -i "s/^    region:.*/    region: \"$S3_REGION\"/" $CONFIG

    echo "S3_ACCESS_KEY=\"$S3_KEY\"" >> /etc/sys-backup-v3/.env
    echo "S3_SECRET_KEY=\"$S3_SECRET\"" >> /etc/sys-backup-v3/.env

    echo ""
    echo "S3 wurde erfolgreich konfiguriert."
    ;;

  4)
    echo ""
    LOCAL_FOLDER=$(ask_required "Pfad für lokalen Backup-Speicher: ")

    sed -i 's/^  type:.*/  type: "local"/' $CONFIG
    sed -i 's/^  rclone_remote:.*/  rclone_remote: null/' $CONFIG
    sed -i "s~^    base_path:.*~    base_path: \"$LOCAL_FOLDER\"~" $CONFIG

    echo ""
    echo "Lokaler Speicher wurde erfolgreich konfiguriert."
    ;;

  5)
    echo ""
    echo "Achtung: Es wird kein Remote-Speicher verwendet."
    echo "Backups werden NUR lokal abgelegt!"
    
    sed -i 's/^  type:.*/  type: "none"/' $CONFIG
    sed -i 's/^  rclone_remote:.*/  rclone_remote: null/' $CONFIG

    echo ""
    echo "Lokal-Modus aktiviert."
    ;;

  *)
    echo "Ungültige Auswahl. Abbruch."
    exit 1
    ;;
esac

echo ""
echo "Speicherkonfiguration erfolgreich gespeichert."
echo ""


# --------------------------------------------------------
# SMTP / EMAIL KONFIGURATION
# --------------------------------------------------------

echo ""
echo "Möchtest du E-Mail Benachrichtigungen aktivieren?"
if ask_yesno "SMTP aktivieren? (Y/n): " "Y"; then

    SMTP_SERVER=$(ask_required "SMTP Server (z.B. smtp.domain.com): ")
    SMTP_PORT=$(ask_required "SMTP Port (z.B. 587): ")
    SMTP_SECURITY=$(ask "Sicherheit (tls/ssl/none) [tls]: " "tls")
    SMTP_USER=$(ask_required "SMTP Benutzername: ")
    SMTP_PASS=$(ask_secret "SMTP Passwort: ")
    SMTP_FROM=$(ask_required "Absender-Adresse: ")
    SMTP_TO=$(ask_required "Empfänger-Adresse: ")

    echo ""
    if ask_yesno "Nur Fehler senden? (Y/n): " "Y"; then
        SMTP_ONLY_ERRORS=true
    else
        SMTP_ONLY_ERRORS=false
    fi

    # SMTP in config.yml speichern
    sed -i 's/^  enabled:.*/  enabled: true/' /etc/sys-backup-v3/config.yml
    sed -i "s/^  server:.*/  server: \"$SMTP_SERVER\"/" /etc/sys-backup-v3/config.yml
    sed -i "s/^  port:.*/  port: $SMTP_PORT/" /etc/sys-backup-v3/config.yml
    sed -i "s/^  security:.*/  security: \"$SMTP_SECURITY\"/" /etc/sys-backup-v3/config.yml
    sed -i "s/^  from:.*/  from: \"$SMTP_FROM\"/" /etc/sys-backup-v3/config.yml
    sed -i "s/^  to:.*/  to: \"$SMTP_TO\"/" /etc/sys-backup-v3/config.yml
    sed -i "s/^  only_errors:.*/  only_errors: $SMTP_ONLY_ERRORS/" /etc/sys-backup-v3/config.yml

    # Passwort in ENV-Datei
    echo "SMTP_PASS=\"$SMTP_PASS\"" >> /etc/sys-backup-v3/.env

    echo ""
    echo "SMTP wurde erfolgreich konfiguriert."

else
    # SMTP deaktivieren
    sed -i 's/^  enabled:.*/  enabled: false/' /etc/sys-backup-v3/config.yml
    echo ""
    echo "SMTP deaktiviert."
fi


# --------------------------------------------------------
# GITHUB KONFIGURATION
# --------------------------------------------------------

echo ""
echo "Möchtest du GitHub für Releases oder Config-Backups nutzen?"
if ask_yesno "GitHub aktivieren? (Y/n): " "n"; then

    GH_USER=$(ask_required "GitHub Benutzername: ")
    GH_ID=$(ask_required "GitHub User-ID (Zahl): ")
    GH_REPO=$(ask_required "GitHub Repository Name: ")
    GH_TOKEN=$(ask_secret "GitHub Personal Access Token: ")

    # Config.yml anpassen
    sed -i 's/^  enabled:.*/  enabled: true/' /etc/sys-backup-v3/config.yml
    sed -i "s/^  username:.*/  username: \"$GH_USER\"/" /etc/sys-backup-v3/config.yml
    sed -i "s/^  user_id:.*/  user_id: \"$GH_ID\"/" /etc/sys-backup-v3/config.yml
    sed -i "s/^  repository:.*/  repository: \"$GH_REPO\"/" /etc/sys-backup-v3/config.yml

    # Token in ENV-Datei schreiben
    echo "GITHUB_TOKEN=\"$GH_TOKEN\"" >> /etc/sys-backup-v3/.env

    echo ""
    echo "GitHub-Konfiguration erfolgreich gespeichert."

else
    sed -i 's/^  enabled:.*/  enabled: false/' /etc/sys-backup-v3/config.yml
    echo "GitHub wurde deaktiviert."
fi


# --------------------------------------------------------
# ABSCHLUSS & ZUSAMMENFASSUNG
# --------------------------------------------------------

echo ""
echo "--------------------------------------------------------"
echo " Sys-Backup-V3 - Setup abgeschlossen"
echo "--------------------------------------------------------"
echo ""

echo "Konfiguration gespeichert unter: /etc/sys-backup-v3/config.yml"
echo "Env-Datei gespeichert unter:      /etc/sys-backup-v3/.env"
echo ""
echo "Version:"
cat /opt/sys-backup-v3/version
echo ""

echo "Setup erfolgreich abgeschlossen!"
echo "Du kannst jetzt Backups starten mit:"
echo "  sys-backup backup"
echo ""
echo -e "${YELLOW}Drücke Enter um zum Hauptmenü zurückzukehren...${RESET}"
read

