#!/bin/bash

# =============================================================================
# Script Name: set_ip_address.sh
# Description: Comprehensive network management script with robust error
#              handling, dynamic interface management, automated failover,
#              SMTP notifications with encrypted passwords, SQLite3 logging,
#              hotspot creation, VPN support, and service management.
# =============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# ---------------------------- Configuration ----------------------------

# Directories and Files
LOG_DIR="/home/nsatt-admin/nsatt/logs"
SETTINGS_DIR="/home/nsatt-admin/nsatt/settings"
LOG_FILE="${LOG_DIR}/network_manager.log"
DB_FILE="${LOG_DIR}/network_manager.db"
BACKUP_DIR="/home/nsatt-admin/nsatt/backups"
INTERFACES_FILE="/etc/network/interfaces"
EMAIL_QUEUE_FILE="${SETTINGS_DIR}/email_queue.txt"
PID_FILE="/var/run/network_manager.pid"

# Network Settings
PING_ADDRESS="8.8.8.8"
CHECK_INTERVAL=60  # seconds
FALLBACK_MODE=true  # Initialize fallback_mode as true

# SMTP Configuration
SMTP_CONFIG_SETUP_FILE="${SETTINGS_DIR}/smtp_config_setup.json"
SMTP_CONFIG_FILE="${SETTINGS_DIR}/smtp_config.json"
SMTP_KEY_FILE="${SETTINGS_DIR}/smtp_key.key"

# Priority List Configuration File
PRIORITY_CONFIG_FILE="${SETTINGS_DIR}/priority_list.conf"

# Hotspot Configuration
HOTSPOT_SSID="NSATT-NETWORK"
HOTSPOT_PASSWORD="12345678"

# Python Web Interface
LAUNCH_PYTHON_SCRIPT=true  # Set to false to disable launching the Python script
PYTHON_SCRIPT="/usr/local/bin/network_manager_web_interface.py"
PYTHON_LOG="${LOG_DIR}/network_manager_web.log"
WEB_INTERFACE_PORT=8079

# VPN Configuration
ENABLE_VPN=true  # Set to false to disable VPN functionality
VPN_CONFIG_FILE="${SETTINGS_DIR}/vpn_config.ovpn"
VPN_AUTOSTART_FILE="${SETTINGS_DIR}/vpn_autostart"

# Feature Toggles (Set to false to disable specific features)
CHECK_DEPENDENCIES=false
INITIALIZE_DATABASE=false
ENABLE_HOTSPOT=true
CONNECT_ON_ALL_ADAPTERS=true
BRING_UP_ALL_DEVICES=true
LAUNCH_WEB_INTERFACE=false
MANAGE_VPN=true

# Additional Feature Toggles
ENABLE_BACKUP=false
ENABLE_SELF_UPDATE=false
ENABLE_LOG_ROTATION=false

# Autostart Files
AUTOSTART_FILE="${SETTINGS_DIR}/network_manager_autostart"
HOTSPOT_AUTOSTART_FILE="${SETTINGS_DIR}/hotspot_autostart"
CONNECT_ADAPTERS_AUTOSTART_FILE="${SETTINGS_DIR}/connect_adapters_autostart"
BRING_UP_DEVICES_AUTOSTART_FILE="${SETTINGS_DIR}/bring_up_devices_autostart"
VPN_AUTOSTART_FILE="${SETTINGS_DIR}/vpn_autostart"
WEB_INTERFACE_AUTOSTART_FILE="${SETTINGS_DIR}/web_interface_autostart"

# Startup Files
queue_email_FILE="${SETTINGS_DIR}/queue_email_check"
ENABLE_BACKUP_FILE="${SETTINGS_DIR}/enable_backup_check"
ENABLE_SELF_UPDATE_FILE="${SETTINGS_DIR}/enable_self_update_check"

# NSATT Production Mode
production_mode_enabled=false

testing_mode() {
    ENABLE_EMAIL=$ENABLE_EMAIL
    ENABLE_BACKUP=$ENABLE_BACKUP
    ENABLE_SELF_UPDATE=$ENABLE_SELF_UPDATE
}

production_mode() {
    # Ensure the files exist in the settings folder
    [ -f "$queue_email_FILE" ] || touch "$queue_email_FILE"
    [ -f "$ENABLE_BACKUP_FILE" ] || touch "$ENABLE_BACKUP_FILE"
    [ -f "$ENABLE_SELF_UPDATE_FILE" ] || touch "$ENABLE_SELF_UPDATE_FILE"
    [ -f "$HOTSPOT_AUTOSTART_FILE" ] || touch "$HOTSPOT_AUTOSTART_FILE"
    [ -f "$VPN_AUTOSTART_FILE" ] || touch "$VPN_AUTOSTART_FILE"
    [ -f "$AUTOSTART_FILE" ] || touch "$AUTOSTART_FILE"
    [ -f "$CONNECT_ADAPTERS_AUTOSTART_FILE" ] || touch "$CONNECT_ADAPTERS_AUTOSTART_FILE"
    [ -f "$BRING_UP_DEVICES_AUTOSTART_FILE" ] || touch "$BRING_UP_DEVICES_AUTOSTART_FILE"
    [ -f "$WEB_INTERFACE_AUTOSTART_FILE" ] || touch "$WEB_INTERFACE_AUTOSTART_FILE"

    # Set the variables based on the presence of the files
    ENABLE_EMAIL=$( [ -f "$queue_email_FILE" ] && echo true || echo false )
    ENABLE_BACKUP=$( [ -f "$ENABLE_BACKUP_FILE" ] && echo true || echo false )
    ENABLE_SELF_UPDATE=$( [ -f "$ENABLE_SELF_UPDATE_FILE" ] && echo true || echo false )
    ENABLE_HOTSPOT=$( [ -f "$HOTSPOT_AUTOSTART_FILE" ] && echo true || echo false )
    ENABLE_VPN=$( [ -f "$VPN_AUTOSTART_FILE" ] && echo true || echo false )
    CHECK_DEPENDENCIES=$( [ -f "$AUTOSTART_FILE" ] && echo true || echo false )
    INITIALIZE_DATABASE=$( [ -f "$AUTOSTART_FILE" ] && echo true || echo false )
    CONNECT_ON_ALL_ADAPTERS=$( [ -f "$CONNECT_ADAPTERS_AUTOSTART_FILE" ] && echo true || echo false )
    BRING_UP_ALL_DEVICES=$( [ -f "$BRING_UP_DEVICES_AUTOSTART_FILE" ] && echo true || echo false )
    LAUNCH_WEB_INTERFACE=$( [ -f "$WEB_INTERFACE_AUTOSTART_FILE" ] && echo true || echo false )
    MANAGE_VPN=$( [ -f "$VPN_AUTOSTART_FILE" ] && echo true || echo false )
    ENABLE_LOG_ROTATION=$( [ -f "$AUTOSTART_FILE" ] && echo true || echo false )
}

# -----------------------------Move Files to Correct Locations-----------------------------

reload_files() {
    # Paths
    local base_dir="/home/nsatt-admin/nsatt"
    local bin_dir="/usr/local/bin"
    local systemd_dir="/etc/systemd/system"
    local log_dir="$base_dir/logs"
    local debug_mode2=true

    # Stylish headers and separators
    local separator="============================================================="
    local success="SUCCESS:"
    local warning="WARNING:"
    local error="ERROR:"

    echo -e "\n$separator"
    echo -e " RELOADING OPERATION FILES"
    echo -e "$separator"

    # Files to move
    declare -A files=(
        ["$base_dir/hid_script.sh"]="$bin_dir/hid_script.sh"
        ["$base_dir/keyboard_script.sh"]="$bin_dir/keyboard_script.sh"
        ["$base_dir/restart_app.sh"]="$bin_dir/restart_app.sh"
        ["$base_dir/start_app_launcher.py"]="$bin_dir/start_app_launcher.py"
        ["$base_dir/start_app_launcher.service"]="$systemd_dir/start_app_launcher.service"
        ["$base_dir/set_ip_address.sh"]="$bin_dir/set_ip_address.sh"
        ["$base_dir/set_ip_address.service"]="$systemd_dir/set_ip_address.service"
        ["$base_dir/restart_launcher.sh"]="$bin_dir/restart_launcher.sh"
        ["$base_dir/network_manager_web_interface.py"]="$bin_dir/network_manager_web_interface.py"
        ["$base_dir/network_manager_web_interface.service"]="$systemd_dir/network_manager_web_interface.service"
    )

    # Permissions
    local permissions=(
        "$bin_dir/hid_script.sh"
        "$bin_dir/keyboard_script.sh"
        "$bin_dir/restart_app.sh"
        "$bin_dir/start_app_launcher.py"
        "$bin_dir/set_ip_address.sh"
        "$systemd_dir/start_app_launcher.service"
        "$systemd_dir/set_ip_address.service"
        "$bin_dir/network_manager_web_interface.py"
        "$systemd_dir/network_manager_web_interface.service"
        "$bin_dir/restart_launcher.sh"
    )

    # Moving files
    echo -e "\n$separator"
    echo " Moving Files to Target Directories"
    echo -e "$separator"
    for src in "${!files[@]}"; do
        local dest="${files[$src]}"
        if [ -f "$src" ]; then
            if mv "$src" "$dest"; then
                echo " $success Moved $src to $dest"
            else
                echo " $error Failed to move $src to $dest"
            fi
        else
            echo " $warning File $src not found. Skipping."
        fi
    done

    # Ensure log directory exists
    echo -e "\n$separator"
    echo " Ensuring Log Directory Exists"
    echo -e "$separator"
    if [ ! -d "$log_dir" ]; then
        if mkdir -p "$log_dir"; then
            echo " $success Created log directory $log_dir"
        else
            echo " $error Failed to create log directory $log_dir"
        fi
    else
        echo " $success Log directory $log_dir already exists"
    fi

    # Debug-specific operations
    echo -e "\n$separator"
    echo " Debug Operations"
    echo -e "$separator"
    if [ "$debug_mode2" = true ]; then
        local debug_log="$log_dir/set_ip_address.log"
        if [ -f "$debug_log" ]; then
            rm -f "$debug_log" && echo " $success Removed old debug log $debug_log"
        fi
        touch "$debug_log" && echo " $success Created new debug log $debug_log"
        chmod 755 "$debug_log" && echo " $success Set permissions for $debug_log"
    fi

    # Set permissions
    echo -e "\n$separator"
    echo " Updating File Permissions"
    echo -e "$separator"
    for file in "${permissions[@]}"; do
        if [ -f "$file" ]; then
            if chmod 755 "$file"; then
                echo " $success Updated permissions for $file"
            else
                echo " $error Failed to update permissions for $file"
            fi
        else
            echo " $warning File $file not found. Skipping permission update."
        fi
    done

    # Convert files to Unix format
    echo -e "\n$separator"
    echo " Converting Files to Unix Format"
    echo -e "$separator"
    for file in "${permissions[@]}"; do
        if [ -f "$file" ]; then
            if dos2unix "$file"; then
                echo " $success Converted $file to Unix format"
            else
                echo " $error Failed to convert $file to Unix format"
            fi
        fi
    done

    # List updated files
    echo -e "\n$separator"
    echo " Listing Updated Files"
    echo -e "$separator"
    for file in "${permissions[@]}"; do
        if [ -f "$file" ]; then
            ls -l "$file"
        fi
    done

    # Success message
    echo -e "\n$separator"
    echo " All files reloaded successfully."
    echo -e "$separator\n"
}

# ---------------------------- Initialize Logging and Database ----------------------------

# Create necessary directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$SETTINGS_DIR"
mkdir -p "$BACKUP_DIR"

# Initialize SQLite3 Database
initialize_database() {
    if [ "$INITIALIZE_DATABASE" = false ]; then
        log_event "INFO" "Skipping database initialization as per configuration."
        return
    fi

    if [ ! -f "$DB_FILE" ]; then
        sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS network_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    interface TEXT NOT NULL,
    event TEXT NOT NULL,
    details TEXT
);
CREATE TABLE IF NOT EXISTS smtp_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    smtp_server TEXT NOT NULL,
    smtp_port INTEGER NOT NULL,
    smtp_user TEXT,
    smtp_password_encrypted TEXT,
    recipient_email TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS vpn_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    vpn_name TEXT NOT NULL,
    status TEXT NOT NULL,
    details TEXT
);
EOF
        log_event "INFO" "Initialized SQLite3 database at $DB_FILE."
    else
        log_event "INFO" "Database already initialized at $DB_FILE."
    fi
}

# ---------------------------- Utility Functions ----------------------------

# Function to ensure only one instance is running
ensure_single_instance() {
    local pid
    local port=8079
    local script_name="set_ip_address.sh"

    # Check if the PID file exists
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")

        # Check if the process with the PID is running
        if kill -0 "$pid" &>/dev/null; then
            if [ "$pid" != "$$" ]; then
                log_event "WARNING" "Another instance of the script is already running with PID: $pid. Terminating it."

                # Kill the other instance and clean up its PID file
                if kill -9 "$pid" &>/dev/null; then
                    log_event "INFO" "Successfully terminated instance with PID: $pid."
                    rm -f "$PID_FILE"
                else
                    log_event "ERROR" "Failed to terminate instance with PID: $pid. Exiting."
                    exit 1
                fi
            else
                log_event "INFO" "This instance is already running with PID: $$. Continuing execution."
                return
            fi
        else
            # PID file exists but process is not running
            log_event "WARNING" "Stale PID file found with PID: $pid. Removing it."
            rm -f "$PID_FILE"
        fi
    fi

    # Check if port 8079 is in use
    if lsof -i :$port &>/dev/null; then
        log_event "WARNING" "Port $port is in use. Attempting to kill the process occupying it."

        # Get the PID of the process using the port and kill it
        local port_pid
        port_pid=$(lsof -ti :$port)
        if [ -n "$port_pid" ] && [ "$port_pid" != "$$" ]; then
            if kill -9 "$port_pid" &>/dev/null; then
                log_event "INFO" "Successfully killed process $port_pid using port $port."
            else
                log_event "ERROR" "Failed to kill process $port_pid using port $port. Continuing."
            fi
        fi
    fi

    # Ensure no other instance of the same script is running
    local existing_pids
    existing_pids=$(pgrep -f "$script_name" | grep -v $$)
    if [ -n "$existing_pids" ]; then
        log_event "WARNING" "Another instance(s) of $script_name found with PID(s): $existing_pids. Terminating them."

        for pid in $existing_pids; do
            if kill -9 "$pid" &>/dev/null; then
                log_event "INFO" "Successfully terminated $script_name instance with PID: $pid."
            else
                log_event "ERROR" "Failed to terminate $script_name instance with PID: $pid."
            fi
        done
    fi

    # Write the current script's PID to the PID file
    echo $$ > "$PID_FILE"
    log_event "INFO" "Script started with PID $$ and PID file '$PID_FILE' created."

    # Set a trap to clean up on exit
    trap 'rm -f "$PID_FILE"; exit' INT TERM EXIT
}

# Function to restart the script
restart_script() {
    log_event "INFO" "Restarting the script..."
    rm -f "$PID_FILE"  # Clean up the PID file
    exec "$0" "$@"     # Restart the script
}

# Function to log messages to both log file and SQLite3
# Log Event Function with Debug Mode Switch
log_event() {
    local level="$1"
    local message="$2"
    local context="$3"

    if [[ "$level" == "DEBUG" && "$DEBUG_MODE" == false ]]; then
        return 0
    fi

    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    if [[ -n "$context" ]]; then
        echo "$timestamp - [$level] - $message ($context)"
    else
        echo "$timestamp - [$level] - $message"
    fi
}

# Centralized error handling with retries and exponential backoff
handle_error() {
    local error_message="$1"    # Description of the error
    local retry_command="$2"    # Command to retry
    local max_retries="${3:-3}" # Maximum number of retries (default: 3)
    local initial_delay="${4:-5}" # Initial delay before retrying in seconds (default: 5)
    local interface="${5:-N/A}"  # Associated network interface (optional)
    local attempt=1
    local sleep_time

    while [ $attempt -le $max_retries ]; do
        log_event "WARNING" "Attempt $attempt of $max_retries: $error_message" "$interface"

        # Add a short delay before retrying the first attempt to ensure the system stabilizes
        if [ $attempt -gt 1 ]; then
            log_event "INFO" "Delaying for $initial_delay seconds to stabilize before retrying..." "$interface"
            sleep "$initial_delay"
        fi

        # Execute the command and check the result
        if eval "$retry_command"; then
            log_event "INFO" "Recovery succeeded on attempt $attempt." "$interface"
            return 0
        fi

        # Calculate the exponential backoff time
        sleep_time=$((initial_delay * 2 ** (attempt - 1)))
        log_event "INFO" "Retrying in $sleep_time seconds..." "$interface"
        sleep "$sleep_time"

        attempt=$((attempt + 1))
    done

    # After all retries have failed, log an error and notify via email
    log_event "ERROR" "Maximum retry attempts reached: $error_message. Manual intervention required." "$interface"
    queue_email "Network Manager Error" "$error_message"
    return 1
}

# Function to queue SMTP email notifications
queue_email() {
    local subject="$1"
    local body="$2"

    # Ensure email queue file exists
    if [ ! -f "$EMAIL_QUEUE_FILE" ]; then
        sudo touch "$EMAIL_QUEUE_FILE" && sudo chmod 666 "$EMAIL_QUEUE_FILE" || {
            log_event "ERROR" "Failed to create or access email queue file: $EMAIL_QUEUE_FILE."
            return 1
        }
    fi

    # Queue the email
    echo "$subject|$body" >> "$EMAIL_QUEUE_FILE"
}

# Function to send all queued emails
send_queued_emails() {
    # Check internet connectivity
    if ! ping -c 1 -W 2 "$PING_ADDRESS" &> /dev/null; then
        log_event "WARNING" "No internet connection. Emails will be sent when connectivity is restored."
        return 0
    fi

    if [ ! -f "$SMTP_CONFIG_FILE" ]; then
        log_event "ERROR" "SMTP configuration file not found: $SMTP_CONFIG_FILE. Unable to send emails."
        return 1
    fi

    # Load SMTP configuration
    SMTP_SERVER=$(jq -r '.smtp_server' "$SMTP_CONFIG_FILE")
    SMTP_PORT=$(jq -r '.smtp_port' "$SMTP_CONFIG_FILE")
    SMTP_USER=$(jq -r '.smtp_user' "$SMTP_CONFIG_FILE")
    ENCRYPTED_PASSWORD=$(jq -r '.smtp_password_encrypted' "$SMTP_CONFIG_FILE")
    RECIPIENT_EMAIL=$(jq -r '.recipient_email' "$SMTP_CONFIG_FILE")

    if [ -z "$SMTP_SERVER" ] || [ -z "$SMTP_PORT" ] || [ -z "$SMTP_USER" ] || [ -z "$ENCRYPTED_PASSWORD" ] || [ -z "$RECIPIENT_EMAIL" ]; then
        log_event "ERROR" "Incomplete SMTP configuration in $SMTP_CONFIG_FILE."
        return 1
    fi

    if [ ! -f "$SMTP_KEY_FILE" ]; then
        log_event "ERROR" "SMTP key file not found: $SMTP_KEY_FILE. Cannot decrypt SMTP password."
        return 1
    fi

    # Decrypt SMTP password
    SMTP_PASSWORD=$(echo "$ENCRYPTED_PASSWORD" | openssl enc -aes-256-cbc -d -a -salt -pass file:"$SMTP_KEY_FILE" 2>/dev/null)
    if [ -z "$SMTP_PASSWORD" ]; then
        log_event "ERROR" "Failed to decrypt SMTP password."
        return 1
    fi

    # Process email queue
    while IFS='|' read -r queued_subject queued_body; do
        echo "$queued_body" | mail -s "$queued_subject" -S smtp="smtp://$SMTP_SERVER:$SMTP_PORT" \
            -S smtp-auth=login -S smtp-auth-user="$SMTP_USER" -S smtp-auth-password="$SMTP_PASSWORD" \
            -S from="$SMTP_USER" "$RECIPIENT_EMAIL" &> /dev/null

        if [ $? -eq 0 ]; then
            log_event "INFO" "Sent email: $queued_subject."
        else
            log_event "ERROR" "Failed to send email: $queued_subject."
        fi
    done < "$EMAIL_QUEUE_FILE"

    # Clear the queue after processing
    > "$EMAIL_QUEUE_FILE"
}

