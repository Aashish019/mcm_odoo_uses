# Odoo 19 Docker Setup + Nginx DNS + SSL (McMillan)

This guide explains how to set up **Odoo 19 using Docker** and configure **Nginx + Domain + SSL (HTTPS)** using the provided scripts from this repository.

---

## ✅ Prerequisites

Before starting, make sure:

- You have a Linux server (Ubuntu recommended)
- You have `wget` installed
- Your domain **A record** is pointing to your server IP
- Firewall allows ports:
  - `80` (HTTP)
  - `443` (HTTPS)

(Optional but recommended)

```bash
sudo ufw allow 80
sudo ufw allow 443

```

# ✅ Step 1: Odoo 19 Using Docker Setup
## 1.1 Create script file odoo19docker.sh

Go to the folder where you want to run setup:
```
mkdir -p odoo19_setup
cd odoo19_setup
```

Download the script and save as odoo19docker.sh:
```
wget -O odoo19docker.sh https://raw.githubusercontent.com/Aashish019/mcm_odoo_uses/refs/heads/main/docker/odoo19/setup_odoo19_docker.sh
```
## 1.2 Give permission
```
chmod +x odoo19docker.sh
```
## 1.3 Run script
```
./odoo19docker.sh
```

 ✅ This will install and run Odoo 19 Docker environment.

 
---------------------------------------------------------------------


# ✅ Step 2: Nginx + DNS + SSL Setup
## 2.1 Create script file nginxdnsssl.sh

Download the Nginx + SSL script and save as nginxdnsssl.sh:
```
wget -O nginxdnsssl.sh https://raw.githubusercontent.com/Aashish019/mcm_odoo_uses/refs/heads/main/docker/odoo19/setup_nginx_ssl_odoo19.sh
```
## 2.2 Give permission
```
chmod +x nginxdnsssl.sh
```
## 2.3 Run script with domain name

Run the script by passing your domain name:
```
./nginxdnsssl.sh test.mcmillan.solutions
```


