#!/bin/bash

BASE_DIR="/root/deployment/odoo-19/config/docker"

echo "=============================================="
echo "✅ Odoo 19 Docker Full Setup + Addons Clone"
echo "=============================================="

# -------------------------------
# 1) Install Docker + Compose
# -------------------------------
echo "✅ Updating system..."
sudo apt update -y

echo "✅ Installing Docker..."
sudo apt install -y docker.io

echo "✅ Enabling Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "✅ Installing Docker Compose ..."
sudo apt install -y docker-compose
docker-compose --version

echo "✅ Installing Git..."
sudo apt install -y git

# -------------------------------
# 2) Create folders
# -------------------------------
echo "✅ Creating folders..."
sudo mkdir -p "$BASE_DIR"/{config,addons,logs,backups}
cd "$BASE_DIR" || exit 1

# -------------------------------
# 3) Create docker-compose.yml (YOUR SAME FILE)
# -------------------------------
echo "✅ Creating docker-compose.yml..."
cat <<EOF > docker-compose.yml
services:
  web:
    image: odoo:19.0
    container_name: odoo19-web
    depends_on:
      - db
    ports:
      - "4101:8069"
      - "4102:8072"
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
      - odoo-web-data-19:/var/lib/odoo
      - ./config:/etc/odoo
      - ./addons:/mnt/extra-addons
      - ./logs:/mnt/log
      - ./backups:/mnt/backup

  db:
    image: postgres:16
    container_name: odoo19-db
    ports:
      - "5101:5432"
    restart: unless-stopped
    networks:
      - odoo_network
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
    volumes:
      - odoo-db-data-16:/var/lib/postgresql/data

networks:
  odoo_network:
    driver: bridge

volumes:
  odoo-web-data-19:
  odoo-db-data-16:
EOF

# -------------------------------
# 4) Create config/odoo.conf (YOUR SAME CONF)
# -------------------------------
echo "✅ Creating config/odoo.conf..."
cat <<EOF > config/odoo.conf
[options]
admin_passwd = Master@Boards123
proxy_mode = True
longpolling_port = 8072
;gevent_port = False
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons/Cybrosys/CybroAddons,/mnt/extra-addons/Cybrosys/OpenHRMS,/mnt/extra-addons/mcm/mcm_gen_modules,/mnt/extra-addons/mcm/mcm_subscription_alert,/mnt/extra-addons/mcm/odoo_enterprise_addons,/mnt/extra-addons/oca/account-financial-reporting,/mnt/extra-addons/oca/account-financial-tools,/mnt/extra-addons/oca/account-invoicing,/mnt/extra-addons/oca/account-payment,/mnt/extra-addons/oca/account-reconcile,/mnt/extra-addons/oca/reporting-engine,/mnt/extra-addons/oca/sale-workflow,/mnt/extra-addons/oca/server-tools,/mnt/extra-addons/oca/server-ux,/mnt/extra-addons/oca/web,/mnt/extra-addons/odoo-mates/odooapps,/mnt/extra-addons/others/myfree

workers = 2
max_cron_threads = 1
EOF

# -------------------------------
# 5) Confirm GitHub SSH Key BEFORE cloning SSH repos
# -------------------------------
echo ""
echo "=============================================="
echo "⚠️ GitHub SSH Key Check (for MCM private repos)"
echo "=============================================="
read -p "Did you already add GitHub SSH key in this server? (y/n): " SSH_OK

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
echo "✅ Moving to addons folder and cloning repositories..."
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

    echo "⬇️ Cloning $repo_name (branch 19.0)..."
    git clone -b 19.0 --single-branch "$repo"
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

echo "✅ All repositories cloned successfully!"

# -------------------------------
# 7) Start Containers
# -------------------------------
echo "✅ Starting Odoo 19 containers..."
cd "$BASE_DIR" || exit 1
docker-compose up -d

echo "=============================================="
echo "✅ DONE! Odoo 19 is running"
echo "🌐 Open: http://YOUR_SERVER_IP:4101"
echo "📌 Logs: docker logs -f odoo19-web"
echo "=============================================="
