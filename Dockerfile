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
# - Connectivity and permission checks
# - One-time or continuous sync mode
#
# Author: dkuhnke
# Version: 2.0
# =============================================================================

# Base Image: Alpine Linux (Security-optimized, minimal footprint)
# Alpine Linux provides a much smaller attack surface and fewer CVEs
FROM alpine:3.19

# =============================================================================
# SYSTEM SETUP AND SECURITY
# =============================================================================

# Create non-root user for security
RUN addgroup -g 1001 nextcloud && \
    adduser -D -u 1001 -G nextcloud nextcloud

# Update package index and install security updates
RUN apk update && apk upgrade

# =============================================================================
# APPLICATION INSTALLATION
# =============================================================================

# Install required packages from Alpine repositories:
# - nextcloud-client: Nextcloud Command-Line Client for synchronization
# - curl: For connectivity tests and HTTP requests
# - bash: Required for the runscript
# - ca-certificates: For HTTPS connections
# - procps: For process monitoring (pgrep command)
RUN apk add --no-cache \
    nextcloud-client \
    curl \
    bash \
    ca-certificates \
    tzdata \
    procps

# Create synchronization directory with proper ownership
# This is where Nextcloud data will be stored locally
RUN mkdir -p /media/nextclouddata && \
    chown nextcloud:nextcloud /media/nextclouddata

# =============================================================================
# SCRIPT SETUP
# =============================================================================

# Copy the main script into the container
# The runscript.sh contains all synchronization logic
COPY --chown=nextcloud:nextcloud runscript.sh /usr/bin/runscript.sh

# Set execution permissions for the script
RUN chmod +x /usr/bin/runscript.sh

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================

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
      description="Nextcloud Sync Container with Alpine Linux (Security-optimized)" \
      version="2.0" \
      org.opencontainers.image.source="https://github.com/dkuhnke/nextcloud-sync" \
      org.opencontainers.image.title="Nextcloud Sync Container" \
      org.opencontainers.image.description="Automated Nextcloud synchronization with retry logic and advanced features"

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
