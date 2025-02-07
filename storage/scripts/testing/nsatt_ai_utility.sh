#!/bin/bash

set -euo pipefail

# =====================
# Configuration
# =====================
LOG_DIR="/home/nsatt-admin/logs"
LOG_FILE="$LOG_DIR/task_manager.log"
BACKUP_DIR="/home/nsatt-admin/backups"
API_KEY_FILE="/home/nsatt-admin/nsatt/settings/secure/openai_api_key.txt"
DB_FILE="/home/nsatt-admin/task_manager/task_manager_memory.db"
SESSION_FILE="/home/nsatt-admin/task_manager/current_session.txt"
MONITOR_INTERVAL=30  # Seconds between session checks
AUTOMATION_THRESHOLD=3  # Number of executions to trigger automation
EMAIL_RECIPIENT="your-email@example.com"  # Replace with your email
PLUGIN_DIR="/home/nsatt-admin/task_manager/plugins"

# =====================
# Initialize Directories and Files
# =====================
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$(dirname "$DB_FILE")" "/home/nsatt-admin/task_manager/scripts" "$PLUGIN_DIR"
touch "$LOG_FILE"

# Initialize SQLite Database if not present
if [[ ! -f "$DB_FILE" ]]; then
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    path TEXT NOT NULL,
    execution_count INTEGER DEFAULT 0,
    analysis TEXT,
    automated BOOLEAN DEFAULT 0
);

CREATE TABLE commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    command TEXT NOT NULL,
    analysis TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF
fi

# =====================
# Trap for Error Handling
# =====================
trap 'log "ERROR" "An unexpected error occurred. Exiting."; exit 1' ERR

# =====================
# Logging Function
# =====================
log() {
    local LEVEL="$1"
    local MESSAGE="$2"
    local TIMESTAMP
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
        *)
            echo "[$TIMESTAMP] [UNKNOWN] $MESSAGE" | tee -a "$LOG_FILE"
            ;;
    esac
}

# =====================
# OpenAI API Integration
# =====================
get_api_key() {
    grep -oP '(?<=KEY=").*(?=")' "$API_KEY_FILE" || { log "ERROR" "API key not found!"; exit 1; }
}

send_to_openai() {
    local PROMPT="$1"
    local MODEL="$2"
    local API_KEY
    API_KEY=$(get_api_key)
    local API_ENDPOINT="https://api.openai.com/v1/chat/completions"

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$PROMPT" \
        '{
            model: $model,
            messages: [
                {role: "system", content: "You are a helpful assistant."},
                {role: "user", content: $prompt}
            ],
            temperature: 0.2,
            max_tokens: 1500
        }')

    local RESPONSE
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    # Check for API errors
    local ERROR_MESSAGE
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.error.message // empty')
    if [[ -n "$ERROR_MESSAGE" ]]; then
        log "ERROR" "OpenAI API Error: $ERROR_MESSAGE"
        send_email "Task Manager Alert: OpenAI API Error" "Error Details: $ERROR_MESSAGE"
        exit 1
    fi

    echo "$RESPONSE"
}

send_email() {
    local SUBJECT="$1"
    local BODY="$2"
    echo "$BODY" | mail -s "$SUBJECT" "$EMAIL_RECIPIENT"
}

send_desktop_notification() {
    local TITLE="$1"
    local MESSAGE="$2"
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus notify-send "$TITLE" "$MESSAGE"
}

sanitize_input() {
    local INPUT="$1"
    # Remove potentially harmful characters
    echo "$INPUT" | sed 's/[^a-zA-Z0-9._/-]//g'
}

# =====================
# SQLite Database Functions
# =====================
add_script_to_db() {
    local NAME="$1"
    local PATH="$2"

    sqlite3 "$DB_FILE" "INSERT INTO scripts (name, path) VALUES ('$NAME', '$PATH');" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        log "WARN" "Script '$NAME' already exists in the database."
    else
        log "INFO" "Added script '$NAME' to the database."
    fi
}

get_script_by_name() {
    local NAME="$1"
    sqlite3 "$DB_FILE" "SELECT path FROM scripts WHERE name='$NAME';"
}

increment_script_execution() {
    local NAME="$1"
    sqlite3 "$DB_FILE" "UPDATE scripts SET execution_count = execution_count + 1 WHERE name='$NAME';"
}

