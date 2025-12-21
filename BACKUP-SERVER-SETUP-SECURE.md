# Backup-Server Einrichtung (Sicherer Dedicated User)

## 🔒 Sicheres Setup mit dediziertem Backup-User

### Auf dem BACKUP-SERVER ausführen

#### 1. Backup-User erstellen
```bash
# Als root auf Backup-Server einloggen
ssh root@167.235.19.185

# Dedizierten Backup-User anlegen
useradd -m -s /bin/bash backup-mailweb

# Backup-Verzeichnis erstellen
mkdir -p /backup/mail.clocklight.de
chown backup-mailweb:backup-mailweb /backup/mail.clocklight.de
chmod 700 /backup/mail.clocklight.de

# .ssh Verzeichnis für den User erstellen
mkdir -p /home/backup-mailweb/.ssh
chmod 700 /home/backup-mailweb/.ssh
touch /home/backup-mailweb/.ssh/authorized_keys
chmod 600 /home/backup-mailweb/.ssh/authorized_keys
chown -R backup-mailweb:backup-mailweb /home/backup-mailweb/.ssh
```

---

### Auf dem HAUPTSERVER (mail.clocklight.de) ausführen

#### 2. SSH-Key generieren (falls nicht vorhanden)
```bash
# Als root
ssh-keygen -t ed25519 -C "backup@mail.clocklight.de" -f /root/.ssh/backup_key

# Öffentlichen Schlüssel anzeigen
cat /root/.ssh/backup_key.pub
```

Kopiere die gesamte Ausgabe (beginnt mit `ssh-ed25519 ...`)

---

### Zurück auf dem BACKUP-SERVER

#### 3. Public Key hinzufügen
```bash
# Als root
nano /home/backup-mailweb/.ssh/authorized_keys

# Füge den Public Key vom Hauptserver ein
# (die Zeile, die mit ssh-ed25519 beginnt)

# Speichern und schließen (Strg+O, Enter, Strg+X)

# Berechtigungen nochmal prüfen
chmod 600 /home/backup-mailweb/.ssh/authorized_keys
chown backup-mailweb:backup-mailweb /home/backup-mailweb/.ssh/authorized_keys
```

#### 4. SSH-Zugriff absichern (optional, aber empfohlen)
```bash
# Beschränke den User nur auf bestimmte Befehle (sehr restriktiv)
nano /home/backup-mailweb/.ssh/authorized_keys

# Füge VOR dem ssh-ed25519 folgendes ein (alles in EINER Zeile):
# command="/usr/bin/rsync --server -vlogDtpre.iLsfx --delete . /backup/mail.clocklight.de/",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA...

# Beispiel einer vollständigen Zeile:
# command="/usr/bin/rsync --server -vlogDtpre.iLsfx --delete . /backup/mail.clocklight.de/",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample... backup@mail.clocklight.de
```

**HINWEIS:** Die command-Einschränkung macht den Zugriff SEHR sicher, erlaubt aber nur rsync. Für flexiblere Nutzung kannst du diese Zeile weglassen.

---

### Zurück auf dem HAUPTSERVER

#### 5. SSH-Verbindung testen
```bash
# Test ohne command-Einschränkung:
ssh -i /root/.ssh/backup_key backup-mailweb@167.235.19.185 "ls -la /backup/mail.clocklight.de/"

# Sollte das Verzeichnis anzeigen

# Wenn command-Einschränkung aktiv ist, sollte obiger Befehl fehlschlagen
# (das ist gut für Sicherheit!)
# rsync sollte aber funktionieren:
rsync -avz -e "ssh -i /root/.ssh/backup_key" /tmp/test.txt backup-mailweb@167.235.19.185:/backup/mail.clocklight.de/
```

---

### Auf dem HAUPTSERVER: Backup-Script anpassen

#### 6. backup-data.sh konfigurieren
```bash
nano /srv/backups/scripts/backup-data.sh

# Ändere folgende Zeilen:
REMOTE_SERVER="DEINE_167.235.19.185"     # z.B. "95.217.123.45"
REMOTE_USER="backup-mailweb"                 # ← Geändert von root
REMOTE_PATH="/backup/mail.clocklight.de"
REMOTE_PORT="22"
SSH_KEY="/root/.ssh/backup_key"            # ← Neue Zeile!

# Bei den rsync-Befehlen wird automatisch der SSH_KEY verwendet
```

#### 7. Ersten Test-Backup durchführen
```bash
# Test-Backup
/srv/backups/scripts/backup-data.sh

# Prüfen ob Backup angekommen ist
ssh -i /root/.ssh/backup_key backup-mailweb@167.235.19.185 "ls -lh /backup/mail.clocklight.de/"
```

