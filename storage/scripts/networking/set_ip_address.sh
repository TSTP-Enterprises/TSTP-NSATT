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

debug_testing=false
debug_testing_show=false
debug_testing_checkpoint_tracer=false
announce_setting=false
RECON_MODE=false
SEND_LOGS=false

# Monitor Interface Settings
current_interface=""
expected_static_ip=""
base_ip=""
ip=""
subnet_mask=""
gateway=""
broadcast=""
dns_servers=()

# Check Interval Settings
CHECK_INTERVAL=60
CHECK_INTERVAL_FILE="/nsatt/settings/check_interval.txt"

# Email Interval Settings
EMAIL_INTERVAL=1000
EMAIL_INTERVAL_FILE="/nsatt/settings/email_interval.txt"

# Check if the email_interval.txt file exists
if [ -f "$EMAIL_INTERVAL_FILE" ]; then
    EMAIL_INTERVAL=$(<"$EMAIL_INTERVAL_FILE")
else
    echo "1000" > "$EMAIL_INTERVAL_FILE"
    EMAIL_INTERVAL=1000
fi

# Check if the check_interval.txt file exists
if [ -f "$CHECK_INTERVAL_FILE" ]; then
    # Read the value from the file
    CHECK_INTERVAL=$(<"$CHECK_INTERVAL_FILE")
else
    # Create the file and set the default value to 10
    echo "10" > "$CHECK_INTERVAL_FILE"
    CHECK_INTERVAL=60
fi
previous_state=""
currently_running=false
current_pass=0
total_passes=0
pass_checkpoint=0
interface=""
iface_info=()
saved_interfaces=""
current_state=""
changes_detected=false
current_interfaces=""
new_interfaces=""
updated_interfaces=""

prev_state=""
current_state=""
check_interval=10

force_set_ip=false
forced_ip="222"

# if file found, debug_testing=true
if [ -f "/nsatt/settings/debug_testing" ]; then
    debug_testing=true
fi

if [ -f "/nsatt/settings/debug_testing_show" ]; then
    debug_testing_show=true
fi

if [ -f "/nsatt/settings/debug_testing_checkpoint_tracer" ]; then
    debug_testing_checkpoint_tracer=true
fi

# if file found, force_set_ip=true
if [ -f "/nsatt/settings/force_set_ip" ]; then
    force_set_ip=true
    forced_ip=$(<"/nsatt/settings/forced_ip.txt")
fi

if [ -f "/nsatt/settings/recon_mode" ]; then
    RECON_MODE=true
fi

if [ -f "/nsatt/settings/send_logs" ]; then
    SEND_LOGS=true
fi

# if file found, announce_setting=true
if [ -f "/nsatt/settings/announce_setting" ]; then
    announce_setting=true
fi

# Directories and Files
BASE_DIR="/nsatt"
STORAGE_DIR="/nsatt/storage"
LOG_DIR="/nsatt/storage/logs"
SETTINGS_DIR="/nsatt/settings"
NETWORK_ADAPTERS_DIR="/nsatt/backups/network_adapters"
BACKUP_DIR="/nsatt/storage/backups"
SCRIPT_DIR="/nsatt/storage/scripts"
UTILITY_DIR="/nsatt/storage/scripts/utility"
RECOVERY_DIR="/nsatt/storage/scripts/recovery"
LOG_FILE="${LOG_DIR}/networking/set_ip_address.log"
DB_FILE="${LOG_DIR}/network_manager.db"
INTERFACES_FILE="/etc/network/interfaces"
EMAIL_QUEUE_FILE="${SETTINGS_DIR}/email_queue.txt"
PID_FILE="/var/run/network_manager.pid"

