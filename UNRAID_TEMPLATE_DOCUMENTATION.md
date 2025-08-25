# Unraid Template Documentation for Nextcloud Sync Container

This document provides comprehensive instructions for installing and configuring the Nextcloud Sync Container on Unraid using the Community Applications (CA) plugin.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Advanced Settings](#advanced-settings)
5. [Monitoring and Maintenance](#monitoring-and-maintenance)
6. [Troubleshooting](#troubleshooting)
7. [Security Best Practices](#security-best-practices)
8. [Backup and Recovery](#backup-and-recovery)

## Prerequisites

### System Requirements

- **Unraid Version**: 6.8.0 or later
- **Available Disk Space**: Sufficient space on your array or cache drive for synchronized data
- **Network Access**: Reliable internet connection to reach your Nextcloud server
- **Community Applications Plugin**: Must be installed for easy template access

### Nextcloud Requirements

- **Nextcloud Server**: Version 20.0 or later recommended
- **User Account**: Valid Nextcloud user account with file access permissions
- **App Password**: Strongly recommended for security (see Security Best Practices section)

### Installing Community Applications Plugin

If you haven't already installed the Community Applications plugin:

1. Navigate to **Apps** tab in Unraid
2. Click **Install** next to "Community Applications"
3. Wait for installation to complete
4. The **Apps** tab will now show available community applications

## Installation

### Method 1: Through Community Applications (Recommended)

1. **Access Apps Section**
   - Navigate to the **Apps** tab in your Unraid web interface
   - Click on **Community Applications**

2. **Search for the Container**
   - In the search bar, type "nextcloud-sync"
   - Look for the template by dkuhnke

3. **Install the Template**
   - Click on the **nextcloud-sync** template
   - Click **Install**
   - The configuration page will open

### Method 2: Manual Template Installation

If the template is not yet available in Community Applications:

1. **Download Template**
   - Download the `nextcloud-sync.xml` file from the GitHub repository
   - Save it to your Unraid flash drive at `/boot/config/plugins/dockerMan/templates-user/`

2. **Refresh Docker Templates**
   - Go to **Docker** tab in Unraid
   - Click **Add Container**
   - Select **nextcloud-sync** from the template dropdown

## Configuration

### Required Settings

#### Basic Configuration

| Setting | Description | Example |
|---------|-------------|---------|
| **Container Name** | Name for your container instance | `nextcloud-sync` |
| **Nextcloud Username** | Your Nextcloud login username | `john.doe` |
| **Nextcloud Password/Token** | App password or user password | `abcd-efgh-ijkl-mnop` |
| **Nextcloud Server URL** | Your Nextcloud server hostname | `cloud.example.com` |
| **Local Data Directory** | Path where data will be synchronized | `/mnt/user/nextcloud-sync/` |

#### Detailed Configuration Steps

1. **Container Name**
   - Use a descriptive name like `nextcloud-sync`
   - Avoid spaces and special characters

2. **Nextcloud Username**
   - Enter your exact Nextcloud username
   - Case-sensitive, must match your Nextcloud login

3. **Nextcloud Password/Token**
   - **Recommended**: Use an app-specific password (see Security section)
   - **Alternative**: Your regular Nextcloud password (less secure)

4. **Nextcloud Server URL**
   - Enter only the hostname/domain (e.g., `cloud.example.com`)
   - Do NOT include `http://` or `https://`
   - Do NOT include paths like `/nextcloud`

5. **Local Data Directory**
   - Choose a location on your Unraid system
   - Recommended: `/mnt/user/nextcloud-sync/` for user share
   - Alternative: `/mnt/cache/nextcloud-sync/` for cache drive only
   - The container will create subdirectories as needed

### Optional Settings

| Setting | Default | Description | Recommended Values |
|---------|---------|-------------|-------------------|
| **Sync Interval** | `300` | Seconds between sync attempts | `300` (5 min) to `3600` (1 hour) |
| **Retry Attempts** | `4` | Number of retry attempts on failure | `4` to `10` for unstable connections |
| **Run Once Mode** | `false` | Run once and exit vs. continuous operation | `false` for continuous sync |
| **Log Directory** | (empty) | Optional persistent log storage | `/mnt/user/appdata/nextcloud-sync/logs/` |

## Advanced Settings

### Network Configuration

- **Network Type**: Bridge (default and recommended)
- **Extra Parameters**: Usually not needed
- **Privileged Mode**: Keep disabled for security

### Resource Limits

For systems with limited resources, consider setting:

```
--memory=512m --cpus=1
```

Add these to the "Extra Parameters" field if needed.

### Multiple Nextcloud Accounts

To sync multiple Nextcloud accounts:

1. Create separate container instances
2. Use different container names (e.g., `nextcloud-sync-work`, `nextcloud-sync-personal`)
3. Configure different local directories for each
4. Use appropriate credentials for each account

### Scheduling with User Scripts

For one-time sync operations, use Unraid's User Scripts plugin:

1. Install User Scripts plugin from Community Applications
2. Create a new script with the following content:

```bash
#!/bin/bash
docker run --rm \
  -e NEXTCLOUD_USER="your_username" \
  -e NEXTCLOUD_PASS="your_password" \
  -e NEXTCLOUD_URL="your-nextcloud.example.com" \
  -e NEXTCLOUD_RUN_ONCE=true \
  -v /mnt/user/nextcloud-sync:/media/nextclouddata \
  dkuhnke/nextcloud-sync
```

3. Schedule the script to run at desired intervals

## Monitoring and Maintenance

### Viewing Logs

1. **Real-time Logs**
   - Go to **Docker** tab
   - Click the container icon for nextcloud-sync
   - Select **Logs**

2. **Persistent Logs** (if configured)
   - Access the log directory you configured
   - Logs are stored with timestamps for easy analysis

### Log Analysis

Look for these key indicators:

- ✅ **Successful sync**: `Synchronization completed successfully`
- ❌ **Connection issues**: `Connection to Nextcloud failed`
- 🔄 **Retry attempts**: Shows when retries are occurring
- 😴 **Sleep cycles**: Normal operation between syncs

### Container Health Monitoring

Use Unraid's built-in monitoring or consider:

- **Notifications**: Set up Unraid notifications for container stop/start events
- **Monitoring Tools**: Use tools like Netdata or Grafana for advanced monitoring

### Updates

The container automatically updates the system daily. To update the container image:

1. Go to **Docker** tab
2. Check for updates
3. Click **Update** when available
4. The container will restart with the new image

## Troubleshooting

### Common Issues

#### 1. Authentication Failures

**Symptoms**: `Authentication failed` or `401 Unauthorized` errors

**Solutions**:
- Verify username and password are correct
- Try creating a new app password in Nextcloud
- Check for special characters in credentials
- Ensure the user account is not disabled

#### 2. Connection Timeouts

**Symptoms**: `Connection timeout` or `Host unreachable` errors

**Solutions**:
- Verify the Nextcloud URL is correct and accessible
- Test connectivity: `ping your-nextcloud-server.com`
- Check your router/firewall settings
- Increase retry attempts if using unstable connection

#### 3. Permission Errors

**Symptoms**: `Permission denied` on local directory

**Solutions**:
- Ensure the local directory exists and is writable
- Check Unraid file permissions
- Verify the path is correct and accessible

#### 4. SSL Certificate Issues

**Symptoms**: `SSL certificate verification failed`

**Solutions**:
- Ensure your Nextcloud server has a valid SSL certificate
- For self-signed certificates, additional configuration may be needed
- Contact your Nextcloud administrator if using a managed service

### Debug Mode

For detailed troubleshooting:

1. Stop the container
2. Add to "Extra Parameters": `--log-level debug`
3. Start the container and monitor logs for detailed output

### Getting Help

1. **Check Logs**: Always review container logs first
2. **Unraid Forums**: Post in the Docker support section
3. **GitHub Issues**: Report bugs at the project repository
4. **Documentation**: Review the complete README on GitHub

## Security Best Practices

### App Passwords (Highly Recommended)

Instead of using your main Nextcloud password:

1. **Log into Nextcloud Web Interface**
2. **Navigate to Settings**
   - Click your profile picture/avatar
   - Select "Personal settings"

3. **Go to Security Section**
   - Find "Devices & sessions" or "Security"
   - Look for "App passwords" section

4. **Create New App Password**
   - Enter a descriptive name: "Unraid Sync"
   - Click "Create new app password"
   - Copy the generated password immediately

5. **Use in Container Configuration**
   - Paste the app password in the "Nextcloud Password/Token" field
   - This provides limited access and can be revoked if needed

### Environment File (Alternative Method)

For enhanced security, you can use environment files:

1. Create `/mnt/user/appdata/nextcloud-sync/.env`:
```
NEXTCLOUD_USER=your_username
NEXTCLOUD_PASS=your_app_password
NEXTCLOUD_URL=your-nextcloud.example.com
```

2. Add to container Extra Parameters: `--env-file /mnt/user/appdata/nextcloud-sync/.env`

### Network Security

- Ensure your Nextcloud server uses HTTPS
- Keep your Unraid system updated
- Use strong, unique passwords
- Regularly rotate app passwords

## Backup and Recovery

### Backing Up Configuration

1. **Container Configuration**
   - Unraid automatically backs up container configurations
   - Additional backup: Export container settings from Docker tab

2. **Synchronized Data**
   - The local sync directory contains your Nextcloud data
   - Include this directory in your regular Unraid backup strategy
   - Consider using Unraid's built-in backup solutions

### Recovery Procedures

1. **Container Recovery**
   - Reinstall container using the same template
   - Restore configuration from backup
   - Data should remain intact in the local directory

2. **Data Recovery**
   - If local data is lost, the container will re-download from Nextcloud
   - If Nextcloud data is lost, restore from local directory backup

### Disaster Recovery Planning

1. **Document Configuration**
   - Keep records of your container settings
   - Note custom paths and configurations

2. **Test Recovery Procedures**
   - Periodically test container reinstallation
   - Verify data integrity after recovery

3. **Multiple Backup Strategies**
   - Use both Nextcloud sync and traditional backups
   - Consider off-site backup solutions for critical data

---

## Support and Resources

- **Project Repository**: https://github.com/dkuhnke/nextcloud-sync
- **Issue Tracker**: https://github.com/dkuhnke/nextcloud-sync/issues
- **Unraid Forums**: https://forums.unraid.net/
- **Docker Hub**: https://hub.docker.com/r/dkuhnke/nextcloud-sync

For additional help, please provide:
- Container logs
- Unraid version
- Nextcloud server version
- Complete error messages
- Steps to reproduce the issue

---

**Last Updated**: August 2025  
**Template Version**: 1.0  
**Compatible Unraid Versions**: 6.8.0+
