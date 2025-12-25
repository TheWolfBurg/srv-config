# Mailcow Monitoring System

Automatisches Überwachungssystem für deine Mailcow-Installation auf mail.clocklight.de

## Installation

Das System wurde vollständig installiert und konfiguriert am **24. Dezember 2025**.
Letzte Aktualisierung: **25. Dezember 2025** (Alert-System V2 mit Gmail-SMTP)

## Komponenten

### 1. Monitoring-Skript: `/usr/local/bin/mailcow-monitor.sh`

Führt alle 10 Minuten automatisch folgende Checks durch:

#### Überprüfte Komponenten:
- ✅ **vmail-Verzeichnis** - Existenz, Berechtigungen (2755), Owner (5000:5000)
- ✅ **Docker Container** - Status aller kritischen Container:
  - mailcowdockerized-dovecot-mailcow-1
  - mailcowdockerized-postfix-mailcow-1
  - mailcowdockerized-nginx-mailcow-1
  - mailcowdockerized-mysql-mailcow-1
  - mailcowdockerized-redis-mailcow-1
  - mailcowdockerized-sogo-mailcow-1
  - mailcowdockerized-php-fpm-mailcow-1
- ✅ **Netzwerk-Ports** - SMTP (25, 587, 465), IMAP (143, 993), POP3 (110, 995)
- ✅ **SMTP-Service** - Erreichbarkeit und Antwort
- ✅ **Webmail** - HTTPS-Zugriff auf die Weboberfläche (Port 8443)
- ✅ **Dovecot-Logs** - Kritische Fehler in den letzten 5 Minuten
- ✅ **Mail-Queue** - Anzahl wartender Emails
- ✅ **Festplattenspeicher** - Verwendung der vmail-Partition
- ✅ **CPU-Auslastung** - Prozessorauslastung (Warnung ab 80%, Fehler ab 90%)
- ✅ **RAM-Auslastung** - Speicherverbrauch (Warnung ab 80%, Fehler ab 90%)
- ✅ **System Load Average** - Systemlast pro Core (Info ab 100%, Fehler ab 170%)

### 2. Alert-Skript V2: `/usr/local/bin/mailcow-alert-v2.sh`

**Mehrkanal-Benachrichtigungssystem** mit automatischer Fallback-Logik.

#### Konfigurierte Benachrichtigungskanäle:

**🔴 Primär: Telegram Bot**
- ✅ **AKTIV** - Instant-Benachrichtigungen auf dein Handy
- Bot: `clocklight.uptimekuma_bot`
- Chat-ID: `1272486023`

**🟠 Sekundär: Externe SMTP (Gmail)**
- ✅ **AKTIV** - Sendet Alerts an: `wolf.burger@gmail.com`
- SMTP-Server: `smtp.gmail.com:587`
- Absender: `claudia.steinhage@gmail.com`
- Authentifizierung: App-Passwort in `/root/.mailcow-alert-credentials`

**⚪ Tertiär: Lokale Email**
- Versucht lokalen Mailserver zu nutzen
- Fallback zu externen Kanälen falls lokal fehlschlägt

**⚫ Optional: Weitere Kanäle (aktuell deaktiviert)**
- Webhook (Slack, Discord, etc.)
- Log-Datei (immer aktiv als Backup)

#### Gmail SMTP Konfiguration

Die Credentials sind sicher in einer separaten Datei gespeichert:

```bash
# Credentials-Datei
/root/.mailcow-alert-credentials

# Inhalt (nur lesbar für root):
EXTERNAL_SMTP_PASSWORD="dein-gmail-app-passwort"
```

**Wichtig:** Diese Datei ist mit `chmod 600` geschützt (nur root kann lesen).

#### Features:
- ✅ **Telegram:** Instant-Push-Benachrichtigungen auf dein Handy
- ✅ **Email:** Zusätzlich via Gmail an wolf.burger@gmail.com
- ✅ Sendet maximal 1 Alert pro Stunde (verhindert Spam)
- ✅ Enthält Details zu den letzten 20 Fehlern
- ✅ Gibt konkrete Handlungsempfehlungen
- ✅ Funktioniert auch wenn lokaler Mailserver down ist
- ✅ Mehrere Benachrichtigungswege für maximale Redundanz

### 3. Daily Status Report: `/usr/local/bin/mailcow-daily-report.sh`

Sendet täglich um 2:00 Uhr einen umfassenden Status-Report per Email.

**Inhalt des Reports:**
- 📊 System-Übersicht (Uptime, CPU, RAM, Disk)
- 📬 Mail-Dienste Status (Container, Queue)
- 📈 Monitoring-Statistik (Fehler der letzten 24h)
- 🛡️ **Security-Statistik (SSH-Angriffe, Fail2ban Bans)**
- 🔍 Detaillierter Service-Status
- 🚨 Letzte Fehler (falls vorhanden)