# Function to execute a command and log its output, with error handling
execute_command() {
    local command="$1"           # Command to execute
    local description="$2"       # Description of the command for logging
    local interface="${3:-N/A}"  # Network interface related to the command (optional)
    local retries=3              # Number of retry attempts
    local initial_delay=5        # Initial delay between retries in seconds

    for (( attempt=1; attempt<=retries; attempt++ )); do
        log_event "INFO" "Attempt $attempt: $description on interface '$interface'." "$interface"
        
        # Execute the command and capture both stdout and stderr
        eval "$command" > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)
        local status=$?

        if [ $status -eq 0 ]; then
            log_event "INFO" "$description succeeded on interface '$interface'." "$interface"
            return 0
        else
            log_event "WARNING" "$description failed on interface '$interface'. Exit status: $status." "$interface"
            if [ $attempt -lt $retries ]; then
                log_event "INFO" "Retrying in $initial_delay seconds..." "$interface"
                sleep $initial_delay
                # Exponential backoff for subsequent retries
                initial_delay=$(( initial_delay * 2 ))
            fi
        fi
    done

    # After all retries have failed
    log_event "ERROR" "$description failed after $retries attempts. Command: '$command'" "$interface"
    queue_email "Network Manager Error: Command Execution Failure" "Failed to execute '$description' on interface '$interface' after $retries attempts. Command: '$command'"
    return 1
}

# Function to create a backup of current network settings
create_backup() {
    # Check if backup functionality is enabled
    if [ "${ENABLE_BACKUP:-false}" != "true" ]; then
        log_event "INFO" "Skipping backup creation as per configuration."
        return 0
    fi

    # Ensure the backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        log_event "INFO" "Backup directory '$BACKUP_DIR' does not exist. Attempting to create it."
        if execute_command "sudo mkdir -p '$BACKUP_DIR'" "Creating backup directory '$BACKUP_DIR'"; then
            log_event "INFO" "Backup directory '$BACKUP_DIR' created successfully."
        else
            log_event "ERROR" "Failed to create backup directory '$BACKUP_DIR'. Backup creation aborted."
            queue_email "Network Manager Error: Backup Directory Creation" "Failed to create backup directory '$BACKUP_DIR'. Backup creation was aborted."
            return 1
        fi
    fi

    # Generate a timestamp for the backup file
    local timestamp
    timestamp=$(date '+%Y%m%d%H%M%S')
    local backup_file="${BACKUP_DIR}/interfaces.backup.$timestamp"

    # Check if the interfaces file exists before attempting backup
    if [ -f "$INTERFACES_FILE" ]; then
        log_event "INFO" "Creating backup of '$INTERFACES_FILE' at '$backup_file'."
        if execute_command "sudo cp '$INTERFACES_FILE' '$backup_file'" "Creating backup of network settings" "N/A"; then
            log_event "INFO" "Backup of '$INTERFACES_FILE' created successfully at '$backup_file'."
        else
            log_event "ERROR" "Failed to create backup of '$INTERFACES_FILE' at '$backup_file'."
            queue_email "Network Manager Error: Backup Failure" "Failed to create backup of '$INTERFACES_FILE' at '$backup_file'."
            return 1
        fi

        # Keep only the last 5 backups
        local backup_count
        backup_count=$(ls -1 "${BACKUP_DIR}/interfaces.backup."* 2>/dev/null | wc -l)
        if [ "$backup_count" -gt 5 ]; then
            log_event "INFO" "Cleaning up old backups. Keeping only the latest 5 backups."
            ls -1t "${BACKUP_DIR}/interfaces.backup."* 2>/dev/null | tail -n +6 | while read -r old_backup; do
                if execute_command "sudo rm -f '$old_backup'" "Removing old backup '$old_backup'" "N/A"; then
                    log_event "INFO" "Removed old backup '$old_backup'."
                else
                    log_event "WARNING" "Failed to remove old backup '$old_backup'. Manual cleanup may be required."
                fi
            done
        fi
    else
        log_event "WARNING" "'$INTERFACES_FILE' does not exist. Skipping backup."
    fi
}

# Function to restore from backup if inconsistencies are detected
restore_backup_if_needed() {
    # Check if backup restoration is enabled
    if [ "${ENABLE_BACKUP:-false}" != "true" ]; then
        log_event "INFO" "Skipping backup restoration as per configuration."
        return 0
    fi

    # Find the latest backup file
    local last_backup
    last_backup=$(ls -1t "${BACKUP_DIR}/interfaces.backup."* 2>/dev/null | head -n 1)

    if [ -f "$last_backup" ]; then
        log_event "INFO" "Latest backup found: '$last_backup'. Checking for inconsistencies."
        
        # Compare the current interfaces file with the backup
        if ! diff "$INTERFACES_FILE" "$last_backup" &>/dev/null; then
            log_event "WARNING" "Detected inconsistency in '$INTERFACES_FILE'. Initiating restoration from backup."
            if execute_command "sudo cp '$last_backup' '$INTERFACES_FILE'" "Restoring network settings from backup" "N/A"; then
                log_event "INFO" "Restored '$INTERFACES_FILE' from backup '$last_backup' successfully."
                # Restart networking service to apply restored settings
                if execute_command "sudo systemctl restart networking" "Restarting networking service after restoration" "N/A"; then
                    log_event "INFO" "Networking service restarted successfully after restoration."
                    queue_email "Network Manager Alert: Restored from Backup" "Network settings were restored from backup '$last_backup' due to detected inconsistencies."
                else
                    log_event "ERROR" "Failed to restart networking service after restoring from backup."
                    queue_email "Network Manager Error: Networking Restart Failure" "Failed to restart networking service after restoring network settings from backup '$last_backup'. Manual intervention may be required."
                    return 1
                fi
            else
                log_event "ERROR" "Failed to restore '$INTERFACES_FILE' from backup '$last_backup'."
                queue_email "Network Manager Error: Backup Restoration Failure" "Failed to restore '$INTERFACES_FILE' from backup '$last_backup'. Manual intervention may be required."
                return 1
            fi
        else
            log_event "INFO" "No inconsistencies detected in '$INTERFACES_FILE'. No restoration needed."
        fi
    else
        log_event "ERROR" "No backup found to restore. Ensure that backups are being created properly."
        queue_email "Network Manager Error: Backup Missing" "Attempted to restore network settings, but no backup was found in '$BACKUP_DIR'. Ensure that backups are being created correctly."
        return 1
    fi
}

# ---------------------------- Network Interface Functions ----------------------------

# Improved get_ip Function with Debug Checkpoints
# CIDR to Netmask Converter with Debug Checkpoints
get_subnet_mask() {
    local interface="$1"
    local cidr
    local subnet_mask

    # Extract CIDR from the interface output
    cidr=$(ip -o -4 addr show dev "$interface" | awk '{print $4}' | cut -d'/' -f2)
    
    # Validate CIDR and convert to subnet mask
    if [[ "$cidr" =~ ^[0-9]+$ ]] && ((cidr >= 0 && cidr <= 32)); then
        subnet_mask=$(cidr_to_netmask "$cidr")
        echo "$subnet_mask"
    else
        echo "N/A"  # Return N/A if CIDR is invalid
    fi
}

# Convert CIDR to subnet mask
cidr_to_netmask() {
    local cidr="$1"
    local mask=""
    local bits=0
    local octets=$((cidr / 8))  # Full 255 octets
    local remainder=$((cidr % 8))  # Remaining bits

    # Add full 255 octets
    for ((i = 0; i < octets; i++)); do
        mask+="255."
    done

    # Add the partial octet, if any
    if ((remainder > 0)); then
        bits=$((256 - 2 ** (8 - remainder)))
        mask+="${bits}."
    fi

    # Fill remaining octets with 0 to ensure a valid subnet mask
    while [[ "$(echo "$mask" | awk -F'.' '{print NF - 1}')" -lt 3 ]]; do
        mask+="0."
    done

    # Remove trailing dot
    mask="${mask%.}"

    # Validate and correct the mask if it seems incomplete
    if ! validate_ip "$mask"; then
        # Split the mask into octets
        IFS='.' read -r -a octets <<< "$mask"

        # Ensure there are 4 octets
        while [[ "${#octets[@]}" -lt 4 ]]; do
            octets+=("0")
        done

        # Rebuild the corrected mask
        mask="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}"
    fi

    echo "$mask"
}

# Improved get_ip Function
get_ip() {
    local interface="$1"
    local ip

    # Retrieve IPv4 address for the interface
    ip=$(ip -o -4 addr show "$interface" 2>/dev/null | awk '{print $4}' | cut -d'/' -f1)

    # Check if a valid IP was found
    if [[ -z "$ip" ]]; then
        return 1
    fi

    # Validate the IP format
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    else
        return 2
    fi
}

validate_ip() {
    local ip="$1"

    # Check if the input is in the format of an IPv4 address or a partial subnet mask
    if [[ "$ip" =~ ^([0-9]{1,3}\.){1,3}[0-9]{0,3}$ ]]; then
        # Split the IP into octets
        IFS='.' read -r octet1 octet2 octet3 octet4 <<< "$ip"

        # Validate each octet is between 0 and 255, allowing empty octets for subnet masks
        if [[ -z "$octet4" ]]; then
            octet4=0
        fi

        if ((octet1 >= 0 && octet1 <= 255)) && \
           ((octet2 >= 0 && octet2 <= 255)) && \
           ((octet3 >= 0 && octet3 <= 255)) && \
           ((octet4 >= 0 && octet4 <= 255)); then
            return 0  # Valid IP or subnet mask
        fi
    fi

    return 1  # Invalid IP or subnet mask
}

# Function to check internet connectivity
check_internet() {
    local interface="$1"             # Network interface to check
    local ping_address="${PING_ADDRESS:-8.8.8.8}" # Address to ping (default: Google DNS)
    local ping_count=4                # Number of ping attempts
    local ping_timeout=2              # Timeout per ping in seconds

    # Validate the interface name
    if ! ip link show "$interface" &>/dev/null; then
        log_event "ERROR" "Cannot check internet connectivity. Interface '$interface' does not exist." "$interface"
        return 1
    fi

    # Bring up the interface if it's down
    if ! ip link show "$interface" | grep -qw "UP"; then
        log_event "INFO" "Interface '$interface' is down. Attempting to bring it up." "$interface"
        if execute_command "sudo ip link set $interface up" "Bringing up interface '$interface'" "$interface"; then
            log_event "INFO" "Successfully brought up interface '$interface'." "$interface"
            sleep 2  # Allow time for the interface to initialize
        else
            log_event "ERROR" "Failed to bring up interface '$interface'." "$interface"
            return 1
        fi
    fi

    log_event "INFO" "Checking internet connectivity on interface '$interface' by pinging '$ping_address'." "$interface"

    # Perform the ping test
    if ping -I "$interface" -c "$ping_count" -W "$ping_timeout" "$ping_address" &>/dev/null; then
        log_event "INFO" "Internet connectivity confirmed on interface '$interface'." "$interface"
        return 0
    else
        log_event "WARNING" "No internet connectivity detected on interface '$interface'." "$interface"
        return 1
    fi
}

# Function to get all active network interfaces, optionally excluding loopback
get_all_interfaces() {
    local exclude_lo="${1:-false}"  # Set to 'true' to exclude the loopback interface 'lo'

    if [ "$exclude_lo" = "true" ]; then
        ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$'
    else
        ip -o link show | awk -F': ' '{print $2}'
    fi
}