mark_script_as_automated() {
    local NAME="$1"
    sqlite3 "$DB_FILE" "UPDATE scripts SET automated=1 WHERE name='$NAME';"
}

add_command_to_db() {
    local COMMAND="$1"
    local ANALYSIS="$2"
    sqlite3 "$DB_FILE" "INSERT INTO commands (command, analysis) VALUES ('$COMMAND', '$ANALYSIS');"
}

get_all_scripts() {
    sqlite3 "$DB_FILE" "SELECT name, path, execution_count, automated FROM scripts;"
}

get_all_commands() {
    sqlite3 "$DB_FILE" "SELECT id, command, analysis, timestamp FROM commands;"
}

get_recent_commands() {
    sqlite3 "$DB_FILE" "SELECT command FROM commands ORDER BY timestamp DESC LIMIT 50;"
}

# =====================
# Script Execution and Analysis
# =====================
execute_script() {
    local SCRIPT_PATH="$1"

    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log "ERROR" "Script not found: $SCRIPT_PATH"
        send_email "Task Manager Alert: Script Not Found" "The script $SCRIPT_PATH was not found."
        return 1
    fi

    if [[ ! -x "$SCRIPT_PATH" ]]; then
        log "WARN" "Script not executable. Setting executable permission."
        chmod +x "$SCRIPT_PATH" || { log "ERROR" "Failed to set executable permission."; send_email "Task Manager Alert: Permission Error" "Failed to set executable permission for $SCRIPT_PATH."; return 1; }
    fi

    local SCRIPT_NAME
    SCRIPT_NAME=$(basename "$SCRIPT_PATH")

    log "INFO" "Executing script: $SCRIPT_NAME"
    local OUTPUT
    OUTPUT=$(bash "$SCRIPT_PATH" 2>&1)
    log "INFO" "Script output:\n$OUTPUT"

    # Analyze script execution
    local PROMPT="Analyze the following script output and suggest improvements or next steps:\n$OUTPUT"
    local RESPONSE
    RESPONSE=$(send_to_openai "$PROMPT" "gpt-4")

    # Clean analysis by removing any code block markers
    RESPONSE=$(echo "$RESPONSE" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

    # Update database with script details
    increment_script_execution "$SCRIPT_NAME"
    sqlite3 "$DB_FILE" "UPDATE scripts SET analysis='$(echo "$RESPONSE" | sed "s/'/''/g")' WHERE name='$SCRIPT_NAME';"

    log "INFO" "Script $SCRIPT_NAME analyzed and updated in the database."
}

# =====================
# Generate New Script using OpenAI
# =====================
generate_script() {
    local DESCRIPTION="$1"

    local MODEL="text-davinci-003"  # Or use a more recent model like gpt-4 if available
    local PROMPT="Write a bash script that $DESCRIPTION"

    local PAYLOAD=$(jq -n --arg prompt "$PROMPT" --arg model "$MODEL" '{
        model: $model,
        prompt: $prompt,
        max_tokens: 500,
        temperature: 0.2
    }')

    local API_KEY
    API_KEY=$(get_api_key)
    local API_ENDPOINT="https://api.openai.com/v1/completions"

    local RESPONSE
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$PAYLOAD")

    local NEW_SCRIPT
    NEW_SCRIPT=$(echo "$RESPONSE" | jq -r '.choices[0].text')

    # Clean the script content
    NEW_SCRIPT=$(echo "$NEW_SCRIPT" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

    echo "$NEW_SCRIPT"
}

# =====================
# Memory Recall and Summary
# =====================
view_memory() {
    echo "===== Scripts in Memory ====="
    get_all_scripts | while read -r NAME PATH EXECUTIONS AUTOMATED; do
        echo "Name: $NAME"
        echo "Path: $PATH"
        echo "Executions: $EXECUTIONS"
        echo "Automated: $AUTOMATED"
        echo "-----------------------------------"
    done

    echo "===== Commands in Memory ====="
    get_all_commands | while read -r ID COMMAND ANALYSIS TIMESTAMP; do
        echo "ID: $ID"
        echo "Command: $COMMAND"
        echo "Analysis: $ANALYSIS"
        echo "Timestamp: $TIMESTAMP"
        echo "-----------------------------------"
    done
}

summarize_memory() {
    local SUMMARY_PROMPT="Provide a concise and insightful summary of the following task manager memory data, highlighting key scripts, their purposes, execution counts, analyses, commands executed, and any important patterns or recommendations:\n"

    # Fetch script summaries
    local SCRIPT_SUMMARIES
    SCRIPT_SUMMARIES=$(sqlite3 "$DB_FILE" "SELECT name || ': Executed ' || execution_count || ' times. Analysis: ' || analysis FROM scripts;")

    # Fetch recent commands
    local COMMAND_SUMMARIES
    COMMAND_SUMMARIES=$(sqlite3 "$DB_FILE" "SELECT command || ' | Analysis: ' || analysis FROM commands ORDER BY timestamp DESC LIMIT 50;")

    SUMMARY_PROMPT+="Scripts:\n$SCRIPT_SUMMARIES\n\nCommands:\n$COMMAND_SUMMARIES"

    local SUMMARY_RESPONSE
    SUMMARY_RESPONSE=$(send_to_openai "$SUMMARY_PROMPT" "gpt-4")

    # Clean summary
    SUMMARY_RESPONSE=$(echo "$SUMMARY_RESPONSE" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

    echo "===== Memory Summary ====="
    echo "$SUMMARY_RESPONSE"
    echo "=========================="
}

# =====================
# Session Monitoring Functions
# =====================
find_active_session() {
    local SESSION
    SESSION=$(who am i 2>/dev/null | awk '{print $2}')
    if [[ -n "$SESSION" ]]; then
        echo "$SESSION" > "$SESSION_FILE"
        log "INFO" "Active session found: $SESSION"
    else
        log "WARN" "Could not identify active session."
    fi
}

obtain_user_consent() {
    local SESSION="$1"
    local TTY="/dev/$SESSION"
    echo "The task manager script would like to monitor your commands to learn and automate tasks. Do you consent? (yes/no)" > "$TTY"
    read -t 60 -r RESPONSE < "$TTY"
    if [[ "$RESPONSE" =~ ^(yes|y|YES|Y)$ ]]; then
        log "INFO" "User consent obtained for monitoring session $SESSION."
        sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS consent (session TEXT PRIMARY KEY, granted BOOLEAN);" 
        sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO consent (session, granted) VALUES ('$SESSION', 1);"
    else
        log "INFO" "User did not consent to monitoring session $SESSION."
        sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO consent (session, granted) VALUES ('$SESSION', 0);"
    fi
}

is_user_consented() {
    local SESSION="$1"
    local CONSENT
    CONSENT=$(sqlite3 "$DB_FILE" "SELECT granted FROM consent WHERE session='$SESSION';")
    echo "$CONSENT"
}

monitor_session_activity() {
    local SESSION
    SESSION=$(cat "$SESSION_FILE" 2>/dev/null || echo "")

    if [[ -z "$SESSION" || "$SESSION" == "none" ]]; then
        log "INFO" "No active session found. Initiating session search."
        find_active_session
        SESSION=$(cat "$SESSION_FILE")
    fi

    if [[ -z "$SESSION" || "$SESSION" == "none" ]]; then
        log "ERROR" "Unable to identify an active session. Exiting session monitoring."
        return 1
    fi

    # Check if consent has been obtained
    local CONSENT=$(is_user_consented "$SESSION")
    if [[ "$CONSENT" != "1" ]]; then
        log "INFO" "User consent not obtained for session $SESSION. Requesting consent."
        obtain_user_consent "$SESSION"
        CONSENT=$(is_user_consented "$SESSION")
    fi

    if [[ "$CONSENT" != "1" ]]; then
        log "WARN" "User consent not granted. Aborting session monitoring."
        return 1
    fi

    log "INFO" "Monitoring session: $SESSION"

    while true; do
        # Capture the last command executed in the session using history
        local LAST_CMD
        LAST_CMD=$(history 1 | sed 's/^ *[0-9]* *//')

        if [[ -n "$LAST_CMD" ]]; then
            log "INFO" "Session $SESSION executed command: $LAST_CMD"

            # Analyze the command
            local CMD_PROMPT="Analyze the following command executed by the user and suggest any improvements or actions:\n$LAST_CMD"
            local CMD_ANALYSIS
            CMD_ANALYSIS=$(send_to_openai "$CMD_PROMPT" "gpt-4")

            # Clean analysis
            CMD_ANALYSIS=$(echo "$CMD_ANALYSIS" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

            # Update database with command details
            add_command_to_db "$LAST_CMD" "$(echo "$CMD_ANALYSIS" | sed "s/'/''/g")"

            log "INFO" "Command analysis added to memory."
        fi

        sleep "$MONITOR_INTERVAL"
    done
}

# =====================
# Automated Task Learning
# =====================
learn_and_automate() {
    # Identify scripts that have been executed multiple times and not yet automated
    local SCRIPTS_TO_AUTOMATE
    SCRIPTS_TO_AUTOMATE=$(sqlite3 "$DB_FILE" "SELECT name FROM scripts WHERE execution_count >= $AUTOMATION_THRESHOLD AND automated = 0;")

    for SCRIPT in $SCRIPTS_TO_AUTOMATE; do
        # Fetch script path
        local SCRIPT_PATH
        SCRIPT_PATH=$(get_script_by_name "$SCRIPT")

        # Check if script exists in scripts directory
        local PLUGIN_SCRIPT="/home/nsatt-admin/task_manager/scripts/$SCRIPT"
        if [[ ! -f "$PLUGIN_SCRIPT" ]]; then
            cp "$SCRIPT_PATH" "$PLUGIN_SCRIPT"
            chmod +x "$PLUGIN_SCRIPT"
            log "INFO" "Copied script '$SCRIPT' to plugins directory."
        fi

        # Create a systemd service for automation
        local SERVICE_NAME="auto_${SCRIPT%.*}.service"
        local SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

        sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Automated Service for $SCRIPT
After=network.target

[Service]
ExecStart=$PLUGIN_SCRIPT
Restart=on-failure
User=taskuser

[Install]
WantedBy=multi-user.target
EOL

        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
        sudo systemctl start "$SERVICE_NAME"

        # Update database to reflect automation
        mark_script_as_automated "$SCRIPT"

        log "INFO" "Automation service '$SERVICE_NAME' created and started for script '$SCRIPT'."
        send_email "Task Manager Notification: Automation Created" "Automation service '$SERVICE_NAME' has been created and started for script '$SCRIPT'."
    done
}

# =====================
# Proactive Automation using Inotify
# =====================
proactive_automation() {
    local WATCH_DIR="$1"
    local SCRIPT_NAME="$2"
    local SCRIPT_PATH="/home/nsatt-admin/task_manager/scripts/$SCRIPT_NAME"

    # Ensure the script exists and is executable
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log "ERROR" "Automation script not found: $SCRIPT_PATH"
        send_email "Task Manager Alert: Automation Script Not Found" "The script $SCRIPT_PATH was not found."
        return 1
    fi
    chmod +x "$SCRIPT_PATH"

    # Start inotify wait in the background if not already running for this watch
    if ! pgrep -f "inotifywait.*$WATCH_DIR.*$SCRIPT_PATH" > /dev/null; then
        inotifywait -m -e create -e moved_to --format '%f' "$WATCH_DIR" | while read NEW_FILE; do
            log "INFO" "Detected new file: $NEW_FILE in $WATCH_DIR. Executing $SCRIPT_NAME."
            bash "$SCRIPT_PATH" "$WATCH_DIR/$NEW_FILE" >> "$LOG_FILE" 2>&1
            log "INFO" "Executed $SCRIPT_NAME for $NEW_FILE."
        done &

        # Store the PID of inotifywait for potential future management
        echo $! >> "/home/nsatt-admin/task_manager/inotify_pids.txt"
        log "INFO" "Proactive automation set up for $WATCH_DIR with script $SCRIPT_NAME."
        send_email "Task Manager Notification: Proactive Automation Set" "Proactive automation set up for directory '$WATCH_DIR' with script '$SCRIPT_NAME'."
    else
        log "WARN" "Proactive automation for '$WATCH_DIR' with script '$SCRIPT_NAME' is already running."
    fi
}

# =====================
# Self-Improvement
# =====================
self_improvement() {
    local IMPROVEMENT_PROMPT="Analyze the following task manager memory data and logs. Suggest improvements to enhance its automation, error handling, adaptability, and overall performance:\n"

    # Fetch memory data
    local MEMORY_DATA
    MEMORY_DATA=$(sqlite3 "$DB_FILE" "SELECT * FROM scripts;" | awk -F'|' '{print "Script Name: "$1"\nPath: "$2"\nExecutions: "$3"\nAutomated: "$4"\nAnalysis: "$5"\n---"}')

    # Fetch recent commands
    local COMMAND_DATA
    COMMAND_DATA=$(sqlite3 "$DB_FILE" "SELECT command, analysis FROM commands ORDER BY timestamp DESC LIMIT 50;" | awk -F'|' '{print "Command: "$1"\nAnalysis: "$2"\n---"}')

    IMPROVEMENT_PROMPT+="$MEMORY_DATA\nCommands:\n$COMMAND_DATA"

    local IMPROVEMENT_RESPONSE
    IMPROVEMENT_RESPONSE=$(send_to_openai "$IMPROVEMENT_PROMPT" "gpt-4")

    # Clean improvement
    IMPROVEMENT_RESPONSE=$(echo "$IMPROVEMENT_RESPONSE" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

    # Save improvements to a separate file for review
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    echo "$IMPROVEMENT_RESPONSE" > "/home/nsatt-admin/task_manager/improvements_$TIMESTAMP.txt"

    log "INFO" "Self-improvement suggestions received from OpenAI and saved to improvements_$TIMESTAMP.txt."
    send_email "Task Manager Alert: Self-Improvement Suggestions" "New improvement suggestions have been saved. Please review the file '/home/nsatt-admin/task_manager/improvements_$TIMESTAMP.txt'."
}

# =====================
# Generate and Integrate New Script
# =====================
generate_and_integrate_script() {
    local DESCRIPTION="$1"
    local NEW_SCRIPT_CONTENT
    NEW_SCRIPT_CONTENT=$(generate_script "$DESCRIPTION")

    # Extract script name from description
    local NEW_SCRIPT_NAME
    NEW_SCRIPT_NAME=$(echo "$DESCRIPTION" | awk '{for(i=1;i<=NF;i++) if ($i=="script") {print $(i+1); exit}}')
    NEW_SCRIPT_NAME=$(sanitize_input "$NEW_SCRIPT_NAME.sh")

    # Save the new script to the plugins directory
    echo "$NEW_SCRIPT_CONTENT" > "$PLUGIN_DIR/$NEW_SCRIPT_NAME"
    chmod +x "$PLUGIN_DIR/$NEW_SCRIPT_NAME"

    log "INFO" "Generated new script: $NEW_SCRIPT_NAME based on description: $DESCRIPTION"
    send_email "Task Manager Notification: New Script Generated" "A new script '$NEW_SCRIPT_NAME' has been generated based on your description: '$DESCRIPTION'. Please review and integrate as needed."
}

# =====================
# Analyze Usage Patterns
# =====================
analyze_usage_patterns() {
    local COMMAND_HISTORY
    COMMAND_HISTORY=$(sqlite3 "$DB_FILE" "SELECT command FROM commands ORDER BY timestamp DESC LIMIT 100;")

    local PROMPT="Based on the following command history, identify patterns and suggest tasks that can be automated:\n$COMMAND_HISTORY"

    local RESPONSE
    RESPONSE=$(send_to_openai "$PROMPT" "gpt-4")

    local SUGGESTIONS
    SUGGESTIONS=$(echo "$RESPONSE" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

    log "INFO" "Usage pattern analysis:\n$SUGGESTIONS"
    send_email "Task Manager Notification: Usage Pattern Analysis" "Usage pattern analysis suggestions:\n$SUGGESTIONS"
}

# =====================
# Plugin Loader
# =====================
load_plugins() {
    for PLUGIN in "$PLUGIN_DIR"/*.sh; do
        if [[ -f "$PLUGIN" ]]; then
            source "$PLUGIN"
            log "INFO" "Loaded plugin: $(basename "$PLUGIN")"
        fi
    done
}

# =====================
# Task Scheduling (Cron Integration)
# =====================
schedule_task() {
    local TASK_NAME="$1"
    local CRON_TIME="$2"
    local SCRIPT_PATH="$3"

    # Sanitize inputs
    TASK_NAME=$(sanitize_input "$TASK_NAME")
    CRON_TIME=$(sanitize_input "$CRON_TIME")
    SCRIPT_PATH=$(sanitize_input "$SCRIPT_PATH")

    # Validate cron time format (basic validation)
    if ! [[ "$CRON_TIME" =~ ^([0-5]?[0-9]|\*)\ ([0-5]?[0-9]|\*)\ ([0-2]?[0-9]|\*)\ ([0-1]?[0-9]|\*)\ ([0-7]?[0-9]|\*)$ ]]; then
        log "ERROR" "Invalid cron time format: $CRON_TIME"
        send_email "Task Manager Alert: Invalid Cron Time" "The cron time '$CRON_TIME' provided for task '$TASK_NAME' is invalid."
        return 1
    fi

    # Add cron job
    (crontab -l 2>/dev/null; echo "$CRON_TIME bash $SCRIPT_PATH") | crontab -
    log "INFO" "Scheduled task '$TASK_NAME' with cron time '$CRON_TIME'."
    send_email "Task Manager Notification: Task Scheduled" "Task '$TASK_NAME' has been scheduled to run at '$CRON_TIME'."
}

# =====================
# AI-Driven Decision Trees (Simplified)
# =====================
ai_decision_tree() {
    local CURRENT_STATE="$1"
    local DECISION_PROMPT="Based on the current system state: $CURRENT_STATE\nSuggest the next best action to maintain system health."
    local DECISION_RESPONSE
    DECISION_RESPONSE=$(send_to_openai "$DECISION_PROMPT" "gpt-4")

    # Clean decision
    DECISION_RESPONSE=$(echo "$DECISION_RESPONSE" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

    echo "$DECISION_RESPONSE"
}

# =====================
# Command Management Functions
# =====================
add_command() {
    local COMMAND="$1"
    local ANALYSIS="$2"
    add_command_to_db "$COMMAND" "$ANALYSIS"
    log "INFO" "Added command to database: $COMMAND"
}

analyze_command() {
    local COMMAND="$1"
    local PROMPT="Analyze the following command and suggest any improvements or best practices:\n$COMMAND"
    local ANALYSIS
    ANALYSIS=$(send_to_openai "$PROMPT" "gpt-4")
    ANALYSIS=$(echo "$ANALYSIS" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')
    add_command "$COMMAND" "$ANALYSIS"
    log "INFO" "Command analyzed and stored."
}

reuse_command() {
    local COMMAND_ID="$1"
    local COMMAND
    COMMAND=$(sqlite3 "$DB_FILE" "SELECT command FROM commands WHERE id='$COMMAND_ID';")
    if [[ -n "$COMMAND" ]]; then
        log "INFO" "Reusing command ID $COMMAND_ID: $COMMAND"
        eval "$COMMAND"
    else
        log "WARN" "No command found with ID $COMMAND_ID."
    fi
}

improve_command() {
    local COMMAND_ID="$1"
    local COMMAND
    COMMAND=$(sqlite3 "$DB_FILE" "SELECT command FROM commands WHERE id='$COMMAND_ID';")
    if [[ -z "$COMMAND" ]]; then
        log "WARN" "No command found with ID $COMMAND_ID."
        return 1
    fi

    local PROMPT="Suggest improvements for the following command:\n$COMMAND"
    local IMPROVEMENT
    IMPROVEMENT=$(send_to_openai "$PROMPT" "gpt-4")
    IMPROVEMENT=$(echo "$IMPROVEMENT" | sed -e 's/^```bash\s*//' -e 's/^```//g' -e 's/```$//g')

    echo "===== Improvement Suggestions ====="
    echo "$IMPROVEMENT"
    echo "===================================="

    log "INFO" "Improvement suggestions provided for command ID $COMMAND_ID."
}

# =====================
# Menu Functions
# =====================
# Submenu for Script Management
script_submenu() {
    while true; do
        clear
        echo "===== Script Management ====="
        echo "1. Add a New Script"
        echo "2. View All Scripts"
        echo "3. Execute a Script"
        echo "4. Analyze a Script"
        echo "5. Back to Main Menu"
        echo "============================="
        read -rp "Choose an option: " SCRIPT_CHOICE

        case $SCRIPT_CHOICE in
            1)
                read -rp "Enter script name: " SCRIPT_NAME
                SCRIPT_NAME=$(sanitize_input "$SCRIPT_NAME")
                read -rp "Enter script path: " SCRIPT_PATH
                SCRIPT_PATH=$(sanitize_input "$SCRIPT_PATH")
                add_script_to_db "$SCRIPT_NAME" "$SCRIPT_PATH"
                read -rp "Press Enter to continue..."
                ;;
            2)
                echo "===== All Scripts ====="
                get_all_scripts | while IFS="|" read -r NAME PATH EXECUTIONS AUTOMATED; do
                    echo "Name: $NAME"
                    echo "Path: $PATH"
                    echo "Executions: $EXECUTIONS"
                    echo "Automated: $AUTOMATED"
                    echo "-----------------------------------"
                done
                echo "========================="
                read -rp "Press Enter to continue..."
                ;;
            3)
                read -rp "Enter the name of the script to execute: " EXECUTE_SCRIPT_NAME
                EXECUTE_SCRIPT_NAME=$(sanitize_input "$EXECUTE_SCRIPT_NAME")
                local EXECUTE_SCRIPT_PATH
                EXECUTE_SCRIPT_PATH=$(get_script_by_name "$EXECUTE_SCRIPT_NAME")
                if [[ -n "$EXECUTE_SCRIPT_PATH" ]]; then
                    execute_script "$EXECUTE_SCRIPT_PATH"
                else
                    log "WARN" "Script '$EXECUTE_SCRIPT_NAME' not found."
                fi
                read -rp "Press Enter to continue..."
                ;;
            4)
                read -rp "Enter the name of the script to analyze: " ANALYZE_SCRIPT_NAME
                ANALYZE_SCRIPT_NAME=$(sanitize_input "$ANALYZE_SCRIPT_NAME")
                local ANALYZE_SCRIPT_PATH
                ANALYZE_SCRIPT_PATH=$(get_script_by_name "$ANALYZE_SCRIPT_NAME")
                if [[ -n "$ANALYZE_SCRIPT_PATH" ]]; then
                    execute_script "$ANALYZE_SCRIPT_PATH"
                else
                    log "WARN" "Script '$ANALYZE_SCRIPT_NAME' not found."
                fi
                read -rp "Press Enter to continue..."
                ;;
            5)
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Submenu for Command Management
command_submenu() {
    while true; do
        clear
        echo "===== Command Management ====="
        echo "1. Add a New Command"
        echo "2. View All Commands"
        echo "3. Analyze a Command"
        echo "4. Reuse a Command"
        echo "5. Improve a Command"
        echo "6. Back to Main Menu"
        echo "=============================="
        read -rp "Choose an option: " COMMAND_CHOICE

        case $COMMAND_CHOICE in
            1)
                read -rp "Enter the command to add: " NEW_COMMAND
                NEW_COMMAND=$(sanitize_input "$NEW_COMMAND")
                analyze_command "$NEW_COMMAND"
                read -rp "Press Enter to continue..."
                ;;
            2)
                echo "===== All Commands ====="
                get_all_commands | while IFS="|" read -r ID COMMAND ANALYSIS TIMESTAMP; do
                    echo "ID: $ID"
                    echo "Command: $COMMAND"
                    echo "Analysis: $ANALYSIS"
                    echo "Timestamp: $TIMESTAMP"
                    echo "-----------------------------------"
                done
                echo "========================="
                read -rp "Press Enter to continue..."
                ;;
            3)
                read -rp "Enter the ID of the command to analyze: " ANALYZE_COMMAND_ID
                ANALYZE_COMMAND_ID=$(sanitize_input "$ANALYZE_COMMAND_ID")
                local COMMAND_TEXT
                COMMAND_TEXT=$(sqlite3 "$DB_FILE" "SELECT command FROM commands WHERE id='$ANALYZE_COMMAND_ID';")
                if [[ -n "$COMMAND_TEXT" ]]; then
                    analyze_command "$COMMAND_TEXT"
                else
                    log "WARN" "Command with ID '$ANALYZE_COMMAND_ID' not found."
                fi
                read -rp "Press Enter to continue..."
                ;;
            4)
                read -rp "Enter the ID of the command to reuse: " REUSE_COMMAND_ID
                REUSE_COMMAND_ID=$(sanitize_input "$REUSE_COMMAND_ID")
                reuse_command "$REUSE_COMMAND_ID"
                read -rp "Press Enter to continue..."
                ;;
            5)
                read -rp "Enter the ID of the command to improve: " IMPROVE_COMMAND_ID
                IMPROVE_COMMAND_ID=$(sanitize_input "$IMPROVE_COMMAND_ID")
                improve_command "$IMPROVE_COMMAND_ID"
                read -rp "Press Enter to continue..."
                ;;
            6)
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Main Menu
menu() {
    while true; do
        clear
        echo "===== Task Manager ====="
        echo "1. Script Management"
        echo "2. Command Management"
        echo "3. View Memory"
        echo "4. Summarize Memory"
        echo "5. Monitor Sessions"
        echo "6. Automate Learned Scripts"
        echo "7. Set Up Proactive Automation"
        echo "8. Request Self-Improvement"
        echo "9. Schedule a Task"
        echo "10. AI-Driven Decision"
        echo "11. Advanced Feedback"
        echo "12. Generate and Integrate New Script"
        echo "13. Analyze Usage Patterns"
        echo "14. Exit"
        echo "========================"
        read -rp "Choose an option: " MAIN_CHOICE

        case $MAIN_CHOICE in
            1)
                script_submenu
                ;;
            2)
                command_submenu
                ;;
            3)
                echo "===== View Memory ====="
                view_memory
                echo "========================"
                read -rp "Press Enter to continue..."
                ;;
            4)
                log "INFO" "Summarizing memory."
                summarize_memory
                read -rp "Press Enter to continue..."
                ;;
            5)
                log "INFO" "Starting session monitoring."
                monitor_session_activity
                ;;
            6)
                log "INFO" "Automating learned scripts."
                learn_and_automate
                read -rp "Press Enter to continue..."
                ;;
            7)
                read -rp "Enter the directory to watch: " WATCH_DIR
                WATCH_DIR=$(sanitize_input "$WATCH_DIR")
                read -rp "Enter the script name to execute on changes: " AUTOSCRIPT_NAME
                AUTOSCRIPT_NAME=$(sanitize_input "$AUTOSCRIPT_NAME")
                proactive_automation "$WATCH_DIR" "$AUTOSCRIPT_NAME"
                read -rp "Press Enter to continue..."
                ;;
            8)
                log "INFO" "Requesting self-improvement."
                self_improvement
                read -rp "Press Enter to continue..."
                ;;
            9)
                read -rp "Enter the task name: " TASK_NAME
                TASK_NAME=$(sanitize_input "$TASK_NAME")
                read -rp "Enter the cron time (e.g., */5 * * * *): " CRON_TIME
                CRON_TIME=$(sanitize_input "$CRON_TIME")
                read -rp "Enter the full path to the script: " SCHEDULE_SCRIPT_PATH
                SCHEDULE_SCRIPT_PATH=$(sanitize_input "$SCHEDULE_SCRIPT_PATH")
                schedule_task "$TASK_NAME" "$CRON_TIME" "$SCHEDULE_SCRIPT_PATH"
                read -rp "Press Enter to continue..."
                ;;
            10)
                read -rp "Enter the current system state or issue: " CURRENT_STATE
                CURRENT_STATE=$(sanitize_input "$CURRENT_STATE")
                local DECISION
                DECISION=$(ai_decision_tree "$CURRENT_STATE")
                echo "===== AI Decision ====="
                echo "$DECISION"
                echo "======================="
                log "INFO" "AI-driven decision provided."
                read -rp "Press Enter to continue..."
                ;;
            11)
                log "INFO" "Requesting advanced feedback."
                advanced_feedback
                read -rp "Press Enter to continue..."
                ;;
            12)
                read -rp "Enter a description for the new script (e.g., 'backup logs every day'): " DESCRIPTION
                generate_and_integrate_script "$DESCRIPTION"
                read -rp "Press Enter to continue..."
                ;;
            13)
                log "INFO" "Analyzing usage patterns."
                analyze_usage_patterns
                read -rp "Press Enter to continue..."
                ;;
            14)
                log "INFO" "Exiting Task Manager."
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
}

# =====================
# Plugin Loader
# =====================
load_plugins

# =====================
# Main Function
# =====================
main() {
    log "INFO" "Task Manager started."
    menu
}

# Execute main function
main
