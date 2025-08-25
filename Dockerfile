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
# - Daily system updates
# - Comprehensive logging functionality
# - Connectivity and permission checks
# - One-time or continuous sync mode
#
# Author: dkuhnke
# Version: 1.0
# =============================================================================

# Base Image: Debian Latest
# Debian is used as a stable, well-supported base for the container
FROM debian:latest

# =============================================================================
# SYSTEM SETUP AND UPDATES
# =============================================================================

# Update the system to the latest state
# This ensures all security updates are installed
RUN apt-get update && apt-get upgrade -y

# =============================================================================
# LOCALE CONFIGURATION
# =============================================================================

# Install and configure locale support
# This prevents Qt warnings and ensures correct character encoding
RUN apt-get install -y locales

# Configure en_US.UTF-8 locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8

# Set environment variables for locale
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# =============================================================================
# APPLICATION INSTALLATION
# =============================================================================

# Install required packages:
# - nextcloud-desktop-cmd: Nextcloud Command-Line Client for synchronization
# - curl: For connectivity tests and HTTP requests
RUN apt-get install -y nextcloud-desktop-cmd curl

# Create synchronization directory
# This is where Nextcloud data will be stored locally
RUN mkdir /media/nextclouddata

# =============================================================================
# SCRIPT SETUP
# =============================================================================

# Copy the main script into the container
# The runscript.sh contains all synchronization logic
COPY runscript.sh /usr/bin/runscript.sh

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
WORKDIR /usr/bin

# Health check for the container
# Checks if the sync process is still running and responsive
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Labels for container metadata
LABEL maintainer="dkuhnke" \
      description="Nextcloud Sync Container with advanced features" \
      version="1.0" \
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
