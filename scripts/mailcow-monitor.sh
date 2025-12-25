#!/bin/bash
#
# Mailcow Monitoring Script
# Überwacht alle kritischen Mail-Services und schreibt Probleme ins Log
#
# Erstellt: 2025-12-24
# Zweck: Überwachung von Mailcow-Installation nach vmail-Fehler

# Konfiguration
LOG_FILE="/var/log/mailcow-monitor.log"
ERROR_LOG="/var/log/mailcow-monitor-errors.log"
MAILCOW_DIR="/srv/mailcow"
VMAIL_DIR="/srv/mailcow/data/vmail"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Zähler für Fehler
ERROR_COUNT=0

# Logging-Funktionen
log_info() {
    echo "[$TIMESTAMP] INFO: $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$TIMESTAMP] ERROR: $1" | tee -a "$LOG_FILE" >> "$ERROR_LOG"
    ((ERROR_COUNT++))
}

log_success() {
    echo "[$TIMESTAMP] OK: $1" >> "$LOG_FILE"
}

# Überprüfungen

# 1. Prüfe ob vmail-Verzeichnis existiert und korrekte Berechtigungen hat
check_vmail_directory() {
    if [ ! -d "$VMAIL_DIR" ]; then
        log_error "vmail-Verzeichnis $VMAIL_DIR existiert nicht!"
        return 1
    fi

    # Prüfe Berechtigungen (sollte 2755 sein)
    PERMS=$(stat -c "%a" "$VMAIL_DIR")
    if [ "$PERMS" != "2755" ]; then
        log_error "vmail-Verzeichnis hat falsche Berechtigungen: $PERMS (erwartet: 2755)"
        return 1
    fi

    # Prüfe Owner (sollte 5000:5000 sein)
    OWNER=$(stat -c "%u:%g" "$VMAIL_DIR")
    if [ "$OWNER" != "5000:5000" ]; then
        log_error "vmail-Verzeichnis hat falschen Owner: $OWNER (erwartet: 5000:5000)"
        return 1
    fi

    log_success "vmail-Verzeichnis OK"
    return 0
}

# 2. Prüfe kritische Container
check_containers() {
    local CRITICAL_CONTAINERS=(
        "mailcowdockerized-dovecot-mailcow-1"
        "mailcowdockerized-postfix-mailcow-1"
        "mailcowdockerized-nginx-mailcow-1"
        "mailcowdockerized-mysql-mailcow-1"
        "mailcowdockerized-redis-mailcow-1"
        "mailcowdockerized-sogo-mailcow-1"
        "mailcowdockerized-php-fpm-mailcow-1"
    )

    for container in "${CRITICAL_CONTAINERS[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            log_error "Container $container läuft nicht!"
        else
            # Prüfe ob Container healthy ist (falls Health-Check definiert)
            HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
            if [ "$HEALTH" == "unhealthy" ]; then
                log_error "Container $container ist unhealthy!"
            else
                log_success "Container $container läuft"
            fi
        fi
    done
}

# 3. Prüfe wichtige Ports
check_ports() {
    local PORTS=(25 587 465 143 993 110 995)

    for port in "${PORTS[@]}"; do
        if ! netstat -tlnp | grep -q ":$port "; then
            log_error "Port $port ist nicht erreichbar!"
        else
            log_success "Port $port ist offen"
        fi
    done
}

# 4. Prüfe SMTP-Verbindung
check_smtp() {
    if timeout 5 bash -c "echo 'QUIT' | nc -w 3 localhost 25" &>/dev/null; then
        log_success "SMTP (Port 25) antwortet"
    else
        log_error "SMTP (Port 25) antwortet nicht!"
    fi
}

# 5. Prüfe Webmail
check_webmail() {
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k https://localhost:8443/ 2>/dev/null)

    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
        log_success "Webmail (HTTPS) ist erreichbar (HTTP $HTTP_CODE)"
    else
        log_error "Webmail (HTTPS) ist nicht erreichbar (HTTP $HTTP_CODE)"
    fi
}

# 6. Prüfe Dovecot-Logs auf kritische Fehler
check_dovecot_errors() {
    RECENT_ERRORS=$(docker logs mailcowdockerized-dovecot-mailcow-1 --since 5m 2>&1 | \
        grep -i "error.*maildir\|failed to autocreate\|no such file" | wc -l)

    if [ "$RECENT_ERRORS" -gt 0 ]; then
        log_error "Dovecot hat $RECENT_ERRORS Fehler in den letzten 5 Minuten"
    else
        log_success "Keine kritischen Dovecot-Fehler"
    fi
}

# 7. Prüfe Postfix-Queue
check_mail_queue() {
    QUEUE_COUNT=$(docker exec mailcowdockerized-postfix-mailcow-1 postqueue -p 2>/dev/null | \
        tail -1 | grep -oP '\d+(?= Request)' || echo "0")

    if [ "$QUEUE_COUNT" -gt 50 ]; then
        log_error "Mail-Queue hat $QUEUE_COUNT wartende Emails (Threshold: 50)"
    elif [ "$QUEUE_COUNT" -gt 10 ]; then
        log_info "Mail-Queue hat $QUEUE_COUNT wartende Emails"
    else
        log_success "Mail-Queue OK ($QUEUE_COUNT Emails)"
    fi
}

