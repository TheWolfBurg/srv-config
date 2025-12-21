# Server Backup & Disaster Recovery Guide

## 📋 Übersicht

Dieses Repository enthält alle Konfigurationsdateien und Scripts für das Backup und die Wiederherstellung deines Mail- und Webservers.

**Hostname:** `mail.clocklight.de`
**Hauptdomain:** `clocklight.de`
**Server-IP:** `46.224.122.105`

---

## 🗂️ Backup-Struktur

```
/srv/backups/
├── config/           # Konfigurationsdateien (in Git)
│   ├── mailcow/      # mailcow Konfiguration
│   ├── caddy/        # Caddy Reverse Proxy
│   ├── netdata/      # Netdata Monitoring
│   ├── system/       # System-Konfiguration
│   ├── ssh/          # SSH-Konfiguration
│   ├── firewall/     # Firewall-Regeln
│   └── docker/       # Docker-Inventar
├── data/             # Daten-Backups (NICHT in Git!)
│   └── YYYYMMDD_HHMMSS/
│       ├── mysql-all-databases.sql.gz
│       ├── redis-dump.rdb.gz
│       ├── vmail.tar.gz
│       └── dkim-keys.tar.gz
└── scripts/          # Backup-Scripts
    ├── backup-config.sh
    └── backup-data.sh
```

---

## 🔄 Automatische Backups

### Konfiguration-Backup (täglich)
- **Was:** Alle Konfigurationsdateien
- **Wohin:** Git Repository + lokaler Speicher
- **Zeitplan:** Täglich um 02:00 Uhr

### Daten-Backup (täglich)
- **Was:** Datenbanken, E-Mails, DKIM-Keys
- **Wohin:** Zweiter Hetzner-Server via rsync
- **Zeitplan:** Täglich um 03:00 Uhr
- **Aufbewahrung:**
  - Lokal: 7 Tage
  - Remote: 30 Tage

---

## 🆘 Disaster Recovery - Server komplett neu aufsetzen

### Phase 1: Neuen Server vorbereiten (30 Minuten)

#### 1.1 Hetzner Server bestellen
- Mindestens: CX32 (4 vCPU, 8 GB RAM)
- Ubuntu 22.04 LTS oder 24.04 LTS
- Gleiche IP konfigurieren (falls möglich) oder DNS anpassen

#### 1.2 Grundsystem einrichten
```bash
# Als root einloggen
ssh root@YOUR_NEW_SERVER_IP

# System aktualisieren
apt update && apt upgrade -y

# Wichtige Pakete installieren
apt install -y git curl wget htop rsync ufw \
    docker.io docker-compose-v2 \
    iptables-persistent

# Docker aktivieren
systemctl enable docker
systemctl start docker

# User anlegen (falls gewünscht)
# adduser wburger
# usermod -aG sudo,docker wburger
```

#### 1.3 Hostname und Basis-Konfiguration
```bash
# Hostname setzen
hostnamectl set-hostname mail.clocklight.de

# /etc/hosts anpassen
cat >> /etc/hosts <<EOF
127.0.0.1 mail.clocklight.de mail
46.224.122.105 mail.clocklight.de mail
EOF

# Timezone setzen
timedatectl set-timezone Europe/Berlin

# Swap erstellen (2 GB)
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

---

### Phase 2: Konfigurationen wiederherstellen (15 Minuten)

#### 2.1 Backup-Repository klonen
```bash
# SSH-Key vom Backup-Server holen (falls vorhanden)
# ODER neuen SSH-Key generieren und zu Git hinzufügen

cd /srv
git clone YOUR_GIT_REPOSITORY_URL backups

# ODER: Vom Backup-Server kopieren
rsync -avz root@BACKUP_SERVER:/backup/mail.clocklight.de/latest/ /srv/backups/
```

#### 2.2 Verzeichnisstruktur erstellen
```bash
mkdir -p /srv/{mailcow,caddy,netdata}
```

#### 2.3 mailcow wiederherstellen
```bash
# mailcow Repository klonen
cd /srv
git clone https://github.com/mailcow/mailcow-dockerized.git mailcow
cd mailcow

