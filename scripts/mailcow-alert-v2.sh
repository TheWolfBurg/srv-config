#!/bin/bash
#
# Mailcow Alert Script V2
# Sendet Benachrichtigungen über MEHRERE unabhängige Kanäle
#
# Verwendung: Wird automatisch vom mailcow-monitor.sh aufgerufen

# ============================================================================
# KONFIGURATION - BITTE ANPASSEN!
# ============================================================================

# Option 1: Lokaler Mailserver (funktioniert NUR wenn Server läuft)
USE_LOCAL_MAIL=true
LOCAL_ALERT_EMAIL="postmaster@clocklight.de"

# Option 2: Externer SMTP-Server (z.B. Gmail, Office365, etc.)
# Dies ist der BACKUP wenn lokaler Server nicht funktioniert!
USE_EXTERNAL_SMTP=true
EXTERNAL_SMTP_HOST="smtp.gmail.com"
EXTERNAL_SMTP_PORT="587"
EXTERNAL_SMTP_USER="claudia.steinhage@gmail.com"
EXTERNAL_SMTP_PASSWORD=""  # Lass leer für Sicherheit, nutze stattdessen .env Datei
EXTERNAL_ALERT_EMAIL="wolf.burger@gmail.com"

# Option 3: Webhook (Slack, Discord, Telegram, etc.)
USE_WEBHOOK=false
WEBHOOK_URL=""  # z.B. https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Option 4: Telegram Bot
USE_TELEGRAM=true
TELEGRAM_BOT_TOKEN="8342326725:AAFMG7kDfDx445VyAV75F2r3CS1N3re-P7M"
TELEGRAM_CHAT_ID="1272486023"

# Option 5: Log-Datei (immer aktiv als Fallback)
USE_LOGFILE=true
ALERT_LOGFILE="/var/log/mailcow-critical-alerts.log"

# ============================================================================
# AB HIER NICHTS ÄNDERN (außer du weißt was du tust)
# ============================================================================

ERROR_LOG="/var/log/mailcow-monitor-errors.log"
LAST_ALERT_FILE="/var/run/mailcow-last-alert"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Lade externe Credentials falls vorhanden
if [ -f /root/.mailcow-alert-credentials ]; then
    source /root/.mailcow-alert-credentials
fi

# Prüfe ob es neue Fehler gibt
if [ ! -f "$ERROR_LOG" ] || [ ! -s "$ERROR_LOG" ]; then
    exit 0
fi

# Prüfe ob bereits in der letzten Stunde eine Alert gesendet wurde
if [ -f "$LAST_ALERT_FILE" ]; then
    LAST_ALERT=$(stat -c %Y "$LAST_ALERT_FILE")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_ALERT))

    # Sende maximal einmal pro Stunde eine Alert
    if [ $TIME_DIFF -lt 3600 ]; then
        exit 0
    fi
fi

# Hol die letzten 20 Fehler
ERRORS=$(tail -20 "$ERROR_LOG")
SUBJECT="[CRITICAL] Mailcow Monitoring Alert - $(hostname)"

# Erstelle Alert-Nachricht
MESSAGE="
⚠️ KRITISCHE WARNUNG ⚠️

Das Mailcow Monitoring hat Probleme erkannt!

Server: $(hostname)
Zeit: $TIMESTAMP

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LETZTE FEHLER:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$ERRORS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EMPFOHLENE MASSNAHMEN:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. SSH zum Server: ssh root@$(hostname -f)
2. Logs prüfen: tail -f /var/log/mailcow-monitor.log
3. Container-Status: docker ps -a
4. vmail prüfen: ls -la /srv/mailcow/data/vmail/
5. Manueller Check: /usr/local/bin/mailcow-monitor.sh

Diese Nachricht wurde automatisch generiert.
"

# ============================================================================
# BENACHRICHTIGUNGS-FUNKTIONEN
# ============================================================================

send_local_email() {
    if [ "$USE_LOCAL_MAIL" = true ]; then
        cat <<EOF | /usr/sbin/sendmail -t 2>/dev/null
To: $LOCAL_ALERT_EMAIL
From: monitoring@$(hostname -f)
Subject: $SUBJECT
Content-Type: text/plain; charset=UTF-8

$MESSAGE
EOF
        if [ $? -eq 0 ]; then
            echo "[$TIMESTAMP] Alert via lokaler Email gesendet" >> "$ALERT_LOGFILE"
            return 0
        else
            echo "[$TIMESTAMP] FEHLER: Lokale Email konnte nicht gesendet werden!" >> "$ALERT_LOGFILE"
            return 1
        fi
    fi
    return 1
}

