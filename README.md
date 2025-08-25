# Nextcloud Sync Container

![Docker](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)

An automated Docker container for continuous synchronization of Nextcloud data with advanced error handling and retry functionality.

## 🌟 Features

- **Continuous Synchronization** - Configurable sync intervals for automated data synchronization
- **Automatic Retry Logic** - Built-in retry mechanism for connection failures with exponential backoff
- **Graceful Shutdown** - Signal handling for clean container stops
- **Daily System Updates** - Automatic system maintenance and security updates
- **Comprehensive Logging** - Detailed logging with timestamps for monitoring and debugging
- **Health Checks** - Connectivity and permission validation before sync operations
- **Flexible Modes** - One-time sync or continuous operation modes
- **Error Recovery** - Robust error handling with configurable retry attempts

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

## 📊 Monitoring and Logging

### View Logs

```bash
# Follow logs in real-time
docker logs -f nextcloud-sync

# View last 100 lines
docker logs --tail 100 nextcloud-sync
```

### Log Format

The container provides structured logging with timestamps:

```
[2025-08-25 10:30:00] 🔄 Starting Nextcloud synchronization...
[2025-08-25 10:30:01] ✅ Connection to Nextcloud successful
[2025-08-25 10:30:02] 📂 Synchronizing data...
[2025-08-25 10:30:15] ✅ Synchronization completed successfully
[2025-08-25 10:30:15] 😴 Sleeping for 300 seconds...
```

## 🐛 Troubleshooting

### Common Issues

#### Connection Failed
```
❌ Connection to Nextcloud failed after 4 attempts
```
- Verify `NEXTCLOUD_URL` is correct and accessible
- Check username and password/app token
- Ensure Nextcloud server is running

#### Permission Denied
```
❌ Permission denied accessing /media/nextclouddata
```
- Check volume mount permissions
- Ensure the user inside container can write to `/media/nextclouddata`

#### SSL Certificate Issues
- For self-signed certificates, the container may reject connections
- Consider using proper SSL certificates or configuring certificate acceptance

### Debug Mode

Enable detailed logging by examining container logs:

```bash
docker logs -f nextcloud-sync 2>&1 | grep -E "(ERROR|WARN|❌)"
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

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [troubleshooting section](#-troubleshooting)
2. Review existing [issues](https://github.com/dkuhnke/nextcloud-sync/issues)
3. Create a new issue with detailed information

## 🔗 Related Projects

- [Nextcloud Desktop Client](https://github.com/nextcloud/desktop)
- [Nextcloud Docker](https://github.com/nextcloud/docker)

---

**Author:** dkuhnke  
**Version:** 1.0  
**Last Updated:** August 2025
