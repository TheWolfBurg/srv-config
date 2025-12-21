# 🚀 Backup-Setup Cheat Sheet (Sichere Variante)

## Schritt-für-Schritt: 5 Minuten Setup

### 1️⃣ Auf dem BACKUP-SERVER

```bash
# Als root einloggen
ssh root@167.235.19.185

# User anlegen
useradd -m -s /bin/bash backup-mailweb

# Verzeichnis erstellen
mkdir -p /backup/mail.clocklight.de
chown backup-mailweb:backup-mailweb /backup/mail.clocklight.de
chmod 700 /backup/mail.clocklight.de

# SSH vorbereiten
mkdir -p /home/backup-mailweb/.ssh
chmod 700 /home/backup-mailweb/.ssh
touch /home/backup-mailweb/.ssh/authorized_keys
chmod 600 /home/backup-mailweb/.ssh/authorized_keys
chown -R backup-mailweb:backup-mailweb /home/backup-mailweb/.ssh
```

---

### 2️⃣ Auf dem HAUPTSERVER (mail.clocklight.de)

```bash
# SSH-Key generieren
ssh-keygen -t ed25519 -C "backup@mail.clocklight.de" -f /root/.ssh/backup_key

# Public Key anzeigen (kopieren!)
cat /root/.ssh/backup_key.pub
```

---

### 3️⃣ Zurück auf BACKUP-SERVER

```bash
# Public Key einfügen
nano /home/backup-mailweb/.ssh/authorized_keys
# → Public Key vom Hauptserver einfügen
# → Speichern: Strg+O, Enter, Strg+X
```

---

### 4️⃣ Auf HAUPTSERVER: Testen

```bash
# Verbindung testen
ssh -i /root/.ssh/backup_key backup-mailweb@167.235.19.185 "ls -la /backup/"
# ✅ Sollte das Verzeichnis anzeigen

# Script konfigurieren
nano /srv/backups/scripts/backup-data.sh
# Ändere nur diese Zeile:
# REMOTE_SERVER="DEINE_167.235.19.185"  # z.B. "95.217.123.45"
```

---

### 5️⃣ Ersten Backup durchführen

```bash
# Daten-Backup starten
/srv/backups/scripts/backup-data.sh

# Prüfen ob angekommen
ssh -i /root/.ssh/backup_key backup-mailweb@167.235.19.185 \
    "ls -lh /backup/mail.clocklight.de/"
```

---

## ✅ Fertig!

Automatische Backups laufen jetzt täglich:
- **02:00 Uhr:** Config → Git
- **03:00 Uhr:** Daten → Backup-Server

---

## 🔧 Häufige Probleme

### Permission denied
```bash
# Auf Backup-Server prüfen:
ls -la /home/backup-mailweb/.ssh/authorized_keys
# Sollte: -rw------- backup-mailweb:backup-mailweb

# Falls falsch:
chmod 600 /home/backup-mailweb/.ssh/authorized_keys
chown backup-mailweb:backup-mailweb /home/backup-mailweb/.ssh/authorized_keys
```

### SSH-Key nicht gefunden
```bash
# Auf Hauptserver:
ls -la /root/.ssh/backup_key*
# Sollte existieren

# Falls nicht:
ssh-keygen -t ed25519 -C "backup@mail.clocklight.de" -f /root/.ssh/backup_key
```

---

## 📖 Ausführliche Anleitungen

- **Vollständige Anleitung:** `BACKUP-SERVER-SETUP-SECURE.md`
- **Wiederherstellung:** `README.md`
- **Schnellstart:** `QUICKSTART.md`

---

**Tipp:** Diese Datei ausdrucken und griffbereit halten! 📋
