#!/bin/bash

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
    
    # If any variables are missing, log error and exit
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log "❌ Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log "   - $var"
        done
        log ""
        log "📖 Required configuration:"
        log "   NEXTCLOUD_USER: Your Nextcloud username"
        log "   NEXTCLOUD_PASS: Your Nextcloud app password (NOT your main password!)"
        log "   NEXTCLOUD_URL:  Your Nextcloud hostname (e.g., cloud.example.com)"
        log ""
        log "💡 How to create an app password:"
        log "   1. Login to your Nextcloud web interface"
        log "   2. Go to Settings → Personal → Security"
        log "   3. Create a new app password for this sync client"
        log "   4. Use the generated app password (NOT your login password)"
        log ""
        log "🚫 Exiting due to incomplete configuration."
        exit 1
    fi
    
    # Validate sync directory exists and is writable
    if [ ! -d "/media/nextclouddata" ]; then
        log "❌ Sync directory /media/nextclouddata does not exist"
        log "💡 Make sure to mount a volume to /media/nextclouddata"
        exit 1
    fi
    
    if [ ! -w "/media/nextclouddata" ]; then
        log "❌ Sync directory /media/nextclouddata is not writable"
        log "💡 Check volume permissions and mount options"
        exit 1
    fi
    
    # Validate numeric parameters
    if ! [[ "$NEXTCLOUD_SYNC_RETRIES" =~ ^[0-9]+$ ]] || [ "$NEXTCLOUD_SYNC_RETRIES" -lt 1 ]; then
        log "⚠️  Invalid NEXTCLOUD_SYNC_RETRIES value: $NEXTCLOUD_SYNC_RETRIES, using default: 4"
        export NEXTCLOUD_SYNC_RETRIES=4
    fi
    
    if ! [[ "$NEXTCLOUD_SLEEP" =~ ^[0-9]+$ ]] || [ "$NEXTCLOUD_SLEEP" -lt 30 ]; then
        log "⚠️  Invalid NEXTCLOUD_SLEEP value: $NEXTCLOUD_SLEEP, using minimum: 30"
        export NEXTCLOUD_SLEEP=30
    fi
    
    log "✅ Environment validation passed"
    log "🔐 Using app password for user: $NEXTCLOUD_USER"
    log "🌐 Syncing with: $NEXTCLOUD_URL"
    log "📁 Sync directory: /media/nextclouddata ($(du -sh /media/nextclouddata 2>/dev/null | cut -f1 || echo 'unknown size'))"
}

# Function to check connectivity to Nextcloud server
check_connectivity() {
    log "🌐 Testing connectivity to $NEXTCLOUD_URL..."
    
    # Test basic connectivity
    if ! curl -s --connect-timeout 10 --max-time 30 "https://$NEXTCLOUD_URL" >/dev/null 2>&1; then
        log "❌ Cannot reach Nextcloud server at $NEXTCLOUD_URL"
        log "💡 Check your network connection and URL"
        return 1
    fi
    
    # Test WebDAV endpoint
    if ! curl -s --connect-timeout 10 --max-time 30 -u "$NEXTCLOUD_USER:$NEXTCLOUD_PASS" \
         "https://$NEXTCLOUD_URL/remote.php/webdav/" >/dev/null 2>&1; then
        log "❌ Cannot authenticate with WebDAV endpoint"
        log "💡 Check your username and app password"
        return 1
    fi
    
    log "✅ Connectivity test passed"
    return 0
}

# Function to check disk space
check_disk_space() {
    local available_space=$(df /media/nextclouddata | awk 'NR==2 {print $4}')
    local threshold=1048576  # 1GB in KB
    
    if [ "$available_space" -lt "$threshold" ]; then
        log "⚠️  Low disk space: $(df -h /media/nextclouddata | awk 'NR==2 {print $4}') available"
        log "💡 Consider cleaning up old files or expanding storage"
        return 1
    fi
    
    return 0
}