---

## 🔒 Sicherheitsverbesserungen (Optional)

### Auf dem BACKUP-SERVER

#### SSH weiter absichern
```bash
# /etc/ssh/sshd_config bearbeiten
nano /etc/ssh/sshd_config

# Nur für bestimmte User SSH erlauben
# Am Ende der Datei hinzufügen:
AllowUsers root backup-mailweb

# SSH neu starten
systemctl restart sshd
```

#### Firewall einrichten
```bash
ufw allow 22/tcp
ufw --force enable
ufw status
```

#### Automatische Bereinigung alter Backups
```bash
# Cronjob auf Backup-Server
crontab -e

# Füge hinzu (löscht Backups älter als 30 Tage):
0 4 * * * find /backup/mail.clocklight.de/ -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;
```

---

## 📊 Monitoring (Optional)

### Backup-Status-Script auf Backup-Server
```bash
# Als root auf Backup-Server
cat > /usr/local/bin/check-backup-age.sh <<'SCRIPT'
#!/bin/bash
BACKUP_DIR="/backup/mail.clocklight.de"
WARN_HOURS=36

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found!"
    exit 1
fi

LATEST=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" | sort -r | head -1)
if [ -z "$LATEST" ]; then
    echo "ERROR: No backups found!"
    exit 1
fi

AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y "$LATEST") ))
AGE_HOURS=$(( AGE_SECONDS / 3600 ))

echo "Latest backup: $(basename $LATEST)"
echo "Age: ${AGE_HOURS} hours"

if [ $AGE_HOURS -gt $WARN_HOURS ]; then
    echo "WARNING: Backup is older than ${WARN_HOURS} hours!"
    exit 1
else
    echo "OK: Backup is current"
fi
SCRIPT

chmod +x /usr/local/bin/check-backup-age.sh

# Testen
/usr/local/bin/check-backup-age.sh

# Optional: Tägliche Prüfung
echo "0 12 * * * root /usr/local/bin/check-backup-age.sh || echo 'Backup Warning!' | mail -s 'Backup Alert' your@email.com" >> /etc/crontab
```

---

## 🔍 Troubleshooting

### Problem: Permission denied
```bash
# Auf BACKUP-SERVER prüfen:
ls -la /backup/mail.clocklight.de/
ls -la /home/backup-mailweb/.ssh/

# Sollte sein:
# drwx------ backup-mailweb:backup-mailweb /backup/mail.clocklight.de/
# -rw------- backup-mailweb:backup-mailweb authorized_keys
```

### Problem: SSH-Key wird nicht akzeptiert
```bash
# Auf HAUPTSERVER:
ssh -vvv -i /root/.ssh/backup_key backup-mailweb@167.235.19.185

# Prüfe die Ausgabe auf Fehler

# Key-Berechtigungen prüfen
ls -la /root/.ssh/backup_key*
# backup_key sollte 600 sein
# backup_key.pub sollte 644 sein
```

### Problem: rsync schlägt fehl
```bash
# Auf HAUPTSERVER:
# Detaillierte rsync-Ausgabe
rsync -avz --progress -e "ssh -i /root/.ssh/backup_key" \
    /tmp/test.txt \
    backup-mailweb@167.235.19.185:/backup/mail.clocklight.de/

# Logs prüfen
tail -100 /var/log/backup-data.log
```

---

## ✅ Sicherheits-Checkliste

- [x] Dedizierter User (nicht root)
- [x] SSH-Key-basierte Authentifizierung
- [x] Eingeschränkte Verzeichnis-Berechtigungen (700)
- [ ] Optional: SSH-Command-Restriction (nur rsync)
- [ ] Optional: Firewall auf Backup-Server
- [ ] Optional: Monitoring/Alerting
- [ ] Optional: Separate Partition für /backup
- [ ] Optional: Verschlüsselung (LUKS)

---

## 🎯 Vorteile dieser Konfiguration

✅ **Kein Root-Zugriff** - Kompromittierung des Hauptservers gefährdet nicht den Backup-Server
✅ **Eingeschränkte Berechtigungen** - User kann nur in sein Verzeichnis schreiben
✅ **SSH-Key statt Passwort** - Sicherer und keine Passwort-Brute-Force möglich
✅ **Optional: Command-Restriction** - SSH-Zugriff nur für rsync-Befehl
✅ **Separate User-Isolierung** - Andere Services auf Backup-Server bleiben getrennt

---

**Erstellt:** 2025-12-21
**Version:** 1.0 (Secure)