# Konfiguration wiederherstellen
cp /srv/backups/config/mailcow/mailcow.conf ./
cp /srv/backups/config/mailcow/docker-compose.yml ./
cp -r /srv/backups/config/mailcow/conf/* ./data/conf/

# WICHTIG: mailcow.conf anpassen falls neue IP!
nano mailcow.conf
# Prüfe: MAILCOW_HOSTNAME, IP-Adressen, etc.

# Images pullen und starten
docker compose pull
docker compose up -d
```

#### 2.4 Caddy wiederherstellen
```bash
cd /srv/caddy

# Konfiguration wiederherstellen
cp /srv/backups/config/caddy/Caddyfile ./
cp /srv/backups/config/caddy/docker-compose.yml ./
cp -r /srv/backups/config/caddy/sites ./
cp -r /srv/backups/config/caddy/snippets ./

# Verzeichnisse erstellen
mkdir -p data config

# Caddy starten
docker compose up -d
```

#### 2.5 Netdata wiederherstellen
```bash
cd /srv/netdata

# Konfiguration wiederherstellen
cp /srv/backups/config/netdata/docker-compose.yml ./

# Netdata starten
docker compose up -d
```

---

### Phase 3: Daten wiederherstellen (60-120 Minuten)

#### 3.1 Neuestes Backup vom Backup-Server holen
```bash
# Liste der verfügbaren Backups
ssh root@BACKUP_SERVER "ls -lt /backup/mail.clocklight.de/"

# Neuestes Backup kopieren (DATUM anpassen!)
BACKUP_DATE="20251221_030000"  # Anpassen!
rsync -avz --progress \
    root@BACKUP_SERVER:/backup/mail.clocklight.de/${BACKUP_DATE}/ \
    /srv/backups/data/${BACKUP_DATE}/
```

#### 3.2 Datenbank wiederherstellen
```bash
cd /srv/backups/data/${BACKUP_DATE}

# Backup entpacken
gunzip mysql-all-databases.sql.gz

# In mailcow importieren
cd /srv/mailcow
docker compose exec -T mysql-mailcow mysql -u root -p$(grep DBROOT mailcow.conf | cut -d= -f2) \
    < /srv/backups/data/${BACKUP_DATE}/mysql-all-databases.sql

echo "Datenbank wiederhergestellt!"
```

#### 3.3 Redis wiederherstellen
```bash
cd /srv/backups/data/${BACKUP_DATE}

# Backup entpacken
gunzip redis-dump.rdb.gz

# Redis Container stoppen
cd /srv/mailcow
docker compose stop redis-mailcow

# Dump-Datei kopieren
docker cp /srv/backups/data/${BACKUP_DATE}/redis-dump.rdb \
    mailcowdockerized-redis-mailcow-1:/data/dump.rdb

# Redis neu starten
docker compose start redis-mailcow

echo "Redis wiederhergestellt!"
```

#### 3.4 E-Mail-Daten wiederherstellen
```bash
cd /srv/backups/data/${BACKUP_DATE}

# Backup entpacken und wiederherstellen
tar -xzf vmail.tar.gz -C /srv/mailcow/data/

# Berechtigungen korrigieren
chown -R 5000:5000 /srv/mailcow/data/vmail/

echo "E-Mail-Daten wiederhergestellt!"
```

#### 3.5 DKIM-Keys wiederherstellen
```bash
cd /srv/backups/data/${BACKUP_DATE}

# DKIM-Keys entpacken
tar -xzf dkim-keys.tar.gz -C /srv/mailcow/data/

# Dovecot und Postfix neu starten
cd /srv/mailcow
docker compose restart dovecot-mailcow postfix-mailcow

echo "DKIM-Keys wiederhergestellt!"
```

---

### Phase 4: Firewall und Sicherheit (10 Minuten)

#### 4.1 Firewall wiederherstellen
```bash
# UFW aktivieren
ufw --force enable

# Wichtige Ports öffnen
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 25/tcp    # SMTP
ufw allow 465/tcp   # SMTPS
ufw allow 587/tcp   # Submission
ufw allow 143/tcp   # IMAP
ufw allow 993/tcp   # IMAPS
ufw allow 110/tcp   # POP3
ufw allow 995/tcp   # POP3S
ufw allow 4190/tcp  # Sieve

ufw reload
```

#### 4.2 SSH absichern
```bash
# SSH-Konfiguration aus Backup
cp /srv/backups/config/ssh/sshd_config /etc/ssh/sshd_config

# SSH neu starten
systemctl restart sshd

# WICHTIG: Teste SSH in neuem Terminal BEVOR du die Verbindung trennst!
```

---

### Phase 5: DNS und SSL-Zertifikate (30 Minuten)

#### 5.1 DNS-Einträge überprüfen
```bash
# Prüfe DNS-Auflösung
dig mail.clocklight.de A
dig clocklight.de MX
dig dkim._domainkey.clocklight.de TXT
dig _dmarc.clocklight.de TXT

# Sollte auf neue Server-IP zeigen!
```

#### 5.2 SSL-Zertifikate
```bash
# mailcow und Caddy sollten automatisch Let's Encrypt Zertifikate anfordern
# Logs prüfen:

cd /srv/mailcow
docker compose logs acme-mailcow | tail -50

cd /srv/caddy
docker compose logs caddy | tail -50

# Falls Probleme: mailcow neu starten
cd /srv/mailcow
docker compose restart
```

---

### Phase 6: Verifikation (15 Minuten)

#### 6.1 Dienste prüfen
```bash
# Alle Container laufen?
docker ps -a

# mailcow Status
cd /srv/mailcow
docker compose ps

# Caddy Status
cd /srv/caddy
docker compose ps

# Netdata Status
cd /srv/netdata
docker compose ps
```

#### 6.2 Mail-Test
```bash
# Test-E-Mail senden
echo "Test from restored server" | mail -s "Test" your-email@example.com

# Logs prüfen
cd /srv/mailcow
docker compose logs postfix-mailcow | tail -50
```

#### 6.3 Webmail-Test
- Öffne: https://mail.clocklight.de
- Logge dich ein
- Prüfe, ob E-Mails vorhanden sind

#### 6.4 DKIM/SPF/DMARC-Test
- Sende Test-Mail an: https://www.mail-tester.com
- Score sollte 9/10 oder 10/10 sein

---

## 📊 Monitoring nach Wiederherstellung

#### Netdata öffnen
- URL: https://netdata.clocklight.de
- Prüfe CPU, RAM, Disk

#### Wichtige Metriken
- Load Average sollte < 2.0 sein
- RAM-Nutzung sollte < 85% sein
- Disk-Nutzung sollte < 80% sein

---

## 🔧 Backup-Scripts konfigurieren

### SSH-Key für Backup-Server einrichten
```bash
# SSH-Key generieren (falls nicht vorhanden)
ssh-keygen -t ed25519 -C "backup@mail.clocklight.de"

# Public Key zum Backup-Server kopieren
ssh-copy-id root@167.235.19.185

# Verbindung testen
ssh root@167.235.19.185 "echo Connection successful"
```

### Backup-Script konfigurieren
```bash
nano /srv/backups/scripts/backup-data.sh

# Anpassen:
REMOTE_SERVER="167.235.19.185"
REMOTE_USER="root"
REMOTE_PATH="/backup/mail.clocklight.de"
```

### Cronjobs einrichten
```bash
# Crontab bearbeiten
crontab -e

# Folgendes hinzufügen:
0 2 * * * /srv/backups/scripts/backup-config.sh >> /var/log/backup-config.log 2>&1
0 3 * * * /srv/backups/scripts/backup-data.sh >> /var/log/backup-data.log 2>&1
```

---

## ✅ Checkliste nach Wiederherstellung

- [ ] Alle Docker-Container laufen
- [ ] mailcow Web-UI erreichbar (https://mail.clocklight.de)
- [ ] E-Mails können gesendet werden
- [ ] E-Mails können empfangen werden
- [ ] Webmail (SOGo) funktioniert
- [ ] IMAP/SMTP funktioniert (Thunderbird, etc.)
- [ ] DKIM-Signatur ist gültig (mail-tester.com)
- [ ] SSL-Zertifikate sind gültig
- [ ] Firewall ist aktiv
- [ ] Backup-Cronjobs sind eingerichtet
- [ ] Netdata Monitoring läuft
- [ ] DNS-Einträge sind korrekt

---

## 🆘 Troubleshooting

### Problem: Datenbank-Import schlägt fehl
```bash
# Prüfe ob MySQL läuft
docker compose ps mysql-mailcow

# Logs prüfen
docker compose logs mysql-mailcow

# MySQL neu starten
docker compose restart mysql-mailcow
```

### Problem: E-Mails werden nicht empfangen
```bash
# DNS MX-Record prüfen
dig clocklight.de MX

# Postfix-Logs prüfen
docker compose logs postfix-mailcow | tail -100

# Port 25 offen?
nc -zv mail.clocklight.de 25
```

### Problem: Let's Encrypt schlägt fehl
```bash
# Ports 80 und 443 offen?
ufw status

# ACME-Logs prüfen
docker compose logs acme-mailcow

# mailcow.conf prüfen
grep SKIP_LETS_ENCRYPT mailcow.conf
# Sollte 'n' sein!
```

---

## 📝 Wichtige Passwörter & Zugänge

**SICHER AUFBEWAHREN! NICHT IN GIT!**

- mailcow Admin: https://mail.clocklight.de/admin
  - User: `admin`
  - Passwort: [SEPARAT AUFBEWAHREN]

- MySQL Root Passwort: siehe `mailcow.conf` → `DBROOT`
- Redis Passwort: siehe `mailcow.conf` → `REDISPASS`

---

## 📞 Support & Kontakt

- mailcow Dokumentation: https://docs.mailcow.email
- Caddy Dokumentation: https://caddyserver.com/docs
- Bei Problemen: Check /var/log/ und Docker-Logs

---

**Erstellt am:** 2025-12-21
**Version:** 1.0
**Letzte Aktualisierung:** 2025-12-21
