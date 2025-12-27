# Server Optimization & Migration Plan

**Erstellt:** 25. Dezember 2025
**Status:** Beobachtungsphase

## Problem-Analyse (25.12.2025)

### Ausgangssituation
- **Server:** 3,7 GB RAM total
- **Load Average:** 2,99 (kritisch hoch)
- **CPU-Auslastung:** 86% (63,6% user + 22,7% system)
- **Freier RAM:** 190 MB
- **Swap-Nutzung:** 797 MB
- **Laufende Container:** 22

### Hauptverursacher
1. **containerd:** 66,7% CPU
2. **dockerd:** 50% CPU
3. **Netdata:** 7,85% CPU + 329 MB RAM
4. **Umami:** ~200 MB RAM

### Root Cause
- **Hardware-Limitation:** 3,7 GB RAM sind zu wenig für:
  - Mailcow (19 Container)
  - Caddy Webserver
  - Netdata Monitoring
  - Umami Analytics

---

## Durchgeführte Optimierungen

### 1. Netdata deaktiviert
```bash
docker stop netdata
docker update --restart=no netdata
```
**Ersparnis:** ~330 MB RAM + 8% CPU

### 2. Umami Analytics deaktiviert
```bash
docker stop umami-umami-1 umami-db-1
docker update --restart=no umami-umami-1 umami-db-1
```
**Ersparnis:** ~200 MB RAM

### Ergebnis nach Optimierung
- **Load Average:** 0,15 (von 2,99!)
- **CPU-Auslastung:** 33% (von 86%)
- **Freier RAM:** 766 MB (von 190 MB)
- **Swap-Nutzung:** 743 MB (von 797 MB)
- **Laufende Container:** 19

---

## Beobachtungsphase (nächste Tage)

### Zu überwachen:
```bash
# CPU & RAM Check
top -bn1 | head -15
free -h

# Load Average
uptime

# Container-Ressourcen
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Swap-Nutzung
swapon --show
```

### Fragen für die Beobachtung:
- [ ] Bleibt der Load unter 1,0?
- [ ] Reicht der freie RAM aus?
- [ ] Wird Swap weiter reduziert?
- [ ] Gibt es CPU-Spitzen bei Mail-Traffic?
- [ ] Läuft Mailcow stabil ohne Netdata?

---

## Empfohlenes Ziel-Setup: 2-Server-Lösung

### Server 1: Dedizierter Mail-Server
**Hetzner CPX21 oder CX21**
- **RAM:** 4 GB (ausreichend für Mailcow)
- **vCPU:** 3 (CPX21) oder 2 (CX21)
- **Preis:** ~€6-8/Monat
- **Services:**
  - Mailcow (alle 19 Container)
  - Optional: Fail2ban, Monitoring-Skripte

### Server 2: Web-Services
**Hetzner CAX11 (ARM)**
- **RAM:** 4 GB
- **vCPU:** 2 (ARM Ampere Altra)
- **SSD:** 40 GB
- **Preis:** ~€3,79/Monat
- **Services:**
  - Caddy Webserver
  - Umami Analytics + PostgreSQL
  - Statische Websites
  - Optional: Netdata (nur für Web-Server)

### Upgrade-Pfad
- **CAX11** kann später zu **CAX21** (8 GB) oder **CAX31** (16 GB) upgraded werden
- Upgrade innerhalb ARM-Serie möglich, kein Wechsel zu x86

### Gesamtkosten
- **Aktuell:** 1 Server (Größe unbekannt)
- **2-Server-Lösung:** ~€10-12/Monat
- **Vorteile:**
  - Bessere Isolation
  - Mail läuft stabil und isoliert
  - Ausfallsicherheit
  - Einfacher zu skalieren

---

## Migration zu 2-Server-Setup (Future)

### Phase 1: Web-Server vorbereiten (CAX11)
```bash
# Auf neuem CAX11 Server:
# 1. Docker installieren
# 2. Caddy + Config migrieren
# 3. Umami migrieren
# 4. DNS umstellen
```