# Function to format duration in human readable format
format_duration() {
    local duration=$1
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

# Function to interpret nextcloudcmd exit codes
interpret_exit_code() {
    local exit_code=$1
    case $exit_code in
        0) echo "Success" ;;
        1) echo "General error" ;;
        3) echo "Network error or timeout" ;;
        4) echo "HTTP error (check URL and credentials)" ;;
        5) echo "Local IO error (check permissions and disk space)" ;;
        6) echo "Authentication failed (check username and app password)" ;;
        7) echo "SSL/TLS error (certificate issue)" ;;
        *) echo "Unknown error code $exit_code" ;;
    esac
}

# Function to check and perform daily system update
check_and_update_system() {
    local update_marker="/tmp/last_system_update"
    local current_date=$(date +%Y-%m-%d)
    local last_update_date=""
    
    # Check if marker file exists and read last update date
    if [ -f "$update_marker" ]; then
        last_update_date=$(cat "$update_marker" 2>/dev/null || echo "")
    fi
    
    # If no update today, perform system update
    if [ "$last_update_date" != "$current_date" ]; then
        log "🔧 Performing daily system update..."
        local start_time=$(date +%s)
        
        # Check if we're on Alpine (apk) or Debian/Ubuntu (apt)
        if command -v apk >/dev/null 2>&1; then
            # Alpine Linux
            if apk update >/dev/null 2>&1 && apk upgrade >/dev/null 2>&1; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                local duration_formatted=$(format_duration $duration)
                
                echo "$current_date" > "$update_marker"
                log "✅ System update completed successfully in $duration_formatted"
            else
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                local duration_formatted=$(format_duration $duration)
                log "❌ System update failed after $duration_formatted"
            fi
        elif command -v apt >/dev/null 2>&1; then
            # Debian/Ubuntu
            if apt update >/dev/null 2>&1 && apt upgrade -y >/dev/null 2>&1; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                local duration_formatted=$(format_duration $duration)
                
                echo "$current_date" > "$update_marker"
                log "✅ System update completed successfully in $duration_formatted"
            else
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                local duration_formatted=$(format_duration $duration)
                log "❌ System update failed after $duration_formatted"
            fi
        else
            log "⚠️  No supported package manager found (apk/apt), skipping system update"
        fi
    fi
}

# Function to run nextcloud sync with timing and retry logic
run_nextcloud_sync() {
    log "🔄 Starting Nextcloud synchronization..."
    
    # Check disk space before sync
    if ! check_disk_space; then
        log "⚠️  Proceeding with sync despite low disk space"
    fi
    
    local start_time=$(date +%s)
    local max_retries=3
    local retry_count=0
    local exit_code=1
    
    while [ $retry_count -lt $max_retries ] && [ $exit_code -ne 0 ]; do
        if [ $retry_count -gt 0 ]; then
            log "🔄 Retry attempt $retry_count/$max_retries"
            sleep $((retry_count * 10))  # Progressive backoff
        fi
        
        # Use temporary variable to capture exit code without triggering set -e
        set +e
        
        # Set locale to fix Qt warnings
        export LC_ALL=C.UTF-8
        export LANG=C.UTF-8
        
        # Capture both stdout and stderr for debugging
        local sync_output
        sync_output=$(nextcloudcmd \
                --max-sync-retries "$NEXTCLOUD_SYNC_RETRIES" \
                --silent \
                --non-interactive \
                /media/nextclouddata \
                "https://${NEXTCLOUD_USER}:${NEXTCLOUD_PASS}@${NEXTCLOUD_URL}" 2>&1)
        exit_code=$?
        set -e
        
        if [ $exit_code -eq 0 ]; then
            break
        fi
        
        local error_description=$(interpret_exit_code $exit_code)
        log "⚠️  Sync attempt failed: $error_description"
        
        # Log sync output for debugging if it contains useful information
        if [ -n "$sync_output" ] && [ "$sync_output" != "" ]; then
            log "🔍 Sync output: $sync_output"
        fi
        
        # Don't retry for authentication or configuration errors
        if [ $exit_code -eq 6 ] || [ $exit_code -eq 4 ]; then
            log "🚫 Not retrying due to authentication/configuration error"
            break
        fi
        
        retry_count=$((retry_count + 1))
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(format_duration $duration)
    
    if [ $exit_code -eq 0 ]; then
        log "✅ Synchronization completed successfully in $duration_formatted"
        if [ $retry_count -gt 0 ]; then
            log "🔄 Required $retry_count retry attempts"
        fi
    else
        local error_description=$(interpret_exit_code $exit_code)
        log "❌ Synchronization failed after $duration_formatted: $error_description"
        if [ $retry_count -eq $max_retries ]; then
            log "🚫 Max retry attempts ($max_retries) exceeded"
        fi
    fi
    
    return $exit_code
}

