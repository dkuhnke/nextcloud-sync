# Nextcloud Sync Container

![Docker](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)
![Alpine](https://img.shields.io/badge/Base-Alpine%203.22.1-0D597F?logo=alpine-linux)
![Security](https://img.shields.io/badge/Security-Hardened-green?logo=security)

An automated Docker container for continuous synchronization of Nextcloud data with advanced error handling and retry functionality, optimized for minimal CVE exposure.

## 🌟 Features

- **Continuous Synchronization** - Configurable sync intervals for automated data synchronization
- **Automatic Retry Logic** - Built-in retry mechanism for connection failures with exponential backoff strategy
- **Graceful Shutdown** - Signal handling for clean container stops
- **Comprehensive Logging** - Detailed logging with timestamps for monitoring and debugging
- **Health Checks** - Connectivity and permission validation before sync operations
- **Flexible Modes** - One-time sync or continuous operation modes
- **Error Recovery** - Robust error handling with configurable retry attempts
- **🔒 Security-optimized** - Alpine Linux 3.22.1 base for minimal CVE exposure
- **📦 Minimal Dependencies** - Only `nextcloud-client` and `bash` for reduced attack surface
- **🛡️ Non-root Execution** - Container runs as unprivileged user for enhanced security

## 🚀 Quick Start

### Basic Usage

```bash
docker run -d \
  --name nextcloud-sync \
  -e NEXTCLOUD_USER="your_username" \
  -e NEXTCLOUD_PASS="your_password" \
  -e NEXTCLOUD_URL="your-nextcloud.example.com" \
  -v /path/to/local/data:/media/nextclouddata \
  dkuhnke/nextcloud-sync
```

### Docker Compose

```yaml
version: '3.8'

services:
  nextcloud-sync:
    image: dkuhnke/nextcloud-sync
    container_name: nextcloud-sync
    restart: unless-stopped
    environment:
      - NEXTCLOUD_USER=your_username
      - NEXTCLOUD_PASS=your_password
      - NEXTCLOUD_URL=your-nextcloud.example.com
      - NEXTCLOUD_SLEEP=300
      - NEXTCLOUD_SYNC_RETRIES=4
      - NEXTCLOUD_RUN_ONCE=false
    volumes:
      - ./data:/media/nextclouddata
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## ⚙️ Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXTCLOUD_USER` | Nextcloud username | `john.doe` |
| `NEXTCLOUD_PASS` | Nextcloud app password | `your-secure-password` |
| `NEXTCLOUD_URL` | Nextcloud server URL | `cloud.example.com` |

### Optional Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `NEXTCLOUD_SLEEP` | Sleep interval between syncs (seconds) | `300` | `600` |
| `NEXTCLOUD_SYNC_RETRIES` | Number of retry attempts on failure | `4` | `10` |
| `NEXTCLOUD_RUN_ONCE` | Run sync once and exit | `false` | `true` |

## 📁 Volume Mapping

The container expects your local data directory to be mounted at `/media/nextclouddata`:

```bash
-v /your/local/path:/media/nextclouddata
```

This directory will be synchronized with your Nextcloud instance.

## 🔧 Advanced Configuration

### One-time Sync

For a single synchronization without continuous operation:

```bash
docker run --rm \
  -e NEXTCLOUD_USER="your_username" \
  -e NEXTCLOUD_PASS="your_password" \
  -e NEXTCLOUD_URL="your-nextcloud.example.com" \
  -e NEXTCLOUD_RUN_ONCE=true \
  -v /path/to/local/data:/media/nextclouddata \
  dkuhnke/nextcloud-sync
```

### Custom Sync Interval

Set a custom sync interval (e.g., every 10 minutes):

```bash
docker run -d \
  -e NEXTCLOUD_SLEEP=600 \
  # ... other environment variables
  dkuhnke/nextcloud-sync
```

### Increased Retry Attempts

For unstable connections, increase retry attempts:

```bash
docker run -d \
  -e NEXTCLOUD_SYNC_RETRIES=10 \
  # ... other environment variables
  dkuhnke/nextcloud-sync
```

## 🔒 Security Improvements

### Alpine Linux Base
- **Minimal CVE Exposure**: Alpine Linux 3.22.1 reduces CVEs by ~80-90% compared to Debian
- **Smaller Attack Surface**: Only essential packages (`nextcloud-client`, `bash`)
- **Security Hardened**: Removal of setuid/setgid binaries and unnecessary files

### Non-root Execution
The container runs as unprivileged `nextcloud` user (UID/GID 1001):
```bash
# Container automatically runs as nextcloud user
USER nextcloud
```

## 🛡️ Security Considerations

### App Tokens (Recommended)

Instead of using your main password, create an app-specific password in Nextcloud:

1. Go to Nextcloud Settings → Security
2. Create a new app password
3. Use the generated token as `NEXTCLOUD_PASS`

### Environment Variables

Store sensitive information securely:

```bash
# Using environment file
docker run --env-file .env dkuhnke/nextcloud-sync
```

### Docker Secrets (Recommended for Production)

For production environments, use Docker Secrets:

```yaml
version: '3.8'

secrets:
  nextcloud_user:
    external: true
  nextcloud_pass:
    external: true

services:
  nextcloud-sync:
    image: dkuhnke/nextcloud-sync
    secrets:
      - nextcloud_user
      - nextcloud_pass
    environment:
      - NEXTCLOUD_URL=cloud.example.com
    # Secrets will be available in /run/secrets/
```

## 🛡️ Security Architecture

### CVE Reduction through Alpine Linux

The migration from Debian to Alpine Linux 3.22.1 brings significant security improvements:

| Aspect | Debian | Alpine Linux | Improvement |
|--------|--------|--------------|-------------|
| **Image Size** | ~124MB | ~5MB | 96% smaller |
| **CVEs** | 70-100 | 5-15 | 80-90% fewer |
| **Packages** | 200+ | < 20 | Minimal installation |
| **Attack Surface** | Large | Minimal | Significantly reduced |

### Security Features

- **Non-root Execution**: Container runs as `nextcloud` user (UID 1001)
- **Minimal Dependencies**: Only `nextcloud-client` and `bash` installed
- **Security Hardening**: Removal of setuid/setgid binaries
- **Clean Filesystem**: Removal of unnecessary files and caches
- **Specific Base Version**: Alpine 3.22.1 for reproducible and secure builds

### Best Practices

1. **Regular Updates**: Rebuild image regularly for latest security patches
2. **Network Isolation**: Run container in isolated Docker networks
3. **Resource Limits**: Define CPU and memory limits
4. **Read-only Filesystem**: When possible, run container with read-only root filesystem
5. **App Passwords**: Never use main login passwords

## 📊 Monitoring and Logging

### View Logs

```bash
# Follow logs in real-time
docker logs -f nextcloud-sync

# View last 100 lines
docker logs --tail 100 nextcloud-sync
```

### Log Format

Der Container bietet strukturierte Protokollierung mit Zeitstempeln:

```
[2025-08-25 10:30:00] � Starting Nextcloud Sync Container v2.4 (Minimal Dependencies)
[2025-08-25 10:30:00]    User: john.doe
[2025-08-25 10:30:00]    URL: cloud.example.com
[2025-08-25 10:30:00]    Retries: 4
[2025-08-25 10:30:00]    Run Once: false
[2025-08-25 10:30:01] ✅ Environment validation successful
[2025-08-25 10:30:01] ✅ Directory permissions validated
[2025-08-25 10:30:02] � Starting continuous sync mode (interval: 300s)
[2025-08-25 10:30:02] 🔄 Sync attempt 1/5
[2025-08-25 10:30:15] ✅ Synchronization completed successfully
[2025-08-25 10:30:15] ⏳ Waiting 300 seconds until next sync...
```

## 🐛 Troubleshooting

### Common Issues

#### Connection Failed
```
❌ All 5 sync attempts failed
```
- Verify `NEXTCLOUD_URL` is correct and accessible
- Check username and password/app token
- Ensure Nextcloud server is running

#### Permission Denied
```
❌ Directory is not writable: /media/nextclouddata
```
- Check volume mount permissions
- Ensure the user inside container can write to `/media/nextclouddata`

#### Environment Variable Errors
```
❌ Missing required environment variables: NEXTCLOUD_USER NEXTCLOUD_PASS
```
- Set all required environment variables
- Check environment variable syntax

### Debug Mode

Enable detailed logging by examining container logs:

```bash
docker logs -f nextcloud-sync 2>&1 | grep -E "(ERROR|WARN|❌)"
```

### Performance Optimization

For large datasets, sync intervals can be adjusted:
```bash
# Longer intervals for large repositories
-e NEXTCLOUD_SLEEP=1800  # 30 minutes
```

## 🏗️ Building from Source

```bash
# Clone the repository
git clone https://github.com/dkuhnke/nextcloud-sync.git
cd nextcloud-sync

# Build the Docker image
docker build -t nextcloud-sync .

# Run your custom build
docker run -d nextcloud-sync
```

### Build Information

- **Base Image**: Alpine Linux 3.22.1
- **Version**: 2.4 (Minimal Dependencies)
- **Security Focus**: Optimized for minimal CVE exposure
- **Dependencies**: `nextcloud-client` + `bash` only

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Security Guidelines

If you find security vulnerabilities, please read [SECURITY_IMPROVEMENTS.md](SECURITY_IMPROVEMENTS.md) for details on security improvements and report issues responsibly.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [troubleshooting section](#-troubleshooting)
2. Review the [security improvements](SECURITY_IMPROVEMENTS.md)
3. Review existing [issues](https://github.com/dkuhnke/nextcloud-sync/issues)
4. Create a new issue with detailed information

## 🔗 Related Projects

- [Nextcloud Desktop Client](https://github.com/nextcloud/desktop)
- [Nextcloud Docker](https://github.com/nextcloud/docker)
- [Alpine Linux Security](https://alpinelinux.org/about/)

---

**Author:** dkuhnke  
**Version:** 2.4  
**Last Updated:** August 2025  
**Security:** Alpine Linux 3.22.1 optimized for minimal CVE exposure
