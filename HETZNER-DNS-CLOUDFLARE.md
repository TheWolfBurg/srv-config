# Cloudflare mit Hetzner DNS - Anleitung

**Problem:** Hetzner erlaubt keine Nameserver-Änderung im Standard-DNS-Panel
**Lösung:** 2 Optionen verfügbar

---

## Aktuelle Situation

### Deine Nameserver (Hetzner):
```
ns1.your-server.de
ns3.second-ns.de
ns.second-ns.com
```

**Das bedeutet:** Domain-DNS wird aktuell über Hetzner verwaltet.

---

## Option 1: Hetzner Konsole verwenden (EMPFOHLEN)

### Wo sind die Nameserver-Einstellungen?

#### Bei Hetzner gibt es 2 verschiedene Panels:

### A) Hetzner Robot (für dedizierte Server)
**URL:** https://robot.hetzner.com

**Schritte:**
1. Einloggen
2. **Nicht im Robot selbst** - Robot verwaltet nur Server, nicht DNS!

### B) Hetzner Konsole (für Cloud & DNS)
**URL:** https://console.hetzner.cloud

**Schritte:**
1. Einloggen
2. **Links:** Klicke auf "DNS"
3. Wähle Domain: **clocklight.de**
4. **HIER IST DAS PROBLEM:**
   - Hetzner DNS-Console hat KEINE Nameserver-Einstellung
   - Nur DNS-Records können bearbeitet werden

### C) Hetzner Domain-Registrierung
**URL:** https://accounts.hetzner.com

**Falls Domain bei Hetzner registriert:**
1. Einloggen bei https://accounts.hetzner.com
2. **Produkte** > **Domains**
3. Domain **clocklight.de** auswählen
4. **Nameserver** Reiter
5. Dort können Nameserver geändert werden

**⚠️ WICHTIG:**
Wenn du hier KEINE Nameserver-Einstellung siehst, ist die Domain NICHT bei Hetzner registriert, sondern nur DNS wird dort gehostet!

---

## Option 2: Cloudflare OHNE Nameserver-Wechsel (Alternative)

### Methode: DNS-Records direkt bei Hetzner auf Cloudflare zeigen

**Vorteil:**
- ✅ Nameserver bleiben bei Hetzner
- ✅ Cloudflare funktioniert trotzdem
- ✅ Einfacher

**Nachteil:**
- ⚠️ Nicht alle Cloudflare-Features verfügbar
- ⚠️ Erfordert Pro-Plan (kostenpflichtig) für volles CNAME-Setup

### Kostenlose Alternative: Cloudflare Partner-Setup

**Achtung:** Cloudflare hat 2021 das Partner-Programm eingestellt.
Diese Option ist **NICHT mehr verfügbar**.

---

## Option 3: Domain zu anderem Registrar transferieren

### Falls Domain NICHT bei Hetzner registriert ist:

**Wo ist die Domain registriert?**

Finde es heraus:
```bash
whois clocklight.de | grep -i registrar
```

**Mögliche Registrars:**
- Namecheap
- GoDaddy
- Google Domains (jetzt Squarespace)
- IONOS
- Strato
- United Domains
- etc.

**Bei jedem dieser Registrars:**
1. Einloggen
2. Domain-Management
3. Nameserver ändern (meist unter "DNS" oder "Nameservers")

---

## Option 4: Hybrid-Lösung - Nur www durch Cloudflare

### Trick: www-Subdomain durch CF, Root-Domain direkt

**Bei Hetzner DNS:**

```
# Root-Domain direkt
Type: A
Name: @
Value: 46.224.122.105

# www durch Cloudflare (CNAME zu CF)
Type: CNAME
Name: www
Value: [dein-cf-subdomain].cdn.cloudflare.net
```

**Problem:** Erfordert Cloudflare Pro ($20/Monat) für CNAME-Setup

---

## EMPFOHLENE LÖSUNG für dich

### Prüfe zuerst: Wo ist die Domain registriert?

```bash
whois clocklight.de | grep -i "registrar\|registration"
```

### Falls bei Hetzner registriert:
→ Gehe zu https://accounts.hetzner.com
→ Domains → clocklight.de → Nameserver ändern

### Falls NICHT bei Hetzner registriert:
→ Gehe zum richtigen Registrar
→ Dort Nameserver ändern

### Falls Nameserver-Wechsel unmöglich:

**Alternative: Nur Caddy Rate Limiting verwenden**
- Kein Cloudflare nötig
- Volle Kontrolle
- Datenschutz-freundlich
- Kein DDoS-Schutz, aber ausreichend für kleine Sites

---

## Schritt-für-Schritt: Domain-Registrar finden

### 1. Whois-Abfrage

