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
    export NEXTCLOUD_DEBUG=${NEXTCLOUD_DEBUG:-false}
    
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
    
    # Check available disk space
    local available_space=$(df -h "$sync_dir" | awk 'NR==2 {print $4}')
    log "💾 Available disk space: $available_space"
    
    log "✅ Directory permissions validated"
}

# Function to test connectivity before sync
test_connectivity() {
    log "🌐 Testing Nextcloud connectivity..."
    
    local server_url="$NEXTCLOUD_URL"
    
    # Ensure URL has correct format (just hostname/server, no WebDAV path)
    # Remove any trailing WebDAV paths if present
    server_url=$(echo "$server_url" | sed 's|/remote\.php/dav/files/.*||' | sed 's|/$||')
    
    log "   Testing server: $server_url"
    
    # Use nextcloudcmd with --dry-run to test connectivity without actually syncing
    local test_output="/tmp/nextcloud_test_output.$$"
    if timeout 60 nextcloudcmd --dry-run --user "$NEXTCLOUD_USER" --password "$NEXTCLOUD_PASS" "/tmp" "$server_url" > "$test_output" 2>&1; then
        rm -f "$test_output"
        log "✅ Connectivity test successful"
        return 0
    else
        local exit_code=$?
        
        # Show any error output
        if [ -f "$test_output" ]; then
            log "   Test output:"
            while IFS= read -r line; do
                log "   $line"
            done < "$test_output"
            rm -f "$test_output"
        fi
        
        if [ $exit_code -eq 124 ]; then
            log "❌ Connectivity test timed out after 60s"
        else
            log "❌ Connectivity test failed (exit code: $exit_code)"
        fi
        log "   This could indicate:"
        log "   - Wrong credentials"
        log "   - Network connectivity issues"
        log "   - Incorrect Nextcloud URL"
        log "   - Firewall blocking the connection"
        return 1
    fi
}

# Function to perform synchronization with retries
perform_sync_with_retries() {
    local attempt=1
    local max_attempts=$((NEXTCLOUD_SYNC_RETRIES + 1))
    local sync_dir="/media/nextclouddata"
    local server_url="$NEXTCLOUD_URL"
    
    # Ensure URL has correct format (just hostname/server, no WebDAV path)
    # Remove any trailing WebDAV paths if present
    server_url=$(echo "$server_url" | sed 's|/remote\.php/dav/files/.*||' | sed 's|/$||')
    
    while [ $attempt -le $max_attempts ]; do
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            log "🛑 Shutdown requested, aborting sync attempt"
            return 1
        fi
        
        log "🔄 Sync attempt $attempt/$max_attempts"
        log "   Server: $server_url"
        log "   Target: $sync_dir"
        log "   Command: nextcloudcmd --user \"$NEXTCLOUD_USER\" --password \"***\" \"$sync_dir\" \"$server_url\""
        
        # Perform synchronization using nextcloudcmd with timeout for large files
        log "⏳ Starting sync (with 30-minute timeout for safety)..."
        
        # Create a temporary file for output
        local temp_output="/tmp/nextcloud_sync_output.$$"
        
        # Run nextcloudcmd with timeout to prevent hanging
        if timeout 1800 nextcloudcmd --user "$NEXTCLOUD_USER" --password "$NEXTCLOUD_PASS" "$sync_dir" "$server_url" > "$temp_output" 2>&1; then
            local sync_exit_code=$?
            
            # Display the output (conditionally verbose)
            if [ "$NEXTCLOUD_DEBUG" = "true" ]; then
                while IFS= read -r line; do
                    log "   $line"
                done < "$temp_output"
            else
                # Show only important lines (errors, warnings, summary)
                while IFS= read -r line; do
                    if [[ "$line" =~ (error|warning|failed|success|completed|finished|summary) ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
                        log "   $line"
                    fi
                done < "$temp_output"
            fi
            
            # Clean up temp file
            rm -f "$temp_output"
            
            if [ $sync_exit_code -eq 0 ]; then
                log "✅ Synchronization completed successfully"
                update_health_check
                return 0
            else
                log "❌ Sync attempt $attempt failed (exit code: $sync_exit_code)"
            fi
        else
            local sync_exit_code=$?
            
            # Display any output before the error
            if [ -f "$temp_output" ]; then
                if [ "$NEXTCLOUD_DEBUG" = "true" ]; then
                    while IFS= read -r line; do
                        log "   $line"
                    done < "$temp_output"
                else
                    # Show only important lines
                    while IFS= read -r line; do
                        if [[ "$line" =~ (error|warning|failed|success|completed|finished|summary) ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
                            log "   $line"
                        fi
                    done < "$temp_output"
                fi
                rm -f "$temp_output"
            fi
            
            if [ $sync_exit_code -eq 124 ]; then
                log "❌ Sync attempt $attempt timed out after 30 minutes (likely hung)"
            else
                log "❌ Sync attempt $attempt failed (exit code: $sync_exit_code)"
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            local wait_time=$((attempt * 30))
            log "⏳ Waiting $wait_time seconds before retry..."
            sleep $wait_time
        else
            log "❌ All $max_attempts sync attempts failed"
            return 1
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
    
    # Test connectivity before starting sync
    if ! test_connectivity; then
        log "❌ Pre-flight connectivity test failed, exiting"
        exit 1
    fi
    
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
