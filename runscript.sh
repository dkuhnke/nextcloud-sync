#!/bin/bash

# =============================================================================
# Nextcloud Sync Script (Minimal Dependencies Version)
# =============================================================================
#
# Simplified sync script that relies on nextcloudcmd for all connectivity
# and authentication checks. No external dependencies on curl or procps.
#
# Author: dkuhnke
# =============================================================================

# Enable strict error handling
set -euo pipefail

cd /usr/bin

# Global variables for graceful shutdown
SHUTDOWN_REQUESTED=false

# Function to handle signals for graceful shutdown
cleanup() {
    log "🛑 Shutdown signal received, finishing current operation..."
    SHUTDOWN_REQUESTED=true
}

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT

# Function to update health check
update_health_check() {
    echo "$(date)" > /tmp/healthcheck
}

# Function to log with timestamp and formatting
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    # Update health check on every log entry
    update_health_check
}

# Function to validate required environment variables
validate_environment() {
    local missing_vars=()
    
    # Set default values for optional variables
    export NEXTCLOUD_SYNC_RETRIES=${NEXTCLOUD_SYNC_RETRIES:-4}
    export NEXTCLOUD_SLEEP=${NEXTCLOUD_SLEEP:-300}
    export NEXTCLOUD_RUN_ONCE=${NEXTCLOUD_RUN_ONCE:-false}
    
    # Check required variables
    if [ -z "$NEXTCLOUD_USER" ] || [ "$NEXTCLOUD_USER" = "" ]; then
        missing_vars+=("NEXTCLOUD_USER")
    fi
    
    if [ -z "$NEXTCLOUD_PASS" ] || [ "$NEXTCLOUD_PASS" = "" ]; then
        missing_vars+=("NEXTCLOUD_PASS")
    fi
    
    if [ -z "$NEXTCLOUD_URL" ] || [ "$NEXTCLOUD_URL" = "" ]; then
        missing_vars+=("NEXTCLOUD_URL")
    fi
    
    # Validate numeric variables
    if ! [[ "$NEXTCLOUD_SYNC_RETRIES" =~ ^[0-9]+$ ]] || [ "$NEXTCLOUD_SYNC_RETRIES" -lt 1 ] || [ "$NEXTCLOUD_SYNC_RETRIES" -gt 10 ]; then
        log "⚠️ Invalid NEXTCLOUD_SYNC_RETRIES: $NEXTCLOUD_SYNC_RETRIES (must be 1-10), using default: 4"
        export NEXTCLOUD_SYNC_RETRIES=4
    fi
    
    if ! [[ "$NEXTCLOUD_SLEEP" =~ ^[0-9]+$ ]] || [ "$NEXTCLOUD_SLEEP" -lt 30 ]; then
        log "⚠️ Invalid NEXTCLOUD_SLEEP: $NEXTCLOUD_SLEEP (must be ≥30), using default: 300"
        export NEXTCLOUD_SLEEP=300
    fi
    
    # Report missing variables
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log "❌ Missing required environment variables: ${missing_vars[*]}"
        log "   Please set these variables when starting the container:"
        for var in "${missing_vars[@]}"; do
            log "   - $var"
        done
        log ""
        log "   Example:"
        log "   docker run -e NEXTCLOUD_USER=myuser -e NEXTCLOUD_PASS=mypass -e NEXTCLOUD_URL=cloud.example.com dkuhnke/nextcloud-sync"
        exit 1
    fi
    
    log "✅ Environment validation successful"
}

# Function to validate directory permissions
validate_directory_permissions() {
    log "🔍 Validating directory permissions..."
    
    local sync_dir="/media/nextclouddata"
    
    # Check if directory exists and create if necessary
    if [ ! -d "$sync_dir" ]; then
        log "📁 Creating sync directory: $sync_dir"
        mkdir -p "$sync_dir" || {
            log "❌ Failed to create directory: $sync_dir"
            exit 1
        }
    fi
    
    # Check if directory is writable
    if [ ! -w "$sync_dir" ]; then
        log "❌ Directory is not writable: $sync_dir"
        log "   Check volume mount permissions and user mapping"
        exit 1
    fi
    
    log "✅ Directory permissions validated"
}

# Function to perform synchronization with retries
perform_sync_with_retries() {
    local attempt=1
    local max_attempts=$((NEXTCLOUD_SYNC_RETRIES + 1))
    local sync_dir="/media/nextclouddata"
    local webdav_url="https://$NEXTCLOUD_URL/remote.php/dav/files/$NEXTCLOUD_USER/"
    
    while [ $attempt -le $max_attempts ]; do
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            log "🛑 Shutdown requested, aborting sync attempt"
            return 1
        fi
        
        log "🔄 Sync attempt $attempt/$max_attempts"
        log "   Source: $webdav_url"
        log "   Target: $sync_dir"
        
        # Perform synchronization using nextcloudcmd
        # The --silent flag reduces output, but errors will still be shown
        if nextcloudcmd --silent --user "$NEXTCLOUD_USER" --password "$NEXTCLOUD_PASS" "$sync_dir" "$webdav_url"; then
            log "✅ Synchronization completed successfully"
            update_health_check
            return 0
        else
            local exit_code=$?
            log "❌ Sync attempt $attempt failed (exit code: $exit_code)"
            
            if [ $attempt -lt $max_attempts ]; then
                local wait_time=$((attempt * 30))
                log "⏳ Waiting $wait_time seconds before retry..."
                sleep $wait_time
            else
                log "❌ All $max_attempts sync attempts failed"
                return 1
            fi
        fi
        
        attempt=$((attempt + 1))
    done
}

# Function to run continuous sync loop
run_continuous_sync() {
    log "🔄 Starting continuous sync mode (interval: ${NEXTCLOUD_SLEEP}s)"
    
    while true; do
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            log "🛑 Shutdown requested, exiting sync loop"
            break
        fi
        
        perform_sync_with_retries
        
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            break
        fi
        
        log "⏳ Waiting $NEXTCLOUD_SLEEP seconds until next sync..."
        sleep "$NEXTCLOUD_SLEEP"
    done
}

# Function to run one-time sync
run_single_sync() {
    log "🔄 Starting one-time sync mode"
    
    if perform_sync_with_retries; then
        log "✅ One-time sync completed successfully"
        exit 0
    else
        log "❌ One-time sync failed"
        exit 1
    fi
}

# Main execution function
main() {
    local version="${CONTAINER_VERSION:-unknown}"
    log "🚀 Starting Nextcloud Sync Container v$version"
    log "   User: $NEXTCLOUD_USER"
    log "   URL: $NEXTCLOUD_URL"
    log "   Retries: $NEXTCLOUD_SYNC_RETRIES"
    log "   Run Once: $NEXTCLOUD_RUN_ONCE"
    
    # Validate environment and setup
    validate_environment
    validate_directory_permissions
    
    # Initial health check update
    update_health_check
    
    # Run sync based on mode
    if [ "$NEXTCLOUD_RUN_ONCE" = "true" ]; then
        run_single_sync
    else
        run_continuous_sync
    fi
    
    log "👋 Nextcloud sync container shutting down"
}

# Start the script
main "$@"
