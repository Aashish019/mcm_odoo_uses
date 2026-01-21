#!/bin/bash
set -e

BASE_DIR="/root/deployment/odoo-17/config/docker"

# ✅ Change ports if needed (if you run multiple odoo versions)
ODOO_PORT="8069"
LONGPOLL_PORT="8072"
DB_PORT="5432"

echo "=============================================="
echo "✅ Odoo 17 Docker Full Setup + Addons Clone"
echo "Base Dir : $BASE_DIR"
echo "Ports    : Odoo=$ODOO_PORT  Longpoll=$LONGPOLL_PORT  DB=$DB_PORT"
echo "=============================================="

# -------------------------------
# 1) Install Docker + Compose + Git
# -------------------------------
echo "✅ Installing Docker + Docker-Compose + Git..."
sudo apt update -y
sudo apt install -y docker.io docker-compose git

sudo systemctl enable docker
sudo systemctl start docker

docker --version
docker-compose --version

# -------------------------------
# 2) Create folders
# -------------------------------
echo "✅ Creating folder structure..."
sudo mkdir -p "$BASE_DIR"/{config,addons,logs,backups}
cd "$BASE_DIR" || exit 1

# -------------------------------
# 3) Create docker-compose.yml (Odoo17)
# -------------------------------
echo "✅ Creating docker-compose.yml..."
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  web:
    image: odoo:17.0
    container_name: odoo17-web
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
    image: postgres:15
    container_name: odoo17-db
    ports:
      - "5107:${DB_PORT}"
    restart: unless-stopped
    networks:
      - odoo_network
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
    volumes:
      - odoo-db-data-15:/var/lib/postgresql/data

networks:
  odoo_network:
    driver: bridge

volumes:
  odoo-web-data-17:
  odoo-db-data-15:
EOF

# -------------------------------
# 4) Create config/odoo.conf
# -------------------------------
echo "✅ Creating config/odoo.conf..."
cat <<EOF > config/odoo.conf
[options]
admin_passwd = Master@Boards123
proxy_mode = True
longpolling_port = 8072

; ✅ Addons
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons/Cybrosys/CybroAddons,/mnt/extra-addons/Cybrosys/OpenHRMS,/mnt/extra-addons/mcm/mcm_gen_modules,/mnt/extra-addons/mcm/mcm_subscription_alert,/mnt/extra-addons/mcm/odoo_enterprise_addons,/mnt/extra-addons/oca/account-financial-reporting,/mnt/extra-addons/oca/account-financial-tools,/mnt/extra-addons/oca/account-invoicing,/mnt/extra-addons/oca/account-payment,/mnt/extra-addons/oca/account-reconcile,/mnt/extra-addons/oca/reporting-engine,/mnt/extra-addons/oca/sale-workflow,/mnt/extra-addons/oca/server-tools,/mnt/extra-addons/oca/server-ux,/mnt/extra-addons/oca/web,/mnt/extra-addons/odoo-mates/odooapps,/mnt/extra-addons/others/myfree

workers = 2
max_cron_threads = 1

; ✅ Logs (optional)
logfile = /mnt/log/odoo17.log
log_level = info
EOF

# -------------------------------
# 5) Confirm GitHub SSH Key before cloning private repos (mcm)
# -------------------------------
echo ""
echo "=============================================="
echo "⚠️ GitHub SSH Key Check (Required for MCM repos)"
echo "=============================================="
read -p "❓ Did you already add GitHub SSH key in this server? (y/n): " SSH_OK

if [[ "$SSH_OK" != "y" && "$SSH_OK" != "Y" ]]; then
  echo ""
  echo "❌ Aborting addon clone because SSH key is not configured."
  echo ""
  echo "✅ Run this command to create SSH key:"
  echo 'ssh-keygen -t ed25519 -C "shameer@mcmwg.com"'
  echo ""
  echo "✅ Then add the public key to GitHub:"
  echo "cat ~/.ssh/id_ed25519.pub"
  echo ""
  exit 1
fi

# -------------------------------
# 6) Clone addons inside addons/
# -------------------------------
echo "✅ Cloning Addons inside: $BASE_DIR/addons"
cd "$BASE_DIR/addons" || exit 1

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

    echo "⬇️ Cloning $repo_name (branch 17.0)..."
    git clone -b 17.0 --single-branch "$repo" || {
        echo "⚠️ Repo branch 17.0 not found, trying default branch..."
        git clone "$repo"
    }
}

for category in "${!REPOS[@]}"; do
    echo "📁 Creating folder: $category"
    mkdir -p "$category"
    cd "$category" || exit 1

    for repo in ${REPOS[$category]}; do
        clone_repo "$repo"
    done

    cd ..
done

echo "✅ Addons cloned successfully!"

# -------------------------------
# 7) Start Odoo 17 Containers
# -------------------------------
echo "✅ Starting Odoo 17 containers..."
cd "$BASE_DIR" || exit 1
docker-compose up -d

echo "=============================================="
echo "✅ DONE! Odoo 17 is running"
echo "🌐 Open: http://YOUR_SERVER_IP:${ODOO_PORT}"
echo "📌 Logs: docker logs -f odoo17-web"
echo "=============================================="
