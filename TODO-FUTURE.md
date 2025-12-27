# Future TODOs - Server-Optimierungen

**Erstellt:** 27. Dezember 2025
**Status:** Geparkt für später

---

## 🔮 Cloudflare-Integration (Hybrid-Setup)

### Ziel:
Cloudflare für statische Websites einrichten (clocklight.de, wolfgang-burger.de)

### Voraussetzungen:
- Domain-Registrar finden (wo ist clocklight.de registriert?)
- Nameserver-Zugriff klären
- Cloudflare-Account erstellen

### Vorteile:
- ✅ 70-90% schnellere Ladezeiten weltweit (CDN)
- ✅ DDoS-Schutz auf Netzwerk-Ebene
- ✅ Web Application Firewall (WAF)
- ✅ Bot-Protection
- ✅ Analytics & Insights
- ✅ 80-90% weniger Server-Last
- ✅ Komplett kostenlos (Free Tier)

### Dokumentation:
- `/srv/CLOUDFLARE-SETUP-GUIDE.md` - Vollständige Anleitung
- `/srv/CLOUDFLARE-VS-RATE-LIMITING.md` - Vergleich & Entscheidungshilfe
- `/srv/HETZNER-DNS-CLOUDFLARE.md` - Hetzner-spezifische Anleitung

### Nächste Schritte (wenn bereit):
1. Domain-Registrar herausfinden
2. Prüfen ob Nameserver-Wechsel möglich
3. Cloudflare-Account erstellen
4. DNS zu Cloudflare migrieren

### Zeitaufwand:
~1-2 Stunden (einmalig)

---

## 🔧 Caddy Rate Limiting (Alternative)

### Problem:
Caddy Standard-Build hat **kein** Rate-Limiting-Modul.

### Lösung erfordert:
1. **Custom Caddy-Build** mit rate-limit Plugin
   - Plugin: https://github.com/mholt/caddy-ratelimit
   - Erfordert: Caddy neu kompilieren oder custom Docker-Image

### Alternative Lösungen:

#### Option A: Cloudflare (EMPFOHLEN)
- Rate Limiting ist in Cloudflare Free Tier enthalten
- Kein Custom-Build nötig
- Einfacher

#### Option B: Nginx vor Caddy
- Nginx als Reverse Proxy vor Caddy
- Nginx hat natives Rate Limiting
- Aufwändiger Setup

#### Option C: iptables/nftables Rate Limiting
- Kernel-Level Rate Limiting
- Komplex zu konfigurieren
- Für fortgeschrittene User

### Empfehlung:
**Warte auf Cloudflare-Setup** - dann ist Rate Limiting inklusive.

---

## ✅ Aktuelle Schutzmaßnahmen (bereits aktiv)

### Du bist bereits gut geschützt:

1. **SSH-Schutz:**
   - ✅ Fail2ban aktiv (5 Versuche → 24h Ban)
   - ✅ Root-Login nur mit SSH-Key
   - ✅ Passwort-Auth deaktiviert
   - ✅ Security Headers aktiv

2. **Mailserver-Schutz:**
   - ✅ Fail2ban für Mailcow (Auth + Postfix)
   - ✅ Postfix Rate Limiting (Mailcow-integriert)
   - ✅ Rspamd Rate Limiting (Spam-Schutz)
   - ✅ Greylisting aktiv

3. **Webserver-Schutz:**
   - ✅ Security Headers (HSTS, X-Frame-Options, etc.)
   - ✅ SSL/TLS via Let's Encrypt
   - ✅ Port-Restriktionen (8090 nur localhost)

4. **Monitoring:**
   - ✅ Beszel System-Monitoring
   - ✅ Mailcow Alerting
   - ✅ Tägliche Status-Reports

### Sicherheitslevel: 🟢 GUT

**Für kleine bis mittlere Websites völlig ausreichend!**

---

## 📊 Weitere Optimierungen (Nice-to-have)

### Performance:
- [ ] Redis-Caching für Websites (falls dynamisch)
- [ ] Image-Optimization (WebP, Lazy-Loading)
- [ ] HTTP/3 aktivieren (in Caddy verfügbar)

### Security:
- [ ] 2FA für SSH (Google Authenticator)
- [ ] SSH-Port ändern (Port 22 → Custom)
- [ ] Backup-Verschlüsselung (GPG)
- [ ] Intrusion Detection (AIDE)

### Monitoring:
- [ ] Uptime-Monitoring (UptimeRobot, etc.)
- [ ] Log-Aggregation (Loki + Grafana)
- [ ] APM (Application Performance Monitoring)

---

## 🎯 Prioritäten

### Jetzt:
- ✅ **Nichts mehr** - System läuft stabil und sicher!

### Bald (nächste Wochen):
- 🔮 **Cloudflare einrichten** (wenn Nameserver geklärt)
  - DDoS-Schutz
  - Rate Limiting
  - CDN
  - Analytics

### Später (bei Bedarf):
- 2FA für SSH
- Backup-Verschlüsselung
- Uptime-Monitoring

---

## 📝 Notes

### Warum kein Caddy Rate Limiting jetzt?
- Standard Caddy-Build hat kein rate_limit Modul
- Custom-Build wäre zu aufwändig
- Cloudflare bietet bessere Lösung
- Aktuelle Schutzmaßnahmen reichen aus

### Warum Cloudflare warten?
- Nameserver-Zugriff muss erst geklärt werden
- Domain-Registrar muss identifiziert werden
- Setup erfordert Zeit (1-2h)
- Aktuell kein dringender Bedarf

---

## 🎖️ Was bereits erreicht wurde (27.12.2025)

### Dokumentation:
- ✅ SERVER-OPTIMIZATION.md
- ✅ SYSTEM-OVERVIEW.md
- ✅ SECURITY-RECOMMENDATIONS.md
- ✅ CLOUDFLARE-SETUP-GUIDE.md
- ✅ CLOUDFLARE-VS-RATE-LIMITING.md
- ✅ HETZNER-DNS-CLOUDFLARE.md

### Security-Verbesserungen:
- ✅ SSH gehärtet (Key-only, kein Passwort)
- ✅ Security Headers (alle Sites)
- ✅ Port 8090 auf localhost
- ✅ Beszel Monitoring
- ✅ Fail2ban aktiv

### Backup-System:
- ✅ Config-Backups täglich
- ✅ Beszel-Daten in Backups
- ✅ Git-Repository aktiv

**Status:** 🟢 Produktiv & Sicher

---

**Erstellt:** 27. Dezember 2025
**Letztes Update:** 27. Dezember 2025
**Nächste Review:** Bei Bedarf
