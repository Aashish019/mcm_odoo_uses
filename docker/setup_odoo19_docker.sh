#!/bin/bash
set -e

BASE_DIR="/root/deployment/odoo-19/config/docker"

echo "=============================================="
echo "   ✅ Odoo 19 Docker Full Setup Script"
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

echo "✅ Installing Docker Compose plugin..."
sudo apt install -y docker-compose-plugin

# -------------------------------
# 2) Create folders
# -------------------------------
echo "✅ Creating folders..."
sudo mkdir -p "$BASE_DIR"/{config,addons,logs,backups}
cd "$BASE_DIR"

# -------------------------------
# 3) Create docker-compose.yml
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
# 4) Create config/odoo.conf
# -------------------------------
echo "✅ Creating config/odoo.conf..."
cat <<EOF > config/odoo.conf
[options]
admin_passwd = Master@Boards123
proxy_mode = True
longpolling_port = 8072
;gevent_port = False
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons/mcm/mcmillan_internal_addons,/mnt/extra-addons/mcm/mcm_gen_modules,/mnt/extra-addons/oca/web,/mnt/extra-addons/odoo-mates,/mnt/extra-addons/mcm/odoo_enterprise_addons,/mnt/extra-addons/Cybrosys/CybroAddons,/mnt/extra-addons/Cybrosys/OpenHRMS,/mnt/extra-addons/mcm/mcm_subscription_alert
workers = 2
max_cron_threads = 1
EOF

# -------------------------------
# 5) Run containers
# -------------------------------
echo "✅ Starting Odoo 19 containers..."
docker compose up -d

echo "=============================================="
echo "✅ DONE! Odoo 19 is running"
echo "🌐 Open: http://YOUR_SERVER_IP:4101"
echo "📌 Logs: docker logs -f odoo19-web"
echo "=============================================="
