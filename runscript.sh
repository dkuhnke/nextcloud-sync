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
    
    # Format URL correctly - ensure it has https:// and no trailing WebDAV paths
    if [[ ! "$server_url" =~ ^https?:// ]]; then
        server_url="https://$server_url"
    fi
    
    # Remove any trailing WebDAV paths if present
    server_url=$(echo "$server_url" | sed 's|/remote\.php/dav/files/.*||' | sed 's|/$||')
    
    log "   Testing server: $server_url"
    
    # Create a temporary test directory
    local test_dir="/tmp/nextcloud_test_$$"
    mkdir -p "$test_dir"
    
    # Use nextcloudcmd with a temporary directory to test connectivity
    local test_output="/tmp/nextcloud_test_output.$$"
    if timeout 60 nextcloudcmd --non-interactive --silent --user "$NEXTCLOUD_USER" --password "$NEXTCLOUD_PASS" "$test_dir" "$server_url" > "$test_output" 2>&1; then
        rm -rf "$test_dir" "$test_output"
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
        
        rm -rf "$test_dir"
        
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
    
    # Format URL correctly - ensure it has https:// and no trailing WebDAV paths
    if [[ ! "$server_url" =~ ^https?:// ]]; then
        server_url="https://$server_url"
    fi
    
    # Remove any trailing WebDAV paths if present
    server_url=$(echo "$server_url" | sed 's|/remote\.php/dav/files/.*||' | sed 's|/$||')
    
    while [ $attempt -le $max_attempts ]; do
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            log "🛑 Shutdown requested, aborting sync attempt"
            return 1
        fi
        
        log "🔄 Sync attempt $attempt/$max_attempts"
        log "   Server: $server_url"
        log "   Command: nextcloudcmd --non-interactive --user \"$NEXTCLOUD_USER\" --password \"***\" \"$sync_dir\" \"$server_url\""
        
        # Perform synchronization using nextcloudcmd with timeout for large files
        log "⏳ Starting sync (with 30-minute timeout for safety)..."
        
        # Create a temporary file for output
        local temp_output="/tmp/nextcloud_sync_output.$$"
        
        # Run nextcloudcmd with timeout to prevent hanging
        local nextcloud_cmd="nextcloudcmd --non-interactive --user \"$NEXTCLOUD_USER\" --password \"$NEXTCLOUD_PASS\" \"$sync_dir\" \"$server_url\""
        
        # Add debug flag if debug mode is enabled
        if [ "$NEXTCLOUD_DEBUG" = "true" ]; then
            nextcloud_cmd="nextcloudcmd --non-interactive --logdebug --user \"$NEXTCLOUD_USER\" --password \"$NEXTCLOUD_PASS\" \"$sync_dir\" \"$server_url\""
        fi
        
        if timeout 1800 bash -c "$nextcloud_cmd" > "$temp_output" 2>&1; then
            # Display the output (conditionally verbose)
            if [ "$NEXTCLOUD_DEBUG" = "true" ]; then
                while IFS= read -r line; do
                    log "   $line"
                done < "$temp_output"
            else
                # Show only important lines (errors, failures, summary) - filter out routine warnings
                while IFS= read -r line; do
                    # Skip routine warnings that are not actual problems
                    if [[ "$line" =~ "Default update channel is \"daily\"" ]] || \
                       [[ "$line" =~ "Authenticated successful on websocket" ]] || \
                       [[ "$line" =~ "Could not complete propagation of \"\._" ]] || \
                       [[ "$line" =~ "File is listed on the ignore list" ]]; then
                        continue
                    fi
                    # Show actual errors, failures, and summary information
                    if [[ "$line" =~ (error|failed|success|completed|finished|summary) ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
                        log "   $line"
                    fi
                done < "$temp_output"
            fi
            
            # Clean up temp file
            rm -f "$temp_output"
            
            log "✅ Synchronization completed successfully"
            update_health_check
            return 0
        else
            local sync_exit_code=$?
            
            # Display any output before the error
            if [ -f "$temp_output" ]; then
                if [ "$NEXTCLOUD_DEBUG" = "true" ]; then
                    while IFS= read -r line; do
                        log "   $line"
                    done < "$temp_output"
                else
                    # Show only important lines - filter out routine warnings
                    while IFS= read -r line; do
                        # Skip routine warnings that are not actual problems
                        if [[ "$line" =~ "Default update channel is \"daily\"" ]] || \
                           [[ "$line" =~ "Authenticated successful on websocket" ]] || \
                           [[ "$line" =~ "Could not complete propagation of \"\._" ]] || \
                           [[ "$line" =~ "File is listed on the ignore list" ]]; then
                            continue
                        fi
                        # Show actual errors, failures, and summary information
                        if [[ "$line" =~ (error|failed|success|completed|finished|summary) ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
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

# Function to get nextcloudcmd version info
get_nextcloudcmd_version() {
    local version_info
    if command -v nextcloudcmd >/dev/null 2>&1; then
        # Get version without the locale warning by redirecting stderr
        version_info=$(nextcloudcmd --version 2>/dev/null | head -1 | grep -o "version [0-9][^[:space:]]*" || echo "version unknown")
        echo "$version_info"
    else
        echo "version not found"
    fi
}

# Main execution function
main() {
    local version="${CONTAINER_VERSION:-unknown}"
    local nextcloud_version=$(get_nextcloudcmd_version)
    
    log "🚀 Starting Nextcloud Sync Container v$version"
    log "   nextcloudcmd: $nextcloud_version"
    log "   User: $NEXTCLOUD_USER"
    log "   URL: $NEXTCLOUD_URL"
    log "   Retries: $NEXTCLOUD_SYNC_RETRIES"
    log "   Run Once: $NEXTCLOUD_RUN_ONCE"
    
    # Validate environment and setup
    validate_environment
    validate_directory_permissions
    
    # Test connectivity before starting sync
    if ! test_connectivity; then
        log "⚠️ Pre-flight connectivity test failed, but attempting sync anyway"
        log "   (Some servers may not respond to the test but work for actual sync)"
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