```bash
whois clocklight.de
```

**Suche nach:**
- "Registrar:" → Zeigt wer die Domain verwaltet
- "Registrar URL:" → Wo du dich einloggen musst

### 2. Typische Hetzner-Anzeichen

**Domain bei Hetzner registriert:**
- Registrar: Hetzner Online GmbH
- Registrar URL: https://hetzner.de

**Nur DNS bei Hetzner:**
- Registrar: NICHT Hetzner
- Name Server: ns1.your-server.de (Hetzner NS)

### 3. Beim richtigen Registrar einloggen

**Login-Portale verschiedener Anbieter:**

| Registrar | Login-URL |
|-----------|-----------|
| Hetzner | https://accounts.hetzner.com |
| Namecheap | https://www.namecheap.com/myaccount/login/ |
| GoDaddy | https://sso.godaddy.com/ |
| IONOS | https://www.ionos.de/login |
| Strato | https://www.strato.de/apps/CustomerService |
| Google Domains | https://domains.google.com/ |

---

## Schnelltest: Domain-Registrar herausfinden

Führe diesen Befehl aus:

```bash
whois clocklight.de | grep -iE "registrar|registration" | grep -v "https" | head -5
```

**Resultat interpretieren:**

```
Registrar: Hetzner Online GmbH
→ Domain bei Hetzner registriert
→ Login: https://accounts.hetzner.com

Registrar: Namecheap, Inc.
→ Domain bei Namecheap registriert
→ Login: https://www.namecheap.com

Registrar: GoDaddy.com, LLC
→ Domain bei GoDaddy registriert
→ Login: https://sso.godaddy.com/
```

---

## Falls Hetzner KEINE Nameserver-Änderung erlaubt

### Plan B: Cloudflare verzichten

**Setze stattdessen um:**

1. **Caddy Rate Limiting** (bereits vorbereitet)
   - Schützt vor Overload
   - Kostenlos
   - Einfach

2. **Mailcow Rate Limiting** (bereits aktiv)
   - Postfix
   - Rspamd
   - Fail2ban

3. **Fail2ban** (bereits aktiv)
   - SSH-Schutz
   - Mailserver-Schutz

**Ergebnis:**
- ✅ Gute Basis-Sicherheit
- ✅ Kein DDoS-Schutz (aber für kleine Sites meist nicht nötig)
- ✅ Volle Kontrolle
- ✅ Datenschutz

---

## Entscheidungshilfe

### Cloudflare lohnt sich, wenn:
- ✅ Viel internationaler Traffic
- ✅ Hohe Performance wichtig
- ✅ DDoS-Risiko besteht
- ✅ Nameserver änderbar

### Cloudflare NICHT nötig, wenn:
- ✅ Nur deutscher Traffic
- ✅ Kleine Website
- ✅ Kein DDoS-Risiko
- ✅ Datenschutz wichtiger als Performance

**Für clocklight.de:**
Wahrscheinlich reicht Caddy Rate Limiting aus.

---

## Meine Empfehlung

### 1. Finde heraus wo Domain registriert ist

```bash
whois clocklight.de | grep -i registrar
```

### 2a. Falls bei Hetzner:
- Login: https://accounts.hetzner.com
- Nameserver ändern

### 2b. Falls woanders:
- Bei richtigem Registrar einloggen
- Nameserver ändern

### 2c. Falls nicht änderbar:
- **Verzichte auf Cloudflare**
- Nutze **Caddy Rate Limiting**
- **Gute Basis-Sicherheit ist bereits vorhanden**

---

## Caddy Rate Limiting als Alternative

### Falls du Cloudflare nicht einrichten kannst/willst:

```caddy
# /srv/caddy/snippets/rate_limiting.caddy
rate_limit {
    zone dynamic {
        key {remote_host}
        events 100
        window 1m
    }
}
```

**Einbinden in Sites:**
```caddy
clocklight.de, www.clocklight.de {
    import ../snippets/rate_limiting.caddy
    import ../snippets/compression.caddy
    import ../snippets/security_headers.caddy

    root * /var/www/clocklight.de
    file_server
}
```

**Soll ich das für dich einrichten?**

---

## Zusammenfassung

**Problem:** Hetzner DNS-Panel hat keine Nameserver-Einstellung

**Lösung:**
1. Prüfe ob Domain bei Hetzner registriert ist (accounts.hetzner.com)
2. Falls ja → Dort Nameserver ändern
3. Falls nein → Beim richtigen Registrar ändern
4. Falls unmöglich → Caddy Rate Limiting nutzen (Plan B)

**Nächster Schritt:**
Sag mir, was `whois clocklight.de | grep -i registrar` ausgibt.

---

**Erstellt:** 27. Dezember 2025