### Phase 2: Mail-Server optimieren
```bash
# Auf aktuellem Server:
# 1. Caddy, Umami komplett entfernen
# 2. Ressourcen für Mailcow freigeben
# 3. Optional: Server downsizen
```

### Zu migrierende Daten
- [ ] Caddy Konfiguration
- [ ] SSL-Zertifikate (Let's Encrypt)
- [ ] Umami-Datenbank (PostgreSQL Dump)
- [ ] Website-Dateien
- [ ] DNS-Einträge anpassen

---

## Alternativen

### Option A: Aktuellen Server upgraden
- **Upgrade auf:** 6-8 GB RAM
- **Vorteil:** Einfach, nur ein Server
- **Nachteil:** Single Point of Failure, alle Services teilen Ressourcen

### Option B: 2-Server-Lösung (EMPFOHLEN)
- **Siehe oben**

---

## Aktuelle Container-Übersicht

### Mailcow (19 Container)
```
mailcowdockerized-dovecot-mailcow-1       # IMAP/POP3
mailcowdockerized-postfix-mailcow-1       # SMTP
mailcowdockerized-rspamd-mailcow-1        # Spam-Filter
mailcowdockerized-clamd-mailcow-1         # Virenscanner
mailcowdockerized-sogo-mailcow-1          # Webmail
mailcowdockerized-mysql-mailcow-1         # MariaDB
mailcowdockerized-redis-mailcow-1         # Cache
mailcowdockerized-memcached-mailcow-1     # Memory Cache
mailcowdockerized-nginx-mailcow-1         # Reverse Proxy
mailcowdockerized-acme-mailcow-1          # SSL-Zertifikate
mailcowdockerized-watchdog-mailcow-1      # Health Check
mailcowdockerized-netfilter-mailcow-1     # Firewall
mailcowdockerized-postfix-tlspol-mailcow-1
mailcowdockerized-php-fpm-mailcow-1
mailcowdockerized-dockerapi-mailcow-1
mailcowdockerized-ofelia-mailcow-1        # Cron
mailcowdockerized-olefy-mailcow-1
mailcowdockerized-unbound-mailcow-1       # DNS
```

### Weitere Services
```
caddy-webserver                           # Webserver
```

### Deaktiviert (Stand: 25.12.2025)
```
netdata                                   # Monitoring (gestoppt)
umami-umami-1                            # Analytics (gestoppt)
umami-db-1                               # PostgreSQL (gestoppt)
```

---

## Nützliche Befehle

### Ressourcen-Monitoring
```bash
# Echtzeit-Monitoring
top

# Load Average
uptime

# RAM-Nutzung
free -h

# Container-Stats
docker stats

# Top Container nach CPU
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | sort -k2 -hr
```

### Container-Verwaltung
```bash
# Deaktivierte Services wieder starten
docker update --restart=unless-stopped netdata
docker start netdata

docker update --restart=unless-stopped umami-umami-1 umami-db-1
docker start umami-umami-1 umami-db-1

# Komplett entfernen (z.B. Umami)
cd /pfad/zu/umami
docker compose down -v
```

---

## Nächste Schritte

1. **Beobachtung (3-7 Tage):**
   - Täglich Load & RAM checken
   - Mail-Funktionalität testen
   - Performance-Probleme dokumentieren

2. **Entscheidung treffen:**
   - Bei stabiler Performance: Status Quo behalten
   - Bei Problemen: Migration zu 2-Server-Setup planen

3. **Optional:**
   - Netdata/Umami komplett entfernen wenn nicht benötigt
   - SOGo deaktivieren wenn kein Webmail benötigt wird

---

## Notes

- ARM (CAX11) ist kompatibel mit allen benötigten Web-Services (Caddy, Umami, PostgreSQL)
- Mailcow läuft besser auf x86 (mehr getestet, bessere Kompatibilität)
- 2-Server-Setup bietet beste Balance aus Kosten, Performance und Ausfallsicherheit

**Letztes Update:** 25. Dezember 2025
