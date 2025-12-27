# System-Übersicht: mail.clocklight.de

**Erstellt:** 27. Dezember 2025
**Status:** Produktiv & Voll funktionsfähig

---

## Infrastruktur-Architektur

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HAUPTSERVER: mail.clocklight.de                  │
│                         (Hetzner Server)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ MAILCOW (19 Docker Container)                                 │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │ • Postfix (SMTP)      • Dovecot (IMAP/POP3)                  │ │
│  │ • Rspamd (Spam)       • ClamAV (Virus)                       │ │
│  │ • SOGo (Webmail)      • MySQL/Redis                          │ │
│  │ • Nginx (Proxy)       • ACME (SSL)                           │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ MONITORING & ALERTING                                         │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │ • mailcow-monitor.sh     (alle 15 Min)                       │ │
│  │ • mailcow-daily-report.sh (täglich 2:00)                     │ │
│  │ • cleanup-zombies.sh     (alle 15 Min)                       │ │
│  │                                                               │ │
│  │ Alerts via:                                                   │ │
│  │   ✓ Telegram Bot      (Instant-Push)                         │ │
│  │   ✓ Gmail SMTP        (wolf.burger@gmail.com)                │ │
│  │   ✓ Log-Dateien       (Backup)                               │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ SECURITY                                                      │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │ • Fail2ban SSH-Schutz                                         │ │
│  │   - 5 Fehlversuche = 24h Ban                                 │ │
│  │   - Eskalierende Bans: 24h → 48h → 96h → 7d                  │ │
│  │   - Tracking im Daily Report                                 │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ BACKUP SYSTEM                                                 │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │ • backup-config.sh   (3:00 täglich)                          │ │
│  │ • backup-data.sh     (on-demand)                             │ │
│  │                                                               │ │
│  │ Lokale Backups: /srv/backups/                                │ │
│  │   ├── configs/       (Mailcow-Konfigurationen)               │ │
│  │   └── data/          (Mail-Daten, MySQL-Dumps)               │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ WEITERE SERVICES                                              │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │ • Caddy Webserver         (Reverse Proxy)                    │ │
│  │ • Beszel Hub              (https://beszel.clocklight.de)     │ │
│  │ • Beszel Agent            (System Monitoring)                │ │
│  │                                                               │ │
│  │ Deaktiviert (Ressourcen-Optimierung):                        │ │
│  │ • Netdata Monitoring                                          │ │
│  │ • Umami Analytics + PostgreSQL                                │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ SSH-Key basiert
                                │ rsync über Port 22
                                │ User: backup-mailweb
                                │ Schedule: täglich
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│               BACKUP-SERVER: 167.235.19.185                         │
│                      (Hetzner Dedicated)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ REMOTE BACKUP STORAGE                                         │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │ • Dedizierter User: backup-mailweb                            │ │
│  │ • Backup-Pfad: /backup/mail.clocklight.de/                    │ │
│  │ • Berechtigungen: 700 (nur User)                              │ │
│  │ • Authentifizierung: SSH-Key (kein Passwort)                  │ │
│  │ • Optional: Command-Restriction (nur rsync)                   │ │
│  │                                                               │ │
│  │ Empfängt:                                                     │ │
│  │   ├── Mailcow-Konfigurationen                                │ │
│  │   ├── Mail-Daten (vmail)                                     │ │
│  │   └── MySQL-Datenbank-Dumps                                  │ │
│  │                                                               │ │
│  │ Retention:                                                    │ │
│  │   • Tägliche Backups bleiben 30 Tage                         │ │
│  │   • Automatische Bereinigung via Cronjob                     │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                     EXTERNE DIENSTE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  📱 TELEGRAM                                                        │
│     • Bot: clocklight.uptimekuma_bot                               │
│     • Chat-ID: 1272486023                                          │
│     • Funktion: Instant-Alerts bei kritischen Problemen            │
│                                                                     │
│  📧 GMAIL SMTP                                                      │
│     • Server: smtp.gmail.com:587                                   │
│     • Von: claudia.steinhage@gmail.com                             │
│     • An: wolf.burger@gmail.com                                    │
│     • Funktion: Email-Alerts + Daily Reports                       │
│     • Credentials: /root/.mailcow-alert-credentials (600)          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Wichtige Zeitpläne (Cronjobs)

| Zeit | Skript | Funktion |
|------|--------|----------|
| **03:00** täglich | `/srv/mailu/backup.sh` | Mailu-Backup (alt?) |
| **02:00** täglich | `/usr/local/bin/mailcow-daily-report.sh` | Täglicher Status-Report per Email |
| ***/15** Minuten | `/usr/local/bin/cleanup-zombies.sh` | Zombie-Prozesse aufräumen |
| ***/15** Minuten | `/usr/local/bin/mailcow-monitor.sh` | System-Monitoring & Checks |

---

## Monitoring-Übersicht

### Was wird überwacht?

#### System-Ressourcen
- ✅ **CPU-Auslastung** (Warnung: 80%, Kritisch: 90%)
- ✅ **RAM-Auslastung** (Warnung: 80%, Kritisch: 90%)
- ✅ **System Load/Core** (Info: 100%, Kritisch: 170%)
- ✅ **Festplatte (vmail)** (Warnung: 80%, Kritisch: 90%)

#### Mail-Services
- ✅ **19 Docker Container** (Status-Check)
- ✅ **Mail-Queue** (Warnung: >10, Kritisch: >50 Emails)
- ✅ **SMTP-Ports** (25, 587, 465)
- ✅ **IMAP-Ports** (143, 993)
- ✅ **POP3-Ports** (110, 995)
- ✅ **Webmail-Zugriff** (HTTPS auf Port 8443)
- ✅ **Dovecot-Logs** (Fehler-Erkennung)
- ✅ **vmail-Verzeichnis** (Berechtigungen & Ownership)

#### Security
- ✅ **SSH-Angriffe** (Failed Password, Invalid User)
- ✅ **Fail2ban Bans** (24h & aktuell geblockt)

### Wann werde ich benachrichtigt?

#### Instant-Alerts (bei Problemen)
- 📱 **Telegram-Push** (sofort)
- 📧 **Gmail-Alert** (sofort)
- 📝 **Log-Eintrag** (immer)

**Frequency:** Maximal 1 Alert pro Stunde (verhindert Spam)

#### Täglicher Report (auch bei Status OK)
- 📧 **Email an wolf.burger@gmail.com**
- 🕐 **Täglich um 2:00 Uhr**
- 📊 Umfassende 24h-Statistik:
  - System-Übersicht
  - Service-Status
  - Fehler-Zusammenfassung
  - Security-Statistiken
  - Handlungsempfehlungen

---

## Log-Dateien

### Monitoring
| Datei | Inhalt |
|-------|--------|
| `/var/log/mailcow-monitor.log` | Alle Monitoring-Läufe (Erfolge + Fehler) |
| `/var/log/mailcow-monitor-errors.log` | **Nur Fehler** (schnelle Diagnose) |
| `/var/log/mailcow-critical-alerts.log` | Versendete Alerts (Telegram + Email) |
| `/var/log/mailcow-daily-report.log` | Daily Report Versand-Log |
| `/var/run/mailcow-last-alert` | Timestamp des letzten Alerts |

### Backups
| Datei | Inhalt |
|-------|--------|
| `/var/log/backup-config.log` | Config-Backup-Log |
| `/var/log/backup-data.log` | Data-Backup-Log |

---

## Backup-Strategie

### 1. Lokale Backups (auf Hauptserver)

**Speicherort:** `/srv/backups/`

```
/srv/backups/
├── configs/           # Mailcow-Konfigurationen
│   └── YYYY-MM-DD/
├── data/              # Mail-Daten & MySQL-Dumps
│   └── YYYY-MM-DD/
└── scripts/
    ├── backup-config.sh
    └── backup-data.sh
```

**Schedule:**
- Config-Backup: Täglich 3:00 Uhr
- Data-Backup: On-demand oder manuell

### 2. Remote Backup (auf Backup-Server)

**Server:** 167.235.19.185
**User:** backup-mailweb
**Pfad:** `/backup/mail.clocklight.de/`

**Übertragung:**
- Via `rsync` über SSH
- SSH-Key-basiert (kein Passwort)
- Key: `/root/.ssh/backup_key`

**Retention:**
- Backups bleiben 30 Tage
- Automatische Bereinigung älterer Backups

**Sicherheit:**
- Dedizierter User (nicht root)
- Eingeschränkte Berechtigungen (700)
- Optional: Command-Restriction (nur rsync)
- SSH-Key statt Passwort

---

## Security-Features

### Fail2ban SSH-Schutz

**Status:** ✅ AKTIV seit 25. Dezember 2025

#### Konfiguration
- **Jail:** `sshd`
- **Max. Versuche:** 5 fehlgeschlagene Logins
- **Zeitfenster:** 10 Minuten
- **Ban-Dauer (initial):** 24 Stunden

#### Ban-Eskalation
| Verstoß | Ban-Dauer |
|---------|-----------|
| 1. Mal | 24 Stunden |
| 2. Mal | 48 Stunden |
| 3. Mal | 96 Stunden (4 Tage) |
| 4. Mal | 168 Stunden (7 Tage) |

#### Kommandos
```bash
# Status prüfen
fail2ban-client status sshd

# Gebannte IPs anzeigen
fail2ban-client status sshd | grep "Banned IP"

# IP manuell entbannen
fail2ban-client set sshd unbanip 1.2.3.4
```

**Dokumentation:** `/srv/FAIL2BAN-SETUP.md`

---

## Wichtige Dateien & Pfade

### Monitoring
- `/usr/local/bin/mailcow-monitor.sh` - Haupt-Monitoring
- `/usr/local/bin/mailcow-alert-v2.sh` - Alert-System
- `/usr/local/bin/mailcow-daily-report.sh` - Daily Report
- `/usr/local/bin/cleanup-zombies.sh` - Zombie-Cleanup

### Backups
- `/srv/backups/scripts/backup-config.sh` - Config-Backup
- `/srv/backups/scripts/backup-data.sh` - Data-Backup
- `/root/.ssh/backup_key` - SSH-Key für Backup-Server

### Credentials
- `/root/.mailcow-alert-credentials` - Gmail SMTP-Passwort (600)

### Mailcow
- `/srv/mailcow/` - Mailcow-Installation
- `/srv/mailcow/mailcow.conf` - Haupt-Konfiguration
- `/var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data/` - Mail-Daten

### Konfigurationen (Repository)
- `/srv/config/` - Gesicherte Konfigurationen
- `/srv/config/fail2ban/` - Fail2ban Config
- `/srv/config/caddy/` - Caddy Config

---

## Nützliche Befehle

### System-Status
```bash
# Schneller Überblick
uptime                  # Load Average
free -h                 # RAM-Nutzung
df -h                   # Festplatte

# Container-Status
docker ps               # Laufende Container
docker stats            # Echtzeit-Ressourcen

# Monitoring-Status
tail -30 /var/log/mailcow-monitor.log
grep ERROR /var/log/mailcow-monitor-errors.log
```

### Manuelles Monitoring
```bash
# Sofort-Check
/usr/local/bin/mailcow-monitor.sh

# Test-Alert senden
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: TEST" >> /var/log/mailcow-monitor-errors.log
/usr/local/bin/mailcow-alert-v2.sh

# Daily Report manuell
/usr/local/bin/mailcow-daily-report.sh
```

### Backup
```bash
# Config-Backup manuell
/srv/backups/scripts/backup-config.sh

# Data-Backup manuell
/srv/backups/scripts/backup-data.sh

# Remote-Backup Status prüfen
ssh -i /root/.ssh/backup_key backup-mailweb@167.235.19.185 "ls -lh /backup/mail.clocklight.de/"
```

---

## Beszel Monitoring

**Status:** ✅ AKTIV seit 27. Dezember 2025
**URL:** https://beszel.clocklight.de

### Was ist Beszel?

Beszel ist ein leichtgewichtiges Server-Monitoring-Tool, das als Ersatz für Netdata eingesetzt wird. Es besteht aus zwei Komponenten:
- **Beszel Hub:** Web-Interface für die Übersicht aller Systeme
- **Beszel Agent:** Sammelt Metriken vom Host-System

### Vorteile gegenüber Netdata
- ⚡ **Deutlich weniger Ressourcen** (~20 MB RAM vs. 330 MB)
- 🔒 **Eingebaute Authentifizierung** (kein separater Reverse Proxy nötig)
- 📊 **Moderne Web-UI** mit Echtzeit-Graphen
- 🐳 **Docker-Container-Monitoring** integriert
- 🔑 **SSH-Key basierte Agent-Authentifizierung**

### Installation & Konfiguration

#### 1. Docker Compose Setup
```yaml
# /srv/beszel/docker-compose.yml
services:
  beszel:
    image: 'henrygd/beszel'
    container_name: 'beszel'
    restart: unless-stopped
    ports:
      - '8090:8090'
    volumes:
      - ./beszel_data:/beszel_data
    networks:
      - web-services

  beszel-agent:
    image: 'henrygd/beszel-agent'
    container_name: 'beszel-agent'
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      PORT: 45876
      KEY: '<SSH-PUBLIC-KEY>'
      FILESYSTEM: /dev/sda1
```

#### 2. Caddy Reverse Proxy
```
# /srv/config/caddy/sites/beszel.clocklight.de.caddy
beszel.clocklight.de {
    reverse_proxy beszel:8090
    import ../snippets/compression.caddy

    log {
        output file /var/log/caddy/beszel.clocklight.de.log
    }
}
```

#### 3. Ersteinrichtung
1. Services starten: `docker compose up -d`
2. Web-Interface öffnen: https://beszel.clocklight.de
3. Admin-Account erstellen
4. System hinzufügen:
   - **Name:** mail.clocklight.de
   - **Host:** host.docker.internal
   - **Port:** 45876
   - **SSH Public Key:** Aus Beszel-Hub kopieren

### Überwachte Metriken
- ✅ **CPU-Auslastung** (Gesamt & per Core)
- ✅ **RAM-Nutzung** (Used/Free/Available)
- ✅ **Festplatten-Nutzung** (Alle Mountpoints)
- ✅ **Netzwerk-Traffic** (Bandwidth In/Out)
- ✅ **System Load** (1/5/15 Minuten)
- ✅ **Temperatur** (CPU & Disks, falls verfügbar)
- ✅ **Docker Container** (Status & Ressourcen)
- ✅ **Prozesse** (Top CPU/RAM Verbraucher)

### Datenspeicherung
- **Lokation:** `/srv/beszel/beszel_data/`
- **Inhalt:** SQLite-Datenbank mit historischen Metriken
- **Retention:** Konfigurierbar (Standard: 30 Tage)
- **Backup:** Wird in `/srv/backups/config/beszel/` gesichert

### Zugriff
```bash
# Webinterface
https://beszel.clocklight.de

# Container-Logs
docker logs beszel
docker logs beszel-agent

# Datenverzeichnis
ls -lh /srv/beszel/beszel_data/
```

### Ressourcen-Verbrauch
- **Beszel Hub:** ~15-20 MB RAM
- **Beszel Agent:** ~5-10 MB RAM
- **Gesamt:** ~25-30 MB (vs. Netdata: 330 MB)
- **CPU:** <1% im Idle

---

## Ressourcen-Optimierung (25.12.2025)

### Deaktivierte Services
Um Ressourcen zu sparen, wurden folgende Services deaktiviert:

- ❌ **Netdata Monitoring** (~330 MB RAM + 8% CPU gespart)
- ❌ **Umami Analytics** (~200 MB RAM gespart)

### Ergebnisse
- **Load Average:** 0,15 (vorher: 2,99!)
- **CPU:** 33% (vorher: 86%)
- **Freier RAM:** 766 MB (vorher: 190 MB)

**Dokumentation:** `/srv/SERVER-OPTIMIZATION.md`

---

## Zugriff & Verwaltung

### Hauptserver (mail.clocklight.de)
```bash
ssh root@mail.clocklight.de
```

### Backup-Server
```bash
# Als root
ssh root@167.235.19.185

# Als backup-user (mit Key)
ssh -i /root/.ssh/backup_key backup-mailweb@167.235.19.185
```

### Mailcow Webinterface
```
https://mail.clocklight.de:8443
```

### Beszel Monitoring
```
https://beszel.clocklight.de
```

---

## Weitere Dokumentation

Detaillierte Dokumentation zu einzelnen Themen:

- **Monitoring:** `/srv/MAILCOW-MONITORING.md`
- **Backup-Setup:** `/srv/BACKUP-SERVER-SETUP-SECURE.md`
- **Fail2ban:** `/srv/FAIL2BAN-SETUP.md`
- **Server-Optimierung:** `/srv/SERVER-OPTIMIZATION.md`
- **Quickstart:** `/srv/QUICKSTART.md`
- **README:** `/srv/README.md`

---

## Status & Changelog

### Aktueller Status (27.12.2025)

✅ **VOLL FUNKTIONSFÄHIG**

- Mailcow läuft stabil (19 Container)
- Monitoring alle 15 Minuten aktiv
- Alerts via Telegram + Gmail funktionieren
- Daily Reports werden versendet
- Fail2ban schützt vor SSH-Angriffen
- Remote-Backup konfiguriert

### Letzte Änderungen

**27.12.2025:** System-Übersicht erstellt
**25.12.2025:** Fail2ban aktiviert, Telegram-Alerts, Daily Reports
**25.12.2025:** Netdata & Umami deaktiviert (Ressourcen-Optimierung)
**24.12.2025:** Monitoring-System installiert
**23.12.2025:** Remote-Backup-Server eingerichtet
**21.12.2025:** Mailcow-Installation

---

## Support & Troubleshooting

Bei Problemen:

1. **Logs prüfen:**
   ```bash
   tail -50 /var/log/mailcow-monitor.log
   grep ERROR /var/log/mailcow-monitor-errors.log
   ```

2. **Container-Status:**
   ```bash
   docker ps -a
   docker logs <container-name>
   ```

3. **Manueller Check:**
   ```bash
   /usr/local/bin/mailcow-monitor.sh
   ```

4. **Service neu starten:**
   ```bash
   cd /srv/mailcow
   docker compose restart <service>
   ```

---

**Erstellt:** 27. Dezember 2025
**Letztes Update:** 27. Dezember 2025
**Maintainer:** Claude Code
**Server:** mail.clocklight.de (Hetzner)
