# Fail2ban SSH Protection

Automatischer Schutz gegen Brute-Force-Angriffe auf SSH.

## Status

✅ **AKTIV** seit 25. Dezember 2025

## Konfiguration

### SSH Jail (`/etc/fail2ban/jail.d/sshd.conf`)

```ini
[sshd]
enabled = true
backend = systemd

# Nach 5 fehlgeschlagenen Versuchen...
maxretry = 5

# ...innerhalb von 10 Minuten...
findtime = 10m

# ...wird die IP für 24 Stunden gebannt
bantime = 24h

# Wiederholungstäter werden progressiv länger gebannt
bantime.increment = true
bantime.factor = 2
bantime.maxtime = 168h  # Max. 7 Tage
```

### Ban-Eskalation

| Verstoß | Ban-Dauer |
|---------|-----------|
| 1. Mal | 24 Stunden |
| 2. Mal | 48 Stunden |
| 3. Mal | 96 Stunden (4 Tage) |
| 4. Mal | 168 Stunden (7 Tage) |

## Verwendung

### Status prüfen
```bash
# Alle Jails
fail2ban-client status

# SSH Jail Details
fail2ban-client status sshd
```

### Gebannte IPs anzeigen
```bash
fail2ban-client status sshd | grep "Banned IP"
```

### IP manuell bannen
```bash
fail2ban-client set sshd banip 1.2.3.4
```

### IP entbannen
```bash
fail2ban-client set sshd unbanip 1.2.3.4
```

### Logs ansehen
```bash
# Fail2ban Log
tail -f /var/log/fail2ban.log

# Nur Bans
grep "Ban " /var/log/fail2ban.log | tail -20
```

## Statistiken

Im täglichen Monitoring-Report (2:00 Uhr) werden SSH-Angriffe und Bans automatisch gemeldet.

## Wichtige Dateien

| Datei | Beschreibung |
|-------|--------------|
| `/etc/fail2ban/jail.local` | Haupt-Konfiguration |
| `/etc/fail2ban/jail.d/sshd.conf` | SSH Jail Einstellungen |
| `/var/log/fail2ban.log` | Fail2ban Logfile |

## Backup im Repository

Die Konfiguration ist gesichert unter:
- `/srv/config/fail2ban/jail.local`
- `/srv/config/fail2ban/sshd.conf`

## Wiederherstellung

```bash
# Konfiguration wiederherstellen
cp /srv/config/fail2ban/jail.local /etc/fail2ban/
cp /srv/config/fail2ban/sshd.conf /etc/fail2ban/jail.d/

# Fail2ban neu laden
fail2ban-client reload
```

## Monitoring Integration

✅ SSH-Angriffe werden im Daily Report gezählt
✅ Fail2ban Bans werden im Daily Report angezeigt
✅ Aktuell geblockte IPs werden gemeldet

Erstellt: 25. Dezember 2025