**Features:**
- ✅ Täglicher Report um 2:00 Uhr
- ✅ Sendet an: `wolf.burger@gmail.com`
- ✅ Automatisches Status-Icon (✅/⚠️/🚨) je nach Zustand
- ✅ Übersichtliche Statistiken der letzten 24 Stunden
- ✅ **Security-Übersicht: SSH-Angriffe & Fail2ban Bans**
- ✅ Handlungsempfehlungen bei Problemen

### 4. Cronjobs

Automatische Ausführungen:

```bash
# Monitoring alle 10 Minuten
*/10 * * * * /usr/local/bin/mailcow-monitor.sh >/dev/null 2>&1

# Daily Report um 2:00 Uhr nachts
0 2 * * * /usr/local/bin/mailcow-daily-report.sh >/dev/null 2>&1
```

Prüfen mit:
```bash
crontab -l | grep mailcow
```

## Log-Dateien

### Haupt-Logfile: `/var/log/mailcow-monitor.log`
Enthält alle Monitoring-Ergebnisse (Erfolge und Fehler)

```bash
# Letzten Check anzeigen
tail -30 /var/log/mailcow-monitor.log

# Logs live verfolgen
tail -f /var/log/mailcow-monitor.log

# Nur Fehler anzeigen
grep ERROR /var/log/mailcow-monitor.log

# Zusammenfassungen der letzten Läufe
grep "Alle Checks erfolgreich\|Fehler gefunden" /var/log/mailcow-monitor.log | tail -10
```

### Fehler-Logfile: `/var/log/mailcow-monitor-errors.log`
Enthält **nur** Fehler für schnelle Diagnose

```bash
# Alle Fehler anzeigen
cat /var/log/mailcow-monitor-errors.log

# Letzte Fehler
tail -20 /var/log/mailcow-monitor-errors.log
```

### Alert-Logfile: `/var/log/mailcow-critical-alerts.log`
Protokolliert alle versendeten Alerts und deren Status

```bash
# Letzte Alerts anzeigen
tail -50 /var/log/mailcow-critical-alerts.log

# Prüfen ob Alerts erfolgreich versendet wurden
grep "erfolgreich versendet\|via externem SMTP" /var/log/mailcow-critical-alerts.log
```

### Daily Report Logfile: `/var/log/mailcow-daily-report.log`
Protokolliert die täglichen Status-Reports

```bash
# Report-Log anzeigen
tail -20 /var/log/mailcow-daily-report.log

# Prüfen wann letzter Report gesendet wurde
tail -1 /var/log/mailcow-daily-report.log
```

## Manueller Check

Du kannst jederzeit einen manuellen Check durchführen:

```bash
# Monitoring ausführen
/usr/local/bin/mailcow-monitor.sh

# Test-Alert senden (nur wenn Fehler im Error-Log vorhanden)
/usr/local/bin/mailcow-alert-v2.sh

# Daily Report manuell senden
/usr/local/bin/mailcow-daily-report.sh
```

## Wartung

### Gmail App-Passwort ändern

Falls du das Gmail-Passwort ändern musst:

```bash
# Credentials-Datei bearbeiten
nano /root/.mailcow-alert-credentials

# Inhalt anpassen:
EXTERNAL_SMTP_PASSWORD="neues-app-passwort"

# Berechtigungen prüfen (sollte 600 sein)
chmod 600 /root/.mailcow-alert-credentials
```

### Alert-Empfänger ändern

```bash
# Alert-Skript bearbeiten
nano /usr/local/bin/mailcow-alert-v2.sh

# Zeile 23 anpassen:
EXTERNAL_ALERT_EMAIL="neue-email@example.com"
```

### Log-Rotation

Die Logs können mit der Zeit groß werden. Empfohlene Log-Rotation:

```bash
# Erstelle Log-Rotation Konfiguration
cat > /etc/logrotate.d/mailcow-monitor <<'EOF'
/var/log/mailcow-monitor.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}

/var/log/mailcow-monitor-errors.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
}

/var/log/mailcow-critical-alerts.log {
    weekly
    rotate 12
    compress
    missingok
    notifempty
}
EOF
```

## Fehlerbehebung

### Monitoring läuft nicht

```bash
# Prüfe Cronjob
crontab -l | grep mailcow-monitor

# Prüfe Skript-Berechtigungen
ls -la /usr/local/bin/mailcow-monitor.sh
# Sollte: -rwx--x--x sein

# Manuell ausführen um Fehler zu sehen
/usr/local/bin/mailcow-monitor.sh
```

### Keine Email-Alerts

