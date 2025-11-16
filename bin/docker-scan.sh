#!/bin/bash

# --------------------------------------------------------
# SYS-BACKUP-V3 - DOCKER PROJEKT SCANNER
# --------------------------------------------------------

LOG="/var/log/sys-backup-v3/docker-scan.log"
PROJECT_DIR="/etc/sys-backup-v3/projects/"

echo "--------------------------------------------------------" | tee -a "$LOG"
echo "SYS-BACKUP-V3 DOCKER-SCAN gestartet: $(date)" | tee -a "$LOG"
echo "--------------------------------------------------------" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# Prüfen ob Docker installiert ist
if ! command -v docker &> /dev/null; then
    echo "Docker ist nicht installiert. Scan wird übersprungen." | tee -a "$LOG"
    exit 0
fi

echo "Docker wurde gefunden. Starte Scan..." | tee -a "$LOG"
echo "" | tee -a "$LOG"

# Docker Projekte scannen
PROJECTS=$(docker ps --format '{{.Names}}')

if [[ -z "$PROJECTS" ]]; then
    echo "Keine laufenden Docker-Projekte gefunden." | tee -a "$LOG"
fi

for project in $PROJECTS
do
    echo "Gefundenes Projekt: $project" | tee -a "$LOG"

    PROFILE="$PROJECT_DIR/$project.yml"

    echo "Erzeuge Profil: $PROFILE" | tee -a "$LOG"

    # Volume-Liste erzeugen
    VOLUMES=$(docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' $project)

    # Bind-Mount-Liste erzeugen
    BINDS=$(docker inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}:{{.Destination}} {{end}}{{end}}' $project)

    cat <<EOC > "$PROFILE"
project: "$project"

volumes:
$(for v in $VOLUMES; do echo "  - $v"; done)

bind_mounts:
$(for b in $BINDS; do echo "  - $b"; done)
EOC

    echo "Profil erstellt." | tee -a "$LOG"
    echo "" | tee -a "$LOG"
done

echo "Docker-Scan abgeschlossen." | tee -a "$LOG"

