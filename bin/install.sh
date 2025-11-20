#!/bin/bash
set -e

echo "===================================================="
echo "  Sys-Backup-V3 — Installations-Script (Neuaufbau)"
echo "===================================================="

############################################
### 1) SYSTEM-UPDATES
############################################

echo "[1/8] System aktualisieren..."
apt update -y
apt install -y curl git unzip ca-certificates gnupg lsb-release

############################################
### 2) DOCKER CHECK
############################################

echo "[2/8] Docker prüfen..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker nicht gefunden – Installation..."
    curl -fsSL https://get.docker.com | sh
else
    echo "✔️ Docker ist installiert."
fi

############################################
### 3) DOCKER COMPOSE CHECK
############################################

echo "[3/8] docker compose prüfen..."
if ! docker compose version &> /dev/null; then
    echo "❌ docker compose fehlt – installieren..."
    LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
       | grep browser_download_url | grep linux-x86_64 | cut -d '"' -f 4)
    curl -L "$LATEST_COMPOSE" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "✔️ docker compose vorhanden."
fi

############################################
### 4) CADDY INSTALLIEREN
############################################

echo "[4/8] Caddy installieren..."
if ! command -v caddy &> /dev/null; then
    apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sSf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
      | gpg --dearmor -o /usr/share/keyrings/caddy.gpg
    curl -1sSf https://dl.cloudsmith.io/public/caddy/stable/deb/debian/any-version.deb.txt \
      | tee /etc/apt/sources.list.d/caddy.list
    apt update
    apt install -y caddy
else
    echo "✔️ Caddy ist installiert."
fi

systemctl enable caddy
systemctl restart caddy

############################################
### 5) ORDNERSTRUKTUR
############################################

echo "[5/8] Ordner anlegen..."
mkdir -p /opt/services
mkdir -p /opt/services/n8n
mkdir -p /opt/services/ollama
mkdir -p /opt/services/openwebui
mkdir -p /opt/services/portainer

mkdir -p /var/lib/ollama

############################################
### 6) DOCKER-COMPOSE.YML
############################################

echo "[6/8] Erzeuge docker-compose.yml..."

cat > /opt/services/docker-compose.yml << 'EOF'
version: "3.9"

services:
  portainer:
    image: portainer/portainer-ce:2.21.4
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.ai.locostyle.ch
      - WEBHOOK_URL=https://n8n.ai.locostyle.ch/
    volumes:
      - n8n_data:/home/node/.n8n

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama

  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: openwebui
    restart: unless-stopped
    ports:
      - "3000:8080"
    depends_on:
      - ollama
    environment:
      - OLLAMA_API_BASE=http://ollama:11434
    volumes:
      - openwebui_data:/app/backend/data

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --schedule "0 0 3 * * *"

volumes:
  portainer_data:
  n8n_data:
  ollama_data:
  openwebui_data:
EOF

############################################
### 7) CADDYFILE ERZEUGEN
############################################

echo "[7/8] Erzeuge Caddyfile..."

cat > /etc/caddy/Caddyfile << 'EOF'
ai.locostyle.ch {
    respond "OK - ai.locostyle.ch läuft"
}

n8n.ai.locostyle.ch {
    reverse_proxy localhost:5678
}

portainer.ai.locostyle.ch {
    reverse_proxy localhost:9000
}

ollama.ai.locostyle.ch {
    reverse_proxy localhost:11434
}

openwebui.ai.locostyle.ch {
    reverse_proxy localhost:3000
}
EOF

systemctl reload caddy

############################################
### 8) DOCKER STARTEN
############################################

echo "[8/8] Services starten..."
cd /opt/services
docker compose up -d

echo "===================================================="
echo " Installation abgeschlossen!"
echo "===================================================="
echo "Du kannst jetzt restore.sh ausführen."