```bash
# Teste Alert-Skript manuell (zuerst Test-Fehler erstellen)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: TEST" >> /var/log/mailcow-monitor-errors.log
/usr/local/bin/mailcow-alert-v2.sh

# Prüfe Alert-Log
tail -30 /var/log/mailcow-critical-alerts.log

# Prüfe Gmail-Credentials
cat /root/.mailcow-alert-credentials

# Prüfe ob curl verfügbar ist (für SMTP)
which curl

# Test Gmail-SMTP direkt
curl --url "smtp://smtp.gmail.com:587" \
     --ssl-reqd \
     --mail-from "claudia.steinhage@gmail.com" \
     --mail-rcpt "wolf.burger@gmail.com" \
     --user "claudia.steinhage@gmail.com:$(grep EXTERNAL_SMTP_PASSWORD /root/.mailcow-alert-credentials | cut -d'"' -f2)" \
     -T - <<EOF
From: Test <claudia.steinhage@gmail.com>
To: wolf.burger@gmail.com
Subject: Test

Dies ist ein Test.
EOF
```

### Zu viele Alerts

Erhöhe die Alert-Frequenz in `/usr/local/bin/mailcow-alert-v2.sh`:

```bash
nano /usr/local/bin/mailcow-alert-v2.sh

# Zeile ~63: Ändere von 3600 (1 Stunde) auf z.B. 7200 (2 Stunden)
if [ $TIME_DIFF -lt 7200 ]; then
```

### Gmail-SMTP funktioniert nicht

**Häufige Ursachen:**

1. **App-Passwort falsch oder abgelaufen**
   - Erstelle neues App-Passwort in Google-Konto
   - Aktualisiere `/root/.mailcow-alert-credentials`

2. **2-Faktor-Authentifizierung nicht aktiviert**
   - Gmail benötigt 2FA für App-Passwörter
   - Aktiviere in Google-Konto-Einstellungen

3. **"Weniger sichere Apps" blockiert**
   - Nutze App-Passwörter statt normalem Passwort

## Überwachte Schwellwerte

| Komponente | Info | Warnung | Kritisch | Aktion |
|------------|------|---------|----------|--------|
| Mail-Queue | < 10 | 10-50 Emails | > 50 Emails | Alert |
| Festplatte (vmail) | < 80% | 80-90% | > 90% | Alert |
| CPU-Auslastung | < 80% | 80-90% | > 90% | Alert |
| RAM-Auslastung | < 80% | 80-90% | > 90% | Alert |
| System Load/Core | < 100% | 100-170% | > 170% | Alert |
| Dovecot-Fehler | 0 | - | > 0 in 5 Min | Alert |
| Container | Running | - | Not running | Alert |
| Ports | Open | - | Closed | Alert |
| vmail-Verzeichnis | 2755, 5000:5000 | - | Falsch | Alert |

## Erweiterte Konfiguration

### Weitere Benachrichtigungskanäle aktivieren

#### Telegram Bot

```bash
nano /usr/local/bin/mailcow-alert-v2.sh

# Aktiviere Telegram (Zeile ~30):
USE_TELEGRAM=true
TELEGRAM_BOT_TOKEN="dein-bot-token"
TELEGRAM_CHAT_ID="deine-chat-id"
```

#### Webhook (Slack, Discord, etc.)

```bash
nano /usr/local/bin/mailcow-alert-v2.sh

# Aktiviere Webhook (Zeile ~26):
USE_WEBHOOK=true
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Weitere Checks hinzufügen

Bearbeite `/usr/local/bin/mailcow-monitor.sh` und füge neue Funktionen hinzu.

Beispiel für einen neuen Check:

```bash
check_custom_service() {
    if systemctl is-active --quiet my-service; then
        log_success "Custom Service läuft"
    else
        log_error "Custom Service ist down!"
    fi
}

# In main() Funktion hinzufügen:
# check_custom_service
```

### Monitoring-Intervall ändern

```bash
# Cronjob bearbeiten
crontab -e

# Beispiele:
# */5 * * * *   - Alle 5 Minuten
# */15 * * * *  - Alle 15 Minuten
# */30 * * * *  - Alle 30 Minuten
# 0 * * * *     - Jede Stunde
```

## Status-Übersicht

Schnellübersicht über den aktuellen Status:

```bash
# Zeige letzten Monitoring-Durchlauf
tail -35 /var/log/mailcow-monitor.log | grep -A 30 "=== Mailcow Monitoring"

# Zähle Fehler heute
grep "$(date '+%Y-%m-%d')" /var/log/mailcow-monitor-errors.log | wc -l

# Zeige nur Zusammenfassungen der letzten 10 Läufe
grep "Alle Checks erfolgreich\|Fehler gefunden" /var/log/mailcow-monitor.log | tail -10

