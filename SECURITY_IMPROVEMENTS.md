# Security Improvements - Alpine Linux Migration

## Übersicht der Optimierungen

Das Dockerfile wurde von Debian auf Alpine Linux migriert, um die Sicherheit zu verbessern und CVEs zu reduzieren.

### Hauptverbesserungen:

#### 🔒 Sicherheit
- **Alpine Linux 3.19**: Deutlich kleinere Angriffsfläche als Debian
- **Non-root User**: Container läuft als `nextcloud` User (UID/GID 1001)
- **Minimal Installation**: Nur notwendige Pakete werden installiert
- **Security Updates**: Automatische tägliche Updates über `apk`

#### 📦 Image-Größe
- **Reduzierte Größe**: Alpine Linux ist ~5MB vs. Debian ~124MB
- **Weniger Pakete**: Nur essentielle Abhängigkeiten
- **Multi-Layer Optimierung**: Effiziente Layer-Struktur

#### 🛡️ CVE Reduzierung
- **Weniger Pakete = Weniger CVEs**: Alpine hat deutlich weniger installierte Pakete
- **Aktuelle Basis**: Alpine 3.19 ist sehr aktuell
- **Minimaler Footprint**: Keine unnötigen Development-Tools oder Libraries

### Installierte Pakete (Alpine):
```
nextcloud-client  # Nextcloud CLI Client
curl             # Für Connectivity Tests  
bash             # Für das runscript.sh
ca-certificates  # Für HTTPS Verbindungen
tzdata           # Timezone Daten
procps           # Für Health Checks
```

### Verbesserter Health Check
- **File-basiert**: Verwendet `/tmp/healthcheck` statt Netzwerk-Tests
- **Zuverlässiger**: Wird bei jeder Log-Ausgabe aktualisiert
- **Weniger Resource-intensiv**: Keine zusätzlichen Netzwerk-Calls

### Weitere Sicherheitsfeatures:
- **.dockerignore**: Verhindert versehentliches Kopieren sensibler Dateien
- **Proper Ownership**: Alle Dateien gehören dem nextcloud User
- **Working Directory**: Sicheres Home-Verzeichnis statt /usr/bin

## Migration von der alten Version

### Build der neuen Version:
```bash
docker build -t nextcloud-sync:alpine .
```

### Vergleich der Image-Größen:
```bash
# Alte Version (Debian)
docker images | grep nextcloud-sync:debian

# Neue Version (Alpine)  
docker images | grep nextcloud-sync:alpine
```

### Verwendung (keine Änderungen erforderlich):
Die Environment Variables und Volume Mounts bleiben identisch:

```yaml
services:
  nextcloud-sync:
    build: .
    environment:
      - NEXTCLOUD_USER=your_username
      - NEXTCLOUD_PASS=your_app_password
      - NEXTCLOUD_URL=cloud.example.com
      - NEXTCLOUD_SLEEP=600
    volumes:
      - ./data:/media/nextclouddata
    restart: unless-stopped
```

## Sicherheitsaudit Empfehlungen

1. **Regelmäßige Updates**: Das Container-Image sollte regelmäßig neu gebaut werden
2. **Secrets Management**: App-Passwörter über Docker Secrets oder Kubernetes Secrets verwalten
3. **Network Policies**: Container in isolierten Netzwerken betreiben
4. **Resource Limits**: CPU und Memory Limits setzen
5. **Read-only Filesystem**: Falls möglich, Container mit read-only Root-Filesystem betreiben

## Erwartete CVE Reduzierung

- **Debian base**: ~70-100 CVEs (je nach Version und installierten Paketen)
- **Alpine base**: ~5-15 CVEs (deutlich weniger aufgrund minimaler Installation)

Die Reduzierung um etwa 80-90% der CVEs ist realistisch erreichbar.
