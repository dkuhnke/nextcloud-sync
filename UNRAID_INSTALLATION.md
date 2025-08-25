# Unraid Installation Guide

This container can be easily installed on Unraid through the Community Applications plugin.

## Quick Installation

1. **Install Community Applications Plugin** (if not already installed)
   - Go to **Apps** tab in Unraid
   - Install "Community Applications"

2. **Search and Install**
   - Open **Apps** → **Community Applications**
   - Search for "nextcloud-sync"
   - Click **Install** on the dkuhnke/nextcloud-sync template

3. **Configure Required Settings**
   - **Nextcloud Username**: Your Nextcloud username
   - **Nextcloud Password**: App password (recommended) or user password
   - **Nextcloud Server URL**: Your server hostname (e.g., `cloud.example.com`)
   - **Local Data Directory**: Path where files will be synced (e.g., `/mnt/user/nextcloud-sync/`)

4. **Apply and Start**
   - Click **Apply** to create and start the container
   - Monitor logs for successful connection and sync

## Manual Template Installation

If the template is not yet available in Community Applications:

1. Download `nextcloud-sync.xml` from this repository
2. Place it in `/boot/config/plugins/dockerMan/templates-user/` on your Unraid system
3. Go to **Docker** tab → **Add Container** → Select template

## Security Recommendation

Create an app-specific password in Nextcloud (Settings → Security → Devices & sessions) instead of using your main password for enhanced security.

## Complete Documentation

For detailed configuration options, troubleshooting, and advanced usage, see:
- [Complete Unraid Template Documentation](UNRAID_TEMPLATE_DOCUMENTATION.md)

## Support

- Report issues: [GitHub Issues](https://github.com/dkuhnke/nextcloud-sync/issues)
- Unraid support: [Unraid Forums](https://forums.unraid.net/)
