# Backup-Server Einrichtung

## Konfiguration des zweiten Hetzner-Servers für Backups

### 1. SSH-Zugriff einrichten

**Auf dem BACKUP-SERVER (zweiter Hetzner):**
```bash
# Als root einloggen
ssh root@167.235.19.185

# Backup-Verzeichnis erstellen
mkdir -p /backup/mail.clocklight.de
chmod 700 /backup
```

### 2. SSH-Key vom Hauptserver hinzufügen

**Auf dem HAUPTSERVER (mail.clocklight.de):**
```bash
# Public Key anzeigen
cat ~/.ssh/id_ed25519.pub
# ODER falls nicht vorhanden:
ssh-keygen -t ed25519 -C "backup@mail.clocklight.de"
cat ~/.ssh/id_ed25519.pub
```

**Auf dem BACKUP-SERVER:**
```bash
# Public Key hinzufügen
nano ~/.ssh/authorized_keys
# Key vom Hauptserver einfügen und speichern
chmod 600 ~/.ssh/authorized_keys
```

### 3. SSH-Verbindung testen

**Auf dem HAUPTSERVER:**
```bash
# Verbindung testen (sollte OHNE Passwort funktionieren)
ssh root@167.235.19.185 "echo SSH connection successful"
```

### 4. Backup-Script konfigurieren

**Auf dem HAUPTSERVER:**
```bash
nano /srv/backups/scripts/backup-data.sh

# Folgende Zeilen anpassen:
REMOTE_SERVER="167.235.19.185_HIER"  # z.B. "95.217.123.456"
REMOTE_USER="root"
REMOTE_PATH="/backup/mail.clocklight.de"
REMOTE_PORT="22"  # Standard SSH-Port
```

### 5. Ersten Backup-Test durchführen

**Auf dem HAUPTSERVER:**
```bash
# Test-Backup durchführen (ohne cronjob)
/srv/backups/scripts/backup-data.sh

# Prüfen ob Backup auf Backup-Server angekommen ist
ssh root@167.235.19.185 "ls -lh /backup/mail.clocklight.de/"
```

### 6. Optional: Backup-Server absichern

**Auf dem BACKUP-SERVER:**
```bash
# Firewall aktivieren
ufw allow 22/tcp
ufw --force enable

# Automatische Updates aktivieren
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Fail2Ban installieren (optional)
apt install fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

### 7. Optional: Monitoring einrichten

**Auf dem BACKUP-SERVER:**
```bash
# Einfaches Monitoring-Script erstellen
cat > /root/check-backups.sh <<'SCRIPT'
#!/bin/bash
# Prüft ob neue Backups ankommen

BACKUP_DIR="/backup/mail.clocklight.de"
LATEST=$(ls -t ${BACKUP_DIR} | head -1)
AGE=$(find ${BACKUP_DIR}/${LATEST} -type d -mtime +2)

if [ -n "$AGE" ]; then
    echo "WARNING: Letztes Backup ist älter als 2 Tage!"
    echo "Letztes Backup: ${LATEST}"
    # Optional: E-Mail-Benachrichtigung senden
    # echo "Letztes Backup ist älter als 2 Tage!" | mail -s "Backup Alert" your@email.com
else
    echo "OK: Backups sind aktuell (${LATEST})"
fi
SCRIPT

chmod +x /root/check-backups.sh

# Cronjob für tägliche Prüfung
echo "0 12 * * * root /root/check-backups.sh" > /etc/cron.d/backup-check
```

### 8. Backup-Größen überwachen

**Auf dem BACKUP-SERVER:**
```bash
# Aktuelle Backup-Größe anzeigen
du -sh /backup/mail.clocklight.de/*

# Gesamtgröße
du -sh /backup/

# Disk-Space prüfen
df -h /
```

---

## Troubleshooting

### Problem: SSH-Verbindung schlägt fehl

```bash
# Auf HAUPTSERVER:
ssh -vvv root@167.235.19.185
# Prüfe die Fehlerausgabe

# SSH-Key Berechtigungen prüfen
ls -la ~/.ssh/
# id_ed25519 sollte 600 sein
# id_ed25519.pub sollte 644 sein
```

### Problem: rsync schlägt fehl

```bash
# Auf HAUPTSERVER:
# Manuell testen
rsync -avz --progress /tmp/test.txt root@167.235.19.185:/tmp/

# Prüfe rsync-Logs
tail -100 /var/log/backup-data.log
```

### Problem: Disk voll auf Backup-Server

```bash
# Auf BACKUP-SERVER:
# Alte Backups manuell löschen
cd /backup/mail.clocklight.de/
ls -lt | tail -20  # Zeige älteste Backups
rm -rf 20241201_*  # Beispiel: Löschen alter Backups

# ODER: Retention-Zeit im Script anpassen
# auf HAUPTSERVER:
nano /srv/backups/scripts/backup-data.sh
# RETENTION_DAYS=30 auf höheren Wert setzen
```

---

## Checkliste

- [ ] Backup-Server ist erreichbar via SSH
- [ ] SSH-Key ist auf Backup-Server hinterlegt
- [ ] Passwortlose SSH-Verbindung funktioniert
- [ ] Backup-Verzeichnis existiert auf Backup-Server
- [ ] backup-data.sh ist konfiguriert (IP, User, Path)
- [ ] Erster Test-Backup war erfolgreich
- [ ] Cronjobs sind auf Hauptserver eingerichtet
- [ ] Backup-Server Firewall ist konfiguriert
- [ ] Monitoring/Alerting ist eingerichtet (optional)

---

**Wichtig:**
- Backup-Server sollte in einem anderen Rechenzentrum stehen als Hauptserver!
- Regelmäßig Wiederherstellung testen!
- Backup-Server-Zugänge sicher aufbewahren!
