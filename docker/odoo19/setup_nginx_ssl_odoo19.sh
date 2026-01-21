#!/bin/bash
set -e

DOMAIN="$1"
EMAIL="mcmillandomains@gmail.com"
ODOO_PORT="4101"
CHAT_PORT="4102"
AUTH_USER="admin"
AUTH_PASS="Master@nginx#17"

if [ -z "$DOMAIN" ]; then
  echo "❌ Usage: $0 <domain>"
  echo "✅ Example: $0 aashi.mcmillan.solutions"
  exit 1
fi

echo "=============================================="
echo "✅ MCM Setup: Nginx + UFW + SSL + Basic Auth"
echo "Domain : $DOMAIN"
echo "Email  : $EMAIL"
echo "Ports  : Odoo=$ODOO_PORT  Chat=$CHAT_PORT"
echo "Auth   : $AUTH_USER / $AUTH_PASS"
echo "=============================================="

# -------------------------------
# 1) Install Nginx + UFW
# -------------------------------
sudo apt update -y
sudo apt install -y nginx ufw

# -------------------------------
# 2) UFW Rules
# -------------------------------
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw --force enable

# -------------------------------
# 3) Enable Nginx
# -------------------------------
sudo systemctl enable nginx
sudo systemctl status nginx --no-pager || true

# -------------------------------
# 4) Create Nginx Site Config
# -------------------------------
NGINX_SITE="/etc/nginx/sites-available/${DOMAIN}"

sudo tee "$NGINX_SITE" > /dev/null <<EOF
upstream odoo {
    server 127.0.0.1:${ODOO_PORT};
}

upstream odoochat {
    server 127.0.0.1:${CHAT_PORT};
}

map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}

server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};

    client_max_body_size 20M;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    access_log /var/log/nginx/odoo.access.log;
    error_log  /var/log/nginx/odoo.error.log;

    location / {
        proxy_redirect off;
        proxy_pass http://odoo;
    }

    # Secure DB Manager
    location /web/database/manager {
        auth_basic "Zone protege";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_redirect off;
        proxy_pass http://odoo;
    }

    # Longpolling (your usual)
    location /longpolling {
        proxy_pass http://odoochat;
    }

    # Websocket (recommended for Odoo 16+)
    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    gzip_types text/css text/plain application/json application/javascript;
    gzip on;
}
EOF

# -------------------------------
# 5) Enable site + remove default
# -------------------------------
sudo ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# -------------------------------
# 6) Enable server_names_hash_bucket_size 64;
# -------------------------------
NGINX_MAIN="/etc/nginx/nginx.conf"

if grep -q "^[# ]*server_names_hash_bucket_size" "$NGINX_MAIN"; then
  sudo sed -i 's/^[# ]*server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/' "$NGINX_MAIN"
else
  # add inside http block
  sudo sed -i '/http {/a \    server_names_hash_bucket_size 64;' "$NGINX_MAIN"
fi

# -------------------------------
# 7) Restart Nginx
# -------------------------------
sudo nginx -t
sudo systemctl restart nginx

# -------------------------------
# 8) Install SSL (Certbot)
# -------------------------------
sudo apt install -y certbot python3-certbot-nginx

sudo certbot --nginx \
  -d "${DOMAIN}" \
  --non-interactive --agree-tos \
  -m "${EMAIL}" \
  --redirect

# -------------------------------
# 9) Basic Authentication Setup
# -------------------------------
sudo apt-get install -y apache2-utils

HTPASS="/etc/nginx/.htpasswd"
if [ -f "$HTPASS" ]; then
  echo "$AUTH_PASS" | sudo htpasswd -i "$HTPASS" "$AUTH_USER"
else
  echo "$AUTH_PASS" | sudo htpasswd -c -i "$HTPASS" "$AUTH_USER"
fi

sudo systemctl restart nginx

echo "=============================================="
echo "✅ DONE ✅"
echo "🌐 Website: https://${DOMAIN}"
echo "🔐 DB Manager Protected: https://${DOMAIN}/web/database/manager"
echo "Auth User: ${AUTH_USER}"
echo "Auth Pass: ${AUTH_PASS}"
echo "=============================================="