# Function to update the priority list of network interfaces based on custom configuration and detected interfaces
update_priority_list() {
    log_event "INFO" "Updating priority list of network interfaces."

    # Initialize arrays
    local custom_priorities=()
    local detected_interfaces=()
    local updated_priority_list=()

    # Read custom priorities from configuration file if it exists
    if [ -f "$PRIORITY_CONFIG_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            # Ignore empty lines and comments
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            custom_priorities+=("$line")
        done < "$PRIORITY_CONFIG_FILE"
        log_event "DEBUG" "Custom priorities loaded: ${custom_priorities[*]}"
    else
        log_event "DEBUG" "Priority configuration file '$PRIORITY_CONFIG_FILE' not found. Proceeding without custom priorities."
    fi

    # Detect all available network interfaces excluding loopback
    detected_interfaces=($(get_all_interfaces true))
    log_event "DEBUG" "Detected network interfaces: ${detected_interfaces[*]}"

    # Combine custom priorities and detected interfaces
    for iface in "${custom_priorities[@]}"; do
        if [[ " ${detected_interfaces[*]} " == *" $iface "* ]]; then
            updated_priority_list+=("$iface")
            log_event "DEBUG" "Added custom priority interface '$iface' to the priority list."
        else
            log_event "WARNING" "Custom priority interface '$iface' is not detected among active interfaces."
        fi
    done

    # Append remaining detected interfaces that are not already in the priority list
    for iface in "${detected_interfaces[@]}"; do
        if [[ ! " ${updated_priority_list[*]} " == *" $iface "* ]]; then
            updated_priority_list+=("$iface")
            log_event "DEBUG" "Added detected interface '$iface' to the priority list."
        fi
    done

    # Remove duplicate entries just in case
    PRIORITY_LIST=($(echo "${updated_priority_list[@]}" | tr ' ' '\n' | awk '!seen[$0]++'))

    log_event "INFO" "Updated PRIORITY_LIST: ${PRIORITY_LIST[*]}"
}

# Function to select and test interfaces based on priority
select_and_test_interface() {
    local selected_interface=""
    local interface

    for interface in "${PRIORITY_LIST[@]}"; do
        if ip link show "$interface" &> /dev/null; then
            log_event "INFO" "Evaluating interface: $interface" "$interface"
            local ip_address
            ip_address=$(get_ip "$interface")
            if [ -n "$ip_address" ]; then
                log_event "INFO" "Interface $interface has IP address $ip_address" "$interface"
            else
                log_event "INFO" "Interface $interface does not have an IP address" "$interface"
            fi
            if check_internet "$interface"; then
                log_event "INFO" "Interface $interface has internet connectivity." "$interface"
                selected_interface="$interface"
                break
            else
                log_event "INFO" "Interface $interface lacks connectivity. Attempting to reset to DHCP." "$interface"
                reset_to_dhcp "$interface"
                sleep 15
                if check_internet "$interface"; then
                    log_event "INFO" "Interface $interface gained connectivity after DHCP reset." "$interface"
                    selected_interface="$interface"
                    break
                else
                    log_event "INFO" "Interface $interface still lacks connectivity after DHCP reset." "$interface"
                fi
            fi
        else
            log_event "INFO" "Interface $interface not present."
        fi
    done
    echo "$selected_interface"
}

# Function to reset the network interface to DHCP
reset_to_dhcp() {
    local interface="$1"

    if [ "$interface" == "lo" ]; then
        log_event "INFO" "Skipping DHCP reset for loopback interface (lo)."
        return 0
    fi

    log_event "INFO" "Resetting interface $interface to DHCP."

    execute_command "sudo dhclient -r $interface" "Releasing DHCP lease on $interface" "$interface"
    sleep 2  # Delay to ensure lease release

    execute_command "sudo ip addr flush dev $interface" "Flushing IP addresses on $interface" "$interface"
    sleep 2  # Delay to ensure address flush

    execute_command "sudo ip link set $interface down" "Bringing interface $interface down" "$interface"
    sleep 2  # Delay to ensure interface is down

    execute_command "sudo ip link set $interface up" "Bringing interface $interface up" "$interface"
    sleep 2  # Delay to ensure interface is up

    execute_command "sudo dhclient $interface" "Requesting new DHCP lease on $interface" "$interface"
    sleep 5  # Delay to allow DHCP to assign a new IP

    local new_ip
    new_ip=$(get_ip "$interface")
    if [ -n "$new_ip" ]; then
        log_event "INFO" "New IP assigned by DHCP: $new_ip on $interface."
        queue_email "Network Manager Info: DHCP Assigned" "Interface $interface obtained IP $new_ip via DHCP."
    else
        log_event "ERROR" "Failed to obtain a new IP via DHCP on $interface."
        queue_email "Network Manager Error: DHCP Failure" "Interface $interface failed to obtain an IP via DHCP."
    fi
}

# Function to disable dhclient for the interface
disable_dhclient() {
    local interface="$1"
    log_event "INFO" "Disabling dhclient for interface $interface."

    # Release any active DHCP leases on the interface
    if execute_command "sudo dhclient -r $interface" "Releasing DHCP lease on $interface" "$interface"; then
        log_event "INFO" "Successfully released DHCP lease on $interface."
    else
        log_event "WARNING" "Failed to release DHCP lease on $interface. Continuing with other operations."
    fi
    sleep 2  # Delay to ensure lease release

    # Stop the dhclient service for the interface
    if systemctl list-units --type=service | grep -q "dhclient@$interface.service"; then
        if execute_command "sudo systemctl stop dhclient@$interface.service" "Stopping dhclient service for $interface" "$interface"; then
            log_event "INFO" "Successfully stopped dhclient service for $interface."
        else
            log_event "WARNING" "Failed to stop dhclient service for $interface. It might not be running."
        fi
        sleep 2  # Delay to ensure service stops

        # Disable the dhclient service to prevent automatic startup
        if execute_command "sudo systemctl disable dhclient@$interface.service" "Disabling dhclient service for $interface" "$interface"; then
            log_event "INFO" "Successfully disabled dhclient service for $interface."
        else
            log_event "WARNING" "Failed to disable dhclient service for $interface. It might already be disabled."
        fi
        sleep 2  # Delay before proceeding
    else
        log_event "INFO" "dhclient@$interface.service not found. No action needed."
    fi
}

# Function to print network settings within a styled box
print_network_settings() {
    local interface="$1"
    local ip="$2"
    local subnet_mask="$3"
    local gateway="$4"
    local broadcast="$5"
    shift 5
    local dns_servers=("$@")

    # Define box dimensions
    local box_width=70
    local horizontal_border="═"
    local vertical_border="║"
    local top_left="╔"
    local top_right="╗"
    local bottom_left="╚"
    local bottom_right="╝"
    local separator="╠"

    # Function to generate a line with content padded to box_width
    generate_line() {
        local content="$1"
        printf "║ %-68s ║\n" "$content"
    }

    # Function to generate a border line
    generate_border() {
        local left="$1"
        local fill="$2"
        local right="$3"
        printf "%s%s%s\n" "$left" "$(printf '═%.0s' $(seq 1 68))" "$right"
    }

    # Print the styled network settings
    log_event "DEBUG" "$(generate_border "$top_left" "$horizontal_border" "$top_right")" "$interface"
    log_event "DEBUG" "$(generate_line "Network Settings for $interface")" "$interface"
    log_event "DEBUG" "$(generate_border "$separator" "$horizontal_border" "$separator")" "$interface"
    log_event "DEBUG" "$(generate_line "   - IP Address      : ${ip:-N/A}")" "$interface"
    log_event "DEBUG" "$(generate_line "   - Subnet Mask     : ${subnet_mask:-N/A}")" "$interface"
    log_event "DEBUG" "$(generate_line "   - Gateway         : ${gateway:-N/A}")" "$interface"
    log_event "DEBUG" "$(generate_line "   - Broadcast       : ${broadcast:-N/A}")" "$interface"
    log_event "DEBUG" "$(generate_line "   - DNS Servers     : ${dns_servers[*]:-N/A}")" "$interface"
    log_event "DEBUG" "$(generate_border "$bottom_left" "$horizontal_border" "$bottom_right")" "$interface"
}

# Function to update /etc/network/interfaces with static IP
update_interfaces_file() {
    local interface="$1"
    local desired_ip="$2"
    local subnet_mask="$3"
    local gateway="$4"
    local broadcast="$5"
    shift 5
    local dns_servers=("$@")

    # Define debug_mode (set to true to enable debug output, false to disable)
    # You can set this globally or pass it as an argument/environment variable as needed
    local debug_mode=true

    log_event "DEBUG" "Entering update_interfaces_file function for interface '$interface'." "$interface"

    # Validate interface
    if [[ -z "$interface" ]]; then
        log_event "ERROR" "No interface specified for updating /etc/network/interfaces." ""
        return 1
    fi

    # Validate desired IP format
    if [[ ! "$desired_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        log_event "ERROR" "Desired IP '$desired_ip' is not a valid IPv4 address for interface '$interface'." "$interface"
        queue_email "Network Manager Error: Invalid IP Address" "Interface '$interface' received an invalid desired IP '$desired_ip'."
        return 1
    fi

    # Derive subnet mask directly from CIDR and validate
    local cidr
    cidr=$(ip -o -4 addr show dev "$interface" | awk '{print $4}' | cut -d'/' -f2)

    # Initialize subnet mask components
    local iface_subnet=""
    if [[ -n "$cidr" && "$cidr" -ge 0 && "$cidr" -le 32 ]]; then
        # Compute the subnet mask using the CIDR
        local full_octets=$((cidr / 8))     # Number of full 255 octets
        local remaining_bits=$((cidr % 8)) # Remaining bits for partial octet

        # Generate full 255 octets
        for ((i = 0; i < full_octets; i++)); do
            iface_subnet+="255."
        done

        # Generate the partial octet if there are remaining bits
        if ((remaining_bits > 0)); then
            local partial_octet=$((256 - 2 ** (8 - remaining_bits)))
            iface_subnet+="$partial_octet."
        fi

        # Pad remaining octets with 0 to make a full IPv4 address
        while [[ "$(echo "$iface_subnet" | awk -F'.' '{print NF}')" -lt 4 ]]; do
            iface_subnet+="0."
        done

        # Remove trailing dot
        iface_subnet="${iface_subnet%.}"

        # Correct incomplete subnet masks like "255.255.255" by appending ".0"
        local octet_count
        octet_count=$(echo "$iface_subnet" | awk -F'.' '{print NF}')
        if [[ "$octet_count" -eq 3 ]]; then
            iface_subnet="${iface_subnet}.0"
        fi

        # Validate the generated subnet mask
        if [[ ! "$iface_subnet" =~ ^(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)$ ]]; then
            iface_subnet="N/A"  # Mark invalid if it doesn't match IPv4 pattern
        fi
    else
        # Fallback to N/A if CIDR is invalid
        iface_subnet="N/A"
    fi

    # Assign the subnet_mask variable
    subnet_mask="$iface_subnet"

    # Validate subnet mask format
    if [[ "$subnet_mask" != "N/A" && ! "$subnet_mask" =~ ^(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)$ ]]; then
        log_event "ERROR" "Subnet mask '$subnet_mask' is not a valid IPv4 subnet mask for interface '$interface'." "$interface"
        queue_email "Network Manager Error: Invalid Subnet Mask" "Interface '$interface' received an invalid subnet mask '$subnet_mask'."
        
        # If debug_mode is enabled, print the provided data for debugging
        if [[ "$debug_mode" == true ]]; then
            log_event "DEBUG" "Data Provided for interface '$interface':" "$interface"
            echo "Interface: $interface"
            echo "Desired IP: $desired_ip"
            echo "Subnet Mask: $subnet_mask"
            echo "Gateway: $gateway"
            echo "Broadcast: $broadcast"
            echo "DNS Servers: ${dns_servers[*]}"
        fi

        return 1
    fi

    # Validate gateway format if not N/A
    if [[ "$gateway" != "N/A" && ! "$gateway" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        log_event "ERROR" "Gateway '$gateway' is not a valid IPv4 address for interface '$interface'." "$interface"
        queue_email "Network Manager Error: Invalid Gateway" "Interface '$interface' received an invalid gateway '$gateway'."
        return 1
    fi

    # Validate broadcast address format if not N/A
    if [[ "$broadcast" != "N/A" && ! "$broadcast" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        log_event "ERROR" "Broadcast address '$broadcast' is not a valid IPv4 address for interface '$interface'." "$interface"
        queue_email "Network Manager Error: Invalid Broadcast Address" "Interface '$interface' received an invalid broadcast address '$broadcast'."
        return 1
    fi

    # Validate DNS servers
    local valid_dns=()
    for dns in "${dns_servers[@]}"; do
        if [[ "$dns" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            valid_dns+=("$dns")
            log_event "DEBUG" "Valid DNS server '$dns' will be applied to interface '$interface'." "$interface"
        else
            log_event "WARNING" "Invalid DNS server IP '$dns' detected for interface '$interface'. It will be ignored." "$interface"
        fi
    done
    dns_servers=("${valid_dns[@]}")

    # Log the intended update
    log_event "INFO" "Preparing to update /etc/network/interfaces for interface '$interface' with desired IP '$desired_ip'." "$interface"

    # Create a temporary file for atomic update
    local temp_file
    temp_file=$(mktemp)
    if [[ ! -f "$temp_file" ]]; then
        log_event "ERROR" "Failed to create temporary file for updating /etc/network/interfaces." "$interface"
        queue_email "Network Manager Error: Temporary File Creation" "Failed to create a temporary file while attempting to update /etc/network/interfaces for interface '$interface'."
        return 1
    fi

    # Ensure required directories and files exist
    if [ ! -d "/etc/network" ]; then
        log_event "WARNING" "Network configuration directory does not exist. Creating /etc/network" "$interface"
        if ! sudo mkdir -p /etc/network; then
            log_event "ERROR" "Failed to create /etc/network directory" "$interface"
            queue_email "Network Manager Error: Directory Creation Failed" "Could not create required directory /etc/network"
            return 1
        fi
    fi

    if [ ! -f "$INTERFACES_FILE" ]; then
        log_event "WARNING" "Network interfaces file does not exist. Creating $INTERFACES_FILE" "$interface"
        if ! sudo touch "$INTERFACES_FILE"; then
            log_event "ERROR" "Failed to create $INTERFACES_FILE" "$interface"
            queue_email "Network Manager Error: File Creation Failed" "Could not create required file $INTERFACES_FILE"
            return 1
        fi
    fi

    # Validate and fix permissions on network configuration files
    local required_files=("$INTERFACES_FILE" "/etc/network")
    for file in "${required_files[@]}"; do
        local current_perms
        current_perms=$(stat -c "%a" "$file")
        local current_owner
        current_owner=$(stat -c "%U:%G" "$file")
        
        if [ -d "$file" ] && [ "$current_perms" != "755" ]; then
            log_event "WARNING" "Incorrect permissions on $file. Fixing..." "$interface"
            if ! sudo chmod 755 "$file"; then
                log_event "ERROR" "Failed to set correct permissions on $file" "$interface"
                return 1
            fi
        elif [ -f "$file" ] && [ "$current_perms" != "644" ]; then
            log_event "WARNING" "Incorrect permissions on $file. Fixing..." "$interface"
            if ! sudo chmod 644 "$file"; then
                log_event "ERROR" "Failed to set correct permissions on $file" "$interface"
                return 1
            fi
        fi

        if [ "$current_owner" != "root:root" ]; then
            log_event "WARNING" "Incorrect ownership on $file. Fixing..." "$interface"
            if ! sudo chown root:root "$file"; then
                log_event "ERROR" "Failed to set correct ownership on $file" "$interface"
                return 1
            fi
        fi
    done

    # Create backup with timestamp and checksum
    local backup_dir="/etc/network/backups"
    if [ ! -d "$backup_dir" ]; then
        log_event "INFO" "Creating backup directory $backup_dir" "$interface"
        if ! sudo mkdir -p "$backup_dir"; then
            log_event "ERROR" "Failed to create backup directory" "$interface"
            return 1
        fi
    fi

    local backup_file="${backup_dir}/interfaces.$(date +%F_%H-%M-%S).bak"
    local checksum_before
    checksum_before=$(md5sum "$INTERFACES_FILE" | cut -d' ' -f1)
    
    log_event "INFO" "Creating backup of $INTERFACES_FILE at $backup_file" "$interface"
    if ! sudo cp -p "$INTERFACES_FILE" "$backup_file"; then
        log_event "ERROR" "Failed to create backup of $INTERFACES_FILE" "$interface"
        queue_email "Network Manager Error: Backup Creation Failed" "Could not backup $INTERFACES_FILE before modifications"
        return 1
    fi

    # Store original configuration for comparison
    local original_config
    original_config=$(cat "$INTERFACES_FILE")

    # Create temporary file with proper permissions
    local temp_file
    temp_file=$(mktemp)
    if [ ! -f "$temp_file" ]; then
        log_event "ERROR" "Failed to create temporary file" "$interface"
        return 1
    fi
    sudo chown root:root "$temp_file"
    sudo chmod 644 "$temp_file"

    # Generate new configuration
    {
        echo "# Network configuration generated by Network Manager"
        echo "# Generated on: $(date)"
        echo "# For interface: $interface"
        echo ""
        echo "auto $interface"
        echo "iface $interface inet static"
        echo "    address $desired_ip"
        echo "    netmask $subnet_mask"
        if [[ "$gateway" != "N/A" ]]; then
            echo "    gateway $gateway"
        fi
        if [[ "$broadcast" != "N/A" ]]; then
            echo "    broadcast $broadcast"
        fi
        if [ ${#dns_servers[@]} -gt 0 ]; then
            echo -n "    dns-nameservers"
            for dns in "${dns_servers[@]}"; do
                echo -n " $dns"
            done
            echo
        fi
        echo ""
    } > "$temp_file"

    # Validate new configuration syntax
    log_event "INFO" "Validating new network configuration" "$interface"
    if ! sudo ifup --no-act "$interface" -i "$temp_file" &>/dev/null; then
        log_event "WARNING" "Initial configuration validation failed. Attempting to fix common issues..." "$interface"
        
        # Try to fix common syntax issues
        sudo sed -i 's/[[:space:]]\+/ /g' "$temp_file"  # Fix multiple spaces
        sudo sed -i '/^$/d' "$temp_file"  # Remove empty lines
        
        # Retry validation
        if ! sudo ifup --no-act "$interface" -i "$temp_file" &>/dev/null; then
            log_event "ERROR" "Configuration validation failed after attempted fixes" "$interface"
            sudo rm -f "$temp_file"
            return 1
        fi
    fi

    # Check if networking service exists and is active
    if ! systemctl list-unit-files | grep -q networking.service; then
        log_event "ERROR" "Networking service not found on system" "$interface"
        queue_email "Network Manager Error: Missing Service" "Networking service not found on system"
        sudo rm -f "$temp_file"
        return 1
    fi

    # Take down interface before making changes
    log_event "INFO" "Taking down interface $interface before applying changes" "$interface"
    if ! sudo ifdown "$interface" &>/dev/null; then
        log_event "WARNING" "Failed to take down interface cleanly. Forcing..." "$interface"
        sudo ip link set "$interface" down
    fi

    # Backup current resolv.conf if it exists
    if [ -f "/etc/resolv.conf" ]; then
        sudo cp -p "/etc/resolv.conf" "/etc/resolv.conf.bak"
    fi

    # Apply new configuration
    log_event "INFO" "Applying new network configuration" "$interface"
    if ! sudo mv "$temp_file" "$INTERFACES_FILE"; then
        log_event "ERROR" "Failed to update $INTERFACES_FILE" "$interface"
        sudo cp "$backup_file" "$INTERFACES_FILE"
        sudo ifup "$interface"
        return 1
    fi

    # Verify file integrity after move
    local checksum_after
    checksum_after=$(md5sum "$INTERFACES_FILE" | cut -d' ' -f1)
    if [ "$checksum_before" = "$checksum_after" ]; then
        log_event "ERROR" "File content unchanged after attempted update" "$interface"
        return 1
    fi

    # Restart networking service
    log_event "INFO" "Restarting networking service" "$interface"
    if ! sudo systemctl restart networking; then
        log_event "WARNING" "Failed to restart networking service. Attempting alternative methods..." "$interface"
        
        # Try alternative methods
        if sudo service networking restart &>/dev/null || sudo /etc/init.d/networking restart &>/dev/null; then
            log_event "INFO" "Successfully restarted networking using alternative method" "$interface"
        else
            log_event "ERROR" "All attempts to restart networking failed" "$interface"
            sudo cp "$backup_file" "$INTERFACES_FILE"
            sudo systemctl restart networking
            return 1
        fi
    fi

    # Verify interface is up and has correct IP
    local max_attempts=5
    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ]; do
        log_event "INFO" "Verifying interface configuration (attempt $attempt/$max_attempts)" "$interface"
        sleep 2  # Give the interface time to come up

        local current_ip
        current_ip=$(get_ip "$interface")
        
        if [ "$current_ip" = "$desired_ip" ]; then
            success=true
            break
        fi
        
        attempt=$((attempt + 1))
    done

    if ! $success; then
        log_event "ERROR" "Failed to verify new IP configuration after $max_attempts attempts" "$interface"
        log_event "INFO" "Rolling back to previous configuration" "$interface"
        sudo cp "$backup_file" "$INTERFACES_FILE"
        sudo systemctl restart networking
        return 1
    fi

    # Clean up old backups (keep last 5)
    find "$backup_dir" -name "interfaces.*.bak" -type f -printf '%T@ %p\n' | \
        sort -n | head -n -5 | cut -d' ' -f2- | xargs -r rm

    log_event "INFO" "Successfully updated network configuration for interface $interface" "$interface"

    # Display the connection properties in a styled, decorative way
    display_connection_properties "$interface"

    # Exit the function successfully
    log_event "DEBUG" "Exiting update_interfaces_file function for interface '$interface'." "$interface"
    return 0
}

# Function to check all interfaces and log their status with error handling
check_all_interfaces_status() {
    log_event "INFO" "Checking status of all network interfaces."

    # Retrieve all network interfaces excluding loopback
    local interfaces=($(get_all_interfaces true | grep -v "^lo$"))
    if [ ${#interfaces[@]} -eq 0 ]; then
        log_event "ERROR" "No network interfaces found. Ensure that the system has active network interfaces."
        queue_email "Network Manager Error: No Interfaces Found" "No active network interfaces detected on the system."
        return 1
    fi

    for iface in "${interfaces[@]}"; do
        # Initialize variables
        local status=""
        local mac_address=""
        local ip_address=""

        # Check if the interface exists
        if ip link show "$iface" &> /dev/null; then
            # Retrieve MAC address
            mac_address=$(ip link show "$iface" | awk '/ether/ {print $2}')
            
            # Retrieve IP address
            ip_address=$(get_ip "$iface")

            # Determine interface status
            if ip link show "$iface" | grep -qw "UP"; then
                status="up"
            else
                status="down"
            fi

            # Log interface details
            log_event "INFO" "Interface '$iface' status: $status, MAC: $mac_address, IP: ${ip_address:-N/A}" "$iface"

            # Self-repair if interface is down
            if [ "$status" == "down" ]; then
                log_event "WARNING" "Interface '$iface' is down. Attempting to bring it up." "$iface"
                if execute_command "sudo ip link set $iface up" "Bringing up interface '$iface'" "$iface"; then
                    log_event "INFO" "Successfully brought up interface '$iface'." "$iface"
                    sleep 3  # Delay to allow interface to come up
                else
                    log_event "ERROR" "Failed to bring up interface '$iface'." "$iface"
                    queue_email "Network Manager Error: Interface Down" "Failed to bring up interface '$iface'. Manual intervention may be required."
                    continue
                fi
            fi

            # Verify internet connectivity if interface is up
            if [ "$status" == "up" ]; then
                if check_internet "$iface"; then
                    log_event "INFO" "Interface '$iface' with IP '$ip_address' has internet connectivity." "$iface"
                else
                    log_event "WARNING" "Interface '$iface' with IP '$ip_address' lacks internet connectivity. Attempting to reconfigure." "$iface"
                    
                    # Attempt to reset to DHCP as a self-repair measure
                    if reset_to_dhcp "$iface"; then
                        log_event "INFO" "Successfully reconfigured interface '$iface' to DHCP." "$iface"
                        sleep 5  # Delay to allow DHCP to assign new settings
                        # Re-check internet connectivity
                        ip_address=$(get_ip "$iface")
                        if check_internet "$iface"; then
                            log_event "INFO" "Internet connectivity restored on interface '$iface' with new IP '$ip_address'." "$iface"
                        else
                            log_event "ERROR" "Failed to restore internet connectivity on interface '$iface' after reconfiguration." "$iface"
                            queue_email "Network Manager Error: Internet Connectivity" "Interface '$iface' still lacks internet connectivity after attempting to reconfigure."
                        fi
                    else
                        log_event "ERROR" "Failed to reconfigure interface '$iface' to DHCP." "$iface"
                        queue_email "Network Manager Error: DHCP Reconfiguration" "Interface '$iface' failed to reconfigure to DHCP."
                    fi
                fi
            fi
        else
            log_event "ERROR" "Failed to retrieve status for interface '$iface'. The interface might not exist or is not accessible."
            queue_email "Network Manager Error: Interface Retrieval" "Failed to retrieve status for interface '$iface'. It might not exist or is inaccessible."
        fi
    done

    log_event "INFO" "Completed checking status of all network interfaces."
    return 0
}

# Function to activate WLAN adapters if needed
activate_wlan_adapters_if_needed() {
    # Check if bringing up all devices is enabled
    if [ "${BRING_UP_ALL_DEVICES:-false}" != "true" ]; then
        log_event "INFO" "Skipping activation of WLAN adapters as per configuration." ""
        return 0
    fi

    # Verify the existence of the autostart file
    if [ ! -f "$BRING_UP_DEVICES_AUTOSTART_FILE" ]; then
        log_event "WARNING" "Autostart file '$BRING_UP_DEVICES_AUTOSTART_FILE' for bringing up devices not found. Skipping activation." ""
        return 1
    fi

    log_event "INFO" "Checking WLAN adapters for activation."

    local wlan_interfaces=()
    local interface

    # Get all available WLAN interfaces
    wlan_interfaces=($(get_all_interfaces | grep -E '^wlan[0-9]+$'))

    if [ ${#wlan_interfaces[@]} -eq 0 ]; then
        log_event "WARNING" "No WLAN interfaces detected."
        return 1
    fi

    log_event "INFO" "Detected WLAN interfaces: ${wlan_interfaces[*]}"

    for interface in "${wlan_interfaces[@]}"; do
        log_event "INFO" "Checking status of interface '$interface'."

        # Check if the interface is up
        if ip link show "$interface" | grep -qw "UP"; then
            log_event "INFO" "WLAN interface '$interface' is already up."
        else
            log_event "INFO" "WLAN interface '$interface' is down. Attempting to bring it up."

            # Bring up the interface
            if execute_command "sudo ip link set $interface up" "Bringing up WLAN interface '$interface'" "$interface"; then
                log_event "INFO" "Successfully brought up interface '$interface'."
            else
                log_event "ERROR" "Failed to bring up interface '$interface'. Skipping to the next WLAN interface."
                queue_email "Network Manager Error: WLAN Interface Up" "Failed to bring up WLAN interface '$interface'."
                continue
            fi
            sleep 2  # Delay to ensure interface is up
        fi

        # Check internet connectivity on this interface
        if check_internet "$interface"; then
            log_event "INFO" "Internet connectivity confirmed on interface '$interface'."
        else
            log_event "WARNING" "No internet connectivity on interface '$interface'. Attempting to connect to a known network."

            # Attempt to connect to a known network
            if try_connect_to_known_network "$interface"; then
                log_event "INFO" "Interface '$interface' successfully connected to a known network."
                if check_internet "$interface"; then
                    log_event "INFO" "Internet connectivity established on interface '$interface' after connecting to a known network."
                else
                    log_event "WARNING" "Interface '$interface' connected to a network but still lacks internet connectivity."
                    # Attempt self-repair by resetting to DHCP
                    if reset_to_dhcp "$interface"; then
                        log_event "INFO" "Successfully reset interface '$interface' to DHCP after failed connectivity."
                        sleep 5  # Delay to allow DHCP to assign new settings
                        if check_internet "$interface"; then
                            log_event "INFO" "Internet connectivity restored on interface '$interface' after DHCP reset."
                        else
                            log_event "ERROR" "Failed to restore internet connectivity on interface '$interface' after DHCP reset."
                            queue_email "Network Manager Error: Internet Connectivity" "Interface '$interface' still lacks internet connectivity after attempting to connect to a known network and resetting to DHCP."
                        fi
                    else
                        log_event "ERROR" "Failed to reset interface '$interface' to DHCP after unsuccessful network connection attempts."
                        queue_email "Network Manager Error: DHCP Reset" "Interface '$interface' failed to reset to DHCP after unsuccessful network connection attempts."
                    fi
                fi
            else
                log_event "ERROR" "Failed to connect interface '$interface' to any known network."
                queue_email "Network Manager Error: Network Connection" "Interface '$interface' failed to connect to any known network."
            fi
        fi
    done

    log_event "INFO" "Finished checking and activating WLAN interfaces."
    return 0
}

# Helper function to try connecting to known networks
try_connect_to_known_network() {
    local interface="$1"
    local known_networks_dir="/etc/NetworkManager/system-connections"

    log_event "INFO" "Attempting to connect interface '$interface' to a known network."

    # Check if the known networks directory exists
    if [ ! -d "$known_networks_dir" ]; then
        log_event "ERROR" "Known networks directory '$known_networks_dir' does not exist. Cannot proceed with connection."
        queue_email "Network Manager Error: Known Networks Directory Missing" "The directory '$known_networks_dir' containing known network configurations was not found. Unable to connect interface '$interface' to any known network."
        return 1
    fi

    local network_file
    local network_name
    local connection_success=false

    # Iterate over each network configuration file
    for network_file in "$known_networks_dir"/*; do
        if [ -f "$network_file" ]; then
            network_name=$(basename "$network_file")
            log_event "INFO" "Attempting to connect interface '$interface' to known network: '$network_name'."

            # Use nmcli to connect to the network
            if execute_command "sudo nmcli device wifi connect '$network_name' ifname '$interface'" \
                "Connecting interface '$interface' to network '$network_name'" "$interface"; then
                log_event "INFO" "Successfully connected interface '$interface' to network '$network_name'."
                connection_success=true
                break
            else
                log_event "WARNING" "Failed to connect interface '$interface' to network '$network_name'. Proceeding to the next known network."
            fi
        else
            log_event "DEBUG" "Skipping non-file entry '$network_file' in known networks directory."
        fi
    done

    if [ "$connection_success" = true ]; then
        log_event "INFO" "Interface '$interface' successfully connected to a known network."
        return 0
    else
        log_event "ERROR" "Unable to connect interface '$interface' to any known networks."
        queue_email "Network Manager Error: Connection Failure" "Interface '$interface' failed to connect to all known networks in '$known_networks_dir'. Manual intervention may be required."
        return 1
    fi
}

# Function to check if any network interface has internet connectivity
check_any_interface_connectivity() {
    log_event "INFO" "Initiating internet connectivity check for all active network interfaces."

    # Retrieve all active network interfaces excluding loopback
    local interfaces=($(get_all_interfaces true | grep -v "^lo$"))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        log_event "ERROR" "No active network interfaces found. Ensure that the system has active network interfaces."
        queue_email "Network Manager Error: No Active Interfaces" "No active network interfaces detected on the system. Unable to perform connectivity checks."
        return 1
    fi

    local iface
    local connectivity_found=false

    for iface in "${interfaces[@]}"; do
        # Verify if the interface exists and is up
        if ! ip link show "$iface" &> /dev/null; then
            log_event "WARNING" "Interface '$iface' does not exist or is not accessible. Skipping."
            continue
        fi

        local mac_address
        mac_address=$(ip link show "$iface" | awk '/ether/ {print $2}')
        local ip_address
        ip_address=$(get_ip "$iface")

        log_event "INFO" "Checking internet connectivity on interface '$iface' (MAC: $mac_address, IP: ${ip_address:-N/A})."

        # Check internet connectivity using ping
        if check_internet "$iface"; then
            log_event "INFO" "Interface '$iface' with IP '$ip_address' has active internet connectivity."
            connectivity_found=true
            break
        else
            log_event "WARNING" "Interface '$iface' with IP '$ip_address' lacks internet connectivity."
        fi
    done

    if [ "$connectivity_found" = true ]; then
        log_event "INFO" "At least one network interface has active internet connectivity."
        return 0
    else
        log_event "ERROR" "No network interfaces have internet connectivity."
        queue_email "Network Manager Alert: No Internet Connectivity" "All network interfaces on the system are currently without internet connectivity. Investigate potential network issues."
        return 1
    fi
}

# Function to update priority list based on network consistency
update_priority_list_consistency() {
    log_event "INFO" "Updating priority list based on network consistency."

    # Placeholder for advanced consistency checks
    # Example: Prioritize interfaces with consistent gateway or specific metrics

    # Retrieve all active network interfaces excluding loopback
    local interfaces=($(get_all_interfaces true | grep -v "^lo$"))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        log_event "WARNING" "No active network interfaces found to update priority list."
        return 1
    fi

    local iface
    local consistent_gateway=true
    local previous_gateway=""
    local updated_priority_list=()

    for iface in "${interfaces[@]}"; do
        # Retrieve gateway for the current interface
        local current_gateway
        current_gateway=$(ip route | grep "^default via" | grep "$iface" | awk '{print $3}')

        if [ -z "$current_gateway" ]; then
            log_event "WARNING" "No gateway found for interface '$iface'. Skipping consistency check."
            continue
        fi

        # Check for gateway consistency
        if [ -z "$previous_gateway" ]; then
            previous_gateway="$current_gateway"
            updated_priority_list+=("$iface")
            log_event "DEBUG" "Interface '$iface' has gateway '$current_gateway'. Adding to priority list."
        else
            if [ "$current_gateway" == "$previous_gateway" ]; then
                updated_priority_list+=("$iface")
                log_event "DEBUG" "Interface '$iface' has the same gateway '$current_gateway'. Adding to priority list."
            else
                log_event "INFO" "Interface '$iface' has a different gateway '$current_gateway' compared to previous gateway '$previous_gateway'. Prioritizing accordingly."
                # Implement specific logic based on differing gateways
                # For example, prioritize interfaces with preferred gateways
                # This is a placeholder for more complex consistency logic
                updated_priority_list+=("$iface")
            fi
        fi
    done

    # Update the priority list (Assuming there's a mechanism to store and utilize this list)
    PRIORITY_LIST=("${updated_priority_list[@]}")
    log_event "INFO" "Priority list updated based on network consistency: ${PRIORITY_LIST[*]}"

    # Additional consistency checks can be implemented here as needed

    return 0
}

# ---------------------------- Hotspot Management ----------------------------

# Function to create a hotspot
create_hotspot() {
    local interface="wlan0"  # Define the wireless interface; adjust as needed

    # Check if hotspot functionality is enabled
    if [ "${ENABLE_HOTSPOT:-false}" != "true" ]; then
        log_event "INFO" "Hotspot functionality is disabled via configuration."
        return 0
    fi

    # Check for the existence of the hotspot autostart file
    if [ ! -f "$HOTSPOT_AUTOSTART_FILE" ]; then
        log_event "WARNING" "Hotspot autostart file '$HOTSPOT_AUTOSTART_FILE' not found. Skipping hotspot creation."
        return 1
    fi

    # Validate hotspot SSID and password
    if [ -z "$HOTSPOT_SSID" ] || [ -z "$HOTSPOT_PASSWORD" ]; then
        log_event "ERROR" "Hotspot SSID or password is not set. Please configure '$HOTSPOT_SSID' and '$HOTSPOT_PASSWORD'."
        queue_email "Network Manager Error: Hotspot Configuration Missing" "Hotspot SSID or password is missing. Please configure the necessary parameters."
        return 1
    fi

    log_event "INFO" "Creating hotspot with SSID '$HOTSPOT_SSID'."

    # Stop services that might interfere with hotspot setup
    if ! execute_command "sudo systemctl stop hostapd" "Stopping hostapd service" "$interface"; then
        log_event "WARNING" "Failed to stop hostapd service. It might not be running."
    fi

    if ! execute_command "sudo systemctl stop dnsmasq" "Stopping dnsmasq service" "$interface"; then
        log_event "WARNING" "Failed to stop dnsmasq service. It might not be running."
    fi

    # Backup existing dnsmasq configuration if not already backed up
    if [ -f "/etc/dnsmasq.conf" ] && [ ! -f "/etc/dnsmasq.conf.backup" ]; then
        if execute_command "sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup" "Backing up existing dnsmasq configuration" "$interface"; then
            log_event "INFO" "Backup of '/etc/dnsmasq.conf' created successfully."
        else
            log_event "ERROR" "Failed to create backup of '/etc/dnsmasq.conf'. Aborting hotspot creation."
            queue_email "Network Manager Error: Backup Failure" "Failed to backup '/etc/dnsmasq.conf' before hotspot creation on interface '$interface'."
            return 1
        fi
    fi

    # Configure hostapd
    sudo bash -c "cat > /etc/hostapd/hostapd.conf" <<EOF
interface=$interface
driver=nl80211
ssid=$HOTSPOT_SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$HOTSPOT_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

    # Update hostapd default configuration to use the new hostapd.conf
    sudo sed -i "s|#DAEMON_CONF=\"\"|DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"|" /etc/default/hostapd

    # Verify hostapd configuration
    if [ ! -f "/etc/hostapd/hostapd.conf" ]; then
        log_event "ERROR" "hostapd configuration file '/etc/hostapd/hostapd.conf' not found after creation."
        queue_email "Network Manager Error: hostapd Configuration Missing" "hostapd configuration file was not created successfully for hotspot on interface '$interface'."
        return 1
    fi

    # Configure dnsmasq
    sudo bash -c "cat > /etc/dnsmasq.conf" <<EOF
interface=$interface
dhcp-range=192.168.150.2,192.168.150.20,255.255.255.0,24h
log-facility=/var/log/dnsmasq.log
log-queries
EOF

    # Set static IP for wlan0 by creating a new interfaces configuration
    sudo bash -c "cat > /etc/network/interfaces.d/$interface" <<EOF
auto $interface
iface $interface inet static
    address 192.168.150.1
    netmask 255.255.255.0
EOF

    # Enable IP forwarding
    if ! execute_command "sudo sysctl -w net.ipv4.ip_forward=1" "Enabling IP forwarding" "$interface"; then
        log_event "ERROR" "Failed to enable IP forwarding."
        queue_email "Network Manager Error: IP Forwarding" "Failed to enable IP forwarding while creating hotspot on interface '$interface'."
        return 1
    fi

    # Configure NAT with iptables
    if ! execute_command "sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE" "Configuring NAT with iptables" "$interface"; then
        log_event "ERROR" "Failed to configure NAT with iptables."
        queue_email "Network Manager Error: NAT Configuration" "Failed to configure NAT with iptables for hotspot on interface '$interface'."
        return 1
    fi

    # Persist iptables rules
    if ! execute_command "sudo sh -c 'iptables-save > /etc/iptables.rules'" "Persisting iptables rules" "$interface"; then
        log_event "ERROR" "Failed to persist iptables rules."
        queue_email "Network Manager Error: Iptables Persistence" "Failed to persist iptables rules after configuring hotspot on interface '$interface'."
        return 1
    fi

    # Install iptables-persistent if not already installed
    if ! dpkg -l | grep -qw "iptables-persistent"; then
        if ! execute_command "sudo apt-get install -y iptables-persistent" "Installing iptables-persistent" "$interface"; then
            log_event "ERROR" "Failed to install iptables-persistent."
            queue_email "Network Manager Error: Iptables-Persistent Installation" "Failed to install iptables-persistent required for hotspot on interface '$interface'."
            return 1
        fi
    else
        log_event "INFO" "iptables-persistent is already installed."
    fi

    # Enable and start iptables-persistent service
    if ! execute_command "sudo systemctl enable iptables-persistent" "Enabling iptables-persistent service" "$interface"; then
        log_event "WARNING" "Failed to enable iptables-persistent service. Continuing."
    fi

    if ! execute_command "sudo systemctl start iptables-persistent" "Starting iptables-persistent service" "$interface"; then
        log_event "WARNING" "Failed to start iptables-persistent service. Continuing."
    fi

    # Start hostapd and dnsmasq services
    if ! execute_command "sudo systemctl start hostapd" "Starting hostapd service" "$interface"; then
        log_event "ERROR" "Failed to start hostapd service."
        queue_email "Network Manager Error: hostapd Service" "Failed to start hostapd service for hotspot on interface '$interface'."
        return 1
    fi

    if ! execute_command "sudo systemctl start dnsmasq" "Starting dnsmasq service" "$interface"; then
        log_event "ERROR" "Failed to start dnsmasq service."
        queue_email "Network Manager Error: dnsmasq Service" "Failed to start dnsmasq service for hotspot on interface '$interface'."
        return 1
    fi

    log_event "INFO" "Hotspot '$HOTSPOT_SSID' created successfully on interface '$interface'."

    # Send notification email about hotspot creation
    queue_email "Network Manager Info: Hotspot Created" "Hotspot '$HOTSPOT_SSID' has been created on interface '$interface' due to no available network connections."

    return 0
}

# Function to remove hotspot
remove_hotspot() {
    local interface="wlan0"  # Define the wireless interface; adjust as needed

    # Check if hotspot functionality is enabled
    if [ "${ENABLE_HOTSPOT:-false}" != "true" ]; then
        log_event "INFO" "Hotspot functionality is disabled via configuration. Skipping removal."
        return 0
    fi

    # Check for the existence of the hotspot autostart file
    if [ ! -f "$HOTSPOT_AUTOSTART_FILE" ]; then
        log_event "WARNING" "Hotspot autostart file '$HOTSPOT_AUTOSTART_FILE' not found. Skipping hotspot removal."
        return 1
    fi

    log_event "INFO" "Removing hotspot '$HOTSPOT_SSID' from interface '$interface'."

    # Stop hostapd and dnsmasq services
    if ! execute_command "sudo systemctl stop hostapd" "Stopping hostapd service" "$interface"; then
        log_event "WARNING" "Failed to stop hostapd service. It might not be running."
    fi

    if ! execute_command "sudo systemctl stop dnsmasq" "Stopping dnsmasq service" "$interface"; then
        log_event "WARNING" "Failed to stop dnsmasq service. It might not be running."
    fi

    # Restore dnsmasq configuration from backup if it exists
    if [ -f "/etc/dnsmasq.conf.backup" ]; then
        if execute_command "sudo mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf" "Restoring dnsmasq configuration from backup" "$interface"; then
            log_event "INFO" "Restored '/etc/dnsmasq.conf' from backup successfully."
        else
            log_event "ERROR" "Failed to restore '/etc/dnsmasq.conf' from backup."
            queue_email "Network Manager Error: dnsmasq Configuration Restoration" "Failed to restore '/etc/dnsmasq.conf' from backup while removing hotspot on interface '$interface'."
            return 1
        fi
    else
        # Recreate dnsmasq.conf with default settings if no backup exists
        sudo bash -c "cat > /etc/dnsmasq.conf" <<EOF
interface=$interface
dhcp-range=192.168.150.2,192.168.150.20,255.255.255.0,24h
EOF
        log_event "INFO" "Recreated default '/etc/dnsmasq.conf' as no backup was found."
    fi

    # Remove static IP configuration for wlan0
    if [ -f "/etc/network/interfaces.d/$interface" ]; then
        if execute_command "sudo rm -f /etc/network/interfaces.d/$interface" "Removing static IP configuration for interface '$interface'" "$interface"; then
            log_event "INFO" "Removed static IP configuration for interface '$interface'."
        else
            log_event "ERROR" "Failed to remove static IP configuration for interface '$interface'."
            queue_email "Network Manager Error: Static IP Removal" "Failed to remove static IP configuration for interface '$interface' during hotspot removal."
            return 1
        fi
    else
        log_event "WARNING" "Static IP configuration file '/etc/network/interfaces.d/$interface' does not exist. Skipping removal."
    fi

    # Disable IP forwarding
    if ! execute_command "sudo sysctl -w net.ipv4.ip_forward=0" "Disabling IP forwarding" "$interface"; then
        log_event "WARNING" "Failed to disable IP forwarding."
    fi

    # Remove iptables NAT rule
    if sudo iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE &> /dev/null; then
        if ! execute_command "sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE" "Removing NAT rule from iptables" "$interface"; then
            log_event "ERROR" "Failed to remove NAT rule from iptables."
            queue_email "Network Manager Error: NAT Rule Removal" "Failed to remove NAT rule from iptables during hotspot removal on interface '$interface'."
            return 1
        fi
    else
        log_event "INFO" "No NAT rule found in iptables for interface '$interface'. Skipping removal."
    fi

    # Restart iptables-persistent to apply changes
    if ! execute_command "sudo systemctl restart iptables-persistent" "Restarting iptables-persistent service" "$interface"; then
        log_event "WARNING" "Failed to restart iptables-persistent service. Manual intervention may be required."
    fi

    # Remove iptables rules file if it exists
    if [ -f "/etc/iptables.rules" ]; then
        if execute_command "sudo rm -f /etc/iptables.rules" "Removing iptables rules file" "$interface"; then
            log_event "INFO" "Removed iptables rules file '/etc/iptables.rules'."
        else
            log_event "WARNING" "Failed to remove iptables rules file '/etc/iptables.rules'."
        fi
    else
        log_event "INFO" "iptables rules file '/etc/iptables.rules' does not exist. Skipping removal."
    fi

    # Restore original network interface configuration if needed
    # Optionally, you can restore from backup or reconfigure interfaces as necessary

    # Restart networking service to apply changes
    if ! execute_command "sudo systemctl restart networking" "Restarting networking service" "$interface"; then
        log_event "ERROR" "Failed to restart networking service after removing hotspot."
        queue_email "Network Manager Error: Networking Service Restart" "Failed to restart networking service after removing hotspot on interface '$interface'."
        return 1
    fi
    sleep 5  # Delay to allow networking service to restart

    log_event "INFO" "Hotspot '$HOTSPOT_SSID' removed successfully from interface '$interface'."

    # Send notification email about hotspot removal
    queue_email "Network Manager Info: Hotspot Removed" "Hotspot '$HOTSPOT_SSID' has been removed from interface '$interface' as network connections are now available."

    return 0
}

# ---------------------------- VPN Management ----------------------------

# Function to start VPN connection
start_vpn() {
    local interface="tun0"  # Define the VPN interface; adjust as needed

    # Check if VPN functionality is enabled
    if [ "${ENABLE_VPN:-false}" != "true" ] || [ "${MANAGE_VPN:-false}" != "true" ]; then
        log_event "INFO" "VPN functionality is disabled via configuration."
        return 0
    fi

    # Check for the existence of the VPN autostart file
    if [ ! -f "$VPN_AUTOSTART_FILE" ]; then
        log_event "WARNING" "VPN autostart file '$VPN_AUTOSTART_FILE' not found. Skipping VPN connection."
        return 1
    fi

    # Check for the existence of the VPN configuration file
    if [ ! -f "$VPN_CONFIG_FILE" ]; then
        log_event "ERROR" "VPN configuration file not found at '$VPN_CONFIG_FILE'. Cannot start VPN."
        queue_email "Network Manager Error: VPN Configuration Missing" "VPN configuration file '$VPN_CONFIG_FILE' not found. Unable to start VPN connection."
        return 1
    fi

    log_event "INFO" "Starting VPN connection using configuration file '$VPN_CONFIG_FILE'."

    # Install OpenVPN if not installed
    if ! dpkg -l | grep -qw "openvpn"; then
        if execute_command "sudo apt-get update && sudo apt-get install -y openvpn" "Installing OpenVPN" ""; then
            log_event "INFO" "OpenVPN installed successfully."
        else
            log_event "ERROR" "Failed to install OpenVPN."
            queue_email "Network Manager Error: OpenVPN Installation" "Failed to install OpenVPN required for VPN connection."
            return 1
        fi
    else
        log_event "INFO" "OpenVPN is already installed."
    fi

    # Check if VPN is already running
    if pgrep -f "openvpn --config $VPN_CONFIG_FILE" > /dev/null; then
        log_event "INFO" "VPN connection is already running."
        return 0
    fi

    # Start OpenVPN as a background process
    if execute_command "sudo openvpn --config '$VPN_CONFIG_FILE' --daemon" "Starting OpenVPN with configuration '$VPN_CONFIG_FILE'" "$interface"; then
        log_event "INFO" "OpenVPN started successfully."
        sleep 5  # Delay to allow VPN to establish connection

        # Verify VPN connection
        if check_internet "$interface"; then
            log_event "INFO" "VPN connection established and internet connectivity verified on interface '$interface'."
            queue_email "Network Manager Info: VPN Started" "VPN connection using '$VPN_CONFIG_FILE' has been started and is active."
            return 0
        else
            log_event "ERROR" "VPN connection started but internet connectivity could not be verified on interface '$interface'. Attempting to restart VPN."
            queue_email "Network Manager Warning: VPN Connectivity Issue" "VPN connection using '$VPN_CONFIG_FILE' started but lacks internet connectivity. Attempting to restart VPN."
            
            # Attempt to restart VPN
            stop_vpn
            sleep 2
            start_vpn
            return 1
        fi
    else
        log_event "ERROR" "Failed to start OpenVPN with configuration '$VPN_CONFIG_FILE'."
        queue_email "Network Manager Error: VPN Start Failure" "Failed to start OpenVPN using configuration '$VPN_CONFIG_FILE'. Manual intervention may be required."
        return 1
    fi
}

# Function to stop VPN connection
stop_vpn() {
    local interface="tun0"  # Define the VPN interface; adjust as needed

    # Check if VPN functionality is enabled
    if [ "${ENABLE_VPN:-false}" != "true" ] || [ "${MANAGE_VPN:-false}" != "true" ]; then
        log_event "INFO" "VPN functionality is disabled via configuration."
        return 0
    fi

    log_event "INFO" "Stopping VPN connection."

    # Check if VPN is running
    if pgrep -f "openvpn --config $VPN_CONFIG_FILE" > /dev/null; then
        # Attempt to gracefully terminate OpenVPN
        if execute_command "sudo pkill -SIGTERM -f 'openvpn --config $VPN_CONFIG_FILE'" "Gracefully stopping OpenVPN" "$interface"; then
            log_event "INFO" "OpenVPN stopped successfully."
            sleep 3  # Delay to ensure VPN has terminated
        else
            log_event "WARNING" "Failed to gracefully stop OpenVPN. Attempting to force stop."
            # Attempt to forcefully terminate OpenVPN
            if execute_command "sudo pkill -SIGKILL -f 'openvpn --config $VPN_CONFIG_FILE'" "Forcefully stopping OpenVPN" "$interface"; then
                log_event "INFO" "OpenVPN forcefully stopped."
            else
                log_event "ERROR" "Failed to stop OpenVPN. It may not be running."
                queue_email "Network Manager Error: VPN Stop Failure" "Failed to stop OpenVPN using configuration '$VPN_CONFIG_FILE'. Manual intervention may be required."
                return 1
            fi
        fi
    else
        log_event "INFO" "VPN connection is not running."
        return 0
    fi

    # Verify VPN has stopped
    if pgrep -f "openvpn --config $VPN_CONFIG_FILE" > /dev/null; then
        log_event "ERROR" "OpenVPN is still running after stop attempt."
        queue_email "Network Manager Error: VPN Still Running" "OpenVPN process is still active after stop attempt for configuration '$VPN_CONFIG_FILE'. Manual intervention may be required."
        return 1
    else
        log_event "INFO" "VPN connection stopped successfully."
        queue_email "Network Manager Info: VPN Stopped" "VPN connection using '$VPN_CONFIG_FILE' has been stopped."
        return 0
    fi
}

# ---------------------------- SMTP Configuration Functions ----------------------------

# Function to setup SMTP configuration with encrypted password
setup_smtp_config_encrypted() {
    if [ -f "$SMTP_CONFIG_FILE" ]; then
        log_event "INFO" "SMTP configuration file already exists at $SMTP_CONFIG_FILE. Skipping setup."
    elif [ -f "$SMTP_CONFIG_SETUP_FILE" ]; then
        log_event "INFO" "SMTP setup file found at $SMTP_CONFIG_SETUP_FILE. Proceeding with setup."

        # Check if SMTP key exists, if not, generate it
        if [ ! -f "$SMTP_KEY_FILE" ]; then
            log_event "INFO" "SMTP key file not found at $SMTP_KEY_FILE. Generating new key."
            openssl rand -base64 32 | sudo tee "$SMTP_KEY_FILE" > /dev/null
            sudo chmod 600 "$SMTP_KEY_FILE"
            log_event "INFO" "SMTP key generated and stored at $SMTP_KEY_FILE."
        else
            log_event "INFO" "SMTP key file already exists at $SMTP_KEY_FILE."
        fi

        # Read SMTP configuration from setup file
        SMTP_SERVER=$(jq -r '.smtp_server' "$SMTP_CONFIG_SETUP_FILE")
        SMTP_PORT=$(jq -r '.smtp_port' "$SMTP_CONFIG_SETUP_FILE")
        SMTP_USER=$(jq -r '.smtp_user' "$SMTP_CONFIG_SETUP_FILE")
        SMTP_PASSWORD=$(jq -r '.smtp_password' "$SMTP_CONFIG_SETUP_FILE")
        RECIPIENT_EMAIL=$(jq -r '.recipient_email' "$SMTP_CONFIG_SETUP_FILE")

        # Encrypt the SMTP password
        ENCRYPTED_PASSWORD=$(echo "$SMTP_PASSWORD" | openssl enc -aes-256-cbc -a -salt -pass file:"$SMTP_KEY_FILE")
        if [ -z "$ENCRYPTED_PASSWORD" ]; then
            log_event "ERROR" "Failed to encrypt SMTP password."
            queue_email "Network Manager Error: SMTP Setup Failed" "Failed to encrypt SMTP password during setup."
            exit 1
        fi

        # Create smtp_config.json with encrypted password
        sudo bash -c "jq -n \
            --arg smtp_server '$SMTP_SERVER' \
            --arg smtp_port '$SMTP_PORT' \
            --arg smtp_user '$SMTP_USER' \
            --arg smtp_password_encrypted '$ENCRYPTED_PASSWORD' \
            --arg recipient_email '$RECIPIENT_EMAIL' \
            '{smtp_server: \$smtp_server, smtp_port: (\$smtp_port | tonumber), smtp_user: \$smtp_user, smtp_password_encrypted: \$smtp_password_encrypted, recipient_email: \$recipient_email}' > $SMTP_CONFIG_FILE"

        log_event "INFO" "SMTP configuration setup completed and stored at $SMTP_CONFIG_FILE."

        # Log the SMTP setup in the database
        if [ "$INITIALIZE_DATABASE" = true ] && [ -f "$DB_FILE" ]; then
            sqlite3 "$DB_FILE" "INSERT INTO smtp_settings (timestamp, smtp_server, smtp_port, smtp_user, smtp_password_encrypted, recipient_email) VALUES ('$(date '+%Y-%m-%d %H:%M:%S')', '$SMTP_SERVER', $SMTP_PORT, '$SMTP_USER', '$ENCRYPTED_PASSWORD', '$RECIPIENT_EMAIL');"
        fi

        queue_email "Network Manager Info: SMTP Setup Completed" "SMTP configuration has been set up successfully."
    else
        log_event "WARNING" "No SMTP setup file found at $SMTP_CONFIG_SETUP_FILE. SMTP notifications will be disabled until configured."
    fi
}

# ---------------------------- Service Management Functions ----------------------------

# Function to check and create required systemd services
check_and_create_services() {
    log_event "INFO" "Checking and creating required systemd services."

    # Define service file paths
    local web_service_file="/etc/systemd/system/web_interface.service"
    local set_ip_service_file="/etc/systemd/system/set_ip_address.service"

    # Define service content
    local web_service_content="[Unit]
Description=Network Manager Web Interface
After=network.target

[Service]
ExecStart=/usr/bin/python3 $PYTHON_SCRIPT
Restart=always
RestartSec=5
User=www-data
Group=www-data
Environment=FLASK_APP=$PYTHON_SCRIPT
Environment=FLASK_ENV=production

[Install]
WantedBy=multi-user.target"

    local set_ip_service_content="[Unit]
Description=Set Static IP Address on Startup
After=network.target

[Service]
ExecStart=/usr/local/bin/set_ip_address.sh
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=set_ip_address
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target"

    # Validate service files
    local web_service_valid=false
    local set_ip_service_valid=false

    if validate_service_file "$web_service_file" "$web_service_content"; then
        web_service_valid=true
    fi

    if validate_service_file "$set_ip_service_file" "$set_ip_service_content"; then
        set_ip_service_valid=true
    fi

    # Skip further actions if both service files are valid
    if [ "$web_service_valid" = true ] && [ "$set_ip_service_valid" = true ]; then
        log_event "INFO" "Both service files are valid. Skipping creation and management."
        return
    fi

    # Enable and start services if autostart files exist
    if [ -f "$WEB_INTERFACE_AUTOSTART_FILE" ] && [ "$LAUNCH_WEB_INTERFACE" = true ]; then
        log_event "INFO" "Ensuring web_interface.service is enabled and running."
        sudo systemctl daemon-reload
        sudo systemctl enable web_interface.service
        sudo systemctl start web_interface.service
    else
        log_event "INFO" "Web interface autostart file not found or launching is disabled. Skipping web_interface.service."
    fi

    if [ -f "$AUTOSTART_FILE" ]; then
        log_event "INFO" "Ensuring set_ip_address.service is enabled and running."
        sudo systemctl daemon-reload
        sudo systemctl enable set_ip_address.service
        sudo systemctl start set_ip_address.service
    else
        log_event "INFO" "Autostart file not found. Disabling set_ip_address.service."
        sudo systemctl disable set_ip_address.service
        sudo systemctl stop set_ip_address.service
    fi

    log_event "INFO" "Systemd services validated and managed successfully."
}

# Function to validate a service file's existence and content
validate_service_file() {
    local file_path="$1"
    local expected_content="$2"

    log_event "INFO" "Validating service file: $file_path"

    if [ ! -f "$file_path" ]; then
        log_event "WARNING" "Service file $file_path does not exist. Creating it."
        echo "$expected_content" | sudo tee "$file_path" > /dev/null
    else
        # Check if the content matches
        if ! diff <(echo "$expected_content") "$file_path" &>/dev/null; then
            log_event "WARNING" "Service file $file_path content is incorrect. Overwriting."
            echo "$expected_content" | sudo tee "$file_path" > /dev/null
        else
            log_event "INFO" "Service file $file_path is valid."
        fi
    fi

    # Set appropriate permissions
    sudo chmod 644 "$file_path"
}

restart_service() {
    local service="$1"
    log_event "INFO" "Restarting service: $service"

    if sudo systemctl restart "$service"; then
        log_event "INFO" "Service $service restarted successfully."
        return 0
    else
        log_event "ERROR" "Service $service failed to restart. Attempting repair."
        return 1
    fi
}

# Function to configure and enable Apache2 for Flask (Web Interface)
configure_apache2_for_flask() {
    log_event "INFO" "Starting Apache2 configuration for Flask web interface."

    # Define required packages for Apache2 and Flask
    local required_packages=("apache2" "libapache2-mod-wsgi-py3")
    local missing_packages=()

    # Check for missing packages
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -qw "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done

    # Install missing packages
    if [ ${#missing_packages[@]} -ne 0 ]; then
        log_event "INFO" "Installing missing packages: ${missing_packages[*]}"
        if ! attempt_package_install "${missing_packages[@]}"; then
            log_event "ERROR" "Failed to install required packages: ${missing_packages[*]}"
            queue_email "Network Manager Error: Package Installation Failure" "Failed to install required Apache2 packages: ${missing_packages[*]}. Manual intervention may be required."
            return 1
        fi
        sleep 2  # Delay to ensure packages are installed
    else
        log_event "INFO" "All required Apache2 packages are installed."
    fi

    # Enable necessary Apache2 modules
    local required_modules=("wsgi" "headers" "rewrite")
    for module in "${required_modules[@]}"; do
        if ! sudo a2query -m "$module" &>/dev/null; then
            log_event "INFO" "Enabling Apache2 module: $module."
            if sudo a2enmod "$module"; then
                log_event "INFO" "Successfully enabled Apache2 module: $module."
            else
                log_event "ERROR" "Failed to enable Apache2 module: $module."
                queue_email "Network Manager Error: Apache2 Module Enablement" "Failed to enable Apache2 module '$module'. Manual intervention may be required."
                return 1
            fi
            sleep 1  # Delay to ensure module is enabled
        else
            log_event "INFO" "Apache2 module '$module' is already enabled."
        fi
    done

    # Define Apache2 configuration file path
    local apache_config="/etc/apache2/sites-available/web_interface.conf"

    # Define expected Apache2 configuration content
    local expected_content="<VirtualHost *:${WEB_INTERFACE_PORT}>
    ServerName localhost
    DocumentRoot /home/nsatt-admin/nsatt/web_interface/templates

    WSGIDaemonProcess web_interface threads=5 python-home=/home/nsatt-admin/nsatt/web_interface/venv
    WSGIScriptAlias / /home/nsatt-admin/nsatt/web_interface/network_manager.wsgi

    <Directory /home/nsatt-admin/nsatt/web_interface>
        WSGIProcessGroup web_interface
        WSGIApplicationGroup %{GLOBAL}
        Require all granted
    </Directory>

    <Directory /home/nsatt-admin/nsatt/web_interface/static>
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/web_interface_error.log
    CustomLog \${APACHE_LOG_DIR}/web_interface_access.log combined

    # Security Headers
    Header always set X-Frame-Options \"DENY\"
    Header always set X-Content-Type-Options \"nosniff\"
    Header always set Content-Security-Policy \"default-src 'self';\"
</VirtualHost>"

    # Backup existing Apache2 configuration if it exists
    if [ -f "$apache_config" ]; then
        log_event "INFO" "Backing up existing Apache2 configuration at '$apache_config'."
        if ! sudo cp "$apache_config" "${apache_config}.bak_$(date +%F_%T)"; then
            log_event "ERROR" "Failed to backup existing Apache2 configuration at '$apache_config'."
            queue_email "Network Manager Error: Apache2 Configuration Backup Failure" "Failed to backup existing Apache2 configuration at '$apache_config'. Manual intervention may be required."
            return 1
        fi
        log_event "INFO" "Backup of Apache2 configuration created successfully."
    fi

    # Create or update Apache2 configuration
    if [ ! -f "$apache_config" ] || ! diff <(echo "$expected_content") "$apache_config" &>/dev/null; then
        log_event "INFO" "Writing new Apache2 configuration to '$apache_config'."
        if ! echo "$expected_content" | sudo tee "$apache_config" > /dev/null; then
            log_event "ERROR" "Failed to write Apache2 configuration to '$apache_config'."
            queue_email "Network Manager Error: Apache2 Configuration Write Failure" "Failed to write Apache2 configuration to '$apache_config' for the Flask web interface."
            return 1
        fi
        log_event "INFO" "Apache2 configuration written successfully to '$apache_config'."
    else
        log_event "INFO" "Apache2 configuration at '$apache_config' is already up-to-date."
    fi

    # Enable the Apache2 site if not already enabled
    if ! sudo a2query -s web_interface.conf &>/dev/null; then
        log_event "INFO" "Enabling Apache2 site 'web_interface.conf'."
        if sudo a2ensite web_interface.conf; then
            log_event "INFO" "Successfully enabled Apache2 site 'web_interface.conf'."
        else
            log_event "ERROR" "Failed to enable Apache2 site 'web_interface.conf'."
            queue_email "Network Manager Error: Apache2 Site Enablement" "Failed to enable Apache2 site 'web_interface.conf' for the Flask web interface."
            return 1
        fi
        sleep 1  # Delay to ensure site is enabled
    else
        log_event "INFO" "Apache2 site 'web_interface.conf' is already enabled."
    fi

    # Ensure the WSGI script exists
    local wsgi_script="/home/nsatt-admin/nsatt/web_interface/network_manager.wsgi"
    if [ ! -f "$wsgi_script" ]; then
        log_event "ERROR" "WSGI script not found at '$wsgi_script'. Ensure the Flask application is correctly set up."
        queue_email "Network Manager Error: WSGI Script Missing" "WSGI script '$wsgi_script' not found. Please ensure the Flask application is correctly configured."
        return 1
    else
        log_event "INFO" "WSGI script found at '$wsgi_script'."
    fi

    # Restart Apache2 to apply configuration changes
    log_event "INFO" "Restarting Apache2 to apply configuration changes."
    if ! restart_service "apache2"; then
        log_event "ERROR" "Failed to restart Apache2 after configuration changes."
        queue_email "Network Manager Error: Apache2 Restart Failure" "Failed to restart Apache2 after applying configuration for the Flask web interface."
        return 1
    fi
    sleep 2  # Delay to allow Apache2 to restart

    # Verify that Apache2 is serving the Flask application
    log_event "INFO" "Verifying that Apache2 is serving the Flask web interface."
    local response
    response=$(curl -s "http://localhost:${WEB_INTERFACE_PORT}/")
    if echo "$response" | grep -q "Flask"; then
        log_event "INFO" "Apache2 is successfully serving the Flask web interface."
    else
        log_event "WARNING" "Flask web interface may not be served correctly. Verify the Flask application."
        queue_email "Network Manager Warning: Flask Interface Verification" "Apache2 restarted but the Flask web interface does not appear to be served correctly. Please verify the Flask application."
    fi

    log_event "INFO" "Apache2 configuration for Flask web interface completed successfully."

    return 0
}

# ---------------------------- Launch Python Web Interface ----------------------------

# Function to launch Python web interface
launch_python_script() {
    local python_script="$PYTHON_SCRIPT"  # Path to the Python Flask application script
    local python_log="$PYTHON_LOG"        # Path to the Python script log file

    # Check if launching the Python script is enabled
    if [ "${LAUNCH_PYTHON_SCRIPT:-false}" != "true" ] || [ "${LAUNCH_WEB_INTERFACE:-false}" != "true" ]; then
        log_event "INFO" "Launching Python script is disabled via configuration."
        return 0
    fi

    # Check for the existence of the web interface autostart file
    if [ ! -f "$WEB_INTERFACE_AUTOSTART_FILE" ]; then
        log_event "WARNING" "Web interface autostart file '$WEB_INTERFACE_AUTOSTART_FILE' not found. Skipping launching Python web interface."
        return 1
    fi

    # Check if the Python script exists
    if [ ! -f "$python_script" ]; then
        log_event "ERROR" "Python script '$python_script' not found. Ensure the Flask application is correctly set up."
        queue_email "Network Manager Error: Python Script Missing" "Python script '$python_script' not found. Please ensure the Flask application is correctly configured."
        return 1
    else
        log_event "INFO" "Python script '$python_script' found."
    fi

    # Check if the Python script is already running
    if pgrep -f "$python_script" > /dev/null; then
        log_event "INFO" "Python web interface ('$python_script') is already running."
        return 0
    fi

    # Start the Python script using nohup to run it in the background
    log_event "INFO" "Starting Python web interface: '$python_script'."
    if nohup python3 "$python_script" > "$python_log" 2>&1 & then
        sleep 2  # Delay to allow the script to start
        # Verify if the Python script started successfully
        if pgrep -f "$python_script" > /dev/null; then
            log_event "INFO" "Python web interface '$python_script' started successfully. Logs: '$python_log'."
            queue_email "Network Manager Info: Python Web Interface Started" "Python web interface '$python_script' has been started successfully. Logs are available at '$python_log'."
        else
            log_event "ERROR" "Failed to start Python web interface '$python_script'. Check logs at '$python_log' for details."
            queue_email "Network Manager Error: Python Web Interface Failed" "Failed to start Python web interface '$python_script'. Please check logs at '$python_log' for details."
            return 1
        fi
    else
        log_event "ERROR" "Failed to initiate Python web interface '$python_script'."
        queue_email "Network Manager Error: Python Web Interface Initiation" "Failed to initiate Python web interface '$python_script'. Manual intervention may be required."
        return 1
    fi

    return 0
}

# ---------------------------- Backup and Restore Functions ----------------------------

# Function to backup network configurations periodically
backup_network_configs() {
    if [ "$ENABLE_BACKUP" = false ]; then
        log_event "INFO" "Skipping network configurations backup as per configuration."
        return
    fi

    local timestamp
    timestamp=$(date '+%Y%m%d%H%M%S')
    local backup_file="${BACKUP_DIR}/interfaces.backup.$timestamp"

    if [ -f "$INTERFACES_FILE" ]; then
        execute_command "sudo cp $INTERFACES_FILE $backup_file" "Creating backup of network settings"
        # Keep only the last 5 backups
        ls -1t "${BACKUP_DIR}/interfaces.backup."* 2>/dev/null | tail -n +6 | xargs -r sudo rm --
    else
        log_event "WARNING" "$INTERFACES_FILE does not exist. Skipping backup."
    fi
}

# ---------------------------- Dependencies ----------------------------

# Main Function to Check and Install Dependencies
check_and_install_dependencies() {
    if [ "$CHECK_DEPENDENCIES" = false ]; then
        log_event "INFO" "Skipping dependency check and installation as per configuration."
        return
    fi

    log_event "INFO" "Starting dependency check and installation process."

    # Backup existing sources.list
    local backup_file="/etc/apt/sources.list.bak"
    if [ ! -f "$backup_file" ]; then
        sudo cp /etc/apt/sources.list "$backup_file" || log_event "WARNING" "Failed to create backup of sources.list"
    else
        log_event "INFO" "Backup of sources.list already exists."
    fi

    # Validate required configuration files
    local required_files=(
        "/etc/NetworkManager/NetworkManager.conf"
        "/etc/dnsmasq.conf"
        "/etc/hostapd/hostapd.conf"
        "/etc/network/interfaces.d/wlan0"
    )
    local default_contents=(
        "[main]
plugins=keyfile

[keyfile]
unmanaged-devices=interface-name:wlan0,interface-name:eth0"
        "interface=wlan0
dhcp-range=192.168.150.2,192.168.150.20,255.255.255.0,24h
log-facility=/var/log/dnsmasq.log
log-queries"
        "interface=wlan0
driver=nl80211
ssid=$HOTSPOT_SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$HOTSPOT_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP"
        "auto wlan0
iface wlan0 inet static
    address 192.168.150.1/24
    netmask 255.255.255.0"
    )

    for i in "${!required_files[@]}"; do
        validate_file "${required_files[i]}" "${default_contents[i]}"
        if [ $? -ne 0 ]; then
            log_event "ERROR" "Validation failed for ${required_files[i]}. Initiating self-repair."
            self_repair
            return 1
        fi
    done

    # Update sources.list with additional mirrors
    update_sources_list
    if [ $? -ne 0 ]; then
        log_event "ERROR" "Failed to update sources.list. Initiating self-repair."
        self_repair
        return 1
    fi

    # Required packages
    local required_packages=("sqlite3" "jq" "mailutils" "hostapd" "dnsmasq" "libapache2-mod-wsgi-py3" "apache2-utils" "openssl" "traceroute" "curl" "udev" "net-tools" "iptables-persistent" "python3-pip")

    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -qw "$pkg"; then
            log_event "WARNING" "Package $pkg is missing. Attempting installation."
            if ! install_package_with_fallback "$pkg"; then
                log_event "ERROR" "Failed to install package: $pkg. Attempting to resolve issues."
                resolve_install_issue "$pkg"
                # Retry installation after resolving issues
                if ! install_package_with_fallback "$pkg"; then
                    log_event "ERROR" "Reinstallation failed for package: $pkg. Initiating self-repair."
                    self_repair
                    return 1
                fi
            fi
        else
            log_event "INFO" "Package $pkg is already installed."
        fi
    done

    # Restart and manage required services with health check
    declare -A service_ports=(
        ["dnsmasq"]=53
        ["hostapd"]=""
        ["NetworkManager"]=""
        ["apache2"]=80
    )

    for service in "${!service_ports[@]}"; do
        local port="${service_ports[$service]}"
        manage_service_with_health_check "$service" "$port"
        if [ $? -ne 0 ]; then
            log_event "ERROR" "Failed to manage service: $service. Initiating self-repair."
            self_repair
            return 1
        fi
    done

    # Specific handling for dnsmasq (in case it is still not active)
    if ! systemctl is-active --quiet dnsmasq; then
        log_event "ERROR" "dnsmasq service is not active after health check. Initiating repair procedures."
        repair_dnsmasq
        if [ $? -ne 0 ]; then
            log_event "ERROR" "Repair failed for dnsmasq. Initiating self-repair."
            self_repair
            return 1
        fi
    else
        log_event "INFO" "dnsmasq service is active and running."
    fi

    # Additional system state verification and repair
    verify_and_repair_system_state
    if [ $? -ne 0 ]; then
        log_event "ERROR" "System state verification failed. Initiating self-repair."
        self_repair
        return 1
    fi

    # Configure web interface
    configure_web_interface
    if [ $? -ne 0 ]; then
        log_event "ERROR" "Web interface configuration failed. Initiating self-repair."
        self_repair
        return 1
    fi

    log_event "INFO" "Dependency check and installation completed successfully."
}

validate_file() {
    local file_path="$1"
    local required_content="$2"

    log_event "INFO" "Validating file: $file_path."

    # Ensure the directory exists
    local dir_path
    dir_path=$(dirname "$file_path")
    if [ ! -d "$dir_path" ]; then
        log_event "WARNING" "Directory $dir_path does not exist. Attempting to create it."
        if sudo mkdir -p "$dir_path"; then
            log_event "INFO" "Successfully created directory $dir_path."
        else
            log_event "ERROR" "Failed to create directory $dir_path. Check permissions and storage."
            return 1
        fi
    fi

    # Ensure the file exists
    if [ ! -f "$file_path" ]; then
        log_event "WARNING" "File $file_path not found. Creating it with default content."
        if echo -e "$required_content" | sudo tee "$file_path" > /dev/null; then
            log_event "INFO" "Successfully created $file_path with default content."
        else
            log_event "ERROR" "Failed to create $file_path. Check permissions and storage."
            return 1
        fi
    fi

    # Remove duplicate lines
    log_event "INFO" "Removing duplicate lines from $file_path."
    if sudo awk '!seen[$0]++' "$file_path" | sudo tee "$file_path" > /dev/null; then
        log_event "INFO" "Duplicate lines removed from $file_path."
    else
        log_event "ERROR" "Failed to remove duplicate lines from $file_path."
        return 1
    fi

    # Ensure unique directives by removing existing ones before appending required content
    log_event "INFO" "Ensuring unique configuration directives in $file_path."

    # Extract directive names from required_content
    # Assumes directives are the first word before any whitespace or '='
    local directives
    directives=$(echo -e "$required_content" | grep -E '^[^#]' | awk '{print $1}' | awk -F= '{print $1}')

    for directive in $directives; do
        # Remove all existing instances of the directive
        sudo sed -i "/^${directive}\b/d" "$file_path"
    done

    # Append the required content
    log_event "INFO" "Appending required configuration directives to $file_path."
    if echo -e "$required_content" | sudo tee -a "$file_path" > /dev/null; then
        log_event "INFO" "Successfully appended required directives to $file_path."
    else
        log_event "ERROR" "Failed to append required directives to $file_path."
        return 1
    fi

    # Validate file permissions
    log_event "INFO" "Setting appropriate permissions for $file_path."
    if sudo chmod 644 "$file_path" && sudo chown root:root "$file_path"; then
        log_event "INFO" "Permissions for $file_path set to 644 successfully."
    else
        log_event "ERROR" "Failed to set permissions for $file_path. Check ownership and storage."
        return 1
    fi

    # Ensure the file is readable
    if [ ! -r "$file_path" ]; then
        log_event "ERROR" "File $file_path is not readable. Attempting to fix permissions."
        if sudo chmod +r "$file_path"; then
            log_event "INFO" "Read permissions for $file_path restored."
        else
            log_event "ERROR" "Failed to restore read permissions for $file_path."
            return 1
        fi
    fi

    # Validate file integrity (e.g., syntax check if applicable)
    if [[ "$file_path" == *"dnsmasq.conf"* ]]; then
        log_event "INFO" "Running syntax check for $file_path."
        if ! dnsmasq --test -C "$file_path" &>/dev/null; then
            log_event "ERROR" "Syntax errors found in $file_path. Attempting to repair."
            # Attempt to remove any blank lines or invalid entries
            if sudo sed -i '/^#/!s/^[ \t]*$//' "$file_path"; then
                log_event "INFO" "Blank lines removed from $file_path."
            else
                log_event "ERROR" "Failed to remove blank lines from $file_path."
                return 1
            fi
            # Retry syntax check
            if ! dnsmasq --test -C "$file_path" &>/dev/null; then
                log_event "ERROR" "Syntax errors persist in $file_path after repair."
                return 1
            else
                log_event "INFO" "Syntax issues in $file_path resolved successfully."
            fi
        else
            log_event "INFO" "Syntax check passed for $file_path."
        fi
    fi

    log_event "INFO" "File $file_path validated successfully."
    return 0
}

mirrors=(
    "http://http.kali.org/kali kali-rolling main non-free non-free-firmware contrib"
    "http://kali.download/kali kali-rolling main non-free non-free-firmware contrib"
    "https://archive-4.kali.org/kali kali-rolling main non-free non-free-firmware contrib"
    "https://free.nchc.org.tw/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.belnet.be/pub/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.cc.uoc.gr/mirrors/linux/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.free.fr/mirrors/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.halifax.rwth-aachen.de/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.jaist.ac.jp/pub/Linux/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.ne.jp/Linux/packages/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.nluug.nl/os/Linux/distr/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.riken.jp/Linux/kali kali-rolling main non-free non-free-firmware contrib"
    "https://ftp.yz.yamagata-u.ac.jp/pub/linux/kali kali-rolling main non-free non-free-firmware contrib"
    "https://kali.cs.nycu.edu.tw/kali kali-rolling main non-free non-free-firmware contrib"
    "https://kali.itsec.am/kali kali-rolling main non-free non-free-firmware contrib"
    "https://kali.koyanet.lv/kali kali-rolling main non-free non-free-firmware contrib"
    "https://kali.mirror.garr.it/mirrors/kali kali-rolling main non-free non-free-firmware contrib"
    "https://kali.mirror.rafal.ca/kali kali-rolling main non-free non-free-firmware contrib"
    "https://kali.mirror1.gnc.am/kali kali-rolling main non-free non-free-firmware contrib"
    "https://kali.mirror2.gnc.am/kali kali-rolling main non-free non-free-firmware contrib"
    "https://md.mirrors.hacktegic.com/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.0xem.ma/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.2degrees.nz/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.accum.se/mirror/kali.org/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.aktkn.sg/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.amuksa.com/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.cedia.org.ec/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.cspacehostings.com/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.freedif.org/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.init7.net/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.karneval.cz/pub/linux/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.kku.ac.th/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.lagoon.nc/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.leitecastro.com/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.netcologne.de/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.primelink.net.id/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.pyratelan.org/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.serverion.com/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.siwoo.org/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.telepoint.bg/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.truenetwork.ru/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.twds.com.tw/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.ufro.cl/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror.vinehost.net/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirror1.sox.rs/kali/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirrors.dotsrc.org/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirrors.jevincanders.net/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirrors.neusoft.edu.cn/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirrors.ocf.berkeley.edu/kali kali-rolling main non-free non-free-firmware contrib"
    "https://mirrors.ustc.edu.cn/kali kali-rolling main non-free non-free-firmware contrib"
    "https://repo.jing.rocks/kali kali-rolling main non-free non-free-firmware contrib"
    "https://xsrv.moratelindo.io/kali kali-rolling main non-free non-free-firmware contrib"
)

# Function to update sources.list with dynamic mirror prioritization
update_sources_list() {
    local sources_file="/etc/apt/sources.list"
    local backup_file="/etc/apt/sources.list.bak"
    local primary_mirror="http://http.kali.org/kali kali-rolling main non-free non-free-firmware contrib"

    log_event "INFO" "Checking primary mirror for connectivity: $primary_mirror."

    # Backup existing sources.list if not already backed up
    if [ ! -f "$backup_file" ]; then
        if sudo cp "$sources_file" "$backup_file"; then
            log_event "INFO" "Backup of sources.list created successfully."
        else
            log_event "WARNING" "Failed to create backup of sources.list."
            return 1
        fi
    fi

    # Test primary mirror
    if curl --head --silent --fail --max-time 3 "http://http.kali.org/kali" &>/dev/null; then
        log_event "INFO" "Primary mirror is reachable. Setting sources.list to use only the primary mirror."
        echo "deb $primary_mirror" | sudo tee "$sources_file" > /dev/null
    else
        log_event "WARNING" "Primary mirror is unreachable. Falling back to alternate mirrors."

        # Clear the current sources list
        if sudo truncate -s 0 "$sources_file"; then
            log_event "INFO" "Cleared existing sources.list."
        else
            log_event "ERROR" "Failed to clear sources.list."
            return 1
        fi

        # Test and add alternate mirrors
        for mirror in "${mirrors[@]}"; do
            local url=$(echo "$mirror" | awk '{print $1}')
            if curl --head --silent --fail --max-time 3 "$url" &>/dev/null; then
                echo "deb $mirror" | sudo tee -a "$sources_file" > /dev/null
                log_event "INFO" "Added reachable mirror: $url"
                break
            else
                log_event "WARNING" "Mirror is unreachable: $url"
            fi
        done
    fi
}

# Function to install a package with fallback and minimal updates
install_package_with_fallback() {
    local package="$1"
    local successful_install=false

    # Check if the package is already installed
    if dpkg -l | grep -qw "$package"; then
        log_event "INFO" "Package $package is already installed. Skipping installation."
        return 0
    fi

    log_event "INFO" "Starting installation process for package: $package."

    # Iterate through mirrors to find a working one
    for mirror in "${mirrors[@]}"; do
        local url=$(echo "$mirror" | awk '{print $1}')
        log_event "INFO" "Testing mirror: $url."

        # Temporarily set sources.list to use the current mirror
        echo "deb $mirror" | sudo tee /etc/apt/sources.list > /dev/null

        # Skip apt-get update if all required packages are already installed
        if dpkg -l | grep -qw "$package"; then
            log_event "INFO" "Package $package was found during mirror switch. Skipping update."
            successful_install=true
            break
        fi

        # Run apt-get update to refresh package lists
        if sudo apt-get update -qq; then
            log_event "INFO" "Updated package lists successfully using mirror: $url."
        else
            log_event "WARNING" "Failed to update package lists with mirror: $url. Trying next mirror."
            continue
        fi

        # Attempt to install the package
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"; then
            log_event "INFO" "Successfully installed $package from mirror: $url."
            successful_install=true
            break
        else
            log_event "WARNING" "Failed to install $package from mirror: $url. Trying next mirror."
        fi
    done

    # Restore default sources.list to the primary mirror if successful
    if [ "$successful_install" = true ]; then
        log_event "INFO" "Restoring sources.list to the default with the primary mirror."
        echo "deb http://http.kali.org/kali kali-rolling main non-free non-free-firmware contrib" | sudo tee /etc/apt/sources.list > /dev/null
        sudo apt-get update -qq
    else
        log_event "ERROR" "Failed to install $package from all available mirrors."
        return 1
    fi

    return 0
}

# Function to resolve installation issues
resolve_install_issue() {
    local pkg="$1"
    log_event "INFO" "Starting resolution process for installation issues related to package: $pkg."

    # Attempt to fix broken dependencies
    if sudo apt-get install -f; then
        log_event "INFO" "Successfully fixed broken dependencies."
    else
        log_event "ERROR" "Failed to fix broken dependencies for package: $pkg."
    fi

    # Reconfigure any packages that are in an incomplete state
    if sudo dpkg --configure -a; then
        log_event "INFO" "Successfully reconfigured packages."
    else
        log_event "ERROR" "Failed to reconfigure packages. Please check for issues."
    fi

    # Clean up the package cache to free up space
    if sudo apt-get clean; then
        log_event "INFO" "Package cache cleaned successfully."
    else
        log_event "WARNING" "Failed to clean package cache. This may lead to storage issues."
    fi

    # Update the sources list to ensure we have the latest package information
    if update_sources_list; then
        log_event "INFO" "Successfully refreshed sources.list."
    else
        log_event "ERROR" "Failed to refresh sources.list. This may affect package installations."
    fi
}

# Function to manage service with health check
manage_service_with_health_check() {
    local service="$1"
    local port="$2"
    
    log_event "INFO" "Managing service: $service"

    # Attempt to start/restart service
    if ! sudo systemctl restart "$service"; then
        log_event "WARNING" "Failed to restart $service, attempting repair..."
        attempt_service_repair "$service"
    fi

    # Verify service health
    if [ -n "$port" ]; then
        timeout 30 bash -c "until netstat -tuln | grep -q :$port; do sleep 2; done" || {
            log_event "ERROR" "Service $service not listening on port $port after 30 seconds"
            attempt_service_repair "$service"
        }
    fi

    # Enable service for automatic startup
    sudo systemctl enable "$service"
}

# Function to attempt service repair
attempt_service_repair() {
    local service_name="$1"
    log_event "INFO" "Initiating repair process for service: $service_name."

    # Reset the service's failed state to allow for a fresh start
    if sudo systemctl reset-failed "$service_name"; then
        log_event "INFO" "Successfully reset the failed state for service: $service_name."
    else
        log_event "ERROR" "Failed to reset the failed state for service: $service_name."
        return 1
    fi

    # Reload the systemd daemon to ensure it recognizes any changes
    if sudo systemctl daemon-reload; then
        log_event "INFO" "Systemd daemon reloaded successfully."
    else
        log_event "ERROR" "Failed to reload systemd daemon."
        return 1
    fi

    # Attempt to restart the service
    if sudo systemctl restart "$service_name"; then
        log_event "INFO" "Service $service_name is restarting. Waiting for it to stabilize..."
        sleep 5  # Allow time for the service to start

        # Check if the service is active after the restart
        if sudo systemctl is-active --quiet "$service_name"; then
            log_event "INFO" "Service $service_name has been repaired and is now active."
            return 0
        else
            log_event "ERROR" "Service $service_name is inactive after the repair attempt. Checking if it's dnsmasq to apply specific repairs."
            if [ "$service_name" == "dnsmasq" ]; then
                repair_dnsmasq
            else
                log_event "ERROR" "Unable to repair service: $service_name. Please check the service logs for more details."
                return 1
            fi
        fi
    else
        log_event "ERROR" "Failed to restart service: $service_name after repair attempt. Checking if it's dnsmasq to apply specific repairs."
        if [ "$service_name" == "dnsmasq" ]; then
            repair_dnsmasq
        else
            log_event "ERROR" "Unable to restart service: $service_name. Please check the service logs for more details."
            return 1
        fi
    fi
}

# Function to repair dnsmasq
repair_dnsmasq() {
    log_event "INFO" "Diagnosing dnsmasq service failure."

    # Check for configuration errors
    if ! dnsmasq --test -C /etc/dnsmasq.conf &>/dev/null; then
        log_event "ERROR" "dnsmasq configuration test failed. Reviewing /etc/dnsmasq.conf."

        # Remove duplicate directives
        log_event "INFO" "Removing duplicate directives from /etc/dnsmasq.conf."
        # Define required directives
        local required_directives=("interface" "dhcp-range" "log-facility" "log-queries")
        
        for directive in "${required_directives[@]}"; do
            # Remove all existing instances of the directive
            sudo sed -i "/^${directive}\b/d" /etc/dnsmasq.conf
        done

        # Append required directives using global variables
        echo -e "interface=wlan0\ndhcp-range=192.168.150.2,192.168.150.20,255.255.255.0,24h\nlog-facility=/var/log/dnsmasq.log\nlog-queries" | sudo tee -a /etc/dnsmasq.conf > /dev/null

        # Run syntax check again
        log_event "INFO" "Re-running syntax check for dnsmasq."
        if dnsmasq --test -C /etc/dnsmasq.conf &>/dev/null; then
            log_event "INFO" "dnsmasq configuration is now valid."
        else
            log_event "ERROR" "dnsmasq configuration still contains errors after repair attempt."
            return 1
        fi
    else
        log_event "INFO" "No configuration errors detected in dnsmasq.conf."
    fi

    # Restart dnsmasq service
    if restart_service "dnsmasq"; then
        log_event "INFO" "dnsmasq service restarted successfully."
    else
        log_event "ERROR" "Failed to restart dnsmasq service after repair."
        return 1
    fi
}

# Function to resolve package installation issues
resolve_package_install_issues() {
    local package="$1"
    
    # Update package lists and fix broken dependencies
    sudo apt-get update
    sudo apt-get --fix-broken install -y
    sudo dpkg --configure -a
    
    # Check for and resolve common issues
    if ! apt-cache show "$package" &>/dev/null; then
        # Package not found - try additional repositories
        sudo add-apt-repository universe -y
        sudo add-apt-repository multiverse -y
        sudo apt-get update
    fi
    
    # Check for and resolve dependency conflicts
    local deps
    deps=$(apt-cache depends "$package" 2>/dev/null | grep Depends | cut -d: -f2)
    for dep in $deps; do
        sudo apt-get install -y "$dep" || true
    done
    
    return 0
}

# Function to verify and repair system state
verify_and_repair_system_state() {
    # Verify system state and perform repairs if needed
    log_event "INFO" "Verifying system state..."
    
    # Check and repair network configuration
    if ! ip link show &>/dev/null; then
        log_event "WARNING" "Network subsystem issues detected, attempting repair..."
        sudo systemctl restart networking
    fi
    
    # Verify required directories and permissions
    local required_dirs=("/var/log/set_ip_address" "/etc/set_ip_address" "/var/run/set_ip_address")
    for dir in "${required_dirs[@]}"; do
        sudo mkdir -p "$dir"
        sudo chmod 755 "$dir"
    done
    
    # Verify and repair firewall rules
    if ! sudo iptables -L &>/dev/null; then
        log_event "WARNING" "Firewall issues detected, resetting rules..."
        sudo iptables-restore < /etc/iptables.rules || true
    fi
}

# Function to configure web interface
configure_web_interface() {
    log_event "INFO" "Configuring web interface..."
    
    # Ensure Python virtual environment
    if [ ! -d "/home/nsatt-admin/nsatt/web_interface/venv" ]; then
        python3 -m venv /home/nsatt-admin/nsatt/web_interface/venv
        source /home/nsatt-admin/nsatt/web_interface/venv/bin/activate
        pip install flask requests
        log_event "INFO" "Python virtual environment created and packages installed."
    else
        log_event "INFO" "Python virtual environment already exists."
    fi
    
    # Set permissions for the virtual environment directory
    sudo chown -R nsatt-admin:nsatt-admin /home/nsatt-admin/nsatt/web_interface/venv
    sudo chmod -R 755 /home/nsatt-admin/nsatt/web_interface/venv
    
    # Configure Apache
    configure_apache2_for_flask
}

# Function to perform self-repair and fix issues
self_repair() {
    log_event "INFO" "Initiating system self-repair process."

    # Attempt to verify and repair system state
    verify_and_repair_system_state
    if [ $? -ne 0 ]; then
        log_event "ERROR" "System state verification failed during self-repair."
    fi

    # Attempt to reinstall and restart dependencies
    check_and_install_dependencies
    if [ $? -ne 0 ]; then
        log_event "ERROR" "Dependency installation failed during self-repair."
    fi

    log_event "INFO" "System self-repair process completed."
}

# ---------------------------- Self-Update Function (Optional) ----------------------------

# Function to self-update the script from a central repository (if ENABLE_SELF_UPDATE is true)
self_update() {
    if [ "$ENABLE_SELF_UPDATE" = false ]; then
        log_event "INFO" "Self-update functionality is disabled via configuration."
        return
    fi

    local repo_url="https://www.tstp.xyz/nsatt/updates/production/networking/set_ip_address.sh"
    local temp_file="/tmp/set_ip_address.sh"

    log_event "INFO" "Checking for script updates."

    # Download the latest script
    if curl -fsSL "$repo_url" -o "$temp_file"; then
        # Compare the downloaded script with the current one
        if ! diff "$temp_file" "$0" &>/dev/null; then
            log_event "INFO" "New version of set_ip_address.sh detected. Updating script."
            sudo mv "$temp_file" "$0"
            sudo chmod +x "$0"
            log_event "INFO" "Script updated successfully. Restarting service."
            sudo systemctl restart set_ip_address.service
        else
            log_event "INFO" "Script is up-to-date."
            rm -f "$temp_file"
        fi
    else
        log_event "ERROR" "Failed to download the latest version of set_ip_address.sh from $repo_url."
    fi
}

# ---------------------------- Monitoring Network Interfaces ----------------------------

# Function to disable NetworkManager for the interface
monitor_interfaces() {
    local current_interface=""
    local expected_static_ip=""
    local base_ip=""
    local ip=""
    local subnet_mask=""
    local gateway=""
    local broadcast=""
    local dns_servers=()
    local CHECK_INTERVAL=60  # Define your desired check interval in seconds

    while true; do
        log_event "INFO" "=== Starting Interface Monitoring Cycle ===" ""

        # Pre-Monitoring Snapshot: Gather and display current status of all relevant network interfaces
        log_event "INFO" "Gathering current network interfaces and their configurations." ""
        local interfaces
        interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -E "^(eth|wlan)" || echo "")
        log_event "DEBUG" "Detected network interfaces: $interfaces" ""

        for iface in $interfaces; do
            # Calculate box width based on longest line
            local box_width=70
            local title="Interface Status: $iface"
            local title_padding=$(( (box_width - ${#title} - 2) / 2 ))
            local title_extra=$(( (box_width - ${#title} - 2) % 2 ))

            # Print top border and title
            printf "╔%s╗\n" "$(printf '═%.0s' $(seq 1 $box_width))"

            # Calculate exact padding to ensure equal borders
            local total_padding=$(( box_width - ${#title} - 2 )) # Total padding needed
            local left_padding=$(( total_padding / 2 ))         # Left padding
            local right_padding=$(( total_padding - left_padding )) # Right padding

            printf "║%s%s%s║\n" "$(printf ' %.0s' $(seq 1 $left_padding))" "$title" "$(printf ' %.0s' $(seq 1 $right_padding))"
            printf "╠%s╣\n" "$(printf '═%.0s' $(seq 1 $box_width))"

            # Get interface status with more detail
            local iface_status
            local iface_speed
            local iface_duplex
            if ip link show "$iface" | grep -q "UP"; then
                iface_status="UP"
                iface_speed=$(ethtool "$iface" 2>/dev/null | grep "Speed:" | awk '{print $2}' || echo "Unknown")
                iface_duplex=$(ethtool "$iface" 2>/dev/null | grep "Duplex:" | awk '{print $2}' || echo "Unknown")
            else
                iface_status="DOWN"
                iface_speed="N/A"
                iface_duplex="N/A"
            fi

            # Get detailed IP and network info
            local iface_ip
            iface_ip=$(ip -4 addr show dev "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || echo "")

            if [[ -n "$iface_ip" ]]; then
                # Derive subnet mask directly from CIDR and validate
                local cidr
                cidr=$(ip -o -4 addr show dev "$iface" | awk '{print $4}' | cut -d'/' -f2)

                # Initialize subnet mask components
                local iface_subnet=""
                if [[ -n "$cidr" && "$cidr" -ge 0 && "$cidr" -le 32 ]]; then
                    # Compute the subnet mask using the CIDR
                    local full_octets=$((cidr / 8))     # Number of full 255 octets
                    local remaining_bits=$((cidr % 8)) # Remaining bits for partial octet

                    # Generate full 255 octets
                    for ((i = 0; i < full_octets; i++)); do
                        iface_subnet+="255."
                    done

                    # Generate the partial octet if there are remaining bits
                    if ((remaining_bits > 0)); then
                        iface_subnet+=$((256 - 2 ** (8 - remaining_bits))). # Calculate partial octet
                    fi

                    # Pad remaining octets with 0 to make a full IPv4 address
                    while [[ "$(echo "$iface_subnet" | awk -F'.' '{print NF - 1}')" -lt 3 ]]; do
                        iface_subnet+="0."
                    done

                    # Remove trailing dot
                    iface_subnet="${iface_subnet%.}"

                    # Correct incomplete subnet masks like "255.255.255"
                    if [[ "$iface_subnet" =~ ^255\.255\.255$ ]]; then
                        iface_subnet+=".0"
                    fi

                    # Validate the generated subnet mask
                    if [[ ! "$iface_subnet" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                        iface_subnet="N/A"  # Mark invalid if it doesn't match IPv4 pattern
                    fi
                else
                    # Fallback to N/A if CIDR is invalid
                    iface_subnet="N/A"
                fi

                # Validate and correct subnet mask if necessary
                if [[ "$iface_subnet" =~ ^255\.255\.255$ ]]; then
                    local ip_last_octet
                    ip_last_octet=$(echo "$iface_ip" | awk -F'.' '{print $4}')
                    if [[ "$ip_last_octet" -eq 0 ]]; then
                        iface_subnet="${iface_subnet}.0"
                    fi
                fi


                # Get gateway
                local iface_gateway
                iface_gateway=$(ip route | awk "/^default via/ && /dev $iface/ {print \$3}")
                [[ -z "$iface_gateway" ]] && iface_gateway="N/A"

                # Get broadcast
                local iface_broadcast
                iface_broadcast=$(ip -o -4 addr show dev "$iface" | awk '{print $6}')
                [[ -z "$iface_broadcast" ]] && iface_broadcast="N/A"

                # Get DNS servers
                local iface_dns
                iface_dns=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | paste -sd "," -)
                [[ -z "$iface_dns" ]] && iface_dns="N/A"

                # Get MAC address
                local mac_address
                mac_address=$(ip link show "$iface" | awk '/ether/ {print $2}')

                # Function to print formatted line with proper padding
                print_line() {
                    local label="$1"
                    local value="$2"
                    local line="$label : $value"
                    local padding=$(( box_width - ${#line} - 2 ))
                    printf "║ %s%s║\n" "$line" "$(printf ' %.0s' $(seq 1 $padding))"
                }

                # Print detailed interface info with adaptive formatting
                print_line "Status" "$iface_status"
                print_line "Speed" "$iface_speed"
                print_line "Duplex" "$iface_duplex"
                print_line "MAC Address" "$mac_address"
                printf "╠%s╣\n" "$(printf '═%.0s' $(seq 1 $box_width))"
                print_line "IP Address" "$iface_ip"
                print_line "Subnet Mask" "$iface_subnet"
                print_line "Gateway" "$iface_gateway"
                print_line "Broadcast" "$iface_broadcast"
                print_line "DNS Servers" "$iface_dns"

                # Assign iface_* variables to main variables
                ip="$iface_ip"
                subnet_mask="$iface_subnet"
                gateway="$iface_gateway"
                broadcast="$iface_broadcast"
                dns_servers=($(echo "$iface_dns" | tr ',' ' '))

                # Internal Validation of the Assigned Variables
                validate_and_correct_network_info "$iface" ip subnet_mask gateway broadcast dns_servers

                # Print standard format for compatibility
                printf "%-12s %-15s %-15s %-15s %-10s %-25s\n" \
                    "$iface" "$ip" "$subnet_mask" "$gateway" "$iface_status" "$(IFS=,; echo "${dns_servers[*]}")"
            else
                # Assign default values when interface is down or has no IP
                ip="N/A"
                subnet_mask="N/A"
                gateway="N/A"
                dns_servers=("N/A")

                print_line "Status" "$iface_status"
                print_line "Message" "Interface is down or has no IP configuration"

                # Print standard format for compatibility
                printf "%-12s %-15s %-15s %-15s %-10s %-25s\n" \
                    "$iface" "$ip" "$subnet_mask" "$gateway" "$iface_status" "N/A"
            fi

            printf "╚%s╝\n" "$(printf '═%.0s' $(seq 1 $box_width))"
            echo ""  # Add blank line for readability
            sleep 1
        done

        display_errors

        # Update the priority list
        log_event "INFO" "Updating priority list of network interfaces." ""
        if ! update_priority_list; then
            log_event "ERROR" "Failed to update priority list. Skipping this cycle." ""
            sleep "$CHECK_INTERVAL"
            continue
        else
            log_event "DEBUG" "Priority list updated successfully." ""
        fi

        # Select the best available interface, excluding 'lo'
        log_event "INFO" "Selecting the best available network interface based on priority." ""
        local interface
        interface=$(select_and_test_interface | grep -E "^(eth|wlan)")
        if [ -n "$interface" ]; then
            log_event "DEBUG" "Selected interface: $interface" ""
        else
            log_event "ERROR" "No valid network interface found. Retrying in $CHECK_INTERVAL seconds." ""
            sleep "$CHECK_INTERVAL"
            continue
        fi

        # Handle interface change
        if [ "$interface" != "$current_interface" ]; then
            log_event "INFO" "Detected interface change. Switching active interface to '$interface'." ""

            if [ -n "$current_interface" ]; then
                log_event "INFO" "Bringing down previous interface: '$current_interface'." "$current_interface"
                if ! execute_command "sudo ip link set $current_interface down" "Bringing down interface $current_interface" "$current_interface"; then
                    log_event "ERROR" "Failed to bring down interface '$current_interface'. Continuing with '$interface'." "$current_interface"
                else
                    log_event "DEBUG" "Successfully brought down interface '$current_interface'." "$current_interface"
                fi
                sleep 2  # Delay to ensure interface is down
            fi

            current_interface="$interface"
            log_event "DEBUG" "Set current_interface to '$current_interface'." "$current_interface"

            # Disable NetworkManager for the selected interface if required
            if [ "$CHECK_DEPENDENCIES" = true ] && ! is_network_manager_disabled "$current_interface"; then
                log_event "INFO" "Disabling NetworkManager for '$current_interface'." "$current_interface"
                if disable_network_manager "$current_interface"; then
                    log_event "INFO" "NetworkManager disabled for '$current_interface'." "$current_interface"
                else
                    log_event "ERROR" "Failed to disable NetworkManager for '$current_interface'." "$current_interface"
                fi
                sleep 2  # Delay to ensure NetworkManager is disabled
            fi

            # Reset to DHCP if CONNECT_ON_ALL_ADAPTERS is true
            if [ "$CONNECT_ON_ALL_ADAPTERS" = true ]; then
                log_event "INFO" "Resetting '$current_interface' to DHCP." "$current_interface"
                if reset_to_dhcp "$current_interface"; then
                    log_event "INFO" "Reset '$current_interface' to DHCP successfully." "$current_interface"
                else
                    log_event "ERROR" "Failed to reset '$current_interface' to DHCP." "$current_interface"
                fi
                sleep 5  # Delay to allow DHCP to assign new settings
            fi

            # Get and validate network settings
            log_event "INFO" "Retrieving network settings for '$current_interface'..." "$current_interface"
            # Since we have already assigned and validated the variables, we can proceed

            # Validate retrieved network settings
            if [[ "$ip" == "N/A" || "$subnet_mask" == "N/A" || "$gateway" == "N/A" ]]; then
                log_event "ERROR" "Incomplete network settings for '$current_interface'. Attempting to repair." "$current_interface"
                if [ "$BRING_UP_ALL_DEVICES" = true ]; then
                    log_event "INFO" "Attempting to reset '$current_interface' to DHCP for repair." "$current_interface"
                    if reset_to_dhcp "$current_interface"; then
                        log_event "INFO" "Successfully reset '$current_interface' to DHCP." "$current_interface"
                        sleep 5  # Wait for DHCP to assign new settings
                        continue
                    else
                        log_event "ERROR" "Failed to reset '$current_interface' to DHCP." "$current_interface"
                    fi
                else
                    log_event "WARNING" "Fallback mode is disabled. Manual intervention required for '$current_interface'." "$current_interface"
                fi
            else
                # Validate IP address format
                if ! validate_ip "$ip"; then
                    log_event "ERROR" "Invalid IP address '$ip' for interface '$current_interface'." "$current_interface"
                    sleep "$CHECK_INTERVAL"
                    continue
                fi

                # Validate subnet mask format
                if ! validate_ip "$subnet_mask"; then
                    log_event "ERROR" "Invalid Subnet Mask '$subnet_mask' for interface '$current_interface'." "$current_interface"
                    sleep "$CHECK_INTERVAL"
                    continue
                fi

                # Validate gateway format
                if ! validate_ip "$gateway"; then
                    log_event "ERROR" "Invalid Gateway '$gateway' for interface '$current_interface'." "$current_interface"
                    sleep "$CHECK_INTERVAL"
                    continue
                fi

                log_event "INFO" "Validated settings for '$current_interface': IP=$ip, Gateway=$gateway, Subnet Mask=$subnet_mask." "$current_interface"
            fi

            # Configure static IP if BRING_UP_ALL_DEVICES is true
            if [ "$BRING_UP_ALL_DEVICES" = true ]; then
                base_ip=$(echo "$ip" | awk -F'.' '{print $1"."$2"."$3}')
                local desired_ip="${base_ip}.200"
                local next_ip=200

                log_event "DEBUG" "Base IP: '$base_ip', Initial Desired IP: '$desired_ip'." "$current_interface"

                # Determine if desired IP is available
                while ping -c 1 -W 1 "$desired_ip" &> /dev/null; do
                    next_ip=$((next_ip + 1))
                    if [ $next_ip -gt 254 ]; then
                        log_event "ERROR" "No available IPs in range for '$current_interface'." "$current_interface"
                        break
                    fi
                    desired_ip="${base_ip}.$next_ip"
                done

                if [[ "$ip" != "$desired_ip" && $next_ip -le 254 ]]; then
                    log_event "INFO" "Assigning IP '$desired_ip' to interface '$current_interface'." "$current_interface"

                    if update_interfaces_file "$current_interface" "$desired_ip" "$subnet_mask" "$gateway" "$broadcast" "${dns_servers[@]}"; then
                        log_event "INFO" "Successfully updated interfaces file for '$current_interface' with IP '$desired_ip'." "$current_interface"

                        if execute_command "sudo systemctl restart networking" "Restarting networking service for '$current_interface'" "$current_interface"; then
                            expected_static_ip="$desired_ip"
                            log_event "INFO" "Assigned IP '$expected_static_ip' to '$current_interface'." "$current_interface"
                        else
                            log_event "ERROR" "Failed to restart networking service after assigning IP to '$current_interface'." "$current_interface"
                        fi
                    else
                        log_event "ERROR" "Failed to update interfaces file for '$current_interface'." "$current_interface"
                    fi
                    sleep 5  # Delay to allow networking service to restart
                else
                    log_event "INFO" "Keeping current IP '$ip' for '$current_interface'." "$current_interface"
                    expected_static_ip="$ip"
                fi
            fi
        fi

        # Reapply static IP if it changes unexpectedly
        if [ "$BRING_UP_ALL_DEVICES" = true ] && [ -n "$expected_static_ip" ] && [ -n "$current_interface" ]; then
            log_event "DEBUG" "Verifying current IP for '$current_interface' against expected static IP '$expected_static_ip'." "$current_interface"
            local current_ip
            current_ip=$(get_ip "$current_interface" 2>/dev/null || echo "")
            log_event "DEBUG" "Current IP for '$current_interface': '${current_ip:-N/A}', Expected IP: '$expected_static_ip'." "$current_interface"

            if [ "$current_ip" != "$expected_static_ip" ]; then
                log_event "WARNING" "IP for '$current_interface' has changed unexpectedly (Current: '$current_ip', Expected: '$expected_static_ip'). Reapplying static IP." "$current_interface"

                if update_interfaces_file "$current_interface" "$expected_static_ip" "$subnet_mask" "$gateway" "$broadcast" "${dns_servers[@]}"; then
                    log_event "INFO" "Successfully updated interfaces file for '$current_interface' with static IP '$expected_static_ip'." "$current_interface"

                    if execute_command "sudo systemctl restart networking" "Restarting networking service for '$current_interface'" "$current_interface"; then
                        log_event "INFO" "Reapplied static IP '$expected_static_ip' to '$current_interface'." "$current_interface"
                        sleep 5  # Delay to allow networking service to restart
                    else
                        log_event "ERROR" "Failed to restart networking service after reapplying static IP to '$current_interface'." "$current_interface"
                    fi
                else
                    log_event "ERROR" "Failed to update interfaces file while reapplying static IP for '$current_interface'." "$current_interface"
                fi
            else
                log_event "INFO" "IP for '$current_interface' matches expected static IP '$expected_static_ip'." "$current_interface"
            fi
        fi

        # Connectivity checks and fallback
        if [ "$CONNECT_ON_ALL_ADAPTERS" = true ]; then
            log_event "INFO" "Checking connectivity status for all interfaces." ""
            if check_all_interfaces_status; then
                log_event "INFO" "All interfaces are up and running with proper connectivity." ""
            else
                log_event "WARNING" "One or more interfaces are down or lack connectivity. Initiating fallback procedures." ""
                # Implement additional fallback logic here if needed
                sleep 2  # Delay before proceeding
            fi
        fi

        # Hotspot management
        if [ "$ENABLE_HOTSPOT" = true ]; then
            log_event "INFO" "Managing hotspot based on current internet connectivity." ""
            if ! check_any_interface_connectivity; then
                log_event "INFO" "No internet connectivity detected on any interface. Attempting to create hotspot." ""
                if create_hotspot; then
                    log_event "INFO" "Hotspot created successfully." ""
                else
                    log_event "ERROR" "Failed to create hotspot. Manual intervention may be required." ""
                fi
                sleep 2  # Delay to ensure hotspot is created
            else
                log_event "INFO" "Internet connectivity detected on at least one interface. Attempting to remove hotspot if active." ""
                if remove_hotspot; then
                    log_event "INFO" "Hotspot removed successfully." ""
                else
                    log_event "ERROR" "Failed to remove hotspot. Manual intervention may be required." ""
                fi
                sleep 2  # Delay to ensure hotspot is removed
            fi
        fi

        # VPN management
        if [ "$MANAGE_VPN" = true ]; then
            log_event "INFO" "Ensuring VPN is active." ""
            if start_vpn; then
                log_event "INFO" "VPN started successfully." ""
            else
                log_event "ERROR" "Failed to start VPN. Manual intervention may be required." ""
            fi
            sleep 2  # Delay after VPN start
        fi

        # Perform self-update
        if [ "$ENABLE_SELF_UPDATE" = true ]; then
            log_event "INFO" "Checking for self-update." ""
            if self_update; then
                log_event "INFO" "Self-update completed successfully." ""
            else
                log_event "ERROR" "Self-update failed. Please check update logs for details." ""
            fi
            sleep 2  # Delay after self-update
        fi

        # Launch Python web interface if enabled
        if [ "$LAUNCH_WEB_INTERFACE" = true ]; then
            log_event "INFO" "Launching Python web interface if not already running." ""
            launch_python_script
        fi

        # Send any queued emails before sleeping
        send_queued_emails

        # Delay before next check
        log_event "DEBUG" "Sleeping for $CHECK_INTERVAL seconds before next check." ""
        sleep "$CHECK_INTERVAL"
    done
}

# Monitor network changes and trigger main monitoring function when needed
monitor_changes() {
    # ISSUE: Original code had recursive loop by calling monitor_interfaces inside the main loop
    # FIXED: Separated monitor_changes into standalone function that triggers main function
    
    log_event "INFO" "Starting network change monitor..." ""
    local prev_state=""
    local current_state=""
    local check_interval=5

    trap 'exit 0' SIGTERM SIGINT

    while true; do
        current_state=$(ip -o addr show | awk '{print $2, $3, $4}' | sort | tr '\n' ' ')

        if [[ "$current_state" != "$prev_state" ]]; then
            log_event "INFO" "Network change detected - starting monitoring cycle" ""
            monitor_interfaces & # Run monitoring asynchronously
            prev_state="$current_state"
        fi

        sleep "$check_interval"
    done
}

# Global error queue
ERROR_QUEUE=()

delayed_error() {
    # Function to queue errors for later display
    local message="$1"
    local interface="$2"
    ERROR_QUEUE+=("ERROR: $message (Interface: $interface)")
}

display_errors() {
    # Function to display all queued errors and clear the queue
    if [ ${#ERROR_QUEUE[@]} -eq 0 ]; then
        echo "No errors to display."
    else
        echo "Displaying all queued errors:"
        for error in "${ERROR_QUEUE[@]}"; do
            echo "$error"
        done
        # Clear the error queue
        ERROR_QUEUE=()
    fi
}

# Function to validate and correct network information
validate_and_correct_network_info() {
    local interface="$1"
    shift
    local -n ip_ref="$1"
    local -n subnet_ref="$2"
    local -n gateway_ref="$3"
    local -n broadcast_ref="$4"
    local -n dns_ref="$5"

    # Validate IP address
    if ! validate_ip "$ip_ref"; then
        delayed_error "Detected invalid IP '$ip_ref' on interface '$interface'. Attempting to retrieve correct IP." "$interface"
        ip_ref=$(ip -4 addr show dev "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || echo "N/A")
        if ! validate_ip "$ip_ref"; then
            delayed_error "Unable to retrieve a valid IP for interface '$interface'." "$interface"
            ip_ref="N/A"
        else
            delayed_error "INFO" "Corrected IP for interface '$interface' to '$ip_ref'." "$interface"
        fi
    fi

    # Validate Subnet Mask
    if ! validate_ip "$subnet_ref"; then
        #log_event "WARNING" "Detected invalid Subnet Mask '$subnet_ref' on interface '$interface'. Attempting to retrieve correct subnet mask." "$interface"
        local cidr
        cidr=$(ip -o -4 addr show dev "$interface" | awk '{print $4}' | cut -d'/' -f2)
        subnet_ref=$(cidr_to_netmask "$cidr")
        if ! validate_ip "$subnet_ref"; then
            delayed_error "Unable to retrieve a valid Subnet Mask for interface '$interface' - Data Provided: $subnet_ref" "$interface"
            subnet_ref="N/A"
        else
            delayed_error "Corrected Subnet Mask for interface '$interface' to '$subnet_ref'." "$interface"
        fi
    fi

    # Validate Gateway
    if [ "$gateway_ref" != "N/A" ] && ! validate_ip "$gateway_ref"; then
        delayed_error "Detected invalid Gateway '$gateway_ref' on interface '$interface'. Attempting to retrieve correct gateway." "$interface"
        gateway_ref=$(ip route | awk "/^default via/ && /dev $interface/ {print \$3}")
        if [ -z "$gateway_ref" ]; then
            delayed_error "Unable to retrieve a valid Gateway for interface '$interface'." "$interface"
            gateway_ref="N/A"
        else
            if ! validate_ip "$gateway_ref"; then
                delayed_error "Retrieved Gateway '$gateway_ref' is invalid for interface '$interface' - Data Provided: $gateway_ref" "$interface"
                gateway_ref="N/A"
            else
                delayed_error "Corrected Gateway for interface '$interface' to '$gateway_ref'." "$interface"
            fi
        fi
    fi

    # Validate Broadcast
    if [ "$broadcast_ref" != "N/A" ] && ! validate_ip "$broadcast_ref"; then
        delayed_error "Detected invalid Broadcast address '$broadcast_ref' on interface '$interface'. Attempting to retrieve correct broadcast address." "$interface"
        broadcast_ref=$(ip -o -4 addr show dev "$interface" | awk '{print $6}')
        if [ -z "$broadcast_ref" ]; then
            delayed_error "Unable to retrieve a valid Broadcast address for interface '$interface' - Data Provided: $broadcast_ref" "$interface"
            broadcast_ref="N/A"
        else
            if ! validate_ip "$broadcast_ref"; then
                delayed_error "Retrieved Broadcast address '$broadcast_ref' is invalid for interface '$interface' - Data Provided: $broadcast_ref" "$interface"
                broadcast_ref="N/A"
            else
                delayed_error "Corrected Broadcast address for interface '$interface' to '$broadcast_ref'." "$interface"
            fi
        fi
    fi

    # Validate DNS Servers
    local idx
    for idx in "${!dns_ref[@]}"; do
        if [ "${dns_ref[$idx]}" != "N/A" ] && ! validate_ip "${dns_ref[$idx]}"; then
            delayed_error "Detected invalid DNS server '${dns_ref[$idx]}' on interface '$interface'. Attempting to retrieve correct DNS servers." "$interface"
            dns_ref=($(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' || echo "N/A"))
            if [ ${#dns_ref[@]} -eq 0 ]; then
                dns_ref=("N/A")
            else
                for dns in "${dns_ref[@]}"; do
                    if ! validate_ip "$dns"; then
                        dns_ref=("N/A")
                        break
                    fi
                done
            fi
            delayed_error "Corrected DNS servers for interface '$interface' to '${dns_ref[*]}'." "$interface"
            break
        fi
    done
}

# ---------------------------- Advanced Features ----------------------------

# Function to hash SMTP password in smtp_config.json
hash_smtp_password() {
    # This function can be expanded to include additional hashing mechanisms
    :
}

# ---------------------------- Entry Point ----------------------------

announce_settings() {
    log_event "INFO" "================ Settings Overview Start =================="
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "General Settings:"
    log_event "INFO" "Production mode enabled: $production_mode_enabled"
    log_event "INFO" "Fallback mode: $FALLBACK_MODE"
    log_event "INFO" "Check interval: $CHECK_INTERVAL seconds"
    log_event "INFO" "Ping address: $PING_ADDRESS"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Email and Backup:"
    log_event "INFO" "Email notifications: $ENABLE_EMAIL"
    log_event "INFO" "Backup functionality: $ENABLE_BACKUP"
    log_event "INFO" "Self-update functionality: $ENABLE_SELF_UPDATE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Logging:"
    log_event "INFO" "Log rotation: $ENABLE_LOG_ROTATION"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Hotspot:"
    log_event "INFO" "Hotspot: $ENABLE_HOTSPOT"
    log_event "INFO" "Hotspot SSID: $HOTSPOT_SSID"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Network Management:"
    log_event "INFO" "Connect on all adapters: $CONNECT_ON_ALL_ADAPTERS"
    log_event "INFO" "Bring up all devices: $BRING_UP_ALL_DEVICES"
    log_event "INFO" "Check dependencies: $CHECK_DEPENDENCIES"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Web Interface:"
    log_event "INFO" "Launch web interface: $LAUNCH_WEB_INTERFACE"
    log_event "INFO" "Web interface port: $WEB_INTERFACE_PORT"
    log_event "INFO" "Launch Python script: $LAUNCH_PYTHON_SCRIPT"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "VPN:"
    log_event "INFO" "Manage VPN: $MANAGE_VPN"
    log_event "INFO" "Enable VPN: $ENABLE_VPN"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Database:"
    log_event "INFO" "Initialize database: $INITIALIZE_DATABASE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "==================== File Locations ======================"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Log Files:"
    log_event "INFO" "Log directory: $LOG_DIR"
    log_event "INFO" "Log file: $LOG_FILE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Database Files:"
    log_event "INFO" "Database file: $DB_FILE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Settings and Configuration Files:"
    log_event "INFO" "Settings directory: $SETTINGS_DIR"
    log_event "INFO" "Backup directory: $BACKUP_DIR"
    log_event "INFO" "Interfaces file: $INTERFACES_FILE"
    log_event "INFO" "Email queue file: $EMAIL_QUEUE_FILE"
    log_event "INFO" "PID file: $PID_FILE"
    log_event "INFO" "Priority configuration file: $PRIORITY_CONFIG_FILE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Hotspot Files:"
    log_event "INFO" "Hotspot autostart file: $HOTSPOT_AUTOSTART_FILE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Adapter Files:"
    log_event "INFO" "Connect adapters autostart file: $CONNECT_ADAPTERS_AUTOSTART_FILE"
    log_event "INFO" "Bring up devices autostart file: $BRING_UP_DEVICES_AUTOSTART_FILE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "Web Interface Files:"
    log_event "INFO" "Web interface autostart file: $WEB_INTERFACE_AUTOSTART_FILE"
    log_event "INFO" "Web interface Python script: $PYTHON_SCRIPT"
    log_event "INFO" "Web interface log: $PYTHON_LOG"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "VPN Files:"
    log_event "INFO" "VPN autostart file: $VPN_AUTOSTART_FILE"
    log_event "INFO" "VPN configuration file: $VPN_CONFIG_FILE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "SMTP Files:"
    log_event "INFO" "SMTP configuration setup file: $SMTP_CONFIG_SETUP_FILE"
    log_event "INFO" "SMTP configuration file: $SMTP_CONFIG_FILE"
    log_event "INFO" "SMTP key file: $SMTP_KEY_FILE"
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "================== Settings Overview End =================="
}

# Start of the script
main() {
    log_event "INFO" "###########################################################"
    log_event "INFO" "         Starting set_ip_address.sh script."
    log_event "INFO" "###########################################################"

    # Move operation files to correct directories
    log_event "INFO" "###########################################################"
    log_event "INFO" "       Moving operation files to correct directories."
    log_event "INFO" "###########################################################"
    reload_files

    sleep 3
    # Ensure single instance and restart if needed
    #ensure_single_instance

    # Determine if production mode is enabled
    if [ "$production_mode_enabled" = true ]; then
        production_mode
        log_event "INFO" "###########################################################"
        log_event "INFO" "#                                                         #"
        log_event "INFO" "#                 Production Mode is Enabled              #"
        log_event "INFO" "#                                                         #"
        log_event "INFO" "###########################################################"
    else
        testing_mode
        log_event "INFO" "###########################################################"
        log_event "INFO" "#                                                         #"
        log_event "INFO" "#                   Testing Mode is Enabled               #"
        log_event "INFO" "#                                                         #"
        log_event "INFO" "###########################################################"
    fi

    # Announce NSATT settings
    announce_settings

    # Check for autostart file
    if [ ! -f "$AUTOSTART_FILE" ]; then
        log_event "WARNING" "Autostart file not found. Disabling non-critical functionalities."
        CHECK_DEPENDENCIES=true
        INITIALIZE_DATABASE=true
        ENABLE_HOTSPOT=false
        CONNECT_ON_ALL_ADAPTERS=false
        BRING_UP_ALL_DEVICES=false
        LAUNCH_WEB_INTERFACE=false
        MANAGE_VPN=false
    fi

    #check_and_create_services

    # Step 1: Check and install dependencies
    log_event "INFO" "Step 1: Checking and installing dependencies."
    check_and_install_dependencies

    # Step 2: Initialize database and create backup
    log_event "INFO" "Step 2: Initializing database and creating backup."
    initialize_database
    create_backup

    # Step 3: Restore from backup if needed
    log_event "INFO" "Step 3: Restoring from backup if needed."
    restore_backup_if_needed

    # Step 4: Setup SMTP configuration with encrypted password
    log_event "INFO" "Step 4: Setting up SMTP configuration with encrypted password."
    setup_smtp_config_encrypted

    # Step 5: Start monitoring network interfaces
    log_event "INFO" "Step 5: Starting to monitor network interfaces."
    monitor_interfaces
}
#test_eth0
#test_wlan0
#test_wlan1
main "$@"