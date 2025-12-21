#!/bin/bash
#
# Data Backup Script
# Backs up databases and mail data to remote Hetzner server
#
# Author: Claude
# Date: 2025-12-21

set -e

# Configuration
BACKUP_DIR="/srv/backups/data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)
RETENTION_DAYS=30

# Remote backup server (CONFIGURE THIS!)
REMOTE_SERVER="YOUR_BACKUP_SERVER_IP_OR_HOSTNAME"
REMOTE_USER="backup-mailweb"
REMOTE_PATH="/backup/mail.clocklight.de"
REMOTE_PORT="22"
SSH_KEY="/root/.ssh/backup_key"

echo "=== Starting Data Backup at $(date) ==="

# Create backup directory
mkdir -p ${BACKUP_DIR}/${TIMESTAMP}

# Backup MySQL/MariaDB databases
echo "Backing up MySQL databases..."
cd /srv/mailcow
docker compose exec -T mysql-mailcow mysqldump -u mailcow -p$(grep DBPASS mailcow.conf | cut -d= -f2) --all-databases \
    > ${BACKUP_DIR}/${TIMESTAMP}/mysql-all-databases.sql
gzip ${BACKUP_DIR}/${TIMESTAMP}/mysql-all-databases.sql

# Backup Redis data
echo "Backing up Redis data..."
docker compose exec -T redis-mailcow redis-cli -a $(grep REDISPASS mailcow.conf | cut -d= -f2) --rdb /data/dump.rdb save
docker cp mailcowdockerized-redis-mailcow-1:/data/dump.rdb ${BACKUP_DIR}/${TIMESTAMP}/redis-dump.rdb
gzip ${BACKUP_DIR}/${TIMESTAMP}/redis-dump.rdb

# Backup mail data (vmail)
echo "Backing up mail data (vmail)..."
tar -czf ${BACKUP_DIR}/${TIMESTAMP}/vmail.tar.gz -C /srv/mailcow/data vmail/ 2>/dev/null || echo "Warning: Some vmail files may have been skipped"

# Backup DKIM keys (if they exist)
echo "Backing up DKIM keys..."
if [ -d "/srv/mailcow/data/dkim" ]; then
    tar -czf ${BACKUP_DIR}/${TIMESTAMP}/dkim-keys.tar.gz -C /srv/mailcow/data dkim/
fi

# Create backup manifest
cat > ${BACKUP_DIR}/${TIMESTAMP}/MANIFEST.txt <<EOF
Data Backup Manifest
====================
Hostname: ${HOSTNAME}
Date: $(date)
Timestamp: ${TIMESTAMP}

Backup Contents:
- mysql-all-databases.sql.gz (All MySQL/MariaDB databases)
- redis-dump.rdb.gz (Redis data including DKIM keys)
- vmail.tar.gz (All email data)
- dkim-keys.tar.gz (DKIM signing keys)

Sizes:
$(du -sh ${BACKUP_DIR}/${TIMESTAMP}/*)

Total Size:
$(du -sh ${BACKUP_DIR}/${TIMESTAMP}/ | cut -f1)
EOF

# Calculate checksums
echo "Calculating checksums..."
cd ${BACKUP_DIR}/${TIMESTAMP}
sha256sum * > SHA256SUMS

# Transfer to remote backup server
echo "Transferring backup to remote server..."
if [ "${REMOTE_SERVER}" != "YOUR_BACKUP_SERVER_IP_OR_HOSTNAME" ]; then
    # Check if SSH key exists
    if [ ! -f "${SSH_KEY}" ]; then
        echo "ERROR: SSH key not found at ${SSH_KEY}"
        echo "Please run: ssh-keygen -t ed25519 -C 'backup@mail.clocklight.de' -f ${SSH_KEY}"
        exit 1
    fi

    # Create remote directory (may fail if command-restriction is active, that's OK)
    ssh -i ${SSH_KEY} -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_SERVER} "mkdir -p ${REMOTE_PATH}/${TIMESTAMP}" 2>/dev/null || true

    # Transfer with rsync using SSH key
    rsync -avz --progress -e "ssh -i ${SSH_KEY} -p ${REMOTE_PORT}" \
        ${BACKUP_DIR}/${TIMESTAMP}/ \
        ${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/${TIMESTAMP}/

    if [ $? -eq 0 ]; then
        echo "Backup successfully transferred to ${REMOTE_SERVER}:${REMOTE_PATH}/${TIMESTAMP}/"
    else
        echo "ERROR: Backup transfer failed!"
        exit 1
    fi
else
    echo "WARNING: Remote server not configured! Backup only stored locally."
    echo "Edit /srv/backups/scripts/backup-data.sh and configure:"
    echo "  - REMOTE_SERVER (your backup server IP)"
    echo "  - SSH_KEY path (default: /root/.ssh/backup_key)"
    echo ""
    echo "See BACKUP-SERVER-SETUP-SECURE.md for detailed setup instructions"
fi

# Clean up old local backups (keep last 7 days locally)
echo "Cleaning up old local backups (keeping last 7 days)..."
find ${BACKUP_DIR}/ -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

# Clean up old remote backups (keep last 30 days on remote)
if [ "${REMOTE_SERVER}" != "YOUR_BACKUP_SERVER_IP_OR_HOSTNAME" ]; then
    echo "Cleaning up old remote backups (keeping last ${RETENTION_DAYS} days)..."
    ssh -i ${SSH_KEY} -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_SERVER} \
        "find ${REMOTE_PATH}/ -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;" 2>/dev/null || true
fi

echo "=== Data Backup Complete at $(date) ==="
echo "Local backup: ${BACKUP_DIR}/${TIMESTAMP}"
[ "${REMOTE_SERVER}" != "YOUR_BACKUP_SERVER_IP_OR_HOSTNAME" ] && echo "Remote backup: ${REMOTE_SERVER}:${REMOTE_PATH}/${TIMESTAMP}/"
