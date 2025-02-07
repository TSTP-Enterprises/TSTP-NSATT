#!/bin/bash

set -euo pipefail

# Configuration Variables
LOG_DIR="/home/nsatt-admin/logs"
LOG_FILE="$LOG_DIR/kali_fix_testing.log"
BACKUP_DIR="/home/nsatt-admin/backups"
API_KEY_FILE="/home/nsatt-admin/nsatt/settings/secure/openai_api_key.txt"
RETRY_LIMIT=5
INITIAL_RETRY_DELAY=10  # Initial delay in seconds
MAX_LOG_SIZE=2000       # Maximum number of lines to send to API
STATUS_FILE="$LOG_DIR/status.txt"
STATE_FILE="$LOG_DIR/state.json"
START_TIME=$(date +%s)

# Ensure required directories exist
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$LOG_DIR/api_responses" "$LOG_DIR/scripts"

# Initialize state file if it doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"attempted_fixes": [], "action_history": []}' > "$STATE_FILE"
fi

# Logging Function with verbosity levels
log() {
    local LEVEL="$1"
    local MESSAGE="$2"
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    case "$LEVEL" in
        INFO)
            echo "[$TIMESTAMP] [INFO] $MESSAGE" | tee -a "$LOG_FILE"
            ;;
        WARN)
            echo "[$TIMESTAMP] [WARN] $MESSAGE" | tee -a "$LOG_FILE" >&2
            ;;
        ERROR)
            echo "[$TIMESTAMP] [ERROR] $MESSAGE" | tee -a "$LOG_FILE" >&2
            ;;
        DEBUG)
            if [[ "${DEBUG:-false}" == "true" ]]; then
                echo "[$TIMESTAMP] [DEBUG] $MESSAGE" | tee -a "$LOG_FILE"
            fi
            ;;
        *)
            echo "[$TIMESTAMP] [UNKNOWN] $MESSAGE" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Progress Function with dynamic updates
start_progress() {
    while true; do
        if [[ -f "$STATUS_FILE" ]]; then
            CURRENT_STEP=$(cat "$STATUS_FILE")
        else
            CURRENT_STEP="Initializing..."
        fi
        ELAPSED_TIME=$(( $(date +%s) - START_TIME ))
        HOURS=$(( ELAPSED_TIME / 3600 ))
        MINUTES=$(( (ELAPSED_TIME % 3600) / 60 ))
        SECONDS=$(( ELAPSED_TIME % 60 ))
        printf "\rProgress: %-50s | Elapsed Time: %02d:%02d:%02d" "$CURRENT_STEP" "$HOURS" "$MINUTES" "$SECONDS" | tee -a "$LOG_FILE"
        sleep 5
    done
}

# Trap unexpected errors and exit gracefully
trap 'log "ERROR" "An unexpected error occurred. See $LOG_FILE for details."; cleanup_and_exit 1' ERR INT TERM

