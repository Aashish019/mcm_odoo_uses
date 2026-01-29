#!/bin/bash
set -e

BASE_DIR="/root/deployment/odoo-17/config/docker"

# ✅ If you want different ports to run parallel with Odoo19, change here
ODOO_PORT="8069"
LONGPOLL_PORT="8072"
DB_EXPOSE_PORT="5107"        # host port for postgres (optional)
POSTGRES_VERSION="15"

ODOO_CONTAINER="odoo17-web"
DB_CONTAINER="odoo17-db"

PUBLIC_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7}')

echo "=============================================="
echo "✅ Odoo 17 Docker Setup (Safe to run multiple times)"
echo "Base Dir : $BASE_DIR"
echo "Ports    : Odoo=${ODOO_PORT}, Longpoll=${LONGPOLL_PORT}, DB=${DB_EXPOSE_PORT}"
echo "ServerIP : ${PUBLIC_IP}"
echo "=============================================="

# -------------------------------
# ✅ Helper functions
# -------------------------------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_if_missing() {
  local pkg="$1"
  dpkg -s "$pkg" >/dev/null 2>&1 || sudo apt install -y "$pkg"
}

# -------------------------------
# 1) Install Docker + Compose + Git (only if missing)
# -------------------------------
echo "✅ Checking required packages..."

sudo apt update -y

if ! command_exists docker; then
  echo "📦 Installing Docker..."
  install_if_missing docker.io
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "✅ Docker already installed. Skipping..."
fi

if ! command_exists docker-compose; then
  echo "📦 Installing docker-compose..."
  install_if_missing docker-compose
else
  echo "✅ docker-compose already installed. Skipping..."
fi

if ! command_exists git; then
  echo "📦 Installing Git..."
  install_if_missing git
else
  echo "✅ Git already installed. Skipping..."
fi

# -------------------------------
# ✅ Fail2ban (SSH brute-force protection)
# -------------------------------
if ! command_exists fail2ban-client; then
  echo "📦 Installing Fail2ban..."
  install_if_missing fail2ban
  sudo systemctl enable --now fail2ban
else
  echo "✅ Fail2ban already installed. Skipping..."
  sudo systemctl enable --now fail2ban >/dev/null 2>&1 || true
fi

echo "✅ Fail2ban status:"
sudo systemctl status fail2ban --no-pager || true


# -------------------------------
# 2) Create folder structure (safe)
# -------------------------------
echo "✅ Ensuring folder structure exists..."
sudo mkdir -p "$BASE_DIR"/{config,addons,logs,backups}
cd "$BASE_DIR" || exit 1

# -------------------------------
# 3) Create docker-compose.yml only if missing
# -------------------------------
if [ -f "$BASE_DIR/docker-compose.yml" ]; then
  echo "✅ docker-compose.yml already exists. Keeping existing file."
else
  echo "✅ Creating docker-compose.yml..."
  cat <<EOF > docker-compose.yml
version: "3.8"

services:
  web:
    image: odoo:17.0
    container_name: ${ODOO_CONTAINER}
    depends_on:
      - db
    ports:
      - "${ODOO_PORT}:8069"
      - "${LONGPOLL_PORT}:8072"
    restart: unless-stopped
    networks:
      - odoo_network
    dns:
      - 8.8.8.8
      - 8.8.4.4
    environment:
      HOST: db
      USER: odoo
      PASSWORD: odoo
    volumes:
      - odoo-web-data-17:/var/lib/odoo
      - ./config:/etc/odoo
      - ./addons:/mnt/extra-addons
      - ./logs:/mnt/log
      - ./backups:/mnt/backup

  db:
    image: postgres:${POSTGRES_VERSION}
    container_name: ${DB_CONTAINER}
    ports:
      - "${DB_EXPOSE_PORT}:5432"
    restart: unless-stopped
    networks:
      - odoo_network
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
    volumes:
      - odoo-db-data-${POSTGRES_VERSION}:/var/lib/postgresql/data

networks:
  odoo_network:
    driver: bridge

volumes:
  odoo-web-data-17:
  odoo-db-data-${POSTGRES_VERSION}:
EOF
fi

# -------------------------------
# 4) Create config/odoo.conf only if missing
# -------------------------------
if [ -f "$BASE_DIR/config/odoo.conf" ]; then
  echo "✅ config/odoo.conf already exists. Keeping existing file."
else
  read -p "Enter Odoo Master Password (admin_passwd) [default: admin123]: " MASTER_PASS
  MASTER_PASS=${MASTER_PASS:-admin123}

  echo "✅ Creating config/odoo.conf..."
  cat <<EOF > config/odoo.conf
[options]
admin_passwd = ${MASTER_PASS}
proxy_mode = True
longpolling_port = 8072

addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons/Cybrosys/CybroAddons,/mnt/extra-addons/Cybrosys/OpenHRMS,/mnt/extra-addons/mcm/mcm_gen_modules,/mnt/extra-addons/mcm/mcm_subscription_alert,/mnt/extra-addons/mcm/odoo_enterprise_addons,/mnt/extra-addons/oca/account-financial-reporting,/mnt/extra-addons/oca/account-financial-tools,/mnt/extra-addons/oca/account-invoicing,/mnt/extra-addons/oca/account-payment,/mnt/extra-addons/oca/account-reconcile,/mnt/extra-addons/oca/reporting-engine,/mnt/extra-addons/oca/sale-workflow,/mnt/extra-addons/oca/server-tools,/mnt/extra-addons/oca/server-ux,/mnt/extra-addons/oca/web,/mnt/extra-addons/odoo-mates/odooapps,/mnt/extra-addons/others/myfree

workers = 2
max_cron_threads = 1

logfile = /mnt/log/odoo17.log
log_level = info
EOF
fi

# -------------------------------
# 5) GitHub SSH key check ONLY if cloning MCM repos is needed
# -------------------------------
cd "$BASE_DIR/addons" || exit 1

NEED_MCM_CLONE=0
if [ ! -d "$BASE_DIR/addons/mcm/odoo_enterprise_addons" ] || \
   [ ! -d "$BASE_DIR/addons/mcm/mcm_gen_modules" ] || \
   [ ! -d "$BASE_DIR/addons/mcm/mcm_subscription_alert" ]; then
  NEED_MCM_CLONE=1
fi

if [ "$NEED_MCM_CLONE" -eq 1 ]; then
  echo ""
  echo "=============================================="
  echo "⚠️ GitHub SSH Key Check (Required for MCM repos)"
  echo "=============================================="
  read -p "Did you already add GitHub SSH key in this server? (y/n): " SSH_OK

  if [[ "$SSH_OK" != "y" && "$SSH_OK" != "Y" ]]; then
    echo ""
    echo "❌ Aborting addon clone because SSH key is not configured."
    echo "✅ Run this to create SSH key:"
    echo 'ssh-keygen -t ed25519 -C "shameer@mcmwg.com"'
    echo ""
    echo "✅ Then add public key to GitHub:"
    echo "cat ~/.ssh/id_ed25519.pub"
    echo ""
    exit 1
  fi
else
  echo "✅ MCM repos already present. Skipping SSH check."
fi

# -------------------------------
# 6) Clone addons safely (skip if already exists)
# -------------------------------
echo "✅ Cloning repositories (skips existing)..."

declare -A REPOS=(
  ["Cybrosys"]="https://github.com/CybroOdoo/CybroAddons https://github.com/CybroOdoo/OpenHRMS"
  ["mcm"]="git@github.com:McMillan-Woods-Global/odoo_enterprise_addons.git git@github.com:McMillan-Woods-Global/mcm_gen_modules.git git@github.com:McMillan-Woods-Global/mcm_subscription_alert.git"
  ["oca"]="https://github.com/OCA/account-financial-reporting https://github.com/OCA/account-financial-tools https://github.com/OCA/account-invoicing https://github.com/OCA/account-payment https://github.com/OCA/account-reconcile https://github.com/OCA/reporting-engine https://github.com/OCA/sale-workflow https://github.com/OCA/server-tools https://github.com/OCA/server-ux https://github.com/OCA/web"
  ["odoo-mates"]="https://github.com/odoomates/odooapps"
  ["others"]="https://github.com/muhlhel/myfree"
)

clone_repo() {
  local repo="$1"
  local repo_name
  repo_name=$(basename "$repo" .git)

  if [ -d "$repo_name" ]; then
    echo "⚠️ Already exists, skipping: $repo_name"
    return 0
  fi

  echo "⬇️ Cloning: $repo_name"
  git clone -b 17.0 --single-branch "$repo" || {
    echo "⚠️ Branch 17.0 not found for $repo_name → cloning default branch..."
    git clone "$repo"
  }
}

for category in "${!REPOS[@]}"; do
  mkdir -p "$category"
  cd "$category" || exit 1

  for repo in ${REPOS[$category]}; do
    clone_repo "$repo"
  done

  cd ..
done

echo "✅ Addons cloning completed."

# -------------------------------
# 7) Start / Verify containers (safe)
# -------------------------------
cd "$BASE_DIR" || exit 1

if docker ps --format '{{.Names}}' | grep -q "^${ODOO_CONTAINER}$"; then
  echo "✅ ${ODOO_CONTAINER} is already running. Skipping docker-compose up."
else
  echo "✅ Starting containers..."
  docker-compose up -d
fi

echo "=============================================="
echo "✅ DONE ✅ Odoo 17 is ready"
echo "🌐 Open: http://${PUBLIC_IP}:${ODOO_PORT}"
echo "📌 Logs: docker logs -f ${ODOO_CONTAINER}"
echo "=============================================="
