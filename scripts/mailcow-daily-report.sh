#!/bin/bash
#
# Mailcow Daily Status Report
# Sendet täglich um 2:00 Uhr einen Status-Report
#
# Erstellt: 2025-12-25

# Konfiguration
REPORT_EMAIL="wolf.burger@gmail.com"
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="claudia.steinhage@gmail.com"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE=$(date '+%Y-%m-%d')

# Lade Credentials
if [ -f /root/.mailcow-alert-credentials ]; then
    source /root/.mailcow-alert-credentials
fi

# Sammle Status-Informationen

# 1. System-Uptime
UPTIME=$(uptime -p)

# 2. Aktuelle Ressourcen
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
MEM_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", ($3/$2)*100}')
DISK_USAGE=$(df -h /srv/mailcow/data/vmail | awk 'NR==2 {print $5}')

# 3. Container-Status
CONTAINERS_RUNNING=$(docker ps --filter "name=mailcow" --format '{{.Names}}' | wc -l)
CONTAINERS_TOTAL=$(docker ps -a --filter "name=mailcow" --format '{{.Names}}' | wc -l)

# 4. Mail-Queue
QUEUE_SIZE=$(docker exec mailcowdockerized-postfix-mailcow-1 postqueue -p 2>/dev/null | tail -1 | grep -oP '\d+(?= Request)' || echo "0")

# 5. Fehler in den letzten 24 Stunden
ERRORS_24H=$(grep "$(date '+%Y-%m-%d')" /var/log/mailcow-monitor-errors.log 2>/dev/null | wc -l)
ERRORS_YESTERDAY=$(grep "$(date -d yesterday '+%Y-%m-%d')" /var/log/mailcow-monitor-errors.log 2>/dev/null | wc -l)
TOTAL_ERRORS=$((ERRORS_24H + ERRORS_YESTERDAY))

# 6. Letzte Fehler (falls vorhanden)
RECENT_ERRORS=""
if [ $TOTAL_ERRORS -gt 0 ]; then
    RECENT_ERRORS=$(tail -10 /var/log/mailcow-monitor-errors.log 2>/dev/null)
fi

# 7. Alerts gesendet in letzten 24h
ALERTS_SENT=$(grep -c "Alert erfolgreich versendet" /var/log/mailcow-critical-alerts.log 2>/dev/null || echo "0")

# 8. Status-Icon basierend auf Fehlern
if [ $TOTAL_ERRORS -eq 0 ]; then
    STATUS_ICON="✅"
    STATUS_TEXT="ALLES OK"
elif [ $TOTAL_ERRORS -lt 5 ]; then
    STATUS_ICON="⚠️"
    STATUS_TEXT="KLEINERE PROBLEME"
else
    STATUS_ICON="🚨"
    STATUS_TEXT="ACHTUNG - MEHRERE FEHLER"
fi

# Erstelle Report-Nachricht
SUBJECT="[Mailcow] Täglicher Status-Report - $(date '+%d.%m.%Y')"

MESSAGE="
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MAILCOW TÄGLICHER STATUS-REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Server: mail.clocklight.de
Datum: $(date '+%d. %B %Y')
Zeit: $(date '+%H:%M:%S Uhr')

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  $STATUS_ICON GESAMTSTATUS: $STATUS_TEXT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 SYSTEM-ÜBERSICHT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏱️  Uptime:              $UPTIME
💻 CPU Load:            $CPU_LOAD
🧠 RAM-Nutzung:         $MEM_USAGE%
💾 Festplatte (vmail):  $DISK_USAGE

📬 MAIL-DIENSTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🐳 Container:           $CONTAINERS_RUNNING/$CONTAINERS_TOTAL laufen
📧 Mail-Queue:          $QUEUE_SIZE Emails wartend

📈 MONITORING (24 Stunden)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❌ Fehler heute:        $ERRORS_24H
❌ Fehler gestern:      $ERRORS_YESTERDAY
🔔 Alerts versendet:    $ALERTS_SENT
"

# Füge letzte Fehler hinzu falls vorhanden
if [ $TOTAL_ERRORS -gt 0 ]; then
    MESSAGE="$MESSAGE
🚨 LETZTE FEHLER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$RECENT_ERRORS

"
fi

# Füge Service-Status hinzu
MESSAGE="$MESSAGE
🔍 SERVICE-DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"

# Prüfe wichtige Container
for container in dovecot postfix nginx mysql redis; do
    if docker ps --format '{{.Names}}' | grep -q "$container"; then
        MESSAGE="$MESSAGE
✅ $container läuft"
    else
        MESSAGE="$MESSAGE
❌ $container ist DOWN!"
    fi
done

MESSAGE="$MESSAGE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  NÄCHSTE SCHRITTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"

if [ $TOTAL_ERRORS -eq 0 ]; then
    MESSAGE="$MESSAGE
🎉 Alles läuft perfekt! Keine Aktion erforderlich.
"
else
    MESSAGE="$MESSAGE
⚠️  Bitte prüfe die Fehler:

1. SSH zum Server: ssh root@mail.clocklight.de
2. Logs prüfen: tail -f /var/log/mailcow-monitor.log
3. Fehler ansehen: cat /var/log/mailcow-monitor-errors.log
4. Container prüfen: docker ps -a
"
fi

MESSAGE="$MESSAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Dieser Report wird täglich um 02:00 Uhr automatisch generiert.

🤖 Mailcow Monitoring System v2.1
"

# Sende Report via Gmail SMTP
TEMP_EMAIL=$(mktemp)
cat > "$TEMP_EMAIL" <<EOF
From: Mailcow Status Report <$SMTP_USER>
To: $REPORT_EMAIL
Subject: $SUBJECT
Content-Type: text/plain; charset=UTF-8

$MESSAGE
EOF

# Sende via curl über Gmail SMTP
curl --url "smtp://$SMTP_HOST:$SMTP_PORT" \
     --ssl-reqd \
     --mail-from "$SMTP_USER" \
     --mail-rcpt "$REPORT_EMAIL" \
     --user "$SMTP_USER:$EXTERNAL_SMTP_PASSWORD" \
     --upload-file "$TEMP_EMAIL" \
     2>/dev/null

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily Report erfolgreich versendet" >> /var/log/mailcow-daily-report.log
    rm -f "$TEMP_EMAIL"
    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FEHLER: Daily Report konnte nicht versendet werden!" >> /var/log/mailcow-daily-report.log
    rm -f "$TEMP_EMAIL"
    exit 1
fi