# Check if NEXTCLOUD_RUN_ONCE is set to true
if [ "$NEXTCLOUD_RUN_ONCE" = "true" ]; then
    log "🚀 Running Nextcloud sync once and then exiting..."
    
    # Validate environment variables first
    validate_environment
    
    # Test connectivity
    if ! check_connectivity; then
        log "🚫 Connectivity test failed, exiting"
        exit 1
    fi
    
    # Check for system updates before sync
    check_and_update_system
    
    run_nextcloud_sync
    exit_code=$?
    log "🏁 Single sync run completed with exit code $exit_code"
    exit $exit_code
else
    log "🔁 Starting Nextcloud sync loop with $(format_duration $NEXTCLOUD_SLEEP) interval..."
    
    # Validate environment variables first
    validate_environment
    
    # Test connectivity
    if ! check_connectivity; then
        log "🚫 Initial connectivity test failed, exiting"
        exit 1
    fi
    
    sync_count=0
    consecutive_failures=0
    max_consecutive_failures=5
    
    # Perform initial system update check
    check_and_update_system
    
    while [ "$SHUTDOWN_REQUESTED" = false ]; do
        sync_count=$((sync_count + 1))
        log "📊 Starting sync #$sync_count"
        
        # Check for system updates before each sync (but only updates once per day)
        check_and_update_system
        
        if run_nextcloud_sync; then
            consecutive_failures=0
            log "😴 Sleeping for $(format_duration $NEXTCLOUD_SLEEP) until next sync..."
        else
            consecutive_failures=$((consecutive_failures + 1))
            log "⚠️  Sync failed (consecutive failures: $consecutive_failures/$max_consecutive_failures)"
            
            if [ $consecutive_failures -ge $max_consecutive_failures ]; then
                log "🚨 Too many consecutive failures, testing connectivity..."
                if ! check_connectivity; then
                    log "❌ Connectivity lost, will retry every 60 seconds until connection is restored"
                    while [ "$SHUTDOWN_REQUESTED" = false ] && ! check_connectivity; do
                        sleep 60
                    done
                    if [ "$SHUTDOWN_REQUESTED" = false ]; then
                        log "✅ Connectivity restored, resuming normal schedule"
                        consecutive_failures=0
                    fi
                else
                    log "🌐 Connectivity OK, continuing with schedule"
                fi
            fi
            
            if [ "$SHUTDOWN_REQUESTED" = false ]; then
                log "😴 Sleeping for $(format_duration $NEXTCLOUD_SLEEP) until next sync..."
            fi
        fi
        
        # Sleep with shutdown check
        sleep_time=$NEXTCLOUD_SLEEP
        while [ $sleep_time -gt 0 ] && [ "$SHUTDOWN_REQUESTED" = false ]; do
            chunk=$((sleep_time > 10 ? 10 : sleep_time))
            sleep $chunk
            sleep_time=$((sleep_time - chunk))
        done
        
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            log "🛑 Graceful shutdown completed"
            exit 0
        fi
    done
fi
