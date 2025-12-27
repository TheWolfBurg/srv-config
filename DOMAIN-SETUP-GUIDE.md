# Domain Setup Script - Anleitung

**Skript:** `/srv/scripts/add-domain.sh`
**Erstellt:** 27. Dezember 2025

---

## Was macht das Skript?

Das `add-domain.sh` Skript automatisiert die komplette Einrichtung einer neuen Domain:

### 1. Mailcow-Konfiguration ✉️
- Domain zu Mailcow hinzufügen
- `info@domain.com` Alias erstellen → Weiterleitung an admin@wolfgang-burger.de
- `postmaster@domain.com` Alias erstellen → Weiterleitung an admin@wolfgang-burger.de

### 2. Caddy-Konfiguration 🌐
- Caddy Site-Config erstellen
- Compression + Security Headers automatisch einbinden
- Website-Verzeichnis anlegen
- Platzhalter-Website erstellen

### 3. DNS-Records generieren 📋
- Zeigt alle benötigten DNS-Records
- A-Record, CNAME, MX, SPF, DMARC

---

## Vorbereitung: Mailcow API-Key erstellen

**Das musst du EINMAL machen:**

### Schritt 1: Mailcow Admin-Panel öffnen
```
https://mail.clocklight.de:8443
```

### Schritt 2: Als Admin einloggen
- Benutzername: admin
- Passwort: [dein Mailcow-Admin-Passwort]

### Schritt 3: API-Key erstellen
1. Gehe zu: **Konfiguration** → **API**
2. Klicke auf: **API erstellen**
3. Setze Häkchen bei:
   - ✅ **Domains** (Read/Write)
   - ✅ **Alias** (Read/Write)
4. Beschreibung: `add-domain.sh Script`
5. Klicke: **Hinzufügen**

### Schritt 4: API-Key speichern
```bash
# Kopiere den angezeigten API-Key
# Speichere ihn in eine Datei:
echo 'DEIN-API-KEY-HIER' > /root/.mailcow-api-key
chmod 600 /root/.mailcow-api-key
```

**⚠️ WICHTIG:**
- API-Key sicher aufbewahren!
- Datei mit `chmod 600` schützen!
- Key hat volle Berechtigung für Domains/Aliase

---

## Verwendung

### Syntax:
```bash
/srv/scripts/add-domain.sh <domain> [website-pfad]
```

### Beispiel 1: Einfach (Standard-Pfad)
```bash
/srv/scripts/add-domain.sh example.com
```

**Erstellt:**
- Mail: info@example.com, postmaster@example.com
- Web: /var/www/example.com
- Caddy: /srv/caddy/sites/example.com.caddy

### Beispiel 2: Eigener Website-Pfad
```bash
/srv/scripts/add-domain.sh example.com /var/www/custom-path
```

**Erstellt:**
- Mail: info@example.com, postmaster@example.com
- Web: /var/www/custom-path (anstatt standard)
- Caddy: /srv/caddy/sites/example.com.caddy

---

## Was passiert im Detail?

### 1. Validierung
```
✓ Root-Rechte prüfen
✓ Domain-Name validieren
✓ API-Key laden
✓ Bestätigung vom User
```

### 2. Mailcow (via API)
```
ℹ Adding domain to Mailcow: example.com
✓ Domain added to Mailcow: example.com

ℹ Creating alias: info@example.com → admin@wolfgang-burger.de
✓ Alias created: info@example.com → admin@wolfgang-burger.de

ℹ Creating alias: postmaster@example.com → admin@wolfgang-burger.de
✓ Alias created: postmaster@example.com → admin@wolfgang-burger.de
```

### 3. Caddy
```
ℹ Creating Caddy configuration for: example.com
✓ Caddy config created: /srv/caddy/sites/example.com.caddy
✓ Config backed up to: /srv/config/caddy/sites/

ℹ Creating website directory: /var/www/example.com
✓ Website directory created: /var/www/example.com

ℹ Reloading Caddy configuration...
✓ Caddy config is valid
✓ Caddy reloaded successfully
```

### 4. DNS-Records
```
================================
  DNS Records for example.com
================================

Add these DNS records to your domain registrar:

# Website (A Record)
Type: A
Name: @
Value: 46.224.122.105
TTL: 3600

# WWW Subdomain (CNAME)
Type: CNAME
Name: www
Value: example.com
TTL: 3600

# Mail Server (MX Record)
Type: MX
Name: @
Value: mail.clocklight.de
Priority: 10
TTL: 3600

# SPF Record (TXT)
Type: TXT
Name: @
Value: "v=spf1 mx ~all"
TTL: 3600

# DMARC Record (TXT)
Type: TXT
Name: _dmarc
Value: "v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com"
TTL: 3600
```

### 5. Summary-Datei
```
✓ Summary saved to: /srv/domains/example.com-setup-summary.txt
```

---

## Nach dem Setup

### 1. DNS-Records hinzufügen
Gehe zu deinem Domain-Registrar und füge die angezeigten DNS-Records hinzu.

### 2. Warten (10-30 Minuten)
DNS-Propagation dauert 10-30 Minuten.

