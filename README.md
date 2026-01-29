# MCM Odoo Uses

A comprehensive collection of scripts, configurations, and utilities for managing Odoo ERP deployments. This repository provides tools for Docker-based deployments, automated backups, monitoring, and various maintenance operations.

## 📋 Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Common Commands](#common-commands)
- [Configuration](#configuration)
- [Backup and Restore](#backup-and-restore)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [ZATCA Integration](#zatca-integration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This repository contains everything needed to deploy, manage, and maintain Odoo ERP systems. It includes:

- Docker Compose configurations for containerized deployments
- Automated backup scripts for databases and filestores
- Monitoring and health check utilities
- CI/CD workflows with GitHub Actions
- Infrastructure as Code (Terraform) configurations
- Custom Odoo modules and addons
- ZATCA (Saudi e-invoicing) integration tools

## 📁 Repository Structure

```
mcm_odoo_uses/
├── .github/
│   └── workflows/          # GitHub Actions CI/CD workflows
├── docker/                 # Docker-related files and configurations
├── odoo/                   # Custom Odoo modules and addons
├── terraform/              # Infrastructure as Code configurations
├── docker-compose.yml      # Docker Compose configuration
├── config                  # Main Odoo configuration file
├── backup.sh              # Simple database backup script
├── odoo_full_backup.sh    # Comprehensive backup (DB + filestore)
└── docs/
    ├── Odoo_Monitoring_Script.md
    ├── addons_path_finder.md
    ├── path_git_pull.md
    ├── pnow.md
    ├── pre_check.md
    ├── repo_install.md
    └── zatcadb.md
```

## 🔧 Prerequisites

- Docker and Docker Compose
- PostgreSQL 12+ (or use Docker container)
- Python 3.8+
- Node.js 14+ (for certain utilities)
- Git
- Sufficient disk space for Odoo filestore and database backups

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/Aashish019/mcm_odoo_uses.git
   cd mcm_odoo_uses
   ```

2. **Review and customize configuration**
   ```bash
   # Edit docker-compose.yml and config file according to your needs
   nano docker-compose.yml
   nano config
   ```

3. **Start the services**
   ```bash
   docker-compose up -d
   ```

4. **Access Odoo**
   ```
   Open your browser and navigate to http://localhost:8069
   ```

## 💻 Common Commands

### Module Management

**Update a specific module:**
```bash
./odoo-bin -c odoo.conf -d DATABASE_NAME -u MODULE_NAME --stop-after-init
```

**Update all modules:**
```bash
./odoo-bin -c odoo.conf -d DATABASE_NAME -u all --stop-after-init
```

**Example:**
```bash
./odoo-bin -c odoo.conf -d Reliant_Rentalz_test -u mcm_sale_purchase_custom --stop-after-init
```

### Database Operations

**Create a backup:**
```bash
# Standard PostgreSQL dump (custom format)
pg_dump -U odoo17 -h localhost -p 5432 -Fc DATABASE_NAME > backup.dump

# Plain SQL format
pg_dump -U odoo17 -h localhost -p 5432 -F p DATABASE_NAME > backup.sql

# Using environment variables
pg_dump -U $DB_USER -h localhost -F c -b -v -f "backup_$(date +%Y%m%d).dump" $DB_NAME
```

**Docker container backup:**
```bash
docker exec -it CONTAINER_NAME pg_dump -U odoo -d DATABASE_NAME -F p > odoo_backup.sql
```

**Restore a backup:**
```bash
# From custom format
pg_restore -U odoo17 -h localhost -p 5432 -d DATABASE_NAME backup.dump

# From SQL format
psql -U odoo17 -h localhost -p 5432 -d DATABASE_NAME < backup.sql
```

### File Transfer

**Copy backup using SCP:**
```bash
scp user@remote_host:/path/to/backup.sql ./
```

**Example:**
```bash
scp aashi@192.168.29.13:/home/aashi/deployment/odoo-17/config/docker/odoo_backup.sql ./
```

## ⚙️ Configuration

### Odoo Configuration File

The main configuration file (`config`) contains essential settings:

```ini
[options]
addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons
admin_passwd = CHANGE_ME
db_host = db
db_port = 5432
db_user = odoo
db_password = odoo
```

**Important settings to customize:**
- `addons_path`: Paths to custom modules
- `admin_passwd`: Master password (change immediately!)
- `db_host`: Database host (use service name in Docker)
- Database credentials

### Docker Compose

Key services in `docker-compose.yml`:

```yaml
services:
  web:
    image: odoo:17.0
    depends_on:
      - db
    ports:
      - "8069:8069"
    volumes:
      - odoo-web-data:/var/lib/odoo
      - ./config:/etc/odoo
      - ./addons:/mnt/extra-addons

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_USER=odoo
      - POSTGRES_PASSWORD=odoo
    volumes:
      - odoo-db-data:/var/lib/postgresql/data
```

## 💾 Backup and Restore

### Automated Backups

**Simple backup script (`backup.sh`):**
```bash
#!/bin/bash
# Run daily via cron
./backup.sh
```

**Full backup script (`odoo_full_backup.sh`):**
- Backs up PostgreSQL database
- Backs up Odoo filestore
- Compresses and timestamps backups
- Manages backup retention

**Set up automated backups:**
```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /path/to/mcm_odoo_uses/odoo_full_backup.sh
```

### Backup Best Practices

1. **Regular Schedule**: Daily backups at minimum
2. **Multiple Locations**: Store backups on-site and off-site
3. **Test Restores**: Regularly verify backup integrity
4. **Retention Policy**: Keep 7 daily, 4 weekly, 12 monthly backups
5. **Compression**: Use `-Fc` format for space efficiency
6. **Monitoring**: Alert on backup failures

## 🚢 Deployment

### Development Environment

```bash
# Use docker-compose for local development
docker-compose up
```

### Production Deployment

1. **Review pre-deployment checklist** (`pre_check.md`)
2. **Follow production notes** (`pnow.md`)
3. **Configure monitoring** (`Odoo_Monitoring_Script.md`)
4. **Set up SSL/TLS** (use nginx reverse proxy)
5. **Configure backups**
6. **Test thoroughly** in staging environment

### CI/CD with GitHub Actions

The repository includes workflow configurations in `.github/workflows/` for:
- Automated testing
- Deployment pipelines
- Code quality checks

## 📊 Monitoring

Set up monitoring following `Odoo_Monitoring_Script.md`:

- **System Resources**: CPU, memory, disk usage
- **Database Performance**: Query performance, connection pools
- **Application Health**: Response times, error rates
- **Backup Status**: Successful completion, file sizes
- **User Activity**: Active sessions, concurrent users

**Recommended Tools:**
- Prometheus + Grafana for metrics
- ELK Stack for log aggregation
- Uptime monitoring services
- Database performance monitoring

## 🇸🇦 ZATCA Integration

For Saudi Arabian e-invoicing compliance (ZATCA/FATOORA):

### Configuration Modes

**Sandbox Mode (Testing):**
```bash
sudo -u postgres psql -d DATABASE_NAME -c "UPDATE res_users SET password = '123' WHERE login = 'administrator'; UPDATE res_company SET l10n_sa_api_mode = 'sandbox';"
```

**Pre-Production Mode:**
```bash
sudo -u postgres psql -d DATABASE_NAME -c "UPDATE res_users SET password = '123' WHERE login = 'administrator'; UPDATE res_company SET l10n_sa_api_mode = 'preprod';"
```

**Production Mode:**
```bash
sudo -u postgres psql -d DATABASE_NAME -c "UPDATE res_company SET l10n_sa_api_mode = 'production';"
```

### ZATCA Setup

1. Review `zatcadb.md` for detailed configuration
2. Configure company details in Odoo
3. Generate and register certificates
4. Test in sandbox environment
5. Submit for ZATCA approval
6. Deploy to production

## 🔍 Troubleshooting

### Common Issues

**Odoo won't start:**
```bash
# Check logs
docker-compose logs web

# Verify database connection
docker-compose exec db psql -U odoo -l

# Check configuration
cat config
```

**Module installation fails:**
```bash
# Check addons path
# Verify file permissions
# Review logs for specific errors
./odoo-bin -c odoo.conf -d DATABASE_NAME -u MODULE_NAME --log-level=debug
```

**Database connection issues:**
```bash
# Verify database is running
docker-compose ps

# Check database connectivity
docker-compose exec web pg_isready -h db -p 5432

# Review database logs
docker-compose logs db
```

**Performance issues:**
- Check system resources
- Review slow query logs
- Optimize database indexes
- Enable Odoo caching
- Consider upgrading hardware

### Useful Debug Commands

```bash
# View Odoo logs
docker-compose logs -f web

# Enter Odoo container shell
docker-compose exec web bash

# Enter database container
docker-compose exec db psql -U odoo

# Check disk space
df -h

# Monitor resource usage
htop
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Python PEP 8 style guide
- Add comments for complex logic
- Update documentation for new features
- Test thoroughly before submitting
- Keep commits focused and atomic

## 📄 License

This project is maintained for internal use. Please contact the repository owner for licensing information.

## 📞 Support

For issues, questions, or contributions:

- **Issues**: Open a GitHub issue
- **Documentation**: Check the `docs/` directory
- **Repository**: [https://github.com/Aashish019/mcm_odoo_uses](https://github.com/Aashish019/mcm_odoo_uses)

## 📚 Additional Resources

- [Official Odoo Documentation](https://www.odoo.com/documentation)
- [Docker Documentation](https://docs.docker.com)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [ZATCA E-Invoicing Portal](https://zatca.gov.sa)
- [Terraform Documentation](https://www.terraform.io/docs)

## 🔖 Version History

See the commit history for detailed version information.

---

**Last Updated**: January 29, 2026

**Repository**: [github.com/Aashish019/mcm_odoo_uses](https://github.com/Aashish019/mcm_odoo_uses)
