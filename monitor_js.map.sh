#!/bin/bash

# Configuration
JS_URL="https://identity.notion.so/identity-main.2cd96d1d26f8c2200299.js"
MAP_URL="https://identity.notion.so/identity-main.2cd96d1d26f8c2200299.js.map"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1403578193948184717/7i4L4vyw76m6OoQP6oJg5AHujt9jlOeYBY6zQ98PHuHIU04GPQpz3NOVn0JLPA1e8p_a" # Replace with your Discord webhook URL
OUTPUT_DIR="/tmp/sourcemap_output"
CHECK_INTERVAL=600 # 10 minutes in seconds
LOG_FILE="/tmp/sourcemap_log.txt"
LAST_STATUS_FILE="/tmp/last_map_status.txt"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Function to send Discord notification
send_discord_notification() {
    local message="$1"
    local json_payload=$(jq -n --arg msg "$message" '{
        content: $msg,
        username: "SourceMap Monitor",
        avatar_url: "https://i.imgur.com/4M34hi2.png"
    }')
    
    curl -s -H "Content-Type: application/json" -X POST -d "$json_payload" "$DISCORD_WEBHOOK_URL"
    if [ $? -eq 0 ]; then
        log_message "Discord notification sent: $message"
    else
        log_message "Failed to send Discord notification"
    fi
}

# Function to check for source map and process it
check_source_map() {
    log_message "Checking JS URL: $JS_URL"

    # Check if the JS file is accessible
    local js_status=$(curl -s -o /dev/null -w "%{http_code}" "$JS_URL")
    if [ "$js_status" -ne 200 ]; then
        log_message "Access denied or error for JS URL: $JS_URL (HTTP $js_status)"
        send_discord_notification "Access denied or error for JS URL: $JS_URL (HTTP $js_status)"
        return 1
    fi

    log_message "Checking source map URL: $MAP_URL"

    # Check if the source map is accessible
    local map_status=$(curl -s -o /dev/null -w "%{http_code}" "$MAP_URL")
    
    # Check if status has changed
    if [ -f "$LAST_STATUS_FILE" ]; then
        last_status=$(cat "$LAST_STATUS_FILE")
        if [ "$map_status" != "$last_status" ]; then
            log_message "Source map status changed from HTTP $last_status to HTTP $map_status"
            send_discord_notification "Source map status changed for $MAP_URL: HTTP $last_status -> HTTP $map_status"
        fi
    fi

    # Save current status
    echo "$map_status" > "$LAST_STATUS_FILE"

    if [ "$map_status" -eq 200 ]; then
        log_message "Source map accessible: $MAP_URL"
        send_discord_notification "Source map now accessible at: $MAP_URL"

        # Run sourcemapper to extract source map
       ./sourcemapper/sourcemapper -output "$OUTPUT_DIR/2cd96d1d26f8c2200299" -jsurl "$JS_URL" 2>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "Sourcemapper successfully processed: $MAP_URL"
            send_discord_notification "Sourcemapper extracted sources to $OUTPUT_DIR/2cd96d1d26f8c2200299"
        else
            log_message "Sourcemapper failed for: $MAP_URL"
            send_discord_notification "Sourcemapper failed to process $MAP_URL"
        fi
    else
        log_message "Source map not accessible: $MAP_URL (HTTP $map_status)"
        send_discord_notification "Source map not accessible: $MAP_URL (HTTP $map_status)"
    fi
}

# Main loop
while true; do
    log_message "Starting source map check"

    # Check source map
    check_source_map

    # Wait for the next interval
    sleep "$CHECK_INTERVAL"
done