### 3. Testen
```bash
# Website testen
curl -I https://example.com

# DNS testen
dig example.com
dig www.example.com
dig example.com MX

# Email testen
echo "Test" | mail -s "Test" info@example.com
```

### 4. DKIM-Record verwenden

**✨ NEU: DKIM wird automatisch geholt!**

Das Skript holt den DKIM-Record automatisch von Mailcow und zeigt ihn direkt an:

```
# DKIM Record (TXT) ⭐ WICHTIG!
Type: TXT
Name: dkim._domainkey
Value: "v=DKIM1; k=rsa; p=MIGfMA0GCSq..."
TTL: 3600

✓ DKIM record is ready to use!
```

**Kopiere einfach den Wert und trage ihn bei deinem DNS-Provider ein!**

Falls DKIM noch nicht verfügbar ist (sehr selten), zeigt das Skript:
```
⚠ DKIM record not yet available
Please wait a few minutes, then get it from:
https://mail.clocklight.de:8443
→ Konfiguration → Routings → DKIM-Schlüssel → example.com
```

---

## Erstelle Dateien & Verzeichnisse

```
/srv/scripts/add-domain.sh                  # Hauptskript
/srv/caddy/sites/example.com.caddy          # Caddy-Config
/srv/config/caddy/sites/example.com.caddy   # Backup
/var/www/example.com/                       # Website-Root
/var/www/example.com/index.html             # Platzhalter-Seite
/srv/domains/example.com-setup-summary.txt  # Zusammenfassung
```

---

## Troubleshooting

### Problem: "Mailcow API key not found"

**Lösung:**
```bash
# API-Key erstellen (siehe oben)
echo 'DEIN-API-KEY' > /root/.mailcow-api-key
chmod 600 /root/.mailcow-api-key
```

### Problem: "Failed to add domain"

**Mögliche Ursachen:**
1. Domain existiert bereits in Mailcow
   - Lösung: Prüfe in Mailcow Admin-Panel
2. API-Key hat keine Berechtigung
   - Lösung: Neu erstellen mit Read/Write für Domains
3. Mailcow nicht erreichbar
   - Lösung: Prüfe `docker ps | grep mailcow`

### Problem: "Caddy config validation failed"

**Lösung:**
```bash
# Validiere manuell
docker exec caddy-webserver caddy validate --config /etc/caddy/Caddyfile

# Zeige Fehler
docker logs caddy-webserver --tail 50
```

### Problem: "Website nicht erreichbar"

**Checkliste:**
1. DNS-Records korrekt gesetzt?
   ```bash
   dig example.com
   # Sollte 46.224.122.105 zeigen
   ```

2. Caddy läuft?
   ```bash
   docker ps | grep caddy
   ```

3. Website-Dateien vorhanden?
   ```bash
   ls -la /var/www/example.com/
   ```

4. Caddy-Config korrekt?
   ```bash
   cat /srv/caddy/sites/example.com.caddy
   ```

### Problem: "Emails kommen nicht an"

**Checkliste:**
1. MX-Record gesetzt?
   ```bash
   dig example.com MX
   # Sollte mail.clocklight.de zeigen
   ```

2. SPF-Record gesetzt?
   ```bash
   dig example.com TXT | grep spf
   ```

3. Alias existiert in Mailcow?
   - Prüfe in Admin-Panel: **Email** → **Aliase**

4. Admin-Email korrekt?
   - Sollte admin@wolfgang-burger.de sein

---

## Mehrere Domains auf einmal

### Batch-Setup:
```bash
#!/bin/bash
# setup-multiple-domains.sh

DOMAINS=(
    "domain1.com"
    "domain2.com"
    "domain3.com"
)

for domain in "${DOMAINS[@]}"; do
    echo "Setting up $domain..."
    /srv/scripts/add-domain.sh "$domain"
    echo ""
    echo "Waiting 5 seconds before next domain..."
    sleep 5
done

echo "All domains configured!"
```

**Verwendung:**
```bash
chmod +x setup-multiple-domains.sh
./setup-multiple-domains.sh
```

---

## Erweiterte Konfiguration

### Eigene Caddy-Config nach Setup anpassen:

```bash
# Öffne Config
nano /srv/caddy/sites/example.com.caddy
```

**Beispiel: PHP-Support hinzufügen:**
```caddy
example.com, www.example.com {
    root * /var/www/example.com
    php_fastcgi unix//run/php/php8.2-fpm.sock
    file_server
    import ../snippets/compression.caddy
    import ../snippets/security_headers.caddy

    log {
        output file /var/log/caddy/example.com.log
    }
}
```

**Beispiel: Reverse Proxy:**
```caddy
example.com, www.example.com {
    reverse_proxy localhost:3000
    import ../snippets/compression.caddy
    import ../snippets/security_headers.caddy

    log {
        output file /var/log/caddy/example.com.log
    }
}
```

**Nach Änderungen:**
```bash
# Config validieren
docker exec caddy-webserver caddy validate --config /etc/caddy/Caddyfile

# Neu laden
docker exec caddy-webserver caddy reload --config /etc/caddy/Caddyfile

# Backup erstellen
cp /srv/caddy/sites/example.com.caddy /srv/config/caddy/sites/
```