# Create if not found
[ ! -d "$STORAGE_DIR" ] && mkdir -p "$STORAGE_DIR"
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
[ ! -d "$LOG_DIR/networking" ] && mkdir -p "$LOG_DIR/networking"
[ ! -d "$SETTINGS_DIR" ] && mkdir -p "$SETTINGS_DIR"
[ ! -d "$NETWORK_ADAPTERS_DIR" ] && mkdir -p "$NETWORK_ADAPTERS_DIR"
[ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"
[ ! -d "$SCRIPT_DIR" ] && mkdir -p "$SCRIPT_DIR"
[ ! -d "$UTILITY_DIR" ] && mkdir -p "$UTILITY_DIR"
[ ! -d "$RECOVERY_DIR" ] && mkdir -p "$RECOVERY_DIR"

# Network Settings
PING_ADDRESS="8.8.8.8"
FALLBACK_MODE=true  # Initialize fallback_mode as true

if [[ "$debug_testing" = true ]]; then
    CHECK_INTERVAL=5
fi

# SMTP Configuration
SMTP_CONFIG_SETUP_FILE="${SETTINGS_DIR}/smtp_config_setup.json"
SMTP_CONFIG_FILE="${SETTINGS_DIR}/smtp_config.json"
SMTP_KEY_FILE="${SETTINGS_DIR}/smtp_key.key"
ENCRYPTED_SMTP_SETTINGS_FILE="${SETTINGS_DIR}/smtp_settings.enc"

# Priority List Configuration File
PRIORITY_CONFIG_FILE="${SETTINGS_DIR}/priority_list.conf"
PRIORITY_LIST="${SETTINGS_DIR}/priority_list_saved.json"
PRIORITY_LIST_FILE="${SETTINGS_DIR}/priority_list.txt"

# Hotspot Configuration
HOTSPOT_SSID="NSATT-NETWORK"
HOTSPOT_PASSWORD="ChangeMe!"

# Python Web Interface
LAUNCH_PYTHON_SCRIPT=true  # Set to false to disable launching the Python script
PYTHON_SCRIPT="/nsatt/storage/scripts/nsatt_web/network_manager_web_interface.py"
PYTHON_LOG="${LOG_DIR}/network_manager_web.log"
WEB_INTERFACE_PORT=8079

# VPN Configuration
ENABLE_VPN=true  # Set to false to disable VPN functionality
VPN_CONFIG_FILE="${SETTINGS_DIR}/vpn_config.ovpn"
VPN_AUTOSTART_FILE="${SETTINGS_DIR}/vpn_autostart"

# Feature Toggles (Set to false to disable specific features)
CHECK_DEPENDENCIES=false
INITIALIZE_DATABASE=true
ENABLE_HOTSPOT=true
CONNECT_ON_ALL_ADAPTERS=true
BRING_UP_ALL_DEVICES=true
LAUNCH_WEB_INTERFACE=false
MANAGE_VPN=true
WEB_INTERFACE_LAUNCHED=false

# Additional Feature Toggles
ENABLE_BACKUP=false
ENABLE_SELF_UPDATE=false
ENABLE_LOG_ROTATION=true

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

    # Allow all messages to be logged without blocking duplicates
    last_logged_message=""  # Reset the last logged message to allow all messages

    if [[ "$level" == "DEBUG" && "$DEBUG_MODE" == false ]]; then
        return 0
    fi

    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local date_only
    date_only=$(date "+%Y-%m-%d")
    local daily_log_file="${LOG_DIR}/networking/daily_log_${date_only}.log"

    local log_message
    if [[ -n "$context" ]]; then
        log_message="$timestamp - [$level] - $message ($context)"
    else
        log_message="$timestamp - [$level] - $message"
    fi

    # Log to main log file
    echo "$log_message" >> "$LOG_FILE"
    
    # Log to daily log file
    echo "$log_message" >> "$daily_log_file"

    # Also output to stdout
    echo "$log_message"
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
    local encrypted_file=""

    # Check for existing encrypted SMTP settings
    if [[ -f "/nsatt/settings/smtp_settings.enc" ]]; then
        encrypted_file="/nsatt/settings/smtp_settings.enc"
        log_event "INFO" "Found encrypted SMTP settings at /nsatt/settings/smtp_settings.enc"
    elif [[ -f "smtp_config.enc" ]]; then
        encrypted_file="smtp_config.enc"
        log_event "INFO" "Found encrypted SMTP settings at smtp_config.enc"
    else
        if [[ -f "/nsatt/settings/smtp_config.json" ]]; then
            log_event "INFO" "Creating encrypted SMTP settings file"
            if ! openssl enc -aes-256-cbc -salt -in "$SMTP_SETTINGS_FILE" -out "$ENCRYPTED_SMTP_SETTINGS_FILE"; then
                log_event "ERROR" "Failed to create encrypted SMTP settings file"
                return 1
            fi
            encrypted_file="$ENCRYPTED_SMTP_SETTINGS_FILE"
        fi
    fi

    # Verify we have an encrypted file to work with
    if [[ -z "$encrypted_file" ]]; then
        log_event "ERROR" "No SMTP settings file found (encrypted or JSON)"
        return 1
    fi

    # Read settings from JSON file
    local smtp_server=$(jq -r '.smtp_server' /nsatt/settings/smtp_config.json)
    local smtp_port=$(jq -r '.smtp_port' /nsatt/settings/smtp_config.json)
    local smtp_username=$(jq -r '.smtp_user' /nsatt/settings/smtp_config.json)
    local smtp_password=$(jq -r '.smtp_password_encrypted' /nsatt/settings/smtp_config.json)
    local recipient_email=$(jq -r '.recipient_email' /nsatt/settings/smtp_config.json)

    # Generate system information
    local hostname=$(uname -n)
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    local uptime=$(uptime -p)
    local logged_in_users=$(who | awk '{print $1}' | sort | uniq | tr '\n' ', ')
    local memory_usage=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    local disk_info=$(df -h | awk 'NR>1 {print $6 " (" $3 " / " $2 ")"}')
    local http_status=$(ss -tuln | grep ':80' &>/dev/null && echo "Active" || echo "Inactive")
    local nsatt_web_status=$(ss -tuln | grep ':8080' &>/dev/null && echo "Active" || echo "Inactive")
    local nsatt_launcher_status=$(ss -tuln | grep ':8081' &>/dev/null && echo "Active" || echo "Inactive")

    # Services to check
    local services=("apache2" "vsftpd" "tailscaled" "postgresql" "ssh" "NetworkManager" "networking" "hostapd" "bluetooth" "cron" "lightdm" "sendmail" "lldpd")
    local service_status=""
    for service in "${services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            service_status+="<li><strong>$service:</strong> Active</li>"
        else
            service_status+="<li><strong>$service:</strong> Inactive</li>"
        fi
    done

    # Network Information
    local adapters=($(ip -o link show | awk -F': ' '{print $2}'))
    local adapter_info=""
    for adapter in "${adapters[@]}"; do
        local ipv4=$(ip -4 addr show "$adapter" | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "Unavailable")
        local ipv6=$(ip -6 addr show "$adapter" | grep "inet6 " | awk '{print $2}' || echo "Unavailable")
        local wan_ip=$(curl -s http://api.ipify.org || echo "Unavailable")
        local dns=$(cat /etc/resolv.conf | grep 'nameserver' | awk '{print $2}' | tr '\n' ', ' || echo "Unavailable")
        local gateway=$(ip route | grep default | awk '{print $3}' || echo "Unavailable")
        local broadcast=$(ip -4 addr show "$adapter" | grep "brd" | awk '{print $4}' || echo "Unavailable")
        local subnet=$(ip -4 addr show "$adapter" | grep "inet " | awk '{print $2}' | cut -d/ -f2 || echo "Unavailable")
        local adapter_type=$(ip -o -f inet addr show "$adapter" | grep "vpn" &>/dev/null && echo "VPN" || echo "Standard")
        local can_ping=$(ping -c 3 -W 1 -I "$adapter" 8.8.8.8 &>/dev/null && echo "Yes" || echo "No")

        adapter_info+="<div style='margin-bottom: 20px; border: 1px solid #ddd; padding: 10px; border-radius: 5px;'>
            <p><strong>Adapter:</strong> $adapter</p>
            <p><strong>IPv4:</strong> ${ipv4:-Unavailable}</p>
            <p><strong>IPv6:</strong> ${ipv6:-Unavailable}</p>
            <p><strong>WAN IP:</strong> $wan_ip</p>
            <p><strong>DNS:</strong> $dns</p>
            <p><strong>Gateway:</strong> $gateway</p>
            <p><strong>Broadcast:</strong> $broadcast</p>
            <p><strong>Subnet:</strong> $subnet</p>
            <p><strong>Type:</strong> $adapter_type</p>
            <p><strong>Can Ping Google:</strong> $can_ping</p>
        </div>"
    done

    # Daily Logs (only if SEND_LOGS is true)
    local date_only=$(date "+%Y-%m-%d")
    local daily_log_file="${LOG_DIR}/networking/daily_log_${date_only}.log"
    local daily_logs=""
    if [[ "$SEND_LOGS" == true ]]; then
        daily_logs=$(cat "$daily_log_file" 2>/dev/null || echo "No log content available.")
    fi

    # Construct the HTML body
    local logs_section=""
    if [[ "$SEND_LOGS" == true ]]; then
        logs_section="<h2>Daily Logs</h2><pre>$daily_logs</pre>"
    fi

    local email_content=$(cat <<EOF
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; background-color: #f9f9f9; color: #333; padding: 0; margin: 0; }
        .container { max-width: 800px; margin: 20px auto; padding: 20px; background: #ffffff; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
        h1, h2 { color: #0056b3; }
        ul { list-style-type: none; padding: 0; }
        li { margin-bottom: 5px; }
        pre { background-color: #f4f4f4; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>NSATT System Status Report</h1>
        <h2>Host Information</h2>
        <p><strong>Hostname:</strong> $hostname</p>
        <p><strong>Date/Time:</strong> $datetime</p>
        <p><strong>Uptime:</strong> $uptime</p>
        <p><strong>Logged-in Users:</strong> $logged_in_users</p>

        <h2>System Information</h2>
        <p><strong>Memory Usage:</strong> $memory_usage</p>
        <p><strong>Disk Usage:</strong><br>$(echo "$disk_info" | sed ':a;N;$!ba;s/\n/<br>/g')</p>
        <p><strong>HTTP Status:</strong> $http_status</p>
        <p><strong>NSATT Web Status:</strong> $nsatt_web_status</p>
        <p><strong>NSATT Launcher Status:</strong> $nsatt_launcher_status</p>

        <h2>Services</h2>
        <ul>$service_status</ul>

        <h2>Network Information</h2>
        $adapter_info

        $logs_section
    </div>
</body>
</html>
EOF
    )

    # Python code to send the email
    python3 - <<EOF
# -*- coding: utf-8 -*-
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

smtp_server = "$smtp_server"
smtp_port = $smtp_port
smtp_username = "$smtp_username"
smtp_password = "$smtp_password"
recipient_email = "$recipient_email"

msg = MIMEMultipart("alternative")
msg["Subject"] = "NSATT System Status Report - $datetime"
msg["From"] = smtp_username
msg["To"] = recipient_email

plain_text = "NSATT System Status Report"
html_content = """$email_content"""

msg.attach(MIMEText(plain_text, "plain"))
msg.attach(MIMEText(html_content, "html"))

try:
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()
        server.login(smtp_username, smtp_password)
        server.sendmail(smtp_username, recipient_email, msg.as_string())
    print("Status report sent successfully.")
except Exception as e:
    print(f"Failed to send email: {e}")
EOF
}


# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              Example SMTP Configuration                      ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║ Configuration File (JSON format):                                            ║
# ║ {                                                                            ║
# ║     "smtp_server": "smtp.example.com",                                       ║
# ║     "smtp_port": "587",                                                      ║
# ║     "smtp_user": "user@example.com",                                         ║
# ║     "smtp_password_encrypted": "encrypted_password_here",                    ║
# ║     "recipient_email": "recipient@example.com"                               ║
# ║ }                                                                            ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║                              Function Details                                ║
# ║                                                                              ║
# ║ This function sends all queued emails using the SMTP configuration provided. ║
# ║ It checks for internet connectivity, loads the SMTP configuration, decrypts  ║
# ║ the password, and processes the email queue. If any step fails, it logs an   ║
# ║ error and returns.                                                           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

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

# Get gateway address for interface
get_gateway() {
    local interface="$1"
    local gateway

    # Try to get gateway from ip route
    gateway=$(ip route show dev "$interface" | grep default | awk '{print $3}' 2>/dev/null)

    # If no gateway found, try alternate method
    if [ -z "$gateway" ]; then
        gateway=$(ip route show | grep "default.*$interface" | awk '{print $3}' 2>/dev/null)
    fi

    # Return gateway or N/A if not found
    if [ -n "$gateway" ] && [[ "$gateway" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$gateway"
    else
        echo "N/A"
    fi
}

# Get DNS servers for interface
get_dns_servers() {
    local interface="$1"
    local dns_servers=()
    local resolv_conf="/etc/resolv.conf"

    # Check if resolv.conf exists and is readable
    if [ -r "$resolv_conf" ]; then
        # Extract nameserver entries
        while read -r line; do
            if [[ "$line" =~ ^nameserver[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                dns_servers+=("${BASH_REMATCH[1]}")
            fi
        done < "$resolv_conf"
    fi

    # If no DNS servers found, try systemd-resolved
    if [ ${#dns_servers[@]} -eq 0 ]; then
        if command -v resolvectl >/dev/null 2>&1; then
            while read -r line; do
                if [[ "$line" =~ ^DNS[[:space:]]+Server:[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                    dns_servers+=("${BASH_REMATCH[1]}")
                fi
            done < <(resolvectl status "$interface" 2>/dev/null)
        fi
    fi

    # Return DNS servers or N/A if none found
    if [ ${#dns_servers[@]} -gt 0 ]; then
        echo "${dns_servers[*]}"
    else
        echo "N/A"
    fi
}


# Convert CIDR to subnet mask
cidr_to_netmask() {
    local cidr="$1"
    local mask=""
    
    # Validate CIDR input is a number between 0-32
    if ! [[ "$cidr" =~ ^[0-9]+$ ]] || ((cidr < 0 || cidr > 32)); then
        echo "N/A"
        return 1
    fi

    # Calculate full octets and remaining bits
    local full_octets=$((cidr / 8))
    local remaining_bits=$((cidr % 8))

    # Build the subnet mask
    local octets=()
    
    # Add full 255 octets
    for ((i = 0; i < full_octets; i++)); do
        octets+=("255")
    done

    # Add partial octet if needed
    if ((remaining_bits > 0)); then
        local partial=$((256 - 2**(8 - remaining_bits)))
        octets+=("$partial")
    fi

    # Fill remaining octets with 0
    while ((${#octets[@]} < 4)); do
        octets+=("0")
    done

    # Join octets with dots
    echo "${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}"
}

get_ip() {
    local interface="$1"
    local ip=""
    local get_ip_debug="${GET_IP_DEBUG:-false}"  # Control for debug logging

    # Retrieve the first valid IPv4 address for the interface
    ip=$(ip -o -4 addr show "$interface" 2>/dev/null | awk '/inet / {print $4; exit}' | cut -d'/' -f1)

    # Debug log: raw output for the interface
    if [[ "$get_ip_debug" == true ]]; then
        local raw_output
        raw_output=$(ip -o -4 addr show "$interface" 2>/dev/null)
        log_event "DEBUG" "Raw IP output for interface '$interface': ${raw_output:-<none>}" "$interface"
    fi

    # Check if a valid IP was found
    if [[ -z "$ip" ]]; then
        [[ "$get_ip_debug" == true ]] && log_event "ERROR" "No IP address found for interface '$interface'." "$interface"
        return 1
    fi

    # Validate the IP format
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    else
        [[ "$get_ip_debug" == true ]] && log_event "ERROR" "Invalid IP format '$ip' for interface '$interface'." "$interface"
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

    sleep 4

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

# Function to update and manage the priority list of network interfaces
update_priority_list() {
    log_event "INFO" "Updating and managing priority list of network interfaces."

    # Create required directories if they don't exist
    [ ! -d "$SETTINGS_DIR" ] && mkdir -p "$SETTINGS_DIR"
    [ ! -d "$(dirname "$PRIORITY_LIST_FILE")" ] && mkdir -p "$(dirname "$PRIORITY_LIST_FILE")"
    [ ! -d "$(dirname "$PRIORITY_CONFIG_FILE")" ] && mkdir -p "$(dirname "$PRIORITY_CONFIG_FILE")"

    # Initialize arrays
    local custom_priorities=()
    local detected_interfaces=()
    local updated_priority_list=()

    # Check if a saved priority list exists
    if [ -f "$PRIORITY_LIST_FILE" ]; then
        log_event "INFO" "Loading saved priority list from $PRIORITY_LIST_FILE"
        mapfile -t PRIORITY_LIST < "$PRIORITY_LIST_FILE"
    else
        log_event "INFO" "No saved priority list found. Creating a new one."
        PRIORITY_LIST=()
        mkdir -p "$(dirname "$PRIORITY_LIST_FILE")" && touch "$PRIORITY_LIST_FILE"
    fi

    # Read custom priorities from configuration file if it exists
    if [ -f "$PRIORITY_CONFIG_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            # Ignore empty lines and comments
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            # Only add interfaces with 'eth' or 'wlan' in the name
            if [[ "$line" =~ ^(eth|wlan) ]]; then
                custom_priorities+=("$line")
            fi
        done < "$PRIORITY_CONFIG_FILE"
        log_event "DEBUG" "Custom priorities loaded: ${custom_priorities[*]}"
    else
        log_event "DEBUG" "Priority configuration file '$PRIORITY_CONFIG_FILE' not found. Creating empty file."
        mkdir -p "$(dirname "$PRIORITY_CONFIG_FILE")" && touch "$PRIORITY_CONFIG_FILE"
    fi

    # Detect all available network interfaces excluding loopback
    detected_interfaces=($(get_all_interfaces true))
    log_event "DEBUG" "Detected network interfaces: ${detected_interfaces[*]}"

    # Combine custom priorities, saved list, and detected interfaces
    for iface in "${custom_priorities[@]}" "${PRIORITY_LIST[@]}" "${detected_interfaces[@]}"; do
        if [[ " ${detected_interfaces[*]} " == *" $iface "* ]] && [[ ! " ${updated_priority_list[*]} " == *" $iface "* ]]; then
            updated_priority_list+=("$iface")
            log_event "DEBUG" "Added interface '$iface' to the priority list."
        fi
    done

    # Update PRIORITY_LIST with the new list
    PRIORITY_LIST=("${updated_priority_list[@]}")

    # Check for the directory and create it if it doesn't exist
    if [ ! -d "$(dirname "$PRIORITY_LIST_FILE")" ]; then
        sudo mkdir -p "$(dirname "$PRIORITY_LIST_FILE")"
    fi

    # Check for the file and create it if it doesn't exist
    if [ ! -f "$PRIORITY_LIST_FILE" ]; then
        sudo touch "$PRIORITY_LIST_FILE"
    fi

    # Save the updated priority list to file
    printf "%s\n" "${PRIORITY_LIST[@]}" | sudo tee "$PRIORITY_LIST_FILE" > /dev/null
    log_event "INFO" "Updated PRIORITY_LIST saved to $PRIORITY_LIST_FILE: ${PRIORITY_LIST[*]}"

    # Perform consistency checks and update priority based on network conditions
    update_priority_list_consistency
}

# Function to update priority list based on network consistency
update_priority_list_consistency() {
    log_event "INFO" "Updating priority list based on network consistency."

    local interfaces=("${PRIORITY_LIST[@]}")
    local consistent_interfaces=()
    local inconsistent_interfaces=()

    # First identify the actual hotspot interface from hostapd config
    local hotspot_interface=""
    if [ -f "/etc/hostapd/hostapd.conf" ]; then
        hotspot_interface=$(grep "^interface=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
        log_event "DEBUG" "Found hotspot interface from hostapd config: $hotspot_interface"
    fi

    # Check if hostapd is running
    if ! pgrep -x "hostapd" > /dev/null; then
        log_event "WARNING" "hostapd is not running. Skipping hotspot interface checks."
        hotspot_interface=""
    fi

    # Check for internet sharing interface (this is not the hotspot)
    local sharing_interface=""
    if sudo iptables -t nat -L POSTROUTING -v -n | grep -q "MASQUERADE"; then
        sharing_interface=$(sudo iptables -t nat -L POSTROUTING -v -n | grep "MASQUERADE" | awk '{print $7}')
        log_event "DEBUG" "Found internet sharing interface: $sharing_interface"
    fi

    for iface in "${interfaces[@]}"; do
        if ! ip link show "$iface" &> /dev/null; then
            log_event "WARNING" "Interface '$iface' not found. Removing from priority list."
            continue
        fi

        # Skip if ENABLE_HOTSPOT is true and the interface is the hotspot interface
        if [ "$ENABLE_HOTSPOT" = true ] && [ "$iface" = "$hotspot_interface" ]; then
            log_event "INFO" "Skipping hotspot interface '$iface'"
            continue
        fi

        # Check if interface is up and has an IP
        if ! ip link show "$iface" | grep -q "UP"; then
            log_event "WARNING" "Interface '$iface' is down. Marking as inconsistent."
            inconsistent_interfaces+=("$iface")
            continue
        fi

        local current_gateway
        current_gateway=$(ip route | grep "^default via" | grep "$iface" | awk '{print $3}')

        # Reset the interface to DHCP only if it is not responding to pings
        if [ "$iface" = "eth0" ] && ! ping -c 1 -W 1 8.8.8.8 &> /dev/null; then
            log_event "INFO" "Resetting interface '$iface' via DHCP as it is not responding to pings."
            reset_to_dhcp "$iface"
            sleep 15
        fi

        current_gateway=$(ip route | grep "^default via" | grep "$iface" | awk '{print $3}')

        if [ -z "$current_gateway" ]; then
            log_event "WARNING" "No gateway found for interface '$iface'. Marking as inconsistent."
            inconsistent_interfaces+=("$iface")

            # If the device is eth0 and has no gateway, reset to DHCP
            if [ "$iface" = "eth0" ]; then
                log_event "INFO" "Setting interface '$iface' to DHCP to check for a gateway."
                reset_to_dhcp "$iface"
                sleep 15  # Wait for DHCP to assign an IP
                current_gateway=$(ip route | grep "^default via" | grep "$iface" | awk '{print $3}')
                if [ -n "$current_gateway" ]; then
                    log_event "INFO" "Interface '$iface' obtained a gateway after DHCP."
                    consistent_interfaces+=("$iface")
                else
                    log_event "WARNING" "Interface '$iface' still has no gateway after DHCP."
                fi
            fi
        else
            # If this is the sharing interface, verify it's actually providing internet
            if [ "$iface" = "$sharing_interface" ]; then
                if check_internet "$iface" && ip route show | grep -q "^default.*$iface"; then
                    log_event "INFO" "Internet sharing interface '$iface' has connectivity. Marking as consistent."
                    consistent_interfaces+=("$iface")
                else
                    log_event "WARNING" "Internet sharing interface '$iface' lacks connectivity. Marking as inconsistent."
                    inconsistent_interfaces+=("$iface")
                fi
            else
                # Normal interface check
                if check_internet "$iface"; then
                    log_event "INFO" "Interface '$iface' has internet connectivity. Marking as consistent."
                    consistent_interfaces+=("$iface")
                else
                    log_event "WARNING" "Interface '$iface' lacks internet connectivity. Marking as inconsistent."
                    inconsistent_interfaces+=("$iface")
                    # If the device is eth0 and marked as inconsistent, check for force_set_ip
                    if [ "$iface" = "eth0" ] && [ "$force_set_ip" = true ]; then
                        log_event "INFO" "Attempting to reset interface '$iface' to DHCP."
                        reset_to_dhcp "$iface"
                        sleep 15  # Wait for DHCP to assign an IP

                        # Check if the interface has obtained an IP
                        local current_ip
                        current_ip=$(get_ip "$iface")

                        # Check if the current IP is valid before proceeding
                        if [[ "$current_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                            # Construct the new IP using the forced last octet
                            local new_ip="192.168.0.$forced_ip"

                            # Get the broadcast address from DHCP
                            local broadcast_ip
                            broadcast_ip=$(ip -o -f inet addr show "$iface" | awk '{print $4}' | cut -d'/' -f1)

                            # Remove any existing IP before adding the new one
                            ip addr flush dev "$iface" 2>/dev/null

                            # Attempt to set the new IP with error handling
                            if ip addr add "$new_ip/24 broadcast $broadcast_ip" dev "$iface" 2>/dev/null; then
                                log_event "INFO" "Interface '$iface' successfully set to IP $new_ip with broadcast $broadcast_ip."
                            else
                                log_event "ERROR" "Failed to assign IP $new_ip to interface '$iface'. Resetting to DHCP."
                                reset_to_dhcp "$iface"
                            fi

                            # Wait and then ping to ensure connectivity
                            sleep 5
                            if ! ping -c 1 -W 1 8.8.8.8 &> /dev/null; then
                                log_event "WARNING" "Interface '$iface' unable to reach Google after setting IP. Resetting to DHCP."
                                reset_to_dhcp "$iface"
                            fi
                        else
                            log_event "WARNING" "Current IP for interface '$iface' is not valid. Skipping IP assignment."
                        fi
                    fi
                fi
            fi
        fi
    done

    # Reorder PRIORITY_LIST based on consistency
    PRIORITY_LIST=("${consistent_interfaces[@]}" "${inconsistent_interfaces[@]}")

    # Ensure the directory exists
    sudo mkdir -p "$(dirname "$PRIORITY_LIST_FILE")"

    # Ensure the file exists
    if [ ! -f "$PRIORITY_LIST_FILE" ]; then
        sudo touch "$PRIORITY_LIST_FILE"
    fi

    # Save the updated priority list to file
    printf "%s\n" "${PRIORITY_LIST[@]}" | sudo tee "$PRIORITY_LIST_FILE" > /dev/null
    log_event "INFO" "Priority list updated based on network consistency: ${PRIORITY_LIST[*]}"
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
    local max_retries=2  # Maximum retries to obtain an IP
    local retry_interval=3  # Time to wait between retries in seconds
    local retry_count=0

    if [ "$interface" == "lo" ]; then
        log_event "INFO" "Skipping DHCP reset for loopback interface (lo)."
        return 0
    fi

    log_event "INFO" "Resetting interface $interface to DHCP."

    # Release current DHCP lease
    execute_command "sudo dhclient -r $interface" "Releasing DHCP lease on $interface" "$interface"
    sleep 2

    # Flush IP and bring the interface down and up
    execute_command "sudo ip addr flush dev $interface" "Flushing IP addresses on $interface" "$interface"
    sleep 2

    execute_command "sudo ip link set $interface down" "Bringing interface $interface down" "$interface"
    sleep 2

    execute_command "sudo ip link set $interface up" "Bringing interface $interface up" "$interface"
    sleep 2

    # Retry mechanism for obtaining a new IP
    while [ $retry_count -lt $max_retries ]; do
        log_event "INFO" "Attempting to obtain a DHCP lease on $interface (Attempt $((retry_count + 1)) of $max_retries)."

        # Request a new DHCP lease
        execute_command "sudo dhclient $interface" "Requesting new DHCP lease on $interface" "$interface"
        sleep $retry_interval

        # Check if a new IP has been assigned
        local new_ip
        new_ip=$(get_ip "$interface")
        if [ -n "$new_ip" ]; then
            log_event "INFO" "New IP assigned by DHCP: $new_ip on $interface."
            queue_email "Network Manager Info: DHCP Assigned" "Interface $interface obtained IP $new_ip via DHCP."
            return 0
        else
            log_event "WARNING" "No IP obtained on $interface via DHCP. Retrying..."
        fi

        retry_count=$((retry_count + 1))
    done

    # If all retries fail, log an error and optionally fallback to a static IP
    log_event "ERROR" "Failed to obtain a new IP via DHCP on $interface after $max_retries attempts."
    queue_email "Network Manager Error: DHCP Failure" "Interface $interface failed to obtain an IP via DHCP after $max_retries attempts."

    # Optional: Assign a fallback static IP
    if assign_fallback_static_ip "$interface"; then
        log_event "INFO" "Fallback static IP assigned to $interface."
    else
        log_event "CRITICAL" "Failed to assign fallback static IP to $interface."
    fi

    return 1
}

assign_fallback_static_ip() {
    local interface="$1"
    local fallback_ip="192.168.1.100"  # Replace with a suitable static IP
    local subnet_mask="255.255.255.0"
    local gateway="192.168.1.1"

    log_event "INFO" "Assigning fallback static IP $fallback_ip to $interface."
    execute_command "sudo ip addr add $fallback_ip/$subnet_mask dev $interface" "Assigning static IP to $interface" "$interface" &&
    execute_command "sudo ip route add default via $gateway dev $interface" "Setting gateway for $interface" "$interface"
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

# Function to display connection properties in a styled box
display_connection_properties() {
    local interface="$1"
    
    # Get current network settings
    local ip
    ip=$(ip -4 addr show dev "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    
    local subnet_mask
    subnet_mask=$(ip -4 addr show dev "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n1 | cut -d'/' -f2)
    if [[ -n "$subnet_mask" ]]; then
        # Convert CIDR to subnet mask
        local full_octets=$((subnet_mask/8))
        local partial_bits=$((subnet_mask%8))
        local mask=""
        
        for ((i=0; i<4; i++)); do
            if ((i < full_octets)); then
                mask+="255"
            elif ((i == full_octets)); then
                mask+="$((256 - 2**(8-partial_bits)))"
            else
                mask+="0"
            fi
            [[ $i < 3 ]] && mask+="."
        done
        subnet_mask="$mask"
    else
        subnet_mask="N/A"
    fi
    
    local gateway
    gateway=$(ip route show dev "$interface" 2>/dev/null | grep -oP '(?<=via\s)\d+(\.\d+){3}' | head -n1 || echo "N/A")
    
    local broadcast
    broadcast=$(ip -4 addr show dev "$interface" 2>/dev/null | grep -oP '(?<=brd\s)\d+(\.\d+){3}' | head -n1 || echo "N/A")
    
    local dns_servers
    mapfile -t dns_servers < <(grep -oP '(?<=nameserver\s)\d+(\.\d+){3}' /etc/resolv.conf 2>/dev/null || echo "N/A")
    
    # Print the network settings using the styled box function
    print_network_settings "$interface" "${ip:-N/A}" "$subnet_mask" "$gateway" "$broadcast" "${dns_servers[@]}"
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
    local debug_mode=false

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

    # Retrieve only eth and wlan interfaces
    local interfaces=($(get_all_interfaces true | grep -E "^(eth|wlan)[0-9]+$"))
    if [ ${#interfaces[@]} -eq 0 ]; then
        log_event "ERROR" "No eth/wlan interfaces found. Ensure that the system has active network interfaces."
        queue_email "Network Manager Error: No Interfaces Found" "No active eth/wlan interfaces detected on the system."
        return 1
    fi

    for iface in "${interfaces[@]}"; do
        # Exclude any interface that does not contain eth or wlan in the name
        if [[ ! "$iface" =~ ^(eth|wlan) ]]; then
            log_event "DEBUG" "Excluding interface '$iface' as it does not match eth or wlan pattern."
            continue
        fi

        # Check if the interface is used for hotspot
        if sudo iptables -t nat -C POSTROUTING -o "$iface" -j MASQUERADE &> /dev/null; then
            log_event "INFO" "Skipping interface '$iface' as it is used for hotspot."
            continue
        fi

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

        # Check if the interface is used for hotspot
        if sudo iptables -t nat -C POSTROUTING -o "$interface" -j MASQUERADE &> /dev/null; then
            log_event "INFO" "WLAN interface '$interface' is used for hotspot. Skipping all checks and actions."
            continue
        fi

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

            # Try connecting to known networks
            if try_connect_to_known_network "$interface"; then
                log_event "INFO" "Successfully connected interface '$interface' to a known network."
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

    # Get list of available WiFi networks
    local available_networks
    available_networks=$(sudo nmcli -t -f SSID device wifi list ifname "$interface" 2>/dev/null | sort -u)
    if [ -z "$available_networks" ]; then
        log_event "WARNING" "No WiFi networks detected in range of interface '$interface'."
        return 1
    fi

    local network_file
    local network_name
    local connection_success=false

    # Iterate over each network configuration file
    for network_file in "$known_networks_dir"/*.nmconnection; do
        if [ -f "$network_file" ]; then
            network_name=$(basename "$network_file" .nmconnection)
            
            # Check if this network is in range
            if echo "$available_networks" | grep -q "^${network_name}$"; then
                log_event "INFO" "Found known network '$network_name' in range. Attempting to connect."

                # Use nmcli to connect to the network with retries
                local max_attempts=3
                for attempt in $(seq 1 $max_attempts); do
                    log_event "INFO" "Attempt $attempt: Connecting to network '$network_name' on interface '$interface'."
                    
                    if execute_command "sudo nmcli device wifi connect '$network_name' ifname '$interface'" \
                        "Connecting interface '$interface' to network '$network_name'" "$interface"; then
                        log_event "INFO" "Successfully connected interface '$interface' to network '$network_name'."
                        connection_success=true
                        break 2
                    else
                        log_event "WARNING" "Failed to connect to network '$network_name' on attempt $attempt."
                        
                        if [ $attempt -lt $max_attempts ]; then
                            local retry_delay=$((attempt * 5))
                            log_event "INFO" "Retrying in $retry_delay seconds..."
                            sleep $retry_delay
                        fi
                    fi
                done
            else
                log_event "DEBUG" "Known network '$network_name' is not currently in range."
            fi
        fi
    done

    if [ "$connection_success" = true ]; then
        log_event "INFO" "Interface '$interface' successfully connected to a known network."
        return 0
    else
        log_event "ERROR" "Unable to connect interface '$interface' to any known networks in range."
        queue_email "Network Manager Error: Connection Failure" "Interface '$interface' failed to connect to any known networks in range. Manual intervention may be required."
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
        start_hotspot
        return 1
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
ExecStart=/nsatt/storage/scripts/networking/set_ip_address.sh
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
    DocumentRoot /nsatt/storage/web_interface/templates

    WSGIDaemonProcess web_interface threads=5 python-home=/nsatt/storage/web_interface/venv
    WSGIScriptAlias / /nsatt/storage/web_interface/network_manager.wsgi

    <Directory /nsatt/storage/web_interface>
        WSGIProcessGroup web_interface
        WSGIApplicationGroup %{GLOBAL}
        Require all granted
    </Directory>

    <Directory /nsatt/storage/web_interface/static>
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
    local wsgi_script="/nsatt/storage/web_interface/network_manager.wsgi"
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

# Function to gather interface information
gather_interface_info() {
    local iface="$1"
    local iface_info=()

    # Retrieve IP address, subnet mask, gateway, broadcast, and DNS servers
    iface_info+=("$(ip -4 addr show dev "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || echo "N/A")")
    iface_info+=("$(get_subnet_mask "$iface" || echo "N/A")")
    iface_info+=("$(ip route | awk "/^default via/ && /dev $iface/ {print \$3}" || echo "N/A")")
    iface_info+=("$(ip -o -4 addr show dev "$iface" | awk '{print $6}' || echo "N/A")")
    iface_info+=("$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | paste -sd "," - || echo "N/A")")

    echo "${iface_info[@]}"
}

monitor_interfaces() {
    # Initialize last logged message variable
    last_logged_message=""
    local settings_file="/nsatt/settings/saved_network_settings.json"

    if [[ "$currently_running" != true && "$debug_testing" = true ]]; then
        rm -f "$settings_file"
        rm -f "$PRIORITY_CONFIG_FILE"
        rm -f "$PRIORITY_LIST_FILE"
    fi

    # Ensure the settings file and directory exist
    mkdir -p "$(dirname "$settings_file")"
    if [[ ! -f "$settings_file" ]]; then
        echo '{"interfaces": []}' > "$settings_file"
    fi

    while true; do
        if [[ "$currently_running" != true ]]; then
            log_event "INFO" "=== Starting Interface Monitoring Cycle ===" ""
            log_event "INFO" "Gathering current network interfaces and their configurations." ""
            
            # Load saved interfaces from the settings file
            saved_interfaces=$(jq -r '.interfaces[]?' "$settings_file" | tr '\n' ' ')
            log_event "DEBUG" "Saved network interfaces: $saved_interfaces" ""
        fi

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.1" ""

        # Detect current interfaces
        current_interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -E "^(eth|wlan)" || echo "")
        #log_event "DEBUG" "Currently detected network interfaces: $current_interfaces" ""

        # Check for new interfaces
        changes_detected=false

        # Initialize new interfaces variable
        new_interfaces=""

        # Check for new interfaces
        for iface in $current_interfaces; do
            if [[ ! " $saved_interfaces " =~ " $iface " ]]; then
                log_event "INFO" "New interface detected: '$iface'" ""
                new_interfaces="$new_interfaces $iface"
                changes_detected=true
            fi
        done

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.2" ""

        # Update the saved interfaces list if changes are detected
        if [[ "$changes_detected" == true ]]; then
            # Merge saved and newly detected interfaces
            updated_interfaces=$(echo "$saved_interfaces $new_interfaces" | tr ' ' '\n' | sort -u | tr '\n' ' ')
            
            # Save the updated interfaces to the settings file
            echo '{"interfaces": [' > "$settings_file"
            for iface in $updated_interfaces; do
                echo "    \"$iface\"," >> "$settings_file"
            done
            sed -i '$ s/,$//' "$settings_file"  # Remove trailing comma
            echo ']}' >> "$settings_file"
            
            log_event "INFO" "Updated network interface list saved to settings file." ""
            saved_interfaces="$updated_interfaces"  # Update saved interfaces to reflect the new state
        fi

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.3" ""

        for iface in $interfaces; do
            # Validate interface name
            if [[ ! "$iface" =~ ^(eth|wlan)[0-9]+$ ]]; then
                log_event "ERROR" "Invalid interface name format: '$iface'. Skipping."
                continue
            fi

            # Verify interface still exists
            if ! ip link show "$iface" &>/dev/null; then
                log_event "WARNING" "Interface '$iface' no longer exists. Removing from monitoring."
                interfaces=${interfaces//$iface/}
                changes_detected=true
                continue
            fi

            # Check if the interface is being used for apache2/hotspot
            if iptables -t nat -L POSTROUTING -v -n | grep -q "$iface"; then
                # Hide if currently running
                [[ "$currently_running" != true ]] && log_event "INFO" "Interface '$iface' is currently used for apache2/hotspot. Checking connectivity without adjustments."
                
                # Perform a ping test to check connectivity
                if ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
                    log_event "ERROR" "Interface '$iface' cannot reach 8.8.8.8. Marking as down."
                    changes_detected=true
                fi
                continue
            fi

            # Gather interface information
            local iface_info
            iface_info=$(gather_interface_info "$iface")
            current_state+="$iface $iface_info "

            # Perform a ping test to check connectivity
            if ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
                log_event "ERROR" "Interface '$iface' cannot reach 8.8.8.8. Marking as down."
                changes_detected=true
            fi
        done
        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.4" ""

        current_pass=$((current_pass + 1))
        total_passes=$((total_passes + 1))
        pass_checkpoint=$((pass_checkpoint + 1))

        if [[ "$changes_detected" == true ]]; then
            log_event "INFO" "Changes detected in network interfaces or connectivity issues found. Processing changes."
            previous_state="$current_state"
            current_pass=0
        else
            [[ "$currently_running" != true ]] && log_event "INFO" "No changes detected in network interfaces. Sleeping for $CHECK_INTERVAL seconds."
            # Show current pass and total passes
            log_event "INFO" "Current pass: $current_pass, Total passes: $total_passes"

            # Ensure the interfaces variable is populated
            if [[ -z "$interfaces" ]]; then
                interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -E "^(eth|wlan)" || echo "")
            fi

            # Display interface properties at specific intervals
            if [[ "$debug_testing_show" = true && "$current_pass" -eq 1 || "$debug_testing" = true && "$current_pass" -eq 10 || "$debug_testing" != true && "$current_pass" -eq 50 ]]; then
                log_event "INFO" "Total passes reached $total_passes."

                if [[ -z "$interfaces" ]]; then
                    log_event "INFO" "No interfaces detected to display properties."
                else
                    for iface in $interfaces; do
                        local box_width=80
                        local title="=== Connection Properties for ${iface^^} ==="

                        # Calculate padding for centering
                        local title_len=${#title}
                        local left_padding=$(( (box_width - title_len - 4) / 2 ))
                        local right_padding=$(( box_width - title_len - 4 - left_padding ))

                        # Print top border
                        log_event "INFO" "$(printf "╔%*s╗" "$box_width" | tr " " "═")"

                        # Print centered title
                        log_event "INFO" "$(printf "║%*s%s%*s║" "$left_padding" "" "$title" "$right_padding" "")"

                        # Print separator
                        log_event "INFO" "$(printf "╠%*s╣" "$box_width" | tr " " "═")"

                        # Display interface IP address
                        local ip_info=$(ip addr show "$iface" | grep "inet " | awk '{print $2}')
                        if [[ -n "$ip_info" ]]; then
                            for ip in $ip_info; do
                                log_event "INFO" "$(printf "║ %-*s ║" $((box_width - 2)) "IP Address: $ip")"
                            done
                        else
                            log_event "INFO" "$(printf "║ %-*s ║" $((box_width - 2)) "No IP address found")"
                        fi

                        # Print interface status
                        log_event "INFO" "$(printf "╟%*s╢" "$box_width" | tr " " "─")"
                        if ip link show "$iface" | grep -q "state UP"; then
                            log_event "INFO" "$(printf "║ %-*s ║" $((box_width - 2)) "Status: INTERFACE IS UP")"
                        else
                            log_event "INFO" "$(printf "║ %-*s ║" $((box_width - 2)) "Status: INTERFACE IS DOWN")"
                        fi

                        # Print hotspot status
                        if iptables -t nat -L POSTROUTING -v -n | grep -q "$iface"; then
                            log_event "INFO" "$(printf "║ %-*s ║" $((box_width - 2)) "Hotspot: ACTIVE ON THIS INTERFACE")"
                        else
                            log_event "INFO" "$(printf "║ %-*s ║" $((box_width - 2)) "Hotspot: NOT ACTIVE")"
                        fi

                        # Print bottom border
                        log_event "INFO" "$(printf "╚%*s╝" "$box_width" | tr " " "═")"

                        # Reset current pass
                        current_pass=0
                    done
                fi
            fi

            if [[ "$pass_checkpoint" -eq "$EMAIL_INTERVAL" ]]; then
                log_event "INFO" "Pass checkpoint reached: $pass_checkpoint.  Sending queued emails." ""
                send_queued_emails
                pass_checkpoint=0
            fi

            sleep "$CHECK_INTERVAL"
            currently_running=true
            continue
        fi

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.5" ""

        for iface in $interfaces; do
            # Wrap entire loop in error handling
            {
                # Validate interface name
                if [[ ! "$iface" =~ ^(eth|wlan)[0-9]+$ ]]; then
                    log_event "ERROR" "Invalid interface name format: '$iface'. Skipping."
                    continue
                fi

                # Calculate box width with error checking
                local box_width=70
                if [[ ! "$box_width" =~ ^[0-9]+$ ]] || [ "$box_width" -lt 40 ]; then
                    log_event "ERROR" "Invalid box width: $box_width. Using default 70."
                    box_width=70
                fi

                local title="Interface Status: $iface"
                local title_padding=0
                local title_extra=0

                # Safely calculate padding with error checking
                if ! title_padding=$(( (box_width - ${#title} - 2) / 2 )); then
                    log_event "ERROR" "Failed to calculate title padding for $iface. Using 0."
                    title_padding=0
                fi

                if ! title_extra=$(( (box_width - ${#title} - 2) % 2 )); then
                    log_event "ERROR" "Failed to calculate title extra for $iface. Using 0."
                    title_extra=0
                fi

                # Print box with error handling
                if ! printf "╔%s╗\n" "$(printf '═%.0s' $(seq 1 $box_width))" 2>/dev/null; then
                    log_event "ERROR" "Failed to print top border for $iface"
                fi

                # Calculate padding with validation
                local total_padding=0
                local left_padding=0
                local right_padding=0

                if ! total_padding=$(( box_width - ${#title} - 2 )); then
                    log_event "ERROR" "Failed to calculate total padding for $iface. Using defaults."
                    total_padding=2
                fi

                if ! left_padding=$(( total_padding / 2 )); then
                    log_event "ERROR" "Failed to calculate left padding for $iface. Using 1."
                    left_padding=1
                fi

                if ! right_padding=$(( total_padding - left_padding )); then
                    log_event "ERROR" "Failed to calculate right padding for $iface. Using 1."
                    right_padding=1
                fi

                # Print title with error handling
                if ! printf "║%s%s%s║\n" "$(printf ' %.0s' $(seq 1 $left_padding))" "$title" "$(printf ' %.0s' $(seq 1 $right_padding))" 2>/dev/null; then
                    log_event "ERROR" "Failed to print title for $iface"
                fi

                if ! printf "╠%s╣\n" "$(printf '═%.0s' $(seq 1 $box_width))" 2>/dev/null; then
                    log_event "ERROR" "Failed to print separator for $iface"
                fi

                # Get interface status with error handling
                local iface_status="UNKNOWN"
                local iface_speed="UNKNOWN" 
                local iface_duplex="UNKNOWN"

                if ! ip link show "$iface" &>/dev/null; then
                    log_event "ERROR" "Failed to get link status for $iface"
                else
                    if ip link show "$iface" | grep -q "UP"; then
                        iface_status="UP"
                        # Safely get speed and duplex
                        if ! iface_speed=$(ethtool "$iface" 2>/dev/null | grep "Speed:" | awk '{print $2}'); then
                            iface_speed="Unknown"
                            log_event "WARNING" "Failed to get speed for $iface"
                        fi
                        if ! iface_duplex=$(ethtool "$iface" 2>/dev/null | grep "Duplex:" | awk '{print $2}'); then
                            iface_duplex="Unknown"
                            log_event "WARNING" "Failed to get duplex for $iface"
                        fi
                    else
                        iface_status="DOWN"
                        iface_speed="N/A"
                        iface_duplex="N/A"
                    fi
                fi

                # Get IP info with error handling
                local iface_ip=""
                if ! iface_ip=$(ip -4 addr show dev "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1); then
                    log_event "WARNING" "Failed to get IP for $iface"
                    iface_ip=""
                fi

                if [[ -n "$iface_ip" ]]; then
                    # Get subnet with error handling
                    local iface_subnet
                    if ! iface_subnet=$(get_subnet_mask "$iface"); then
                        log_event "WARNING" "Failed to get subnet mask using get_subnet_mask for $iface"
                        # Fallback method
                        local cidr
                        if ! cidr=$(ip -o -4 addr show dev "$iface" | awk '{print $4}' | cut -d'/' -f2); then
                            log_event "ERROR" "Failed to get CIDR for $iface"
                            iface_subnet="N/A"
                        else
                            if ! iface_subnet=$(cidr_to_netmask "$cidr"); then
                                log_event "ERROR" "Failed to convert CIDR to netmask for $iface"
                                iface_subnet="N/A"
                            fi
                        fi
                    fi

                    # Validate subnet mask
                    if [[ ! "$iface_subnet" =~ ^(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)$ ]]; then
                        log_event "WARNING" "Invalid subnet mask format for $iface: $iface_subnet"
                        iface_subnet="N/A"
                    fi

                    # Get gateway with error handling
                    local iface_gateway
                    if ! iface_gateway=$(ip route | awk "/^default via/ && /dev $iface/ {print \$3}"); then
                        log_event "WARNING" "Failed to get gateway for $iface"
                        iface_gateway="N/A"
                    fi
                    [[ -z "$iface_gateway" ]] && iface_gateway="N/A"

                    # Get broadcast with error handling
                    local iface_broadcast
                    if ! iface_broadcast=$(ip -o -4 addr show dev "$iface" | awk '{print $6}'); then
                        log_event "WARNING" "Failed to get broadcast for $iface"
                        iface_broadcast="N/A"
                    fi
                    [[ -z "$iface_broadcast" ]] && iface_broadcast="N/A"

                    # Get DNS with error handling
                    local iface_dns
                    if ! iface_dns=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | paste -sd "," -); then
                        log_event "WARNING" "Failed to get DNS servers for $iface"
                        iface_dns="N/A"
                    fi
                    [[ -z "$iface_dns" ]] && iface_dns="N/A"

                    # Get MAC with error handling
                    local mac_address
                    if ! mac_address=$(ip link show "$iface" | awk '/ether/ {print $2}'); then
                        log_event "WARNING" "Failed to get MAC address for $iface"
                        mac_address="N/A"
                    fi

                    # Print line function with error handling
                    print_line() {
                        local label="$1"
                        local value="$2"
                        local line="$label : $value"
                        local padding=0
                        
                        if ! padding=$(( box_width - ${#line} - 2 )); then
                            log_event "ERROR" "Failed to calculate padding for line: $label"
                            padding=1
                        fi

                        if ! printf "║ %s%s║\n" "$line" "$(printf ' %.0s' $(seq 1 $padding))" 2>/dev/null; then
                            log_event "ERROR" "Failed to print line: $label"
                            return 1
                        fi
                        return 0
                    }

                    # Print all info with error checking
                    print_line "Status" "$iface_status" || log_event "ERROR" "Failed to print status line"
                    print_line "Speed" "$iface_speed" || log_event "ERROR" "Failed to print speed line"
                    print_line "Duplex" "$iface_duplex" || log_event "ERROR" "Failed to print duplex line"
                    print_line "MAC Address" "$mac_address" || log_event "ERROR" "Failed to print MAC line"

                    if ! printf "╠%s╣\n" "$(printf '═%.0s' $(seq 1 $box_width))" 2>/dev/null; then
                        log_event "ERROR" "Failed to print separator"
                    fi

                    print_line "IP Address" "$iface_ip" || log_event "ERROR" "Failed to print IP line"
                    print_line "Subnet Mask" "$iface_subnet" || log_event "ERROR" "Failed to print subnet line"
                    print_line "Gateway" "$iface_gateway" || log_event "ERROR" "Failed to print gateway line"
                    print_line "Broadcast" "$iface_broadcast" || log_event "ERROR" "Failed to print broadcast line"
                    print_line "DNS Servers" "$iface_dns" || log_event "ERROR" "Failed to print DNS line"

                    # Assign variables with validation
                    ip="$iface_ip"
                    subnet_mask="$iface_subnet"
                    gateway="$iface_gateway"
                    broadcast="$iface_broadcast"
                    
                    # Safely convert DNS string to array
                    if ! dns_servers=($(echo "$iface_dns" | tr ',' ' ')); then
                        log_event "ERROR" "Failed to convert DNS servers to array for $iface"
                        dns_servers=("N/A")
                    fi

                    # Validate network info
                    if ! validate_and_correct_network_info "$iface" ip subnet_mask gateway broadcast dns_servers; then
                        log_event "ERROR" "Network info validation failed for $iface"
                    fi

                    # Print compatibility format with error handling
                    if ! printf "%-12s %-15s %-15s %-15s %-10s %-25s\n" \
                        "$iface" "${iface_info[0]}" "${iface_info[1]}" "${iface_info[2]}" "${iface_info[3]}" "${iface_info[4]}" 2>/dev/null; then
                        log_event "ERROR" "Failed to print compatibility format for $iface"
                    fi
                else
                    # Handle interfaces without IP
                    ip="N/A"
                    subnet_mask="N/A"
                    gateway="N/A"
                    dns_servers=("N/A")

                    print_line "Status" "$iface_status" || log_event "ERROR" "Failed to print status line"
                    print_line "Message" "Interface is down or has no IP configuration" || log_event "ERROR" "Failed to print message line"

                    if ! printf "%-12s %-15s %-15s %-15s %-10s %-25s\n" \
                        "$iface" "$ip" "$subnet_mask" "$gateway" "$iface_status" "N/A" 2>/dev/null; then
                        log_event "ERROR" "Failed to print compatibility format for down interface $iface"
                    fi
                fi

                # Print bottom border
                if ! printf "╚%s╝\n" "$(printf '═%.0s' $(seq 1 $box_width))" 2>/dev/null; then
                    log_event "ERROR" "Failed to print bottom border for $iface"
                fi

                echo ""  # Add blank line
                sleep 1

            } || {
                # Catch any unexpected errors in the loop
                log_event "ERROR" "Unexpected error processing interface $iface. Error: $?"
                continue
            }
        done

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.6" ""

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

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.7" ""

        # Select the best available interface, excluding 'lo'
        log_event "INFO" "Selecting the best available network interface based on priority." ""
        interface=$(select_and_test_interface | grep -E "^(eth|wlan)")
        if [ -n "$interface" ]; then
            log_event "DEBUG" "Selected interface: $interface" ""
        else
            log_event "ERROR" "No valid network interface found. Retrying in $CHECK_INTERVAL seconds." ""
            sleep "$CHECK_INTERVAL"
            continue
        fi

        # Handle interface change - only process eth or wlan interfaces
        if [[ ! "$interface" =~ ^(eth|wlan) ]]; then
            log_event "DEBUG" "Skipping non-ethernet/wireless interface: $interface"
            continue
        fi

        # Define the network info file path
        NETWORK_INFO_FILE="/nsatt/storage/settings/network_info.json"

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.8" ""

        # Function to save network information
        save_network_info() {
            local iface="$1"
            local ip="$2"
            local subnet_mask="$3"
            local gateway="$4"
            local dns_servers="$5"

            jq -n \
                --arg iface "$iface" \
                --arg ip "$ip" \
                --arg subnet_mask "$subnet_mask" \
                --arg gateway "$gateway" \
                --arg dns_servers "$dns_servers" \
                '{interface: $iface, ip: $ip, subnet_mask: $subnet_mask, gateway: $gateway, dns_servers: $dns_servers}' > "$NETWORK_INFO_FILE"
        }

        # Function to load network information
        load_network_info() {
            if [ -f "$NETWORK_INFO_FILE" ]; then
                jq '.' "$NETWORK_INFO_FILE"
            else
                echo '{}'
            fi
        }

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 0.9" ""

        # Function to check ping connectivity
        check_ping_connectivity() {
            local iface="$1"
            local gateway="$2"
            local ping_count=3
            local ping_timeout=2

            # Try pinging the gateway first
            if [ -n "$gateway" ] && [ "$gateway" != "N/A" ]; then
                if ! ping -I "$iface" -c "$ping_count" -W "$ping_timeout" "$gateway" >/dev/null 2>&1; then
                    log_event "WARNING" "Interface $iface failed to ping gateway $gateway" ""
                    return 1
                fi
            fi

            # Try pinging a reliable external host (Google DNS)
            if ! ping -I "$iface" -c "$ping_count" -W "$ping_timeout" 8.8.8.8 >/dev/null 2>&1; then
                log_event "WARNING" "Interface $iface failed to ping external host" ""
                return 1
            fi

            return 0
        }

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 1" ""

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 2" ""

        if [ "$currently_running" = false ] && [ "$interface" != "$current_interface" ]; then
            log_event "INFO" "Detected interface change. Switching active interface to '$interface'." ""

            if [[ -n "$current_interface" && "$current_interface" =~ ^(eth|wlan) ]]; then
                log_event "INFO" "Bringing down previous interface: '$current_interface'." ""
                if ! execute_command "sudo ip link set $current_interface down" "Bringing down interface $current_interface" ""; then
                    log_event "ERROR" "Failed to bring down interface '$current_interface'. Continuing with '$interface'." ""
                else
                    log_event "DEBUG" "Successfully brought down interface '$current_interface'." ""
                fi
                sleep 2  # Delay to ensure interface is down
            fi

            current_interface="$interface"
            log_event "DEBUG" "Set current_interface to '$current_interface'." ""

            # Configure static IP if BRING_UP_ALL_DEVICES is true
            if [ "$BRING_UP_ALL_DEVICES" = true ]; then
                log_event "INFO" "BRING_UP_ALL_DEVICES is true. Configuring static IP for all interfaces." ""
                # Check if all interfaces are up and can ping
                for iface in "${!iface_info[@]}"; do
                    if [[ "$iface" == eth* || "$iface" == wlan* ]]; then
                        if ip link show "$iface" | grep -q "UP"; then
                            if ! ping -c 1 -W 1 "$PING_ADDRESS" &> /dev/null; then
                                log_event "WARNING" "Interface '$iface' is up but cannot ping $PING_ADDRESS. Resetting to DHCP."
                                reset_to_dhcp "$iface"
                                sleep 15  # Wait for DHCP to assign an IP
                            else
                                log_event "INFO" "Interface '$iface' is up and can ping $PING_ADDRESS."
                            fi
                        else
                            log_event "WARNING" "Interface '$iface' is down. Skipping configuration."
                        fi
                    fi
                done

                # Attempt to set the forced IP if eth0 is active
                if [ "$force_set_ip" = true ]; then
                    log_event "INFO" "force_set_ip is true. Attempting to set the last octet if eth0 is active." ""

                    local current_ip
                    current_ip=$(get_ip "eth0")
                    log_event "DEBUG" "Current IP for 'eth0': ${current_ip:-<none>}" ""

                    if [[ "$current_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        if [[ "$current_ip" == *"$forced_ip" ]]; then
                            log_event "INFO" "Current IP for 'eth0' matches the forced IP ($forced_ip). Skipping assignment."
                        else
                            local base_ip="${current_ip%.*}"
                            local desired_ip="${base_ip}.${forced_ip}"

                            if ip link show "eth0" | grep -q "UP"; then
                                log_event "INFO" "Attempting to set interface 'eth0' to the forced IP ($desired_ip)."

                                # Retrieve the broadcast address for the current IP before flushing
                                local ip_output
                                ip_output=$(ip -o -f inet addr show eth0)
                                log_event "DEBUG" "Raw output from 'ip addr show eth0': $ip_output"

                                # Extract the broadcast address
                                local broadcast_ip
                                broadcast_ip=$(echo "$ip_output" | awk '/inet / {print $6}' | head -n 1)  # Use only the first match

                                log_event "DEBUG" "Retrieved broadcast address for 'eth0' BEFORE flush: ${broadcast_ip:-<none>}"

                                # Validate the retrieved broadcast address
                                if [[ "$broadcast_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                    # Flush the IPs and set the desired IP with the broadcast
                                    ip addr flush dev "eth0" 2>/dev/null
                                    if execute_command "sudo ip addr add ${desired_ip}/24 broadcast ${broadcast_ip} dev eth0" "Setting IP address for eth0" ""; then
                                        log_event "INFO" "Assigned IP '$desired_ip' with broadcast '$broadcast_ip' to 'eth0'."
                                    else
                                        log_event "ERROR" "Failed to assign IP $desired_ip to interface 'eth0'."
                                    fi
                                else
                                    log_event "ERROR" "Invalid broadcast address retrieved for 'eth0'. Resetting to DHCP."
                                    reset_to_dhcp "eth0"
                                fi

                                # Verify connectivity after setting the IP
                                sleep 5
                                if ! ping -c 1 -W 1 "$PING_ADDRESS" &>/dev/null; then
                                    log_event "WARNING" "Interface 'eth0' unable to reach $PING_ADDRESS after setting IP. Resetting to DHCP."
                                    reset_to_dhcp "eth0"
                                fi
                            else
                                log_event "ERROR" "Interface 'eth0' is not active. Skipping IP assignment."
                            fi
                        fi
                    else
                        log_event "ERROR" "Current IP for 'eth0' is not valid. Skipping IP assignment."
                    fi
                fi

                    # Attempt to set the forced IP on other available interfaces if eth0 fails
                    for next_iface in "${!iface_info[@]}"; do
                        if [[ "$next_iface" != "eth0" && ( "$next_iface" == eth* || "$next_iface" == wlan* ) ]]; then
                            log_event "INFO" "Attempting to set the forced IP on interface '$next_iface'." ""
                            local next_current_ip
                            next_current_ip=$(get_ip "$next_iface")
                            if [[ "$next_current_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                local next_base_ip="${next_current_ip%.*}"
                                local next_desired_ip="${next_base_ip}.${forced_ip}"
                                local next_ip_output
                                next_ip_output=$(ip -o -f inet addr show "$next_iface")

                                log_event "DEBUG" "Interface: $next_iface, Current IP: $next_current_ip"
                                log_event "DEBUG" "Raw IP output for $next_iface: $next_ip_output"

                                local next_broadcast_ip
                                next_broadcast_ip=$(echo "$next_ip_output" | awk '/inet / {print $6}')

                                log_event "DEBUG" "Broadcast for '$next_iface': ${next_broadcast_ip:-<none>}"

                                if ip link show "$next_iface" | grep -q "UP"; then
                                    log_event "INFO" "Attempting to set interface '$next_iface' to the forced IP ($next_desired_ip)."
                                    ip addr flush dev "$next_iface" 2>/dev/null

                                    if [[ "$next_broadcast_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                        if execute_command "sudo ip addr add ${next_desired_ip}/24 broadcast ${next_broadcast_ip} dev $next_iface" "Setting IP address for $next_iface" ""; then
                                            log_event "INFO" "Assigned IP '$next_desired_ip' with broadcast '$next_broadcast_ip' to '$next_iface'."
                                            break
                                        else
                                            log_event "ERROR" "Failed to assign IP $next_desired_ip to interface '$next_iface'."
                                        fi
                                    else
                                        log_event "ERROR" "Invalid broadcast address for interface '$next_iface'."
                                    fi
                                else
                                    log_event "ERROR" "Interface '$next_iface' is not active. Skipping IP assignment."
                                fi
                            else
                                log_event "ERROR" "Current IP for '$next_iface' is not valid. Skipping IP assignment."
                            fi
                        fi
                    log_event "INFO" "Finished attempting to set the forced IP on interface '$next_iface'." ""
                done
            fi
        fi

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 3" ""
        
        # Reapply static IP if it changes unexpectedly (only for eth/wlan interfaces)
        if [[ "$BRING_UP_ALL_DEVICES" = true && -n "$expected_static_ip" && -n "$current_interface" && "$current_interface" =~ ^(eth|wlan) ]]; then
            log_event "DEBUG" "Verifying current IP for '$current_interface' against expected static IP '$expected_static_ip'." ""
            local current_ip
            current_ip=$(get_ip "$current_interface" 2>/dev/null || echo "")
            log_event "DEBUG" "Current IP for '$current_interface': '${current_ip:-N/A}', Expected IP: '$expected_static_ip'." ""

            if [ "$current_ip" != "$expected_static_ip" ]; then
                log_event "WARNING" "IP for '$current_interface' has changed unexpectedly (Current: '$current_ip', Expected: '$expected_static_ip'). Reapplying static IP." ""

                if update_interfaces_file "$current_interface" "$expected_static_ip" "$subnet_mask" "$gateway" "$broadcast" "${dns_servers[@]}"; then
                    log_event "INFO" "Successfully updated interfaces file for '$current_interface' with static IP '$expected_static_ip'." ""

                    if execute_command "sudo systemctl restart networking" "Restarting networking service for '$current_interface'" ""; then
                        log_event "INFO" "Reapplied static IP '$expected_static_ip' to '$current_interface'." ""
                        sleep 5  # Delay to allow networking service to restart
                    else
                        log_event "ERROR" "Failed to restart networking service after reapplying static IP to '$current_interface'." ""
                    fi
                else
                    log_event "ERROR" "Failed to update interfaces file while reapplying static IP for '$current_interface'." ""
                fi
            else
                log_event "INFO" "IP for '$current_interface' matches expected static IP '$expected_static_ip'." ""
            fi
        fi

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 5" ""

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

        if [ "$LAUNCH_WEB_INTERFACE" = true ] && [ "$WEB_INTERFACE_LAUNCHED" = false ]; then
            if ! netstat -tuln | grep -q ":8079 "; then
                log_event "INFO" "Launching Python web interface on port 8079." ""
                launch_python_script || log_event "ERROR" "Failed to launch Python web interface."
            else
                log_event "INFO" "Python web interface already running on port 8079."
            fi
            WEB_INTERFACE_LAUNCHED=true
        fi

        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 6" ""

        log_event "DEBUG" "Monitor Interfaces Completed" ""
        # Send any queued emails before sleeping
        if [ "$ENABLE_EMAIL" = true ]; then
            send_queued_emails
            #log_event "INFO" "Emails currently disabled" ""
        fi

        # Delay before next check
        log_event "DEBUG" "Sleeping for 15 seconds before next check." ""
        sleep 15
        #monitor_changes
        log_event "DEBUG" "Loop iteration complete. Restarting monitoring cycle." ""
        display_errors
        [[ "$debug_testing_checkpoint_tracer" == true ]] && log_event "WARNING" "DEBUG Checkpoint 7" ""
        currently_running=true
        log_event "INFO" "Currently running: $currently_running" ""

        done

        # Connectivity checks and fallback
        if [ "$CONNECT_ON_ALL_ADAPTERS" = true ]; then
            log_event "INFO" "Checking connectivity status for all interfaces." ""
            activate_wlan_adapters_if_needed

            if check_all_interfaces_status; then
                log_event "INFO" "All interfaces are up and running with proper connectivity." ""
            else
                log_event "WARNING" "One or more interfaces are down or lack connectivity. Initiating fallback procedures." ""
                # Implement additional fallback logic here if needed
                sleep 2  # Delay before proceeding
            fi

            # Display adapters and their information
            log_event "INFO" "Displaying information for all network adapters." ""
            local interfaces
            interfaces=($(get_all_interfaces true | grep -E "^(eth|wlan)[0-9]+$"))

            # Check if the interfaces array is empty
            if [ ${#interfaces[@]} -eq 0 ]; then
                log_event "WARNING" "No network interfaces detected." ""
            else
                for iface in "${interfaces[@]}"; do
                    if ip link show "$iface" &> /dev/null; then
                        local mac_address
                        local ip_address
                        local status

                        # Retrieve MAC address
                        mac_address=$(ip link show "$iface" | awk '/ether/ {print $2}')

                        # Retrieve IP address (empty if none is assigned)
                        ip_address=$(get_ip "$iface")

                        # Determine the interface status
                        if ip link show "$iface" | grep -qw "UP"; then
                            status="up"
                        else
                            status="down"
                        fi

                        # Log the interface details
                        log_event "INFO" "Interface '$iface' status: $status, MAC: $mac_address, IP: ${ip_address:-N/A}" ""
                    else
                        log_event "ERROR" "Failed to retrieve status for interface '$iface'. The interface might not exist or is not accessible." "$iface"
                    fi
                done
            fi
        fi
    currently_running=true
}

# Monitor network changes and trigger main monitoring function when needed
monitor_changes() {
    
    log_event "INFO" "Starting network change monitor..." ""

    trap 'exit 0' SIGTERM SIGINT

    while true; do
        current_state=$(ip -o addr show | awk '{print $2, $3, $4}' | sort | tr '\n' ' ')

        if [[ "$current_state" != "$prev_state" ]]; then
            log_event "INFO" "Network change detected - starting monitoring cycle" ""
            monitor_interfaces & # Run monitoring asynchronously
            prev_state="$current_state"
        fi

        sleep 20
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
        log_event "INFO" "No errors to display." ""
    else
        log_event "INFO" "Displaying all queued errors:" ""
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
    
    log_event "INFO" "-----------------------------------------------------------"
    log_event "INFO" "================== Settings Overview End =================="
}

# Start of the script
main() {
    
    log_event "INFO" "###########################################################"
    log_event "INFO" "         Starting set_ip_address.sh script."
    log_event "INFO" "###########################################################"

    log_event "INFO" "Check interval: $CHECK_INTERVAL"

    # Ensure single instance and restart if needed
    #ensure_single_instance

    # Announce NSATT settings
    if [ "$announce_setting" = true ]; then
        announce_settings
    fi

    # Step 2: Initialize database and create backup
    log_event "INFO" "Initializing database and creating backup."
    initialize_database

    # Step 4: Start monitoring network interfaces
    log_event "INFO" "Starting to monitor network interfaces."
    monitor_interfaces
}
#test_eth0
#test_wlan0
#test_wlan1
main "$@"