# Function to update state file
update_state() {
    local FIX_NAME="$1"
    local RESULT="$2"
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    jq --arg fix "$FIX_NAME" \
       --arg result "$RESULT" \
       --arg timestamp "$TIMESTAMP" \
       '.attempted_fixes += [{name: $fix, result: $result, timestamp: $timestamp}]' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Function to check if a fix has been attempted with a specific result
has_attempted_fix_with_result() {
    local FIX_NAME="$1"
    local RESULT="$2"
    jq --arg fix "$FIX_NAME" --arg result "$RESULT" \
       '.attempted_fixes[] | select(.name == $fix and .result == $result)' "$STATE_FILE" >/dev/null
}

# Function to record an action in the action history
record_action() {
    local ACTION="$1"
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    jq --arg action "$ACTION" --arg timestamp "$TIMESTAMP" \
       '.action_history += [{action: $action, timestamp: $timestamp}]' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Function to analyze action history for patterns
analyze_action_history() {
    # For simplicity, this function just counts the number of times each action has occurred
    jq '.action_history | group_by(.action) | map({action: .[0].action, count: length})' "$STATE_FILE"
}

# Backup Critical Configuration Files with verification
backup_configs() {
    CURRENT_STEP="Backing up critical configuration files..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    TIMESTAMP=$(date +%Y%m%d%H%M%S)

    for CONFIG in /etc/lightdm ~/.xsession-errors; do
        if [[ -e "$CONFIG" ]]; then
            BASENAME=$(basename "$CONFIG" | tr '.' '_')
            sudo cp -r "$CONFIG" "$BACKUP_DIR/${BASENAME}_$TIMESTAMP" 2>>"$LOG_FILE" && log "INFO" "Successfully backed up $CONFIG to $BACKUP_DIR/${BASENAME}_$TIMESTAMP." || log "WARN" "Failed to backup $CONFIG."
        else
            log "WARN" "$CONFIG does not exist. Skipping backup."
        fi
    done

    record_action "backup_configs"
}

# Gather Logs for Analysis with enhanced coverage
gather_logs() {
    CURRENT_STEP="Gathering logs for analysis..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    local LOG_FILES=(
        "$LOG_DIR/lightdm.log"
        "$LOG_DIR/system_journal.log"
        "$LOG_DIR/xsession-errors.log"
        "$LOG_DIR/xorg.log"
        "$LOG_DIR/disk_space.log"
        "$LOG_DIR/home_permissions.log"
    )

    journalctl -u lightdm --no-pager | tail -n 200 > "${LOG_FILES[0]}" 2>>"$LOG_FILE" || log "WARN" "Failed to gather lightdm logs."
    sudo journalctl -xe | tail -n 200 > "${LOG_FILES[1]}" 2>>"$LOG_FILE" || log "WARN" "Failed to gather system journal logs."
    cat ~/.xsession-errors 2>/dev/null > "${LOG_FILES[2]}" || echo "No .xsession-errors found." > "${LOG_FILES[2]}"
    cat /var/log/Xorg.0.log 2>/dev/null > "${LOG_FILES[3]}" || echo "No Xorg.0.log found." > "${LOG_FILES[3]}"
    df -h > "${LOG_FILES[4]}" 2>>"$LOG_FILE" || log "WARN" "Failed to gather disk space logs."
    ls -la /home/nsatt-admin > "${LOG_FILES[5]}" 2>>"$LOG_FILE" || log "WARN" "Failed to gather home permissions logs."

    log "DEBUG" "Logs gathered: ${LOG_FILES[*]}"

    record_action "gather_logs"
}

# Summarize Logs for API with additional filtering
summarize_logs() {
    CURRENT_STEP="Summarizing logs for API..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    grep -Ei 'error|fail|critical|unable|cannot|warning' "$LOG_DIR"/*.log | grep -v "api_summary.log" > "$LOG_DIR/api_summary.log" 2>>"$LOG_FILE"

    # Truncate if necessary
    if [[ $(wc -l < "$LOG_DIR/api_summary.log") -gt "$MAX_LOG_SIZE" ]]; then
        tail -n "$MAX_LOG_SIZE" "$LOG_DIR/api_summary.log" > "$LOG_DIR/api_summary_truncated.log" && mv "$LOG_DIR/api_summary_truncated.log" "$LOG_DIR/api_summary.log"
        log "INFO" "API summary truncated to the last $MAX_LOG_SIZE lines."
    fi

    # Set flag if no significant errors
    if [[ ! -s "$LOG_DIR/api_summary.log" ]]; then
        echo "No significant errors found." > "$LOG_DIR/api_summary.log"
        touch "$LOG_DIR/no_errors.flag"
        log "INFO" "No significant errors found."
    else
        rm -f "$LOG_DIR/no_errors.flag"
        log "INFO" "Significant errors found and summarized."
    fi

    record_action "summarize_logs"
}

# Send Logs to OpenAI API with enhanced error handling
send_to_openai() {
    CURRENT_STEP="Sending logs to OpenAI API for analysis..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    local LOGS
    LOGS=$(<"$LOG_DIR/api_summary.log")

    # Validate API key file
    if [[ ! -f "$API_KEY_FILE" ]]; then
        log "ERROR" "API key file not found at $API_KEY_FILE. Exiting."
        exit 1
    fi

    API_KEY=$(grep -oP '(?<=KEY=").*(?=")' "$API_KEY_FILE" || echo "")

    if [[ -z "$API_KEY" ]]; then
        log "ERROR" "API key not found or empty in $API_KEY_FILE. Exiting."
        exit 1
    fi

    # Prepare API request
    local MODEL="gpt-4"
    local API_ENDPOINT="https://api.openai.com/v1/chat/completions"
    local PAYLOAD
    PAYLOAD=$(jq -n --arg model "$MODEL" \
                    --arg prompt "Analyze the following logs and provide a standalone Bash script to resolve the issue. Only include the script without any code block markers, comments, or explanations:\n$LOGS" \
                    '{
                        model: $model,
                        messages: [
                            {role: "system", content: "You are a helpful assistant."},
                            {role: "user", content: $prompt}
                        ],
                        temperature: 0.2,
                        max_tokens: 1500
                    }')

    # Validate JSON Payload
    if ! echo "$PAYLOAD" | jq empty >/dev/null 2>&1; then
        log "ERROR" "Failed to construct a valid JSON payload."
        exit 1
    fi

    # Send API request with retry mechanism
    local CURL_RESPONSE
    local CURL_STATUS
    local CURL_RETRIES=3
    local CURL_DELAY=5
    for attempt in $(seq 1 $CURL_RETRIES); do
        CURL_RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD")
        CURL_STATUS=$?
        if [[ $CURL_STATUS -eq 0 ]]; then
            break
        else
            log "WARN" "API request failed (Attempt $attempt/$CURL_RETRIES). Retrying in $CURL_DELAY seconds..."
            sleep "$CURL_DELAY"
        fi
    done

    if [[ $CURL_STATUS -ne 0 ]]; then
        log "ERROR" "Failed to communicate with OpenAI API after $CURL_RETRIES attempts."
        exit 1
    fi

    # Log the full API response for internal analysis
    local RESPONSE_FILE="$LOG_DIR/api_responses/openai_response_$(date +%Y%m%d%H%M%S).json"
    echo "$CURL_RESPONSE" | tee "$RESPONSE_FILE"

    # Check for API errors
    local ERROR_MESSAGE
    ERROR_MESSAGE=$(echo "$CURL_RESPONSE" | jq -r '.error.message // empty')
    if [[ -n "$ERROR_MESSAGE" ]]; then
        log "ERROR" "API Error: $ERROR_MESSAGE"
        exit 1
    fi

    # Extract the script from the response
    SCRIPT=$(echo "$CURL_RESPONSE" | jq -r '.choices[0].message.content')

    # Log the script content for debugging
    log "DEBUG" "Extracted script content:\n$SCRIPT"

    # Remove code block markers if present
    if [[ "$SCRIPT" == *'```'* ]]; then
        SCRIPT=$(echo "$SCRIPT" | sed -e 's/^```bash\s*//' -e 's/^```//' -e 's/```$//')
    fi

    # Save the script to a file
    if [[ "$SCRIPT" != "null" && -n "$SCRIPT" ]]; then
        SCRIPT_FILE="$LOG_DIR/scripts/openai_script_$(date +%Y%m%d%H%M%S).sh"
        echo "$SCRIPT" > "$SCRIPT_FILE"
        chmod +x "$SCRIPT_FILE"
        log "INFO" "API response received and script saved to $SCRIPT_FILE."
    else
        log "WARN" "API did not return a valid script."
        touch "$LOG_DIR/api_failure.flag"
    fi

    record_action "send_to_openai"
}

# Validate API Response
validate_api_response() {
    CURRENT_STEP="Validating API response..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    if [[ -f "$SCRIPT_FILE" ]]; then
        if grep -qE "^#!/bin/bash" "$SCRIPT_FILE"; then
            chmod +x "$SCRIPT_FILE"
            log "INFO" "API response validated successfully."
            return 0
        else
            log "WARN" "Invalid API response in $SCRIPT_FILE. Skipping execution."
            log "DEBUG" "Script content:\n$(cat "$SCRIPT_FILE")"
            rm -f "$SCRIPT_FILE"
            return 1
        fi
    else
        log "WARN" "No script file found to validate."
        return 1
    fi
}

# Execute the Fix Script Provided by API
execute_and_validate_fix() {
    CURRENT_STEP="Executing API-provided fix..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    if [[ -f "$SCRIPT_FILE" ]]; then
        bash "$SCRIPT_FILE" >> "$LOG_FILE" 2>&1 && {
            log "INFO" "API-provided fix executed from $SCRIPT_FILE."
            update_state "$SCRIPT_FILE" "success"
        } || {
            log "WARN" "Execution of $SCRIPT_FILE failed."
            update_state "$SCRIPT_FILE" "failure"
        }
    else
        log "WARN" "No fix script found to execute."
        return 1
    fi

    CURRENT_STEP="Rechecking system health after fix..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    # Re-gather logs to verify if issues are resolved
    gather_logs
    summarize_logs

    # Check system health
    if systemctl is-active --quiet lightdm && [[ -f "$LOG_DIR/no_errors.flag" ]]; then
        log "INFO" "System appears stable. Exiting script."
        disable_service
        return 0
    else
        log "WARN" "Fix did not resolve the issue. Preparing to retry."
        return 1
    fi
}

# Reboot the System if Required
reboot_if_required() {
    if [[ -f "$LOG_DIR/reboot_required.flag" ]]; then
        CURRENT_STEP="Reboot required. System will restart now..."
        echo "$CURRENT_STEP" > "$STATUS_FILE"
        log "INFO" "$CURRENT_STEP"
        sudo reboot
    fi
}

# Create Systemd Service for Persistence
create_service() {
    CURRENT_STEP="Creating systemd service for persistence..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    local SERVICE_FILE="/etc/systemd/system/kali_auto_fix.service"
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Kali Auto Fix Service
After=network.target

[Service]
ExecStart=/home/nsatt-admin/nsatt/storage/scripts/recovery/ai_login_repair.sh
Restart=on-failure
Environment=DEBUG=false

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable kali_auto_fix.service
    log "INFO" "Systemd service created and enabled."

    record_action "create_service"
}

# Disable the Systemd Service Once Fixed
disable_service() {
    CURRENT_STEP="Disabling systemd service..."
    echo "$CURRENT_STEP" > "$STATUS_FILE"
    log "INFO" "$CURRENT_STEP"

    sudo systemctl disable kali_auto_fix.service || log "WARN" "Failed to disable systemd service."
    sudo systemctl stop kali_auto_fix.service || log "WARN" "Failed to stop systemd service."
    log "INFO" "Systemd service disabled."

    record_action "disable_service"
}

# Cleanup function to kill background processes and exit
cleanup_and_exit() {
    local EXIT_CODE="$1"
    if [[ -n "${progress_pid:-}" ]]; then
        kill "$progress_pid" 2>/dev/null || true
    fi
    exit "$EXIT_CODE"
}

# Function to execute and learn from other scripts
execute_and_learn_script() {
    local SCRIPT_PATH="$1"
    if [[ -f "$SCRIPT_PATH" ]]; then
        log "INFO" "Executing script at $SCRIPT_PATH."
        bash "$SCRIPT_PATH" >> "$LOG_FILE" 2>&1 && {
            log "INFO" "Script $SCRIPT_PATH executed successfully."
            analyze_script "$SCRIPT_PATH"
            record_action "execute_script:$SCRIPT_PATH"
        } || {
            log "WARN" "Execution of $SCRIPT_PATH failed."
        }
    else
        log "WARN" "Script $SCRIPT_PATH not found."
    fi
}

# Function to analyze a script using OpenAI API
analyze_script() {
    local SCRIPT_PATH="$1"
    local API_KEY
    API_KEY=$(grep -oP '(?<=KEY=").*(?=")' "$API_KEY_FILE" || echo "")
    local API_ENDPOINT="https://api.openai.com/v1/chat/completions"

    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log "WARN" "Script '$SCRIPT_PATH' not found for analysis."
        return
    fi

    local SCRIPT_CONTENT
    SCRIPT_CONTENT=$(<"$SCRIPT_PATH")

    local PROMPT
    PROMPT="Explain the purpose and functionality of the following bash script in detail:\n\n$SCRIPT_CONTENT"

    local PAYLOAD
    PAYLOAD=$(jq -n --arg model "gpt-4" \
                    --arg prompt "$PROMPT" \
                    '{
                        model: $model,
                        messages: [
                            {role: "system", content: "You are a helpful assistant that explains bash scripts."},
                            {role: "user", content: $prompt}
                        ],
                        temperature: 0.2,
                        max_tokens: 500
                    }')

    local RESPONSE
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    local EXPLANATION
    EXPLANATION=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

    log "INFO" "Script analysis:\n$EXPLANATION"

    # Optionally, store the explanation for future reference
    echo "$EXPLANATION" > "$SCRIPT_PATH.explanation.txt"

    record_action "analyze_script:$SCRIPT_PATH"
}

# Function to detect repeated actions and automate
detect_and_automate() {
    local ACTION_COUNTS
    ACTION_COUNTS=$(analyze_action_history)
    # Check if any action has occurred more than a threshold
    local THRESHOLD=3
    local ACTION_TO_AUTOMATE
    ACTION_TO_AUTOMATE=$(echo "$ACTION_COUNTS" | jq -r --argjson threshold "$THRESHOLD" '.[] | select(.count >= $threshold) | .action' | head -n1)
    if [[ -n "$ACTION_TO_AUTOMATE" ]]; then
        log "INFO" "Action '$ACTION_TO_AUTOMATE' has occurred frequently. Considering automation."
        # Implement automation logic here
        # For example, if the action is changing permissions, set up a monitor
        if [[ "$ACTION_TO_AUTOMATE" == *"chmod +x"* ]]; then
            log "INFO" "Setting up directory monitoring for automatic permission changes."
            monitor_directory_changes
        fi
    fi
}

# Function to monitor a directory for changes and automate actions
monitor_directory_changes() {
    local WATCH_DIR="/home/nsatt-admin/scripts_to_monitor"
    log "INFO" "Monitoring directory '$WATCH_DIR' for changes."

    inotifywait -m -e create "$WATCH_DIR" | while read -r directory events filename; do
        local FILE_PATH="$directory/$filename"
        chmod +x "$FILE_PATH"
        log "INFO" "Automatically changed permissions for '$FILE_PATH'."
        record_action "auto_chmod:$FILE_PATH"
    done &
}

# Main Function with enhanced adaptability and feedback
main() {
    RETRIES=0
    RETRY_DELAY="$INITIAL_RETRY_DELAY"
    log "INFO" "Starting automated repair script..."
    backup_configs

    # Start the progress indicator in the background
    start_progress &
    progress_pid=$!

    while [[ $RETRIES -lt $RETRY_LIMIT ]]; do
        gather_logs
        summarize_logs

        # Check if no significant errors are found
        if [[ -f "$LOG_DIR/no_errors.flag" ]]; then
            log "INFO" "No significant errors to fix. Exiting script."
            disable_service
            cleanup_and_exit 0
        fi

        # Check if we have already tried this fix and it failed
        if [[ -n "${SCRIPT_FILE:-}" ]] && has_attempted_fix_with_result "$SCRIPT_FILE" "failure"; then
            log "WARN" "This fix has already been attempted and failed. Skipping."
            RETRIES=$((RETRIES + 1))
            continue
        fi

        # Send logs to OpenAI API
        send_to_openai

        # Validate API response
        if validate_api_response; then
            log "INFO" "API response is valid."
        else
            log "WARN" "API response is invalid. Skipping execution."
            RETRIES=$((RETRIES + 1))
            sleep "$RETRY_DELAY"
            RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
            continue
        fi

        # Execute and validate fix
        if execute_and_validate_fix; then
            log "INFO" "Fix applied successfully."
            cleanup_and_exit 0
        else
            RETRIES=$((RETRIES + 1))
            log "WARN" "Retry $RETRIES/$RETRY_LIMIT initiated after failure."
            echo "Retry $RETRIES/$RETRY_LIMIT initiated after failure." > "$STATUS_FILE"
            sleep "$RETRY_DELAY"
            RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
        fi
    done

    if [[ $RETRIES -ge $RETRY_LIMIT ]]; then
        log "ERROR" "Maximum retries reached. Manual intervention required."
        # Optionally, notify the user via email or other means here
    fi

    reboot_if_required
    cleanup_and_exit 0
}

# Execute Main Function
main