---

## Sicherheit

### API-Key schützen:
```bash
# Nur root darf lesen
chmod 600 /root/.mailcow-api-key
chown root:root /root/.mailcow-api-key

# Prüfen
ls -la /root/.mailcow-api-key
# Sollte zeigen: -rw------- 1 root root
```

### API-Key rotieren (alle 6 Monate):
1. Neuen Key in Mailcow erstellen
2. Alten Key in Datei ersetzen
3. Alten Key in Mailcow löschen

### Logs prüfen:
```bash
# Mailcow API-Logs
docker logs mailcowdockerized-nginx-mailcow-1 --tail 100 | grep API

# Caddy-Logs
docker logs caddy-webserver --tail 100
```

---

## Automatisierung

### Cronjob für regelmäßige Setups (optional):

```bash
# /etc/cron.d/domain-setup
# Jeden Montag um 10:00 Uhr neue Domains aus Datei hinzufügen

0 10 * * 1 root /srv/scripts/process-domain-queue.sh
```

---

## Checkliste: Neue Domain hinzufügen

### Vor dem Setup:
- [ ] API-Key erstellt und gespeichert
- [ ] Domain-Name bereit
- [ ] Website-Dateien vorbereitet (optional)

### Setup durchführen:
- [ ] Skript ausführen: `/srv/scripts/add-domain.sh domain.com`
- [ ] DNS-Records notieren
- [ ] Setup-Summary prüfen

### Nach dem Setup:
- [ ] DNS-Records beim Registrar hinzufügen
- [ ] 10-30 Min warten (DNS-Propagation)
- [ ] Website testen: `https://domain.com`
- [ ] Email testen: An `info@domain.com` senden
- [ ] DKIM-Record von Mailcow holen und hinzufügen
- [ ] SPF/DMARC testen: https://mxtoolbox.com

### Optional:
- [ ] Website-Inhalte hochladen
- [ ] Caddy-Config anpassen (PHP, etc.)
- [ ] SSL-Zertifikat prüfen (automatisch via Let's Encrypt)
- [ ] Backup-Test durchführen

---

## Beispiel: Vollständiger Ablauf

```bash
# 1. API-Key vorbereiten (einmalig)
echo 'abc123...' > /root/.mailcow-api-key
chmod 600 /root/.mailcow-api-key

# 2. Domain hinzufügen
/srv/scripts/add-domain.sh neue-domain.de

# Output:
# ================================
#   Domain Setup Script
# ================================
#
# ✓ Domain validated: neue-domain.de
# ✓ Mailcow API key loaded
#
# ℹ Setting up domain: neue-domain.de
# ℹ Admin email: admin@wolfgang-burger.de
# ℹ Website path: /var/www/neue-domain.de (default)
#
# Continue? (y/N): y
#
# Step 1: Mailcow Configuration
# ----------------------------
# ℹ Adding domain to Mailcow: neue-domain.de
# ✓ Domain added to Mailcow: neue-domain.de
# ℹ Creating alias: info@neue-domain.de → admin@wolfgang-burger.de
# ✓ Alias created: info@neue-domain.de → admin@wolfgang-burger.de
# ℹ Creating alias: postmaster@neue-domain.de → admin@wolfgang-burger.de
# ✓ Alias created: postmaster@neue-domain.de → admin@wolfgang-burger.de
#
# Step 2: Caddy Configuration
# ---------------------------
# ✓ Caddy config created: /srv/caddy/sites/neue-domain.de.caddy
# ✓ Website directory created: /var/www/neue-domain.de
# ✓ Caddy reloaded successfully
#
# Step 3: DNS Configuration
# -------------------------
# [DNS Records werden angezeigt]
#
# ================================
#   Setup Complete!
# ================================

# 3. DNS-Records hinzufügen (bei deinem Registrar)

# 4. Warten und testen
sleep 1800  # 30 Minuten
curl -I https://neue-domain.de
```

---

## Support & Hilfe

### Bei Problemen:
1. Prüfe Logs: `/var/log/caddy/domain.com.log`
2. Prüfe Mailcow-Logs: `docker logs mailcowdockerized-nginx-mailcow-1`
3. Prüfe DNS: `dig domain.com`
4. Prüfe Caddy: `docker logs caddy-webserver`

### Nützliche Befehle:
```bash
# Domain-Liste in Mailcow
curl -H "X-API-Key: $(cat /root/.mailcow-api-key)" \
     https://mail.clocklight.de/api/v1/get/domain/all | jq

# Alias-Liste
curl -H "X-API-Key: $(cat /root/.mailcow-api-key)" \
     https://mail.clocklight.de/api/v1/get/alias/all | jq

# Caddy-Sites auflisten
ls -la /srv/caddy/sites/

# Aktive Websites
docker exec caddy-webserver caddy list-modules | grep http
```

---

**Erstellt:** 27. Dezember 2025
**Version:** 1.0
**Maintainer:** Wolfgang Burger
**Support:** admin@wolfgang-burger.de