send_external_email() {
    if [ "$USE_EXTERNAL_SMTP" = true ] && [ -n "$EXTERNAL_SMTP_PASSWORD" ]; then
        # Verwende curl für SMTP (funktioniert auch wenn lokaler Mailserver down ist)

        # Erstelle temporäre Email-Datei
        TEMP_EMAIL=$(mktemp)
        cat > "$TEMP_EMAIL" <<EOF
From: Mailcow Monitor <$EXTERNAL_SMTP_USER>
To: $EXTERNAL_ALERT_EMAIL
Subject: $SUBJECT
Content-Type: text/plain; charset=UTF-8

$MESSAGE
EOF

        # Sende via curl über externen SMTP
        curl --url "smtp://$EXTERNAL_SMTP_HOST:$EXTERNAL_SMTP_PORT" \
             --ssl-reqd \
             --mail-from "$EXTERNAL_SMTP_USER" \
             --mail-rcpt "$EXTERNAL_ALERT_EMAIL" \
             --user "$EXTERNAL_SMTP_USER:$EXTERNAL_SMTP_PASSWORD" \
             --upload-file "$TEMP_EMAIL" \
             2>/dev/null

        if [ $? -eq 0 ]; then
            echo "[$TIMESTAMP] Alert via externem SMTP gesendet" >> "$ALERT_LOGFILE"
            rm -f "$TEMP_EMAIL"
            return 0
        else
            echo "[$TIMESTAMP] FEHLER: Externe SMTP Email fehlgeschlagen!" >> "$ALERT_LOGFILE"
            rm -f "$TEMP_EMAIL"
            return 1
        fi
    fi
    return 1
}

send_webhook() {
    if [ "$USE_WEBHOOK" = true ] && [ -n "$WEBHOOK_URL" ]; then
        # Escape JSON
        JSON_MESSAGE=$(echo "$MESSAGE" | jq -Rs .)

        curl -X POST "$WEBHOOK_URL" \
             -H "Content-Type: application/json" \
             -d "{\"text\": $JSON_MESSAGE}" \
             2>/dev/null

        if [ $? -eq 0 ]; then
            echo "[$TIMESTAMP] Alert via Webhook gesendet" >> "$ALERT_LOGFILE"
            return 0
        else
            echo "[$TIMESTAMP] FEHLER: Webhook fehlgeschlagen!" >> "$ALERT_LOGFILE"
            return 1
        fi
    fi
    return 1
}

send_telegram() {
    if [ "$USE_TELEGRAM" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        # Escape für URL
        ENCODED_MESSAGE=$(echo "$MESSAGE" | jq -sRr @uri)

        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
             -d "chat_id=$TELEGRAM_CHAT_ID" \
             -d "text=$MESSAGE" \
             -d "parse_mode=HTML" \
             2>/dev/null

        if [ $? -eq 0 ]; then
            echo "[$TIMESTAMP] Alert via Telegram gesendet" >> "$ALERT_LOGFILE"
            return 0
        else
            echo "[$TIMESTAMP] FEHLER: Telegram fehlgeschlagen!" >> "$ALERT_LOGFILE"
            return 1
        fi
    fi
    return 1
}

log_to_file() {
    if [ "$USE_LOGFILE" = true ]; then
        echo "================================" >> "$ALERT_LOGFILE"
        echo "$MESSAGE" >> "$ALERT_LOGFILE"
        echo "================================" >> "$ALERT_LOGFILE"
        echo "" >> "$ALERT_LOGFILE"
        return 0
    fi
    return 1
}

# ============================================================================
# HAUPTPROGRAMM - Versuche alle konfigurierten Kanäle
# ============================================================================

SUCCESS=false

# Versuche lokale Email (wird wahrscheinlich fehlschlagen wenn Server down ist)
send_local_email && SUCCESS=true

# Falls lokale Email fehlschlägt, versuche externe Alternativen
if [ "$SUCCESS" = false ]; then
    send_external_email && SUCCESS=true
    send_webhook && SUCCESS=true
    send_telegram && SUCCESS=true
fi

# Immer in Log-Datei schreiben (Fallback)
log_to_file

# Markiere, dass eine Alert gesendet wurde
touch "$LAST_ALERT_FILE"

if [ "$SUCCESS" = true ]; then
    echo "[$TIMESTAMP] Alert erfolgreich versendet" >> "$ALERT_LOGFILE"
    exit 0
else
    echo "[$TIMESTAMP] WARNUNG: Konnte Alert über KEINEN Kanal versenden!" >> "$ALERT_LOGFILE"
    exit 1
fi
