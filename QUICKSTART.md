# Quick Start Guide - Backup System

## 🚀 Schnellstart

### Was wurde eingerichtet?

1. **Config-Backup** → Git Repository (`/srv/backups/config/`)
2. **Daten-Backup** → Zweiter Hetzner-Server
3. **Automatische Backups** → Täglich via Cronjob
4. **Wiederherstellungs-Anleitung** → README.md

---

## ✅ Nächste Schritte (WICHTIG!)

### 1. Backup-Server konfigurieren

```bash
# Öffne die Datei
nano /srv/backups/scripts/backup-data.sh

# Ändere diese Zeilen:
REMOTE_SERVER="DEINE_167.235.19.185"
REMOTE_USER="root"
REMOTE_PATH="/backup/mail.clocklight.de"
```

Siehe **BACKUP-SERVER-SETUP.md** für Details!

### 2. SSH-Key einrichten

```bash
# SSH-Key generieren (falls nicht vorhanden)
ssh-keygen -t ed25519 -C "backup@mail.clocklight.de"

# Public Key kopieren
cat ~/.ssh/id_ed25519.pub

# Zum Backup-Server hinzufügen
ssh-copy-id root@DEINE_167.235.19.185
```

### 3. Ersten Backup-Test durchführen

```bash
# Config-Backup testen
/srv/backups/scripts/backup-config.sh

# Daten-Backup testen (ERST NACH SSH-Setup!)
/srv/backups/scripts/backup-data.sh
```

### 4. Git Remote hinzufügen (Optional aber empfohlen!)

```bash
cd /srv/backups

# GitHub/GitLab Repository erstellen (privat!)
# Dann:
git remote add origin git@github.com:DEIN_USERNAME/mailcow-backups.git
git branch -M main
git push -u origin main
```

---

## 📊 Backup-Status überprüfen

### Letzter Config-Backup
```bash
cd /srv/backups
git log --oneline | head -5
ls -lh config/
```

### Letzter Daten-Backup (lokal)
```bash
ls -lth /srv/backups/data/ | head -5
```

### Letzter Daten-Backup (remote)
```bash
ssh root@167.235.19.185 "ls -lth /backup/mail.clocklight.de/ | head -5"
```

### Backup-Logs ansehen
```bash
# Config-Backup Log
tail -50 /var/log/backup-config.log

# Daten-Backup Log
tail -50 /var/log/backup-data.log
```

---

## 🔄 Manuellen Backup durchführen

```bash
# Config-Backup (schnell, ca. 5 Sekunden)
/srv/backups/scripts/backup-config.sh

# Daten-Backup (langsam, 5-30 Minuten je nach Datenmenge)
/srv/backups/scripts/backup-data.sh
```

---

## 🆘 Im Notfall (Server-Crash)

**1. README.md öffnen und Schritt-für-Schritt folgen:**
```bash
# Vom Backup-Server oder Git-Repository holen
cat /srv/backups/README.md
```

**2. Kurzversion:**
- Neuen Server aufsetzen (Ubuntu + Docker)
- Git-Repository oder Backup-Server-Daten kopieren
- Config wiederherstellen (`/srv/backups/config/`)
- Daten wiederherstellen (neuester Backup von Backup-Server)
- DNS prüfen und SSL neu generieren lassen

**Geschätzte Wiederherstellungszeit:** 2-3 Stunden

---

## 📅 Backup-Zeitplan

| Zeit  | Was                | Wohin               | Aufbewahrung |
|-------|--------------------|---------------------|--------------|
| 02:00 | Config-Backup      | Git (lokal)         | Unbegrenzt   |
| 03:00 | Daten-Backup       | Backup-Server       | 30 Tage      |
| -     | Lokale Daten-Kopie | /srv/backups/data/  | 7 Tage       |

---

## 🔒 Sicherheitshinweise

⚠️ **WICHTIG:**
- [ ] Backup-Server sollte in anderem Rechenzentrum stehen
- [ ] Git-Repository sollte PRIVAT sein
- [ ] SSH-Keys sicher aufbewahren
- [ ] Regelmäßig Wiederherstellung testen (alle 6 Monate)
- [ ] Passwörter NICHT in Git committen (.gitignore beachten!)

---

## 📞 Hilfe & Dokumentation

- **Vollständige Anleitung:** `README.md`
- **Backup-Server Setup:** `BACKUP-SERVER-SETUP.md`
- **Config-Backup-Script:** `scripts/backup-config.sh`
- **Daten-Backup-Script:** `scripts/backup-data.sh`

---

## ✨ Features

✅ Automatische tägliche Backups
✅ Git-Versionierung für Konfigurationen
✅ Remote-Backup auf zweiten Server
✅ Detaillierte Wiederherstellungsanleitung
✅ Backup-Inventar und Checksums
✅ Automatische Bereinigung alter Backups
✅ Logging aller Backup-Operationen

---

**Erstellt:** 2025-12-21
**Version:** 1.0