# 8. Prüfe Festplattenspeicher
check_disk_space() {
    VMAIL_USAGE=$(df -h "$VMAIL_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$VMAIL_USAGE" -gt 90 ]; then
        log_error "vmail Partition ist zu $VMAIL_USAGE% voll!"
    elif [ "$VMAIL_USAGE" -gt 80 ]; then
        log_info "vmail Partition ist zu $VMAIL_USAGE% voll"
    else
        log_success "Festplattenspeicher OK ($VMAIL_USAGE% verwendet)"
    fi
}

# 9. Prüfe CPU-Auslastung
check_cpu_usage() {
    # CPU-Auslastung über 1 Minute gemittelt (idle time invertiert)
    CPU_IDLE=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | awk '{print $8}' | cut -d'%' -f1 | cut -d'.' -f1)

    # Fallback falls leer
    if [ -z "$CPU_IDLE" ]; then
        CPU_IDLE=0
    fi

    CPU_USAGE=$((100 - CPU_IDLE))

    if [ "$CPU_USAGE" -gt 90 ]; then
        log_error "CPU-Auslastung ist bei $CPU_USAGE% (Threshold: 90%)"
    elif [ "$CPU_USAGE" -gt 80 ]; then
        log_info "CPU-Auslastung ist bei $CPU_USAGE% (Warnung ab 80%)"
    else
        log_success "CPU-Auslastung OK ($CPU_USAGE%)"
    fi
}

# 10. Prüfe RAM-Auslastung
check_memory_usage() {
    # Speicher-Auslastung in Prozent
    MEM_TOTAL=$(free | awk '/^Mem:/ {print $2}')
    MEM_AVAILABLE=$(free | awk '/^Mem:/ {print $7}')
    MEM_USED=$((MEM_TOTAL - MEM_AVAILABLE))
    MEM_USAGE=$((MEM_USED * 100 / MEM_TOTAL))

    if [ "$MEM_USAGE" -gt 90 ]; then
        log_error "RAM-Auslastung ist bei $MEM_USAGE% (Threshold: 90%)"
    elif [ "$MEM_USAGE" -gt 80 ]; then
        log_info "RAM-Auslastung ist bei $MEM_USAGE% (Warnung ab 80%)"
    else
        log_success "RAM-Auslastung OK ($MEM_USAGE%)"
    fi
}

# 11. Prüfe System Load Average
check_load_average() {
    # Hole Load Average (1 Minute) und bereinige es
    LOAD_RAW=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
    # Entferne Kommas und konvertiere zu Ganzzahl (multipliziere mit 100 für Präzision)
    LOAD_1MIN=$(echo "$LOAD_RAW" | tr ',' '.' | cut -d'.' -f1)
    CPU_CORES=$(nproc)

    # Fallback falls leer
    if [ -z "$LOAD_1MIN" ] || [ "$LOAD_1MIN" = "" ]; then
        LOAD_1MIN=0
    fi

    # Berechne Load pro Core (als Ganzzahl-Prozentsatz)
    if [ "$CPU_CORES" -gt 0 ] && [ "$LOAD_1MIN" -ge 0 ]; then
        LOAD_PERCENT=$((LOAD_1MIN * 100 / CPU_CORES))
    else
        LOAD_PERCENT=0
    fi

    if [ "$LOAD_PERCENT" -gt 150 ]; then
        log_error "System Load ist hoch: $LOAD_RAW bei $CPU_CORES Cores ($LOAD_PERCENT%)"
    elif [ "$LOAD_PERCENT" -gt 100 ]; then
        log_info "System Load: $LOAD_RAW bei $CPU_CORES Cores ($LOAD_PERCENT%)"
    else
        log_success "System Load OK: $LOAD_RAW bei $CPU_CORES Cores"
    fi
}

# Hauptprogramm
main() {
    echo "=== Mailcow Monitoring gestartet um $TIMESTAMP ===" >> "$LOG_FILE"

    check_vmail_directory
    check_containers
    check_ports
    check_smtp
    check_webmail
    check_dovecot_errors
    check_mail_queue
    check_disk_space
    check_cpu_usage
    check_memory_usage
    check_load_average

    # Zusammenfassung
    if [ $ERROR_COUNT -eq 0 ]; then
        log_info "Alle Checks erfolgreich! System läuft einwandfrei."
    else
        log_error "==> $ERROR_COUNT Fehler gefunden! Bitte prüfen!"

        # Sende Email-Benachrichtigung
        if [ -x /usr/local/bin/mailcow-alert-v2.sh ]; then
            /usr/local/bin/mailcow-alert-v2.sh
        fi
    fi

    echo "" >> "$LOG_FILE"
}

# Skript ausführen
main
