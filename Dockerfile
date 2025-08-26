# =============================================================================
# Nextcloud Sync Container
# =============================================================================
# 
# An automated Docker container for continuous synchronization of Nextcloud data
# with advanced error handling and retry functionality.
#
# Features:
# - Continuous synchronization with configurable intervals
# - Automatic retry logic for connection failures
# - Graceful shutdown with signal handling
# - Comprehensive logging functionality
# - One-time or continuous sync mode
# - Security-hardened with minimal dependencies (only nextcloud-client + bash)
# - Optimized for reduced CVE exposure
#
# Author: dkuhnke
# Version: 2.5
# =============================================================================

# Base Image
FROM debian:trixie-slim

# =============================================================================
# SYSTEM SETUP AND SECURITY
# =============================================================================

# Install only essential packages - minimal approach
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        nextcloud-desktop-cmd \
        ca-certificates && \
    # Security hardening: Remove package cache and unnecessary files
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
           /tmp/* \
           /var/tmp/* \
           /usr/share/man \
           /usr/share/doc \
           /usr/share/info \
           /usr/share/locale && \
    # Create non-root user for security
    groupadd -g 1001 nextcloud && \
    useradd -u 1001 -g nextcloud -m -s /bin/bash nextcloud

# Create synchronization directory with proper ownership
# This is where Nextcloud data will be stored locally
RUN mkdir -p /media/nextclouddata && \
    chown nextcloud:nextcloud /media/nextclouddata && \
    # Additional security hardening measures
    # Remove potentially dangerous setuid/setgid binaries
    find / -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

# =============================================================================
# SCRIPT SETUP
# =============================================================================

# Copy the optimized script into the container
# The runscript.sh contains minimal-dependency synchronization logic
COPY --chown=nextcloud:nextcloud runscript.sh /usr/bin/runscript.sh

# Set execution permissions for the script
RUN chmod +x /usr/bin/runscript.sh

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================

# Container version (automatically set by build)
ENV CONTAINER_VERSION=2.5

# Required configuration variables (must be set when starting the container):

# NEXTCLOUD_USER: Nextcloud username
ENV NEXTCLOUD_USER=

# NEXTCLOUD_PASS: Nextcloud app password (NOT the main login password!)
# Create an app password under: Settings → Personal → Security
ENV NEXTCLOUD_PASS=

# NEXTCLOUD_URL: Nextcloud server URL (e.g., cloud.example.com)
# Only the hostname, without https:// or paths
ENV NEXTCLOUD_URL=

# Optional configuration variables with default values:

# NEXTCLOUD_SYNC_RETRIES: Number of retry attempts for failed sync
# Default: 4 (Range: 1-10 recommended)
ENV NEXTCLOUD_SYNC_RETRIES=4

# NEXTCLOUD_RUN_ONCE: One-time sync mode
# - true: Performs one sync and exits the container
# - false: Continuous sync mode (default)
ENV NEXTCLOUD_RUN_ONCE=false

# NEXTCLOUD_SLEEP: Wait time between synchronizations in seconds
# Default: 300 (5 minutes)
# Minimum: 30 seconds
ENV NEXTCLOUD_SLEEP=300

# =============================================================================
# CONTAINER CONFIGURATION
# =============================================================================

# Mark the synchronization directory as volume
# This allows mounting local directories
VOLUME ["/media/nextclouddata"]

# Set working directory
WORKDIR /home/nextcloud

# Switch to non-root user for security
USER nextcloud

# Health check for the container (file-based health check)
# Creates a health check that verifies the script is running properly
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD test -f /tmp/healthcheck || exit 1

# Labels for container metadata
LABEL maintainer="dkuhnke" \
      description="Nextcloud Sync Container (Debian-based for stability)" \
      version="2.5" \
      org.opencontainers.image.source="https://github.com/dkuhnke/nextcloud-sync" \
      org.opencontainers.image.title="Nextcloud Sync Container (Debian)" \
      org.opencontainers.image.description="Stable Nextcloud sync with Debian base for better compatibility"

# =============================================================================
# CONTAINER START
# =============================================================================

# Execute the main script when starting the container
# The script handles all synchronization logic
CMD ["/usr/bin/runscript.sh"]

# =============================================================================
# USAGE INSTRUCTIONS
# =============================================================================
#
# Docker Compose Example:
# 
# services:
#   nextcloud-sync:
#     build: .
#     environment:
#       - NEXTCLOUD_USER=your_username
#       - NEXTCLOUD_PASS=your_app_password
#       - NEXTCLOUD_URL=cloud.example.com
#       - NEXTCLOUD_SLEEP=600
#     volumes:
#       - ./data:/media/nextclouddata
#     restart: unless-stopped
#
# Docker Run Example:
# 
# docker run -d \
#   --name nextcloud-sync \
#   -e NEXTCLOUD_USER=your_username \
#   -e NEXTCLOUD_PASS=your_app_password \
#   -e NEXTCLOUD_URL=cloud.example.com \
#   -v $(pwd)/data:/media/nextclouddata \
#   dkuhnke/nextcloud-sync
#
# Creating an App Password:
# 1. Login to your Nextcloud web interface
# 2. Go to Settings → Personal → Security
# 3. Create a new app password
# 4. Use the generated password (NOT your login password!)
#
# =============================================================================