# Letzter Alert
ls -lh /var/run/mailcow-last-alert 2>/dev/null && \
  echo "Letzter Alert: $(stat -c '%y' /var/run/mailcow-last-alert)"
```

## Changelog

### Version 2.4 - 25. Dezember 2025
- ✅ **NEU:** Security-Statistiken im Daily Report
- ✅ **NEU:** SSH-Angriffsstatistiken (Failed Password, Invalid User)
- ✅ **NEU:** Fail2ban Ban-Statistiken (24h & aktuell geblockt)
- ✅ System Load Threshold angepasst: 150% → 170%

### Version 2.3 - 25. Dezember 2025
- ✅ **NEU:** Telegram-Benachrichtigungen aktiviert
- ✅ **NEU:** Instant-Push-Nachrichten bei Problemen
- ✅ Alerts jetzt über 3 Kanäle: Telegram + Gmail + Log

### Version 2.2 - 25. Dezember 2025
- ✅ **NEU:** Täglicher Status-Report um 2:00 Uhr nachts
- ✅ **NEU:** Umfassende 24h-Statistiken (Fehler, Alerts, Services)
- ✅ **NEU:** Automatisches Status-Icon basierend auf Fehlerzahl
- ✅ **NEU:** Handlungsempfehlungen im Daily Report

### Version 2.1 - 25. Dezember 2025
- ✅ **NEU:** CPU-Auslastung Monitoring (Warnung ab 80%, Fehler ab 90%)
- ✅ **NEU:** RAM-Auslastung Monitoring (Warnung ab 80%, Fehler ab 90%)
- ✅ **NEU:** System Load Average Monitoring (Info ab 100%, Fehler ab 150%)
- ✅ Log-Rotation konfiguriert (wöchentlich, automatische Komprimierung)

### Version 2.0 - 25. Dezember 2025
- ✅ Umstellung auf `mailcow-alert-v2.sh`
- ✅ Gmail SMTP-Integration für externe Benachrichtigungen
- ✅ Mehrkanal-System mit Fallback-Logik
- ✅ Sichere Credential-Speicherung in separater Datei
- ✅ Erweiterte Logging-Funktionen
- ✅ Support für Telegram & Webhooks (optional)
- ✅ Getestet und funktionsfähig

### Version 1.0 - 24. Dezember 2025
- Initiale Installation
- Basis-Monitoring aller kritischen Komponenten
- Einfache Email-Benachrichtigungen

## Erstellt am

**Initialer Setup:** 24. Dezember 2025
**Letzte Aktualisierung:** 25. Dezember 2025
**Anlass:** Nach Behebung des vmail-Verzeichnis-Problems
**Zweck:** Frühzeitige Erkennung ähnlicher Probleme

## Aktueller Status

✅ **VOLL FUNKTIONSFÄHIG**

- Monitoring läuft alle 10 Minuten
- Alerts werden erfolgreich via Gmail an wolf.burger@gmail.com versendet
- Alle Container laufen einwandfrei
- Keine aktuellen Fehler

Letzter erfolgreicher Test: 25. Dezember 2025, 11:24 Uhr

## Support

Bei Problemen oder Fragen:

1. Prüfe die Logs: `/var/log/mailcow-monitor.log`
2. Führe manuellen Check aus: `/usr/local/bin/mailcow-monitor.sh`
3. Prüfe Container-Status: `docker ps -a`
4. Prüfe spezifische Container-Logs: `docker logs <container-name>`
5. Prüfe Alert-System: `tail -50 /var/log/mailcow-critical-alerts.log`

## Wichtige Dateien

| Datei | Beschreibung | Berechtigungen |
|-------|--------------|----------------|
| `/usr/local/bin/mailcow-monitor.sh` | Haupt-Monitoring-Skript | -rwxr-xr-x |
| `/usr/local/bin/mailcow-alert-v2.sh` | Alert-Benachrichtigungssystem | -rwxr-xr-x |
| `/usr/local/bin/mailcow-daily-report.sh` | Täglicher Status-Report | -rwxr-xr-x |
| `/root/.mailcow-alert-credentials` | Gmail SMTP Credentials | -rw------- |
| `/var/log/mailcow-monitor.log` | Monitoring-Log | -rw-r--r-- |
| `/var/log/mailcow-monitor-errors.log` | Nur Fehler | -rw-r--r-- |
| `/var/log/mailcow-critical-alerts.log` | Alert-Protokoll | -rw-r--r-- |
| `/var/log/mailcow-daily-report.log` | Daily Report Log | -rw-r--r-- |
| `/var/run/mailcow-last-alert` | Timestamp letzter Alert | -rw-r--r-- |
