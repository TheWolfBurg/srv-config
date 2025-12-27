#!/bin/bash
#
# Configuration Backup Script
# Backs up all configuration files to git repository
#
# Author: Claude
# Date: 2025-12-21

set -e

BACKUP_DIR="/srv/backups/config"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)

echo "=== Starting Configuration Backup at $(date) ==="

# Clean backup directory
rm -rf ${BACKUP_DIR}/*

# Backup mailcow configuration
echo "Backing up mailcow configuration..."
mkdir -p ${BACKUP_DIR}/mailcow
cp -r /srv/mailcow/mailcow.conf ${BACKUP_DIR}/mailcow/
cp -r /srv/mailcow/data/conf ${BACKUP_DIR}/mailcow/
cp /srv/mailcow/docker-compose.yml ${BACKUP_DIR}/mailcow/ 2>/dev/null || true

# Backup Caddy configuration
echo "Backing up Caddy configuration..."
mkdir -p ${BACKUP_DIR}/caddy
cp -r /srv/caddy/Caddyfile ${BACKUP_DIR}/caddy/
cp -r /srv/caddy/sites ${BACKUP_DIR}/caddy/
cp -r /srv/caddy/snippets ${BACKUP_DIR}/caddy/ 2>/dev/null || true
cp /srv/caddy/docker-compose.yml ${BACKUP_DIR}/caddy/

# Backup Netdata configuration
echo "Backing up Netdata configuration..."
mkdir -p ${BACKUP_DIR}/netdata
cp /srv/netdata/docker-compose.yml ${BACKUP_DIR}/netdata/ 2>/dev/null || true

# Backup Beszel configuration
echo "Backing up Beszel configuration..."
mkdir -p ${BACKUP_DIR}/beszel
cp /srv/beszel/docker-compose.yml ${BACKUP_DIR}/beszel/
# Backup Beszel data (SQLite database with metrics)
if [ -d "/srv/beszel/beszel_data" ]; then
    tar -czf ${BACKUP_DIR}/beszel/beszel_data.tar.gz -C /srv/beszel beszel_data/
fi

# Backup system configuration
echo "Backing up system configuration..."
mkdir -p ${BACKUP_DIR}/system
cp /etc/hostname ${BACKUP_DIR}/system/ 2>/dev/null || true
cp /etc/hosts ${BACKUP_DIR}/system/ 2>/dev/null || true
cp /etc/fstab ${BACKUP_DIR}/system/ 2>/dev/null || true
cp /etc/crontab ${BACKUP_DIR}/system/ 2>/dev/null || true
cp -r /etc/cron.d ${BACKUP_DIR}/system/ 2>/dev/null || true

# Backup SSH configuration (without private keys!)
echo "Backing up SSH configuration..."
mkdir -p ${BACKUP_DIR}/ssh
cp /etc/ssh/sshd_config ${BACKUP_DIR}/ssh/ 2>/dev/null || true

# Backup firewall rules
echo "Backing up firewall rules..."
mkdir -p ${BACKUP_DIR}/firewall
iptables-save > ${BACKUP_DIR}/firewall/iptables.rules 2>/dev/null || true
ufw status verbose > ${BACKUP_DIR}/firewall/ufw-status.txt 2>/dev/null || true

# Backup Docker configurations
echo "Backing up Docker configurations..."
mkdir -p ${BACKUP_DIR}/docker
docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.Status}}" > ${BACKUP_DIR}/docker/containers.txt
docker network ls > ${BACKUP_DIR}/docker/networks.txt
docker volume ls > ${BACKUP_DIR}/docker/volumes.txt

# Create inventory file
echo "Creating inventory file..."
cat > ${BACKUP_DIR}/INVENTORY.txt <<EOF
Configuration Backup Inventory
==============================
Hostname: ${HOSTNAME}
Date: $(date)
Backup Script Version: 1.0

Included Configurations:
- mailcow (mailcow.conf, data/conf/, docker-compose.yml)
- Caddy (Caddyfile, sites, snippets, docker-compose.yml)
- Netdata (docker-compose.yml)
- Beszel (docker-compose.yml, beszel_data.tar.gz)
- System (/etc/hostname, hosts, fstab, crontab)
- SSH (sshd_config)
- Firewall (iptables, ufw)
- Docker (container list, networks, volumes)

Not Included (use data backup for these):
- Email data (/srv/mailcow/data/vmail/)
- Databases
- DKIM keys
- SSL certificates (auto-renewed via Let's Encrypt)
EOF

# Commit to git
cd /srv/backups
git add config/
git commit -m "Config backup ${TIMESTAMP} from ${HOSTNAME}" || echo "No changes to commit"

echo "=== Configuration Backup Complete at $(date) ==="
echo "Backup location: ${BACKUP_DIR}"
