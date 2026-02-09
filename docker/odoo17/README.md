# Odoo 17 Docker Setup + Nginx DNS + SSL (McMillan)

This guide explains how to set up **Odoo 17 using Docker** and configure **Nginx + Domain + SSL (HTTPS)** using the provided scripts from this repository.

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

# ✅ Step 1: Odoo 17 Using Docker Setup
## 1.1 Create script file odoo17docker.sh

Go to the folder where you want to run setup:
```
mkdir -p odoo17_setup
cd odoo17_setup
```

Download the script and save as odoo17docker.sh:
```
wget -O odoo17docker.sh https://raw.githubusercontent.com/Aashish019/mcm_odoo_uses/refs/heads/main/docker/odoo17/setup_odoo17_docker.sh
```
## 1.2 Give permission
```
chmod +x odoo17docker.sh
```
## 1.3 Run script
```
./odoo17docker.sh
```

 ✅ This will install and run Odoo 17 Docker environment.

 
---------------------------------------------------------------------


# ✅ Step 2: Nginx + DNS + SSL Setup
## 2.1 Create script file nginxdnsssl.sh

Download the Nginx + SSL script and save as nginxdnsssl.sh:
```
wget -O nginxdnsssl.sh https://raw.githubusercontent.com/Aashish019/mcm_odoo_uses/refs/heads/main/docker/odoo17/setup_nginx_ssl_odoo17.sh
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


---

# ✅ Step 3: Initialize/Update Odoo Database

After the setup is complete, you need to initialize or update your Odoo database and modules.

## 3.1 Create a new database and install all modules

```bash
docker exec -it odoo17-web odoo \
  -d KBG \
  -i base \
  --db_host=db \
  --db_user=odoo \
  --db_password=odoo \
  --without-demo=all \
  --stop-after-init
```

Replace `KBG` with your desired database name.

## 3.2 Update all modules in an existing database

```bash
docker exec -it odoo17-web odoo \
  -d KBG \
  -u all \
  --db_host=db \
  --db_user=odoo \
  --db_password=odoo \
  --no-http \
  --stop-after-init
```


---

## 📝 Useful Docker Commands

**View running containers:**
```bash
docker ps
```

**View Odoo logs:**
```bash
docker logs -f odoo17-web
```

**Restart Odoo:**
```bash
docker restart odoo17-web
```

**Stop all services:**
```bash
docker-compose down
```

**Start all services:**
```bash
docker-compose up -d
```

---


---

## 📄 License

This setup guide is provided as-is for McMillan solutions deployment.
