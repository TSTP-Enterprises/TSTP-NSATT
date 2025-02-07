#!/bin/bash


########################################################
# Automatic Mode
########################################################

automatic_mode=false
automatic_mode_file="/nsatt/settings/automatic_mode.nsatt"

if [ -f "$automatic_mode_file" ]; then
    automatic_mode=true
fi

full_email_mode=false
full_email_mode_file="/nsatt/settings/full_email_mode.nsatt"

if [ -f "$full_email_mode_file" ]; then
    full_email_mode=true
fi

########################################################
# Program paths
########################################################

BASE_DIR="/nsatt"
STORAGE_DIR="/nsatt/storage"
LOG_DIR="/nsatt/storage/logs"
BACKUP_DIR="/nsatt/storage/backups"
SCRIPT_DIR="/nsatt/storage/scripts"
WWW_DIR="/nsatt/storage/www"
DOWNLOADS_DIR="/nsatt/storage/downloads"
EXPLOITS_DIR="/nsatt/storage/scripts/exploits"
UTILITY_DIR="/nsatt/storage/scripts/utility"
NETWORKING_DIR="/nsatt/storage/scripts/networking"
HARDWARE_DIR="/nsatt/storage/scripts/hardware"
SOFTWARE_DIR="/nsatt/storage/scripts/software"
PLUGINS_DIR="/nsatt/storage/scripts/plugins"
RECON_DIR="/nsatt/storage/scripts/recon"
SECURITY_DIR="/nsatt/storage/scripts/security"
TESTING_DIR="/nsatt/storage/scripts/testing"
NSATT_WEB_DIR="/nsatt/storage/scripts/nsatt_web"
LOG_FILE="$LOG_DIR/nsatt_boot_$(date '+%Y-%m-%d').log"
SMTP_SETTINGS_FILE="/nsatt/settings/smtp_config.json"
ENCRYPTED_SMTP_SETTINGS_FILE="/nsatt/settings/smtp_settings.enc"

########################################################
# Script Paths
########################################################

START_ALL_ADAPTERS_AND_IP_ADDRESS="/nsatt/start_all_adapters_and_ip_address.sh"

########################################################
# Settings File Locations
########################################################

AUTOSTART_BOOT_SERVICE="/nsatt/settings/autostart_boot_service.nsatt"
FIRST_INSTALL_FILE="/nsatt/settings/first_install.nsatt"
AUTOSTART_HOTSPOT="/nsatt/settings/autostart_hotspot.nsatt"
AUTOSTART_VPN="/nsatt/settings/autostart_vpn.nsatt"
AUTOSTART_SSH="/nsatt/settings/autostart_ssh.nsatt"
AUTOSTART_APACHE2="/nsatt/settings/autostart_apache2.nsatt"
AUTOSTART_VSFTPD="/nsatt/settings/autostart_vsftpd.nsatt"
AUTOSTART_POSTGRESQL="/nsatt/settings/autostart_postgresql.nsatt"
AUTOSTART_LLDP="/nsatt/settings/autostart_lldpd.nsatt"
AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS="/nsatt/settings/autostart_all_adapters_and_ip_address.nsatt"
AUTOSTART_SMTP_SENDER="/nsatt/settings/autostart_smtp_sender.nsatt"
AUTOSTART_NETWORK_MANAGER_WEB_INTERFACE="/nsatt/settings/autostart_network_manager_web_interface.nsatt"
AUTOSTART_VNC="/nsatt/settings/autostart_vnc.nsatt"
AUTOSTART_LAUNCHER="/nsatt/settings/autostart_launcher.nsatt"
AUTOSTART_NSATT="/nsatt/settings/autostart_nsatt.nsatt"
NSATT_ADMIN_EMAIL_FILE="/nsatt/settings/nsatt_admin_email.nsatt"
NSATT_ADMIN_EMAIL=""

########################################################
# Automatic Mode and NSATT Admin Email
########################################################

# load automatic mode
if [ -f "$automatic_mode_file" ]; then
    automatic_mode=true
fi
# load nsatt admin email
if [ -f "$NSATT_ADMIN_EMAIL_FILE" ]; then
    NSATT_ADMIN_EMAIL=$(cat "$NSATT_ADMIN_EMAIL_FILE")
fi

########################################################
# Example SMTP Settings File
########################################################

# SMTP_SERVER="smtp.example.com"
# SMTP_PORT="587"
# SMTP_USERNAME="your_username"
# SMTP_PASSWORD="your_password"

########################################################
# Log Function
########################################################

# Show events immediately as they come in instead of logging them.
print_line() {
    echo "-------------------------------------------------------------"
}

show_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Display events
display_events() {
    # Load log file, analyze for errors (info, warning, and success events), change colors of text based on event type, and display them.
    cat "$LOG_FILE" | while read -r line; do
        echo "$line"
    done

    # Clear the log file
    > "$LOG_FILE"
}

########################################################
# Create Folders, Set Permissions, and Create Files
########################################################

create_folders() {
    # Define an array of directories to check and create
    directories=(
        "$BASE_DIR"
        "$STORAGE_DIR"
        "$LOG_DIR"
        "$BACKUP_DIR"
        "$SCRIPT_DIR"
        "$WWW_DIR"
        "$EXPLOITS_DIR"
        "$UTILITY_DIR"
        "$NETWORKING_DIR"
        "$HARDWARE_DIR"
        "$SOFTWARE_DIR"
        "$PLUGINS_DIR"
        "$RECON_DIR"
        "$SECURITY_DIR"
        "$TESTING_DIR"
        "$NSATT_WEB_DIR"
        "$DOWNLOADS_DIR"
    )

    # Iterate over each directory and create it if it doesn't exist
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi
    done
}

########################################################
# Settings Functions
########################################################

create_settings() {
    # Create list of services and autostart files
    services=("Hotspot" "VPN" "SSH" "Apache2" "VSFTPD" "PostgreSQL" "LLDP" "SMTP Sender" "All Adapters and IP Address")
    autostart_files=("$AUTOSTART_HOTSPOT" "$AUTOSTART_VPN" "$AUTOSTART_SSH" "$AUTOSTART_APACHE2" "$AUTOSTART_VSFTPD" 
    "$AUTOSTART_POSTGRESQL" "$AUTOSTART_LLDP" "$AUTOSTART_SMTP_SENDER" "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS" 
    "$AUTOSTART_NETWORK_MANAGER_WEB_INTERFACE" "$AUTOSTART_VNC")
    
    # Loop through services and autostart files and ask user if they want to autostart each service
    for i in "${!services[@]}"; do
        show_event "Do you want to autostart ${services[$i]}? (y/n)"
        read -r answer
        if [ "$answer" = "y" ]; then
            # Ensure the directory for the file exists before touching the file
            dir_path=$(dirname "${autostart_files[$i]}")
            if [ ! -d "$dir_path" ]; then
                mkdir -p "$dir_path"
            fi
            touch "${autostart_files[$i]}"
        fi
    done
}

validate_settings() {
    # Loop to check for files to confirm settings and display service name and "Enabled" or "Disabled"
    show_event "Autostart Settings:"
    show_event "Hotspot: $(if [ -f "$AUTOSTART_HOTSPOT" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "VPN: $(if [ -f "$AUTOSTART_VPN" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "SSH: $(if [ -f "$AUTOSTART_SSH" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "Apache2: $(if [ -f "$AUTOSTART_APACHE2" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "VSFTPD: $(if [ -f "$AUTOSTART_VSFTPD" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "PostgreSQL: $(if [ -f "$AUTOSTART_POSTGRESQL" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "LLDP: $(if [ -f "$AUTOSTART_LLDP" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "NSATT Network Manager Web Interface: $(if [ -f "$AUTOSTART_NETWORK_MANAGER_WEB_INTERFACE" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "VNC: $(if [ -f "$AUTOSTART_VNC" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "NSATT Launcher: $(if [ -f "$AUTOSTART_LAUNCHER" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "SMTP Sender: $(if [ -f "$AUTOSTART_SMTP_SENDER" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "All Adapters and IP Address: $(if [ -f "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event ""
}

########################################################
# SMTP Settings Functions
########################################################

# Test E-mail Functionality

send_startup_email() {
    # Check for encrypted SMTP settings files
    local encrypted_file=""
    if [[ -f "/nsatt/settings/smtp_settings.enc" ]]; then
        encrypted_file="/nsatt/settings/smtp_settings.enc"
        show_event "Found encrypted SMTP settings at /nsatt/settings/smtp_settings.enc"
    elif [[ -f "smtp_config.enc" ]]; then
        encrypted_file="smtp_config.enc"
        show_event "Found encrypted SMTP settings at smtp_config.enc"
    else
        # If no encrypted file exists yet but JSON exists, create it
        if [[ -f "/nsatt/settings/smtp_config.json" ]]; then
            show_event "Creating encrypted SMTP settings file"
            if ! openssl enc -aes-256-cbc -salt -in "$SMTP_SETTINGS_FILE" -out "$ENCRYPTED_SMTP_SETTINGS_FILE"; then
                show_event "ERROR - Failed to create encrypted SMTP settings file"
                return 1
            fi
            encrypted_file="$ENCRYPTED_SMTP_SETTINGS_FILE"
        fi
    fi

    # Verify we have an encrypted file to work with
    if [[ -z "$encrypted_file" ]]; then
        show_event "Error: No SMTP settings file found (encrypted or JSON)"
        return 1
    fi

    # Read settings from JSON file
    local smtp_server=$(jq -r '.smtp_server' /nsatt/settings/smtp_config.json)
    local smtp_port=$(jq -r '.smtp_port' /nsatt/settings/smtp_config.json)
    local smtp_username=$(jq -r '.smtp_user' /nsatt/settings/smtp_config.json)
    local smtp_password=$(jq -r '.smtp_password_encrypted' /nsatt/settings/smtp_config.json)
    local recipient_email=$(jq -r '.recipient_email' /nsatt/settings/smtp_config.json)

    # Gather system information more concisely
    network_info=$(ip -o addr show | awk '{print $2, $4}' | grep -v '^lo')
    system_info=$(uname -n)
    memory_info=$(free -h | awk '/^Mem:/ {print "Total: " $2 " Used: " $3 " Free: " $4}')
    disk_info=$(df -h / | awk 'NR==2 {print "Used: " $3 " Free: " $4 " Total: " $2}')
    
    # Get autoboot services status
    autoboot_services=""
    for service in "$AUTOSTART_APACHE2" "$AUTOSTART_VSFTPD" "$AUTOSTART_POSTGRESQL" "$AUTOSTART_LLDP" \
                  "$AUTOSTART_NETWORK_MANAGER_WEB_INTERFACE" "$AUTOSTART_VNC" "$AUTOSTART_LAUNCHER" \
                  "$AUTOSTART_SMTP_SENDER" "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS"; do
        service_name=$(basename "$service" | sed 's/autostart_//')
        status="Disabled"
        [ -f "$service" ] && status="Enabled"
        autoboot_services+="$service_name: $status\n"
    done

    # Create plain text email with minimal formatting
    email_content="Subject: NSATT Status Report - $(date '+%Y-%m-%d')
From: $smtp_username
To: $recipient_email
Content-Type: text/plain
MIME-Version: 1.0

NSATT System Status Report
-------------------------
Host: $system_info
Time: $(date '+%Y-%m-%d %H:%M:%S')

Network Interfaces:
$network_info

System Resources:
Memory: $memory_info
Storage: $disk_info

Active Services:
$autoboot_services

This is an automated message from your NSATT system."

    # Send email using swaks with proper authentication
    if ! command -v swaks &> /dev/null; then
        show_event "Installing swaks email client..."
        sudo apt-get update && sudo apt-get install -y swaks
    fi

    show_event "Sending status report..."
    if swaks --server "$smtp_server" \
         --port "$smtp_port" \
         --auth LOGIN \
         --auth-user "$smtp_username" \
         --auth-password "$smtp_password" \
         --from "$smtp_username" \
         --to "$recipient_email" \
         --tls \
         --data "$email_content"; then
        show_event "Status report sent successfully"
    else
        show_event "ERROR - Failed to send status report"
        return 1
    fi
}

# Create smtp settings file if not found and ask user for settings
create_smtp_settings() {
    # Check and install required packages
    show_event "Checking required packages..."
    
    if ! command -v openssl &> /dev/null; then
        show_event "Installing openssl..."
        if ! sudo apt-get update && sudo apt-get install -y openssl; then
            show_event "ERROR - Failed to install openssl"
            return 1
        fi
    fi

    if ! command -v curl &> /dev/null; then
        show_event "Installing curl..."
        if ! sudo apt-get update && sudo apt-get install -y curl; then
            show_event "ERROR - Failed to install curl"
            return 1
        fi
    fi

    if ! command -v swaks &> /dev/null; then
        show_event "Installing swaks email client..."
        if ! sudo apt-get update && sudo apt-get install -y swaks; then
            show_event "ERROR - Failed to install swaks"
            return 1
        fi
    fi

    if [ ! -f "$SMTP_SETTINGS_FILE" ]; then
        show_event "Creating SMTP settings file"
        touch "$SMTP_SETTINGS_FILE"
        
        # Prompt for SMTP settings
        read -p "SMTP Server: " smtp_server
        read -p "SMTP Port: " smtp_port
        read -p "SMTP Username: " smtp_username
        read -sp "SMTP Password: " smtp_password
        echo # To move to the next line after password input

        # Save settings to the file
        {
            echo "SMTP_SERVER=$smtp_server"
            echo "SMTP_PORT=$smtp_port"
            echo "SMTP_USERNAME=$smtp_username"
            echo "SMTP_PASSWORD=$smtp_password"
        } > "$SMTP_SETTINGS_FILE"

        show_event "SMTP settings file created"
        create_encrypted_smtp_settings
    else
        show_event "SMTP settings file already exists, skipping creation."
    fi
}

# Load smtp file, validate it, create encrypted smtp settings file, test them, confirm they are correct, and remove original file.
create_encrypted_smtp_settings() {
    # Load and validate SMTP settings
    if [ ! -f "$SMTP_SETTINGS_FILE" ]; then
        show_event "ERROR - SMTP settings file not found"
        return 1
    fi

    # Source the settings file to load variables
    source "$SMTP_SETTINGS_FILE"

    # Validate required settings are present
    if [ -z "$SMTP_SERVER" ] || [ -z "$SMTP_PORT" ] || [ -z "$SMTP_USERNAME" ] || [ -z "$SMTP_PASSWORD" ]; then
        show_event "ERROR - Missing required SMTP settings"
        return 1
    fi

    # Create encrypted settings file
    show_event "Creating encrypted SMTP settings file"
    if ! openssl enc -aes-256-cbc -salt -in "$SMTP_SETTINGS_FILE" -out "${SMTP_SETTINGS_FILE}.enc" -pass pass:"$ENCRYPTION_KEY"; then
        show_event "ERROR - Failed to create encrypted SMTP settings file"
        return 1
    fi

    # Test SMTP settings by sending a test email
    local email_content="This is a test email to verify SMTP settings."
    if ! curl --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
         --ssl-reqd \
         --mail-from "$SMTP_USERNAME" \
         --user "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
         --to "$SMTP_USERNAME" \
         --tls \
         --data "$email_content"; then
        show_event "ERROR - Failed to send test email"
        rm "${SMTP_SETTINGS_FILE}.enc"
        return 1
    fi

    show_event "SMTP settings verified successfully"

    # Remove original settings file
    if ! rm "$SMTP_SETTINGS_FILE"; then
        show_event "ERROR - Failed to remove original SMTP settings file"
        return 1
    fi

    show_event "Original SMTP settings file removed"
    show_event "Encrypted SMTP settings file created successfully"
}

########################################################
# System Functions
########################################################

# Required packages (openssl, curl, wget, git, etc.)
REQUIRED_PACKAGES=("openssl" "curl" "wget" "git" "vsftpd" "apache2" "postgresql" "lldpd" 
    "openvpn" "ssh" "hostapd" "mailutils" "dnsmasq" "nmap" "python3-pip" "python3-requests"
    "python3-flask" "python3-netifaces" "python3-nmap" "python3-pymetasploit3" "python3-netmiko"
    "sqlite3" "jq" "libapache2-mod-wsgi-py3" "apache2-utils" "traceroute" "udev" "net-tools"
    "iptables-persistent" "tightvncserver" "ybsockify" "x11-apps" "imagemagick" "python3-websockify" 
    "python3-flask-socketio" "dhcpd" "ffmpeg" "wireless-tools" "aircrack-ng" "build-essential" 
    "libssl-dev" "libnl-3-dev" "libnl-genl-3-dev" "ethtool" "iw" "rfkill" "wifite" "tailscaled"
    "sendmail" "v4l-utils")
PIP_PACKAGES=("requests" "netifaces" "netmiko" "pymetasploit3" "flask" "websockify" "flask-socketio" "flask-cors")

# Update and upgrade the system (Catch Errors)
update_and_upgrade() {
    show_event "Do you want to update the system? (y/n)"
    read -r update_answer
    if [ "$update_answer" = "y" ]; then
        show_event "Updating the system"
        export DEBIAN_FRONTEND=noninteractive
        if ! apt-get update -yq; then
            show_event "ERROR - Failed to update package list"
            return 1
        fi
        if ! apt-get install -yq "${REQUIRED_PACKAGES[@]}"; then
            show_event "ERROR - Failed to install required packages"
            return 1
        fi
        show_event "System updated"
    fi

    show_event "Do you want to upgrade the system? (y/n)"
    read -r upgrade_answer
    if [ "$upgrade_answer" = "y" ]; then
        show_event "Upgrading the system"
        if ! apt-get upgrade -yq; then
            show_event "ERROR - Failed to upgrade packages"
            return 1
        fi
        show_event "System upgraded"
    fi

    show_event "Installing required Python packages"
    if ! pipx install "${PIP_PACKAGES[@]}"; then
        show_event "ERROR - Failed to install required Python packages"
        return 1
    fi
    show_event "Python packages installed"

    unset DEBIAN_FRONTEND
}

########################################################
# User Functions
########################################################

# Check for and create nsatt-admin and nsatt-superadmin users
create_users() {
    show_event "Checking for nsatt-admin and nsatt-superadmin users"
    
    # Check if nsatt-admin user exists
    if id "nsatt-admin" &> /dev/null; then
        show_event "nsatt-admin user already exists, skipping creation."
    else
        read -p "nsatt-admin user does not exist. Do you want to create it? (y/n): " create_admin
        if [ "$create_admin" = "y" ]; then
            show_event "Creating nsatt-admin user"
            adduser nsatt-admin
        fi
    fi

    # Check if nsatt-superadmin user exists
    if id "nsatt-superadmin" &> /dev/null; then
        show_event "nsatt-superadmin user already exists, skipping creation."
    else
        read -p "nsatt-superadmin user does not exist. Do you want to create it? (y/n): " create_superadmin
        if [ "$create_superadmin" = "y" ]; then
            show_event "Creating nsatt-superadmin user"
            adduser nsatt-superadmin
        fi
    fi

    # Set permissions for nsatt-admin and nsatt-superadmin users if they were created
    if id "nsatt-admin" &> /dev/null; then
        show_event "Setting permissions for nsatt-admin user"
        chown -R nsatt-admin:nsatt-admin /home/nsatt-admin
    fi

    if id "nsatt-superadmin" &> /dev/null; then
        show_event "Setting permissions for nsatt-superadmin user"
        chown -R nsatt-superadmin:nsatt-superadmin /home/nsatt-superadmin
    fi

    # Set as admin users
    if id "nsatt-admin" &> /dev/null; then
        show_event "Setting nsatt-admin user as admin"
        usermod -aG sudo nsatt-admin
    fi

    if id "nsatt-superadmin" &> /dev/null; then
        show_event "Setting nsatt-superadmin user as admin"
        usermod -aG sudo nsatt-superadmin
    fi
}

########################################################
# Host Functions
########################################################

#Check for hostname, if not set to nsatt, ask user if they want to set it to nsatt
check_and_set_hostname() {
    show_event "Checking and setting hostname"
    current_hostname=$(hostnamectl | grep "Static hostname" | awk '{print $3}')
    if [ "$current_hostname" != "nsatt" ]; then
        show_event "Hostname is not set to nsatt, setting it now"
        hostnamectl set-hostname nsatt
    fi
}

########################################################
# First Install Functions
########################################################

# Create first install file and announce completion of script
first_install_completed() {
    touch "$FIRST_INSTALL_FILE"
    echo -e "${GREEN}"
    echo "    _   _______ ___  ____________  "
    echo "   / | / / ___//   |/_  __/_  __/  "
    echo "  /  |/ /\__ \/ /| | / /   / /     "
    echo " / /|  /___/ / ___ |/ /   / /      "
    echo "/_/ |_//____/_/  |_/_/   /_/       "
    echo ""
    echo -e "### Initial installation completed ###"
    echo ""
    echo -e "### Ready to start services ###"
    
    # Ask if they want to start services now
    show_event "Do you want to start services now? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        start_services
    fi
}
########################################################
# Setup Services Functions
########################################################

# Setup services
setup_services() {
    show_event "Setting up services"

    show_event "Do you want to setup the boot service? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_boot_service
    fi

    # Ask user if they want to setup hotspot, vpn, ssh, apache2, vsftpd, postgresql, lldpd, desired ip address, smtp sender, and all adapters
    show_event "Do you want to setup hotspot? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_hotspot
    fi

    show_event "Do you want to setup vpn? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_vpn
    fi

    show_event "Do you want to setup ssh? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_ssh
    fi

    show_event "Do you want to setup apache2? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_apache2
    fi

    show_event "Do you want to setup vsftpd? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_vsftpd
    fi

    show_event "Do you want to setup postgresql? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_postgresql
    fi

    show_event "Do you want to setup lldpd? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_lldpd
    fi

    show_event "Do you want to setup smtp sender? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_smtp_sender
    fi

    show_event "Do you want to setup all adapters and set the IP address? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_all_adapters_and_ip_address
    fi

    show_event "Do you want to setup VNC? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        setup_vnc
    fi

    show_event "Do you want to setup the network manager web interface? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        start_network_manager_web_interface
    fi

    show_event "Services setup"
}

setup_boot_service() {
    # Check if service already exists or if autostart is disabled
    if systemctl list-unit-files | grep -q "nsatt_boot.service" || [ ! -f "$AUTOSTART_BOOT_SERVICE" ]; then
        show_event "NSATT Boot service already exists or autostart is disabled."
        return 0
    fi

    # Create systemd service file
    local service_file="/etc/systemd/system/nsatt_boot.service"
    sudo bash -c "cat > $service_file" << 'EOL'
[Unit]
Description=NSATT Boot Service
After=network.target

[Service]
Type=simple
ExecStart=/nsatt/storage/scripts/utility/nsatt_boot.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    if [ "$automatic_mode" = true ]; then
        # Automatically create and start service in automatic mode
        if sudo chmod +x /nsatt/storage/scripts/utility/nsatt_boot.sh && \
           sudo systemctl daemon-reload && \
           sudo systemctl enable nsatt_boot.service && \
           sudo systemctl start nsatt_boot.service; then
            if validate_boot_service; then
                show_event "NSATT Boot service installed and started successfully."
            else
                show_event "ERROR - Failed to install NSATT Boot service."
            fi
        else
            show_event "ERROR - Failed to create NSATT Boot service."
        fi
    else
        # Ask for confirmation in manual mode
        show_event "Do you want to install and start the boot service? (y/n)"
        read -r answer
        if [ "$answer" = "y" ]; then
            if sudo chmod +x /nsatt/storage/scripts/utility/nsatt_boot.sh && \
               sudo systemctl daemon-reload && \
               sudo systemctl enable nsatt_boot.service && \
               sudo systemctl start nsatt_boot.service; then
                if validate_boot_service; then
                    show_event "NSATT Boot service installed and started successfully."
                else
                    show_event "ERROR - Failed to install NSATT Boot service."
                fi
            else
                show_event "ERROR - Failed to create NSATT Boot service."
            fi
        else
            show_event "NSATT Boot service installation canceled."
        fi
    fi
}

setup_vnc() {
    show_event "Setting up VNC"

    # Debug mode check
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Starting VNC setup in debug mode"
    fi

    # Kill any existing VNC processes first
    if pgrep -f "Xtightvnc" > /dev/null; then
        show_event "Stopping existing VNC processes..."
        sudo pkill -f "Xtightvnc"
        sleep 2
    fi

    # Check if VNC is already installed and configured properly
    if systemctl is-active --quiet vncserver@1.service && pgrep -f "Xtightvnc" > /dev/null; then
        show_event "VNC appears to be already installed and running"
        show_event "VNC server is running on port 5901"
        show_event "Websockify is available on port 6080"
        return 0
    fi

    # Create base VNC directory structure if it doesn't exist
    local base_dir="/nsatt/storage/scripts/nsatt_web/saves/vnc"
    local dirs=("screenshots" "videos" "logs")

    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Creating base directory structure"
    fi

    if [ ! -d "$base_dir" ]; then
        show_event "Creating base VNC directory at $base_dir"
        if ! sudo mkdir -p "$base_dir"; then
            show_event "ERROR - Failed to create base VNC directory"
            if [ "${debug_testing:-false}" = true ]; then
                show_event "DEBUG: mkdir failed with code $?"
            fi
            return 1
        fi
        sudo chown -R www-data:www-data "$base_dir"
        sudo chmod -R 755 "$base_dir"
    fi

    # Create subdirectories and set permissions
    for dir in "${dirs[@]}"; do
        local full_path="$base_dir/$dir"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: Processing directory $full_path"
        fi
        
        if [ ! -d "$full_path" ]; then
            show_event "Creating directory: $full_path"
            if ! sudo mkdir -p "$full_path"; then
                show_event "ERROR - Failed to create directory: $full_path"
                if [ "${debug_testing:-false}" = true ]; then
                    show_event "DEBUG: mkdir failed with code $?"
                fi
                return 1
            fi
            sudo chown -R www-data:www-data "$full_path"
            sudo chmod -R 755 "$full_path"
        fi
    done

    # Set up logging
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Setting up logging"
    fi
    local log_file="$base_dir/logs/vnc_setup.log"
    if ! sudo touch "$log_file"; then
        show_event "ERROR - Failed to create log file"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: touch failed with code $?"
        fi
        return 1
    fi
    sudo chown www-data:www-data "$log_file"
    sudo chmod 644 "$log_file"

    # Install required packages if not already installed
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Starting package installation"
    fi
    show_event "Installing required packages..."
    if ! sudo apt-get update; then
        show_event "ERROR - Failed to update package lists"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: apt-get update failed with code $?"
        fi
        return 1
    fi

    local packages=(tightvncserver x11-apps imagemagick python3-pip xfce4 python3-pyvnc)
    for package in "${packages[@]}"; do
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: Installing package $package"
        fi
        if ! dpkg -l | grep -q "^ii\s\+$package"; then
            show_event "Installing $package..."
            if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"; then
                show_event "ERROR - Failed to install $package"
                if [ "${debug_testing:-false}" = true ]; then
                    show_event "DEBUG: apt-get install failed with code $?"
                fi
                return 1
            fi
        fi
    done

    # Install Python packages
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Starting Python package installation"
    fi
    show_event "Installing Python packages..."
    local pip_packages=(websockify flask)
    for package in "${pip_packages[@]}"; do
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: Installing pip package $package"
        fi
        if ! pip3 list | grep -q "^$package"; then
            if ! sudo pip3 install "$package"; then
                show_event "ERROR - Failed to install Python package $package"
                if [ "${debug_testing:-false}" = true ]; then
                    show_event "DEBUG: pip3 install failed with code $?"
                fi
                return 1
            fi
        fi
    done

    # Set up noVNC
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Setting up noVNC"
    fi
    show_event "Setting up noVNC..."
    if [ ! -d "/var/www/html/noVNC" ]; then
        cd /var/www/html/ || {
            show_event "ERROR - Failed to change directory to /var/www/html/"
            if [ "${debug_testing:-false}" = true ]; then
                show_event "DEBUG: cd failed with code $?"
            fi
            return 1
        }
        if ! sudo git clone https://github.com/novnc/noVNC.git; then
            show_event "ERROR - Failed to clone noVNC repository"
            if [ "${debug_testing:-false}" = true ]; then
                show_event "DEBUG: git clone failed with code $?"
            fi
            return 1
        fi
        cd noVNC || return 1
        sudo ln -sf vnc_lite.html index.html
    fi

    # Create VNC config directory and set up password using tightvncpasswd
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Setting up VNC configuration"
    fi
    if [ ! -d "/etc/vnc" ]; then
        sudo mkdir -p /etc/vnc
    fi

    show_event "Setting up VNC password..."
    printf "nsatt\nnsatt\nn\n" | sudo tightvncpasswd /etc/vnc/.vnc_passwd >/dev/null 2>&1
    if [ ! -f "/etc/vnc/.vnc_passwd" ]; then
        show_event "ERROR - Failed to set VNC password"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: tightvncpasswd failed"
        fi
        return 1
    fi
    sudo chmod 600 /etc/vnc/.vnc_passwd

    # Create and configure VNC service
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Creating VNC service file"
    fi
    show_event "Creating VNC service file..."
    cat << 'EOF' | sudo tee /etc/systemd/system/vncserver@.service > /dev/null
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=root
PIDFile=/tmp/.X%i-lock
ExecStartPre=-/usr/bin/tightvncserver -kill :%i
ExecStart=/usr/bin/tightvncserver :%i -rfbauth /etc/vnc/.vnc_passwd -geometry 1920x1080 -depth 24
ExecStop=/usr/bin/tightvncserver -kill :%i
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Configure VNC startup
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Configuring VNC startup"
    fi
    show_event "Configuring VNC startup..."
    cat << 'EOF' | sudo tee /etc/vnc/xstartup > /dev/null
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
startxfce4 &
EOF

    sudo chmod +x /etc/vnc/xstartup

    # Configure firewall
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Configuring firewall"
    fi
    show_event "Configuring firewall..."
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 5901/tcp
        sudo ufw allow 6080/tcp
    fi

    # Reload systemd and enable/start VNC service
    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: Starting VNC service"
    fi
    show_event "Enabling and starting VNC service..."
    if ! sudo systemctl daemon-reload; then
        show_event "ERROR - Failed to reload systemd"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: daemon-reload failed with code $?"
        fi
        return 1
    fi

    if ! sudo systemctl enable vncserver@1.service; then
        show_event "ERROR - Failed to enable VNC service"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: systemctl enable failed with code $?"
        fi
        return 1
    fi

    if ! sudo systemctl start vncserver@1.service; then
        show_event "ERROR - Failed to start VNC service"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: systemctl start failed with code $?"
        fi
        return 1
    fi

    # Verify service is running with proper process
    sleep 2
    if ! systemctl is-active --quiet vncserver@1.service || ! pgrep -f "Xtightvnc" > /dev/null; then
        show_event "ERROR - VNC service failed to start properly"
        if [ "${debug_testing:-false}" = true ]; then
            show_event "DEBUG: Service not active or Xtightvnc not running"
        fi
        return 1
    fi

    if [ "${debug_testing:-false}" = true ]; then
        show_event "DEBUG: VNC setup completed successfully"
    fi
    show_event "VNC setup completed successfully"
    show_event "VNC server is running on port 5901"
    show_event "Websockify is available on port 6080"
    show_event "Setup log available at: $log_file"
    return 0
}

setup_hotspot() {
    show_event "Setting up hotspot"

    # Update package lists
    show_event "Updating package lists..."
    if ! sudo apt-get update; then
        show_event "ERROR - Failed to update package lists."
        return 1
    fi

    # Install hostapd if not installed
    if ! command -v hostapd &> /dev/null; then
        show_event "Installing hostapd..."
        if ! sudo apt-get install -y hostapd; then
            show_event "ERROR - Failed to install hostapd."
            return 1
        fi
    else
        show_event "hostapd is already installed."
    fi

    # List available network interfaces
    show_event "Available network interfaces:"
    interfaces=$(ls /sys/class/net)
    echo "$interfaces"

    # Prompt user to select an interface
    show_event "Please select the interface to use for the hotspot:"
    read -r selected_interface

    # Check if DHCP is already configured
    if [ -f "/etc/dhcp/dhcpd.conf" ] || [ -f "/etc/dnsmasq.conf" ]; then
        show_event "DHCP is already configured. Do you want to reconfigure it? (y/n)"
        read -r answer
        if [ "$answer" != "y" ]; then
            show_event "INFO - Skipping DHCP configuration."
            return 0
        fi
    fi

    # Attempt to install isc-dhcp-server
    show_event "Attempting to install isc-dhcp-server..."
    if sudo apt-get install -y isc-dhcp-server; then
        DHCP_SERVER="isc-dhcp-server"
        show_event "isc-dhcp-server installed successfully."
    else
        show_event "WARNING - isc-dhcp-server is not available. Attempting to install dnsmasq instead."
        # Install dnsmasq as an alternative
        if sudo apt-get install -y dnsmasq; then
            DHCP_SERVER="dnsmasq"
            show_event "dnsmasq installed successfully."
        else
            show_event "ERROR - Failed to install both isc-dhcp-server and dnsmasq."
            return 1
        fi
    fi

    # Configure DHCP Server
    if [ "$DHCP_SERVER" == "isc-dhcp-server" ]; then
        local dhcp_conf="/etc/dhcp/dhcpd.conf"
        sudo bash -c "cat > $dhcp_conf <<EOL
subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.10 192.168.1.100;
  option routers 192.168.1.1;
  option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOL"

        # Assign IP address to the selected interface
        sudo ip addr add 192.168.1.1/24 dev "$selected_interface"
        sudo ip link set dev "$selected_interface" up

        # Restart DHCP Server
        sudo systemctl restart isc-dhcp-server
        sudo systemctl enable isc-dhcp-server
    elif [ "$DHCP_SERVER" == "dnsmasq" ]; then
        local dnsmasq_conf="/etc/dnsmasq.conf"
        sudo mv $dnsmasq_conf "${dnsmasq_conf}.backup" 2>/dev/null
        sudo bash -c "cat > $dnsmasq_conf <<EOL
interface=$selected_interface
dhcp-range=192.168.1.10,192.168.1.100,12h
EOL"

        # Assign IP address to the selected interface
        sudo ip addr add 192.168.1.1/24 dev "$selected_interface"
        sudo ip link set dev "$selected_interface" up

        # Restart dnsmasq
        sudo systemctl restart dnsmasq
        sudo systemctl enable dnsmasq
    fi

    # Configure hostapd
    local hostapd_conf="/etc/hostapd/hostapd.conf"
    sudo bash -c "cat > $hostapd_conf <<EOL
interface=$selected_interface
driver=nl80211
ssid=NSATT-NETWORK
hw_mode=g
channel=6
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=ChangeMe!
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOL"

    # Point hostapd to the configuration file
    sudo bash -c "echo 'DAEMON_CONF=\"$hostapd_conf\"' > /etc/default/hostapd"

    # Enable and start hostapd
    if ! sudo systemctl enable hostapd; then
        show_event "ERROR - Failed to enable hostapd service."
        return 1
    fi

    if ! sudo systemctl start hostapd; then
        show_event "ERROR - Failed to start hostapd service."
        return 1
    fi

    show_event "INFO - Hotspot setup completed successfully."
}

setup_vpn() {
    show_event "Setting up Tailscale VPN"
    
    # Check if Tailscale is installed
    if ! command -v tailscale &> /dev/null; then
        show_event "Tailscale is not installed. Installing Tailscale."
        
        # Install Tailscale
        if ! curl -fsSL https://tailscale.com/install.sh | sh; then
            show_event "ERROR - Failed to download and execute Tailscale installation script."
            return 1
        fi
    fi

    # Enable and start Tailscale service
    if ! sudo systemctl enable tailscaled; then
        show_event "ERROR - Failed to enable Tailscale service."
        return 1
    fi

    if ! sudo systemctl start tailscaled; then
        show_event "ERROR - Failed to start Tailscale service."
        return 1
    fi

    # Authenticate Tailscale
    show_event "Please authenticate Tailscale using the provided URL."
    auth_url=$(sudo tailscale up --qr | grep -o 'https://login.tailscale.com/[^ ]*')
    
    if [ -z "$auth_url" ]; then
        show_event "ERROR - Failed to retrieve Tailscale authentication URL."
        return 1
    fi

    show_event "Open the following URL in your browser to authenticate Tailscale: $auth_url"
    read -p "Press Enter after you have authenticated Tailscale..."

    # Verify Tailscale connection
    if ! sudo tailscale status &> /dev/null; then
        show_event "ERROR - Tailscale is not connected. Please check your authentication and network settings."
        return 1
    fi

    show_event "INFO - Tailscale VPN setup completed successfully."
}

setup_ssh() {
    show_event "Setting up SSH"
    # Initial framework for setting up SSH
    if ! sudo apt-get install -y openssh-server; then
        show_event "ERROR - Failed to install OpenSSH server."
        return 1
    fi

    if ! sudo systemctl enable ssh; then
        show_event "ERROR - Failed to enable SSH service."
        return 1
    fi

    if ! sudo systemctl start ssh; then
        show_event "ERROR - Failed to start SSH service."
        return 1
    fi

    show_event "INFO - SSH setup completed successfully."
}

setup_apache2() {
    show_event "Setting up Apache2"
    # Initial framework for setting up Apache2
    if ! sudo apt-get install -y apache2; then
        show_event "ERROR - Failed to install Apache2."
        return 1
    fi

    if ! sudo systemctl enable apache2; then
        show_event "ERROR - Failed to enable Apache2 service."
        return 1
    fi

    if ! sudo systemctl start apache2; then
        show_event "ERROR - Failed to start Apache2 service."
        return 1
    fi

    show_event "INFO - Apache2 setup completed successfully."
}

setup_vsftpd() {
    show_event "INFO - Installing and configuring vsftpd."

    if ! dpkg -l | grep -qw vsftpd; then
        if ! sudo apt-get install -y vsftpd; then
            show_event "ERROR - Failed to install vsftpd."
            return 1
        fi
    fi

    if ! sudo systemctl enable vsftpd; then
        show_event "ERROR - Failed to enable vsftpd service."
        return 1
    fi

    if ! sudo systemctl start vsftpd; then
        show_event "ERROR - Failed to start vsftpd service."
        return 1
    fi

    local vsftpd_conf="/etc/vsftpd.conf"
    if ! sudo sed -i '/^write_enable=/d' "$vsftpd_conf" || ! echo "write_enable=YES" | sudo tee -a "$vsftpd_conf" > /dev/null; then
        show_event "ERROR - Failed to configure write_enable in vsftpd."
        return 1
    fi

    if ! sudo sed -i '/^local_root=/d' "$vsftpd_conf" || ! echo "local_root=/nsatt" | sudo tee -a "$vsftpd_conf" > /dev/null; then
        show_event "ERROR - Failed to configure local_root in vsftpd."
        return 1
    fi

    if ! sudo systemctl restart vsftpd; then
        show_event "ERROR - Failed to restart vsftpd service."
        return 1
    fi

    if ! sudo chown -R nsatt-admin /nsatt; then
        show_event "ERROR - Failed to set ownership for /nsatt."
        return 1
    fi

    if ! sudo chmod -R 755 /nsatt; then
        show_event "ERROR - Failed to set permissions for /nsatt."
        return 1
    fi

    show_event "INFO - vsftpd installed and configured successfully with /nsatt as the default folder."
    return 0
}

setup_postgresql() {
    show_event "Setting up PostgreSQL"
    # Initial framework for setting up PostgreSQL
    if ! sudo apt-get install -y postgresql; then
        show_event "ERROR - Failed to install PostgreSQL."
        return 1
    fi

    if ! sudo systemctl enable postgresql; then
        show_event "ERROR - Failed to enable PostgreSQL service."
        return 1
    fi

    if ! sudo systemctl start postgresql; then
        show_event "ERROR - Failed to start PostgreSQL service."
        return 1
    fi

    show_event "INFO - PostgreSQL setup completed successfully."
}

setup_lldpd() {
    show_event "Setting up LLDP"
    # Initial framework for setting up LLDP
    if ! sudo apt-get install -y lldpd; then
        show_event "ERROR - Failed to install LLDPD."
        return 1
    fi

    if ! sudo systemctl enable lldpd; then
        show_event "ERROR - Failed to enable LLDPD service."
        return 1
    fi

    if ! sudo systemctl start lldpd; then
        show_event "ERROR - Failed to start LLDPD service."
        return 1
    fi

    show_event "INFO - LLDP setup completed successfully."
}

setup_metasploit() {
    show_event "Setting up Metasploit"
    # Check if Metasploit is already installed
    if command -v msfconsole >/dev/null 2>&1; then
        show_event "INFO - Metasploit is already installed. Skipping installation."
    else
        # Download the Metasploit installer script
        local installer_url="https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb"
        local installer_file="$DOWNLOADS_DIR/msfinstall"

        if curl -s "$installer_url" -o "$installer_file"; then
            chmod 755 "$installer_file"
            if ./"$installer_file"; then
                show_event "INFO - Metasploit installed successfully."
            else
                show_event "ERROR - Execution of Metasploit installer failed."
                return 1
            fi
        else
            show_event "ERROR - Failed to download Metasploit installer from $installer_url."
            return 1
        fi
    fi

    # Initialize the Metasploit database
    if sudo msfdb init; then
        show_event "INFO - Metasploit database initialized successfully."
    else
        show_event "ERROR - Metasploit database initialization failed."
        return 1
    fi

    # Start Metasploit console in quiet mode and exit immediately
    if sudo msfconsole -q -x "exit"; then
        show_event "INFO - Metasploit console started and exited successfully."
    else
        show_event "ERROR - Failed to start Metasploit console."
        return 1
    fi

    return 0
}

setup_smtp_sender() {
    show_event "Setting up SMTP Sender"

    # Check if required packages are installed
    local required_packages=("jq" "openssl" "swaks")
    for package in "${required_packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            show_event "Installing $package..."
            if ! sudo apt-get update && sudo apt-get install -y "$package"; then
                show_event "ERROR - Failed to install $package"
                return 1
            fi
        fi
    done

    # Create settings directory if it doesn't exist
    if [ ! -d "/nsatt/settings" ]; then
        sudo mkdir -p /nsatt/settings
    fi

    # Create smtp_config.json if it doesn't exist
    local smtp_config="/nsatt/settings/smtp_config.json"
    if [ ! -f "$smtp_config" ]; then
        show_event "Creating SMTP configuration file"
        
        # Prompt for SMTP settings if not in automatic mode
        if [ "$automatic_mode" != true ]; then
            read -p "SMTP Server: " smtp_server
            read -p "SMTP Port: " smtp_port
            read -p "SMTP Username: " smtp_username
            read -sp "SMTP Password: " smtp_password
            echo # New line after password
            read -p "Recipient Email: " recipient_email
        else
            # Use environment variables in automatic mode
            smtp_server="$SMTP_SERVER"
            smtp_port="$SMTP_PORT"
            smtp_username="$SMTP_USERNAME"
            smtp_password="$SMTP_PASSWORD"
            recipient_email="$SMTP_RECIPIENT"
        fi

        # Encrypt password
        local encrypted_password=$(echo -n "$smtp_password" | openssl enc -aes-256-cbc -a -salt -pass pass:"$ENCRYPTION_KEY")

        # Create JSON config
        cat > "$smtp_config" << EOL
{
    "smtp_server": "$smtp_server",
    "smtp_port": "$smtp_port",
    "smtp_user": "$smtp_username",
    "smtp_password_encrypted": "$encrypted_password",
    "recipient_email": "$recipient_email"
}
EOL

        # Set proper permissions
        sudo chmod 600 "$smtp_config"
    fi

    # Remove existing service if it exists
    local service_file="/etc/systemd/system/smtp-sender.service"
    if [ -f "$service_file" ]; then
        sudo systemctl stop smtp-sender
        sudo systemctl disable smtp-sender
        sudo rm -f "$service_file"
    fi

    # Create systemd service
    sudo bash -c "cat > $service_file" << 'EOL'
[Unit]
Description=SMTP Sender Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'source /nsatt/storage/scripts/utility/nsatt_boot.sh && send_startup_email'
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd and enable service
    if ! sudo systemctl daemon-reload; then
        show_event "ERROR - Failed to reload systemd daemon"
        return 1
    fi

    if ! sudo systemctl enable smtp-sender; then
        show_event "ERROR - Failed to enable smtp-sender service"
        return 1
    fi

    # Start service and send test email if in automatic mode
    if [ "$automatic_mode" = true ]; then
        if ! sudo systemctl start smtp-sender; then
            show_event "ERROR - Failed to start smtp-sender service"
            return 1
        fi
        
        # Wait briefly for service to start
        sleep 2
        
        # Send test email
        if ! send_startup_email; then
            show_event "ERROR - Failed to send test email"
            return 1
        fi
    fi

    show_event "INFO - SMTP sender setup completed successfully"
}

# If set_ip_address service doesn't exist, trigger set_ip_address script.
setup_all_adapters_and_ip_address() {
    show_event "Starting Set IP Address"
    if ! sudo /nsatt/storage/scripts/networking/set_ip_address.sh; then
        show_event "ERROR - Failed to start Set IP Address service."
    else
        show_event "INFO - Set IP Address service started successfully."
    fi
}

########################################################
# Start Services Functions
########################################################

# Start services
start_services() {
    show_event "Starting services"
    if [ -f "$AUTOSTART_BOOT" ]; then
        start_boot_service
    fi
    if [ -f "$AUTOSTART_NSATT" ]; then
        start_nsatt
    fi
    if [ -f "$AUTOSTART_HOTSPOT" ]; then
        start_hotspot
    fi
    if [ -f "$AUTOSTART_VPN" ]; then
        start_vpn
    fi
    if [ -f "$AUTOSTART_SSH" ]; then
        start_ssh
    fi
    if [ -f "$AUTOSTART_APACHE2" ]; then
        start_apache2
    fi
    if [ -f "$AUTOSTART_VSFTPD" ]; then
        start_vsftpd
    fi
    if [ -f "$AUTOSTART_POSTGRESQL" ]; then
        start_postgresql
    fi
    if [ -f "$AUTOSTART_LLDP" ]; then
        start_lldpd
    fi
    if [ -f "$AUTOSTART_SMTP_SENDER" ]; then
        start_smtp_sender
    fi
    if [ -f "$AUTOSTART_VNC" ]; then
        start_vnc
    fi
    if [ -f "$AUTOSTART_NETWORK_MANAGER_WEB_INTERFACE" ]; then
        start_network_manager_web_interface
    fi
    if [ -f "$AUTOSTART_LAUNCHER" ]; then
        restart_launcher
    fi
    show_event "Services started:"
    validate_settings
    if [ -f "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS" ]; then
        start_all_adapters_and_ip_address
    fi
}

start_nsatt() {
    show_event "Starting NSATT"
    if [ -f "$AUTOSTART_NSATT" ]; then
        start_boot_service
    fi
}

start_boot_service() {
    # Start boot service
    show_event "Starting NSATT Boot"
    if ! sudo systemctl start nsatt_boot.service; then
        show_event "ERROR - Failed to start NSATT Boot."
    fi
}

validate_boot_service() {
    if ! sudo systemctl is-enabled /nsatt/storage/scripts/utility/nsatt_boot.sh; then
        if ! sudo systemctl enable /nsatt/storage/scripts/utility/nsatt_boot.sh; then
            show_event "ERROR - Failed to enable NSATT Boot service."
        else
            show_event "NSATT Boot service enabled successfully."
        fi
    else
        show_event "NSATT Boot service is already enabled."
    fi
}

stop_hotspot() {
    # Debugging flag: true for verbose, false for production
    local debug_testing=true

    # Utility function for verbose output
    log_event() {
        local message="$1"
        if [ "$debug_testing" = true ]; then
            echo "DEBUG: $message"
        fi
    }

    # Utility function for production checkpoint messages
    show_event() {
        local message="$1"
        echo "INFO: $message"
    }

    # Use the correct log function based on debug_testing
    checkpoint() {
        local message="$1"
        if [ "$debug_testing" = true ]; then
            log_event "$message"
        else
            show_event "$message"
        fi
    }

    checkpoint "Stopping Hotspot service..."
    if sudo systemctl is-active hostapd &>/dev/null; then
        log_event "hostapd is active. Attempting to stop the service."
        if sudo systemctl stop hostapd; then
            checkpoint "Hotspot service stopped successfully."
        else
            checkpoint "ERROR: Failed to stop Hotspot service. Exiting."
            return 1
        fi
    else
        checkpoint "Hotspot service is not running."
    fi

    # Detect the actual hotspot device
    log_event "Checking for hotspot configuration in /etc/hostapd/hostapd.conf..."
    local actual_hotspot_device=""
    if [ -f "/etc/hostapd/hostapd.conf" ]; then
        actual_hotspot_device=$(grep "^interface=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
        log_event "Hostapd configuration specifies interface: $actual_hotspot_device"
    else
        log_event "No hostapd configuration file found."
    fi

    # Detect internet-sharing device via iptables
    log_event "Checking iptables for devices sharing internet..."
    local sharing_device=""
    if sudo iptables -t nat -L POSTROUTING -v -n | grep -q "eth0"; then
        sharing_device="eth0"
    elif sudo iptables -t nat -L POSTROUTING -v -n | grep -q "wlan1"; then
        sharing_device="wlan1"
    fi
    log_event "Sharing device detected via iptables: $sharing_device"

    # Determine the device to reset
    local device_to_reset="${actual_hotspot_device:-$sharing_device}"
    if [ -z "$device_to_reset" ]; then
        checkpoint "No hotspot or sharing device detected. Exiting."
        return 0
    fi

    checkpoint "Device to reset: $device_to_reset (Hotspot: ${actual_hotspot_device:-unknown}, Sharing: ${sharing_device:-none})"

    # Cleanup iptables
    checkpoint "Flushing iptables and disabling IP forwarding..."
    sudo iptables -t nat -F || log_event "WARNING: Failed to flush NAT table rules."
    sudo iptables -F || log_event "WARNING: Failed to flush iptables rules."
    sudo sysctl -w net.ipv4.ip_forward=0 || log_event "WARNING: Failed to disable IP forwarding."

    # Stop DHCP and DNS services
    checkpoint "Stopping DHCP and DNS services..."
    sudo systemctl stop dnsmasq isc-dhcp-server &>/dev/null || log_event "WARNING: DHCP and DNS services might not have been running."

    # Restore original DNS configuration
    if [ -f "/etc/dnsmasq.conf.backup" ]; then
        sudo mv "/etc/dnsmasq.conf.backup" "/etc/dnsmasq.conf" || log_event "WARNING: Failed to restore dnsmasq configuration from backup."
    fi

    # Reset network device state
    checkpoint "Resetting network state for $device_to_reset..."
    sudo ip addr flush dev "$device_to_reset" || log_event "WARNING: Failed to flush IP addresses for $device_to_reset."
    sudo ip link set "$device_to_reset" down || log_event "WARNING: Failed to bring $device_to_reset down."

    # Restart NetworkManager
    checkpoint "Restarting NetworkManager service..."
    sudo systemctl restart NetworkManager || {
        checkpoint "ERROR: Failed to restart NetworkManager. Exiting."
        return 1
    }

    # Ensure the device is managed
    checkpoint "Ensuring $device_to_reset is managed by NetworkManager..."
    sudo nmcli device set "$device_to_reset" managed yes || log_event "WARNING: Failed to set $device_to_reset as managed."

    # Bring the device up
    checkpoint "Bringing up $device_to_reset..."
    sudo ip link set "$device_to_reset" up || log_event "WARNING: Failed to bring $device_to_reset up."

    # Configure for DHCP
    checkpoint "Configuring $device_to_reset for DHCP..."
    sudo dhclient -r "$device_to_reset" &>/dev/null
    sudo dhclient "$device_to_reset" &>/dev/null || log_event "WARNING: DHCP failed for $device_to_reset."

    # Check for an IP address
    if ip addr show "$device_to_reset" | grep -q "inet "; then
        checkpoint "$device_to_reset obtained an IP address via DHCP."
    else
        log_event "No IP address obtained for $device_to_reset. Attempting NetworkManager configuration."
        sudo nmcli device connect "$device_to_reset" || log_event "WARNING: NetworkManager failed to connect $device_to_reset."
    fi

    # Final state verification
    checkpoint "Verifying final network state for $device_to_reset..."
    ip addr show "$device_to_reset" || log_event "ERROR: Unable to retrieve IP configuration for $device_to_reset."
    nmcli device status | grep "$device_to_reset" || log_event "ERROR: Unable to retrieve NetworkManager status."

    checkpoint "Hotspot cleanup completed. Verify network connectivity."
}

start_vpn() {
    show_event "Checking Tailscale VPN status"
    
    # Check if Tailscale is installed
    if ! command -v tailscale &> /dev/null; then
        show_event "Tailscale is not installed."
        if [ "$automatic_mode" != true ]; then
            read -p "Would you like to set up Tailscale VPN now? (y/n): " answer
            if [ "$answer" = "y" ]; then
                setup_vpn
            else
                show_event "Tailscale VPN setup aborted."
                return 1
            fi
        else
            show_event "Skipping Tailscale setup in automatic mode."
            return 1
        fi
    fi

    # Check if Tailscale service is active
    if ! sudo systemctl is-active tailscaled &> /dev/null; then
        show_event "Tailscale service is not running. Starting it."
        if ! sudo systemctl start tailscaled; then
            show_event "WARNING - Initial start attempt failed, waiting 5 seconds and trying again..."
            sleep 5
            if ! sudo systemctl start tailscaled; then
                show_event "ERROR - Failed to start Tailscale service after retry."
                return 1
            fi
        fi
        
        # Give tailscaled time to fully initialize
        show_event "Waiting for Tailscale service to initialize..."
        sleep 10
    fi

    # Verify Tailscale connection with retries
    local max_attempts=3
    local attempt=1
    local connected=false
    
    while [ $attempt -le $max_attempts ]; do
        if sudo tailscale status &> /dev/null; then
            connected=true
            break
        else
            show_event "Attempt $attempt of $max_attempts: Waiting for Tailscale to connect..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done

    if [ "$connected" = false ]; then
        show_event "ERROR - Tailscale failed to connect after $max_attempts attempts. Please check your authentication and network settings."
        return 1
    fi

    show_event "INFO - Tailscale VPN is running successfully."
    return 0
}

start_ssh() {
    show_event "Checking SSH configuration"
    if ! command -v sshd &> /dev/null; then
        show_event "ERROR - OpenSSH server is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active ssh &> /dev/null; then
        show_event "Starting SSH service"
        if ! sudo systemctl start ssh; then
            show_event "ERROR - Failed to start SSH service."
            return 1
        fi
    fi

    show_event "SSH service is running."
}

start_apache2() {
    show_event "Checking Apache2 configuration"
    if ! command -v apache2 &> /dev/null; then
        show_event "ERROR - Apache2 is not installed. Please install it first."
        return 1
    fi

    # Check if Apache2 configuration is valid
    if ! sudo apache2ctl configtest &> /dev/null; then
        show_event "ERROR - Apache2 configuration test failed. Attempting to fix..."
        if ! sudo apache2ctl -t 2>/dev/null; then
            show_event "ERROR - Unable to identify configuration errors. Manual intervention required."
            return 1
        fi
    fi

    # Check if ports are available
    if netstat -tuln | grep -q ":80\|:443"; then
        show_event "WARNING - Ports 80/443 are in use. Checking what's using them..."
        local pid=$(sudo lsof -t -i:80,443 2>/dev/null)
        if [ -n "$pid" ]; then
            show_event "Found process using ports. Attempting to stop it..."
            sudo kill $pid
            sleep 2
        fi
    fi

    # Check service status and attempt to fix if not running
    if ! sudo systemctl is-active apache2 &> /dev/null; then
        show_event "Apache2 service is not running. Checking for issues..."

        # Check for file permissions
        if ! sudo chown -R www-data:www-data /var/www/html; then
            show_event "WARNING - Failed to set proper permissions on /var/www/html"
        fi

        # Attempt to start service
        show_event "Starting Apache2 service"
        if ! sudo systemctl start apache2; then
            show_event "ERROR - Failed to start Apache2 service. Attempting recovery..."
            
            # Try to stop and start again
            sudo systemctl stop apache2
            sleep 2
            if ! sudo systemctl start apache2; then
                show_event "ERROR - Recovery failed. Apache2 service could not be started."
                return 1
            fi
        fi
    fi

    # Verify service is actually running and responding
    if ! curl -s --head http://localhost &> /dev/null; then
        show_event "WARNING - Apache2 is running but not responding to requests. Restarting service..."
        sudo systemctl restart apache2
        sleep 2
        if ! curl -s --head http://localhost &> /dev/null; then
            show_event "ERROR - Apache2 is still not responding after restart."
            return 1
        fi
    fi

    show_event "Apache2 service is running and responding correctly."
}

start_vsftpd() {
    show_event "Checking VSFTPD configuration"
    if ! command -v vsftpd &> /dev/null; then
        show_event "ERROR - VSFTPD is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active vsftpd &> /dev/null; then
        show_event "Starting VSFTPD service"
        if ! sudo systemctl start vsftpd; then
            show_event "ERROR - Failed to start VSFTPD service."
            return 1
        fi
    fi

    show_event "VSFTPD service is running."
}

start_postgresql() {
    show_event "Checking PostgreSQL configuration"
    if ! command -v psql &> /dev/null; then
        show_event "ERROR - PostgreSQL is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active postgresql &> /dev/null; then
        show_event "Starting PostgreSQL service"
        if ! sudo systemctl start postgresql; then
            show_event "ERROR - Failed to start PostgreSQL service."
            return 1
        fi
    fi

    show_event "PostgreSQL service is running."
}

start_lldpd() {
    show_event "Checking LLDP configuration"
    if ! command -v lldpd &> /dev/null; then
        show_event "ERROR - LLDP is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active lldpd &> /dev/null; then
        show_event "Starting LLDP service"
        if ! sudo systemctl start lldpd; then
            show_event "ERROR - Failed to start LLDP service."
            return 1
        fi
    fi

    show_event "LLDP service is running."
}

start_smtp_sender() {
    show_event "Checking SMTP Sender configuration"
    if ! sudo systemctl is-active smtp-sender &> /dev/null; then
        if [ "$automatic_mode" = true ]; then
            show_event "Starting SMTP Sender service"
            if ! sudo systemctl start smtp-sender; then
                show_event "ERROR - Failed to start SMTP Sender service."
                return 1
            fi
            send_startup_email
        else
            read -p "Would you like to send a startup email? (y/n): " answer
            if [ "$answer" = "y" ]; then
                if ! sudo systemctl start smtp-sender; then
                    show_event "ERROR - Failed to start SMTP Sender service."
                    return 1
                fi
                send_startup_email
            fi
        fi
    fi

    show_event "SMTP Sender service is running."
}

start_all_adapters_and_ip_address() {
    show_event "Starting All Adapters and IP Address"
    if ! sudo /nsatt/storage/scripts/networking/set_ip_address.sh; then
        show_event "ERROR - Failed to start All Adapters and IP Address service."
    fi
}

start_vnc() {
    show_event "Starting VNC"

    # Check if VNC service is already running
    if systemctl is-active --quiet vncserver@1.service; then
        show_event "VNC service is already running"
        return 0
    fi

    # Check if vncserver package is installed
    if ! command -v vncserver >/dev/null 2>&1; then
        show_event "ERROR - VNC server is not installed. Installing tigervnc-standalone-server..."
        if ! sudo apt-get install -y tigervnc-standalone-server; then
            show_event "ERROR - Failed to install VNC server"
            return 1
        fi
    fi

    # Check if ~/.vnc directory exists, create if not
    if [ ! -d "$HOME/.vnc" ]; then
        mkdir -p "$HOME/.vnc"
    fi

    # Check if VNC password is set
    if [ ! -f "$HOME/.vnc/passwd" ]; then
        show_event "Setting up VNC password..."
        expect -c '
            spawn vncpasswd
            expect "Password:"
            send "nsatt\r"
            expect "Verify:"
            send "nsatt\r"
            expect "Would you like to enter a view-only password (y/n)?"
            send "n\r"
            expect eof
        ' >/dev/null 2>&1
    fi

    # Clone noVNC repository if it doesn't exist
    if [ ! -d "/nsatt/storage/scripts/nsatt_web/static/noVNC" ]; then
        show_event "Cloning noVNC repository..."
        cd /nsatt/storage/scripts/nsatt_web/static
        if ! git clone https://github.com/novnc/noVNC.git noVNC; then
            show_event "ERROR - Failed to clone noVNC repository"
            return 1
        fi
        cd noVNC
        ln -sf vnc_lite.html index.html
    fi

    # Start VNC service
    if ! systemctl start vncserver@1.service; then
        show_event "ERROR - Failed to start VNC service, attempting to fix..."
        
        # Kill any existing VNC processes
        pkill -f "Xvnc"
        pkill -f "vncserver"
        
        # Try starting VNC server directly
        if ! vncserver :1 -geometry 1920x1080 -depth 24; then
            show_event "ERROR - Failed to start VNC server directly"
            return 1
        fi
    fi

    # Verify service started successfully
    sleep 2
    if ! systemctl is-active --quiet vncserver@1.service && ! pgrep -f "Xvnc" >/dev/null; then
        show_event "ERROR - VNC service failed to start properly"
        return 1
    fi

    show_event "VNC service started successfully"
    show_event "VNC server is running on port 5901"
    show_event "Websockify is available on port 6080"
    return 0
}

########################################################
# Stop Services
########################################################

########################################################
# Stop Services Functions
########################################################

stop_services() {
    show_event "Stopping services"
    if [ -f "$AUTOSTART_HOTSPOT" ]; then
        stop_hotspot
    fi
    if [ -f "$AUTOSTART_VPN" ]; then
        stop_vpn
    fi
    sleep 2
    if [ -f "$AUTOSTART_SSH" ]; then
        stop_ssh
    fi
    sleep 2
    if [ -f "$AUTOSTART_APACHE2" ]; then
        stop_apache2
    fi
    sleep 2
    if [ -f "$AUTOSTART_VSFTPD" ]; then
        stop_vsftpd
    fi
    sleep 2
    if [ -f "$AUTOSTART_POSTGRESQL" ]; then
        stop_postgresql
    fi
    sleep 2
    if [ -f "$AUTOSTART_LLDP" ]; then
        stop_lldpd
    fi
    sleep 2
    if [ -f "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS" ]; then
        stop_all_adapters_and_ip_address
    fi
    sleep 2
    if [ -f "$AUTOSTART_SMTP_SENDER" ]; then
        stop_smtp_sender
    fi
    sleep 2
    if [ -f "$AUTOSTART_NETWORK_MANAGER_WEB_INTERFACE" ]; then
        stop_network_manager_web_interface
    fi
    sleep 2
    if [ -f "$AUTOSTART_VNC" ]; then
        stop_vnc
    fi
    sleep 2
    show_event "Services stopped."
}

stop_boot_service() {
    show_event "Stopping NSATT Boot service"
    if sudo systemctl stop nsatt_boot.service; then
        if sudo systemctl disable nsatt_boot.service; then
            show_event "NSATT Boot service stopped successfully."
        else
            show_event "ERROR - Failed to disable NSATT Boot service."
        fi
    else
        show_event "ERROR - Failed to stop NSATT Boot service."
    fi
}

stop_hotspot() {
    # Set debug flag: true for verbose, false for production
    local debug_testing=true

    # Utility function for verbose output
    log_event() {
        local message="$1"
        if [ "$debug_testing" = true ]; then
            echo "DEBUG: $message"
        fi
    }

    # Utility function for production checkpoint messages
    show_event() {
        local message="$1"
        echo "INFO: $message"
    }

    # Use the correct log function based on debug_testing
    checkpoint() {
        local message="$1"
        if [ "$debug_testing" = true ]; then
            log_event "$message"
        else
            show_event "$message"
        fi
    }

    checkpoint "Stopping Hotspot service..."
    if sudo systemctl is-active hostapd &>/dev/null; then
        log_event "hostapd is active. Attempting to stop the service."
        if sudo systemctl stop hostapd; then
            checkpoint "Hotspot service stopped successfully."
        else
            checkpoint "ERROR: Failed to stop Hotspot service. Exiting."
            return 1
        fi
    else
        checkpoint "Hotspot service is not running."
    fi

    # Detect actual hotspot device
    log_event "Checking for hotspot configuration in /etc/hostapd/hostapd.conf..."
    local actual_hotspot_device=""
    if [ -f "/etc/hostapd/hostapd.conf" ]; then
        actual_hotspot_device=$(grep "^interface=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
        log_event "Hostapd configuration specifies interface: $actual_hotspot_device"
    else
        log_event "No hostapd configuration file found."
    fi

    # Detect internet-sharing device via iptables
    log_event "Checking iptables for devices sharing internet..."
    local sharing_device=""
    if sudo iptables -t nat -L POSTROUTING -v -n | grep -q "eth0"; then
        sharing_device="eth0"
    elif sudo iptables -t nat -L POSTROUTING -v -n | grep -q "wlan1"; then
        sharing_device="wlan1"
    fi
    log_event "Sharing device detected via iptables: $sharing_device"

    # Determine device to reset
    local device_to_reset="${actual_hotspot_device:-$sharing_device}"
    if [ -z "$device_to_reset" ]; then
        checkpoint "No hotspot or sharing device detected. Exiting."
        return 0
    fi

    checkpoint "Device to reset: $device_to_reset (Hotspot: ${actual_hotspot_device:-unknown}, Sharing: ${sharing_device:-none})"

    # Cleanup iptables
    checkpoint "Flushing iptables and disabling IP forwarding..."
    if sudo iptables -t nat -F; then
        log_event "NAT table rules flushed successfully."
    else
        log_event "WARNING: Failed to flush NAT table rules."
    fi

    if sudo iptables -F; then
        log_event "All iptables rules flushed successfully."
    else
        log_event "WARNING: Failed to flush iptables rules."
    fi

    if sudo sysctl -w net.ipv4.ip_forward=0; then
        log_event "IP forwarding disabled successfully."
    else
        log_event "WARNING: Failed to disable IP forwarding."
    fi

    # Stop DHCP and DNS services
    checkpoint "Stopping DHCP and DNS services..."
    if sudo systemctl stop dnsmasq isc-dhcp-server &>/dev/null; then
        log_event "DHCP and DNS services stopped successfully."
    else
        log_event "WARNING: DHCP and DNS services might not have been running."
    fi

    # Restore original DNS configuration if backup exists
    if [ -f "/etc/dnsmasq.conf.backup" ]; then
        if sudo mv "/etc/dnsmasq.conf.backup" "/etc/dnsmasq.conf"; then
            log_event "Restored dnsmasq configuration from backup."
        else
            log_event "WARNING: Failed to restore dnsmasq configuration from backup."
        fi
    fi

    # Reset network device state
    checkpoint "Resetting network state for $device_to_reset..."
    if sudo ip addr flush dev "$device_to_reset"; then
        log_event "IP addresses flushed for $device_to_reset."
    else
        log_event "WARNING: Failed to flush IP addresses for $device_to_reset."
    fi

    if sudo ip link set "$device_to_reset" down; then
        log_event "Set $device_to_reset down successfully."
    else
        log_event "WARNING: Failed to bring $device_to_reset down."
    fi

    # Restart NetworkManager
    checkpoint "Restarting NetworkManager service..."
    if sudo systemctl restart NetworkManager; then
        log_event "NetworkManager restarted successfully."
    else
        checkpoint "ERROR: Failed to restart NetworkManager. Exiting."
        return 1
    fi

    # Ensure the device is managed
    checkpoint "Ensuring $device_to_reset is managed by NetworkManager..."
    if sudo nmcli device set "$device_to_reset" managed yes; then
        log_event "$device_to_reset is now managed by NetworkManager."
    else
        log_event "WARNING: Failed to set $device_to_reset as managed."
    fi

    # Bring the device up
    checkpoint "Bringing up $device_to_reset..."
    if sudo ip link set "$device_to_reset" up; then
        log_event "$device_to_reset is up."
    else
        log_event "WARNING: Failed to bring $device_to_reset up."
    fi

    # Configure for DHCP
    checkpoint "Configuring $device_to_reset for DHCP..."
    sudo dhclient -r "$device_to_reset" &>/dev/null
    if sudo dhclient "$device_to_reset" &>/dev/null; then
        log_event "DHCP successfully configured on $device_to_reset."
    else
        log_event "WARNING: DHCP failed for $device_to_reset."
    fi

    # Check for an IP address
    if ip addr show "$device_to_reset" | grep -q "inet "; then
        checkpoint "$device_to_reset obtained an IP address via DHCP."
    else
        log_event "No IP address obtained for $device_to_reset. Attempting NetworkManager configuration."
        if sudo nmcli device connect "$device_to_reset"; then
            log_event "$device_to_reset connected via NetworkManager."
        else
            log_event "WARNING: NetworkManager failed to connect $device_to_reset."
        fi
    fi

    # Final state verification
    checkpoint "Verifying final network state for $device_to_reset..."
    local final_state
    final_state=$(ip addr show "$device_to_reset" || echo "ERROR: Unable to retrieve IP configuration for $device_to_reset.")
    log_event "Final state of $device_to_reset:\n$final_state"

    local nmcli_status
    nmcli_status=$(nmcli device status | grep "$device_to_reset" || echo "ERROR: Unable to retrieve NetworkManager status.")
    log_event "NetworkManager status for $device_to_reset:\n$nmcli_status"

    checkpoint "Hotspot cleanup completed. Verify network connectivity."
}

try_connect_to_known_network() {
    local interface="$1"
    local known_networks_dir="/etc/NetworkManager/system-connections"

    show_event "Attempting to connect interface '$interface' to a known network."

    # Check if the known networks directory exists
    if [ ! -d "$known_networks_dir" ]; then
        show_event "ERROR - Known networks directory '$known_networks_dir' does not exist. Cannot proceed with connection."
        return 1
    fi

    # Get list of available WiFi networks
    local available_networks
    available_networks=$(sudo nmcli -t -f SSID device wifi list ifname "$interface" 2>/dev/null | sort -u)
    if [ -z "$available_networks" ]; then
        show_event "WARNING - No WiFi networks detected in range of interface '$interface'."
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
                show_event "Found known network '$network_name' in range. Attempting to connect."

                # Use nmcli to connect to the network with retries
                local max_attempts=3
                for attempt in $(seq 1 $max_attempts); do
                    show_event "Attempt $attempt: Connecting to network '$network_name' on interface '$interface'."
                    
                    if sudo nmcli device wifi connect "$network_name" ifname "$interface"; then
                        show_event "Successfully connected interface '$interface' to network '$network_name'."
                        connection_success=true
                        break 2
                    else
                        show_event "WARNING - Failed to connect to network '$network_name' on attempt $attempt."
                        
                        if [ $attempt -lt $max_attempts ]; then
                            local retry_delay=$((attempt * 5))
                            show_event "Retrying in $retry_delay seconds..."
                            sleep $retry_delay
                        fi
                    fi
                done
            else
                show_event "DEBUG - Known network '$network_name' is not currently in range."
            fi
        fi
    done

    if [ "$connection_success" = true ]; then
        show_event "Interface '$interface' successfully connected to a known network."
        return 0
    else
        show_event "ERROR - Unable to connect interface '$interface' to any known networks in range."
        return 1
    fi
}

stop_vpn() {
    show_event "Stopping Tailscale VPN service"
    if sudo systemctl is-active tailscaled &> /dev/null; then
        if sudo systemctl stop tailscaled; then
            show_event "Tailscale VPN service stopped successfully."
        else
            show_event "ERROR - Failed to stop Tailscale VPN service."
        fi
    else
        show_event "Tailscale VPN service is not running."
    fi
}

stop_ssh() {
    show_event "Stopping SSH service"
    if sudo systemctl is-active ssh &> /dev/null; then
        if sudo systemctl stop ssh; then
            show_event "SSH service stopped successfully."
        else
            show_event "ERROR - Failed to stop SSH service."
        fi
    else
        show_event "SSH service is not running."
    fi
}

stop_apache2() {
    show_event "Stopping Apache2 service"
    if sudo systemctl is-active apache2 &> /dev/null; then
        if sudo systemctl stop apache2; then
            show_event "Apache2 service stopped successfully."
        else
            show_event "ERROR - Failed to stop Apache2 service."
        fi
    else
        show_event "Apache2 service is not running."
    fi
}

stop_vsftpd() {
    show_event "Stopping VSFTPD service"
    if sudo systemctl is-active vsftpd &> /dev/null; then
        if sudo systemctl stop vsftpd; then
            show_event "VSFTPD service stopped successfully."
        else
            show_event "ERROR - Failed to stop VSFTPD service."
        fi
    else
        show_event "VSFTPD service is not running."
    fi
}

stop_postgresql() {
    show_event "Stopping PostgreSQL service"
    if sudo systemctl is-active postgresql &> /dev/null; then
        if sudo systemctl stop postgresql; then
            show_event "PostgreSQL service stopped successfully."
        else
            show_event "ERROR - Failed to stop PostgreSQL service."
        fi
    else
        show_event "PostgreSQL service is not running."
    fi
}

stop_lldpd() {
    show_event "Stopping LLDPD service"
    if sudo systemctl is-active lldpd &> /dev/null; then
        if sudo systemctl stop lldpd; then
            show_event "LLDPD service stopped successfully."
        else
            show_event "ERROR - Failed to stop LLDPD service."
        fi
    else
        show_event "LLDPD service is not running."
    fi
}

stop_all_adapters_and_ip_address() {
    show_event "Stopping All Adapters and IP Address service"
    if sudo systemctl is-active set_ip_address &> /dev/null; then
        if sudo systemctl stop set_ip_address; then
            show_event "All Adapters and IP Address service stopped successfully."
        else
            show_event "ERROR - Failed to stop All Adapters and IP Address service."
        fi
    else
        show_event "All Adapters and IP Address service is not running."
    fi
}

stop_smtp_sender() {
    show_event "Stopping SMTP Sender service"
    if sudo systemctl is-active smtp-sender &> /dev/null; then
        if sudo systemctl stop smtp-sender; then
            show_event "SMTP Sender service stopped successfully."
        else
            show_event "ERROR - Failed to stop SMTP Sender service."
        fi
    else
        show_event "SMTP Sender service is not running."
    fi
}

stop_vnc() {
    show_event "Stopping VNC"
    if systemctl is-active --quiet vncserver@1.service; then
        systemctl stop vncserver@1.service
        show_event "VNC service stopped successfully."
    else
        show_event "VNC service is not running."
    fi
}

stop_network_manager_web_interface() {
    show_event "Stopping Network Manager Web Interface"
    # Find and kill all instances of the web interface script
    if pgrep -f "network_manager_web_interface.py" > /dev/null; then
        if sudo pkill -f "network_manager_web_interface.py"; then
            show_event "Network Manager Web Interface stopped successfully."
        else
            show_event "ERROR - Failed to stop Network Manager Web Interface."
        fi
    else
        show_event "Network Manager Web Interface is not running."
    fi
}

stop_launcher() {
    show_event "Stopping NSATT Launcher"
    # Kill any remaining launcher processes
    if pgrep -f "start_app_launcher.py" > /dev/null; then
        if sudo pkill -f "start_app_launcher.py"; then
            show_event "Launcher process killed successfully."
        else
            show_event "ERROR - Failed to kill launcher process."
        fi
    fi
}

stop_nsatt() {
    # Kill launch_nsatt script if running
    if pgrep -f "launch_nsatt.py" > /dev/null; then
        if sudo pkill -f "launch_nsatt.py"; then
            show_event "launch_nsatt.py process killed successfully."
        else
            show_event "ERROR - Failed to kill launch_nsatt.py process."
        fi
    fi

    # Kill app.py if running
    if pgrep -f "/nsatt/storage/scripts/nsatt_web/app.py" > /dev/null; then
        if sudo pkill -f "/nsatt/storage/scripts/nsatt_web/app.py"; then
            show_event "app.py process killed successfully."
        else
            show_event "ERROR - Failed to kill app.py process."
        fi
    fi
}

########################################################
# NSATT Scripts
########################################################

reload_files_and_permissions() {
    show_event "Reloading files and permissions"
    if sudo /nsatt/storage/scripts/utility/reload_files_and_permissions.sh; then
        show_event "Files and permissions reloaded successfully."
    else
        show_event "ERROR - Failed to reload files and permissions."
    fi
    return 0
}

restart_launcher() {
    show_event "Restarting Launcher"
    if sudo /nsatt/storage/scripts/utility/restart_launcher.sh > /dev/null 2>&1 & then
        show_event "Launcher restarted successfully."
    else
        show_event "ERROR - Failed to restart Launcher."
    fi
}

fix_login_issue() {
    show_event "Fixing login issue"
    if sudo /nsatt/storage/scripts/recovery/fix_login_issue.sh; then
        show_event "Login issue fixed successfully."
    else
        show_event "ERROR - Failed to fix login issue."
    fi
}

start_network_manager_web_interface() {
    show_event "Starting Network Manager Web Interface"
    if sudo /nsatt/storage/scripts/nsatt_web/network_manager_web_interface.py > /dev/null 2>&1 & then
        show_event "Network Manager Web Interface started successfully."
    else
        show_event "ERROR - Failed to start Network Manager Web Interface."
    fi
}

########################################################
# Main Program
########################################################

# Main program
main_program() {
    echo "----------------------------------------"
    echo "----------------------------------------"    
    echo "       _   _______ ___  ____________    "
    echo "      / | / / ___//   |/_  __/_  __/    "
    echo "     /  |/ /\__ \/ /| | / /   / /       "
    echo "    / /|  /___/ / ___ |/ /   / /        "
    echo "   /_/ |_//____/_/  |_/_/   /_/         "
    echo "                                        "
    echo "----------------------------------------"
    echo "----------------------------------------"
    echo "Automatic mode: $automatic_mode"
    echo "----------------------------------------"
    echo "----------------------------------------"
    echo "Created by TSTP"
    echo "https://www.tstp.xyz"
    echo "----------------------------------------"
    echo "----------------------------------------"
    # If first install file found, check automatic mode
    if [ -f "$FIRST_INSTALL_FILE" ]; then
        if [ "$automatic_mode" = true ]; then
            nsatt_boot
        else
            manual_mode
        fi
    else
        first_install
    fi
}

########################################################
# First Install
########################################################

# First Install
first_install() {
    echo "----------------------------------------"
    echo "----------------------------------------"
    echo "Automatic mode: $automatic_mode"
    echo "----------------------------------------"
    echo "----------------------------------------"
    echo "Starting NSATT Setup"
    echo "----------------------------------------"
    echo "----------------------------------------"
    echo "Creating folders"
    create_folders
    echo "Creating users"
    create_users
    echo "Creating settings"
    create_settings
    echo "Updating and upgrading"
    update_and_upgrade
    echo "Setting up services"
    setup_services
    echo "Creating boot service"
    create_boot_service
    echo "First install completed"
    first_install_completed

}

########################################################
# NSATT Boot
########################################################

# NSATT Boot
nsatt_boot() {
    echo ""
    echo ""
    echo "----------------------------------------"
    echo "Starting NSATT services"
    echo "----------------------------------------"
    if [ "$automatic_mode" = true ]; then
        show_event "INFO - Starting services automatically..."
        reload_files_and_permissions
        stop_services
        start_services
    else
        read -p "Do you want to start the NSATT services? (y/n): " user_input
        if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
            show_event "INFO - Starting services..."
            start_services
        else
            show_event "INFO - Services will not be started."
        fi
    fi
    return
}

manual_mode() {
    echo ""
    echo ""
    echo "----------------------------------------"
    echo "Running in manual mode."
    echo "----------------------------------------"
    echo "Select an option:"
    echo "1 - First Install"
    echo "2 - NSATT Boot"
    echo "3 - Setup Services"
    echo "4 - Start Services"
    echo "5 - Stop Services"
    echo "6 - NSATT Scripts"
    echo "7 - Exit Manual Mode"
    read -p "Enter your choice (1-7): " main_choice

    case $main_choice in
        1)
            first_install
            ;;
        2)
            nsatt_boot
            ;;
        3)
            manual_setup_mode
            ;;
        4)
            manual_start_mode
            ;;
        5)
            manual_stop_mode
            ;;
        6)
            manual_scripts_mode
            ;;
        7)
            echo "Exiting Manual Mode."
            return
            ;;
        *)
            echo "Invalid choice. Please select 1, 2, 3, 4, 5, 6, or 7."
            ;;
    esac
    return
}

manual_scripts_mode() {
    while true; do
        echo ""
        echo ""
        echo ""
        echo "----------------------------------------"
        echo "Listing scripts:"
        echo "----------------------------------------"
        echo "1 - Set IP Address"
        echo "2 - Restart Launcher"
        echo "3 - Reload Files and Permissions"
        echo "4 - Fix Login Issue"
        echo "5 - Start Network Manager Web Interface"
        echo "6 - Exit Manual Scripts Mode"
        echo "7 - Back to Manual Mode"
        read -p "Enter your choice (1-7): " scripts_choice
        case $scripts_choice in
            1) setup_ip_address ;;
            2) restart_launcher ;;
            3) reload_files_and_permissions ;;
            4) fix_login_issue ;;
            5) start_network_manager_web_interface ;;
            6) return ;;
            7) manual_mode; return ;;
            *) echo "Invalid choice. Please select 1, 2, 3, 4, 5, 6, or 7." ;;
        esac
    done
}

manual_setup_mode() {
    echo ""
    echo ""
    echo ""
    echo "----------------------------------------"
    echo "Listing services to setup:"
    echo "----------------------------------------"
    services=("NSATT Application" "NSATT Auto Boot" "Hotspot" "VPN" "SSH" "Apache2" "VSFTPD" "PostgreSQL" "LLDPD" "SMTP Sender" "All Adapters and IP Address" "VNC" "Network Manager Web Interface" "Launcher" "Back to Manual Mode")
    echo "Select a service to setup:"
    for i in "${!services[@]}"; do
        echo "$((i + 1)) - ${services[$i]}"
    done
    read -p "Enter your choice (1-15): " setup_choice
    case $setup_choice in
        1) setup_nsatt ;;
        2) setup_boot_service ;;
        3) setup_hotspot ;;
        4) setup_vpn ;;
        5) setup_ssh ;;
        6) setup_apache2 ;;
        7) setup_vsftpd ;;
        8) setup_postgresql ;;
        9) setup_lldpd ;;
        10) setup_smtp_sender ;;
        11) setup_all_adapters_and_ip_address ;;
        12) setup_vnc ;;
        13) setup_network_manager_web_interface ;;
        14) setup_launcher ;;
        15) manual_mode; return ;;
        *) echo "Invalid choice. Please select a valid option." ;;
    esac

    if [[ $setup_choice -ge 1 && $setup_choice -le 15 ]]; then
        read -p "Do you want to start the selected service? (y/n): " start_input
        if [[ "$start_input" == "yes" || "$start_input" == "y" ]]; then
            case $setup_choice in
                1) start_nsatt ;;
                2) start_boot_service ;;
                3) start_hotspot ;;
                4) start_vpn ;;
                5) start_ssh ;;
                6) start_apache2 ;;
                7) start_vsftpd ;;
                8) start_postgresql ;;
                9) start_lldpd ;;
                10) start_smtp_sender ;;
                11) start_all_adapters_and_ip_address ;;
                12) start_vnc ;;
                13) start_network_manager_web_interface ;;
                14) restart_launcher ;;
                15) manual_mode; return ;;
            esac
        else
            echo "Service will not be started."
        fi
    fi

    manual_start_mode
}

manual_start_mode() {
    echo ""
    echo ""
    echo ""
    echo "----------------------------------------"
    echo "Listing services to start:"
    echo "----------------------------------------"
    services=("NSATT Application" "NSATT Auto Boot" "Hotspot" "VPN" "SSH" "Apache2" "VSFTPD" "PostgreSQL" "LLDPD" "SMTP Sender" "All Adapters and IP Address" "VNC" "Network Manager Web Interface" "Launcher" "Back to Manual Mode")
    echo "Select a service to start:"
    for i in "${!services[@]}"; do
        echo "$((i + 1)) - ${services[$i]}"
    done
    read -p "Enter your choice (1-15): " start_choice
    case $start_choice in
        1) start_nsatt ;;
        2) start_boot_service ;;
        3) start_hotspot ;;
        4) start_vpn ;;
        5) start_ssh ;;
        6) start_apache2 ;;
        7) start_vsftpd ;;
        8) start_postgresql ;;
        9) start_lldpd ;;
        10) start_smtp_sender ;;
        11) start_all_adapters_and_ip_address ;;
        12) start_vnc ;;
        13) start_network_manager_web_interface ;;
        14) restart_launcher ;;
        15) manual_mode; return ;;
        *) echo "Invalid choice. Please select a valid option." ;;
    esac

    manual_mode
}

manual_stop_mode() {
    echo ""
    echo ""
    echo ""
    echo "----------------------------------------"
    echo "Listing services to stop:"
    echo "----------------------------------------"
    services=("NSATT Application" "NSATT Auto Boot" "Hotspot" "VPN" "SSH" "Apache2" "VSFTPD" "PostgreSQL" "LLDPD" "SMTP Sender" "All Adapters and IP Address" "VNC" "Network Manager Web Interface" "Launcher" "Back to Manual Mode")
    echo "Select a service to stop:"
    for i in "${!services[@]}"; do
        echo "$((i + 1)) - ${services[$i]}"
    done
    read -p "Enter your choice (1-15): " stop_choice
    case $stop_choice in
        1) stop_nsatt ;;
        2) stop_boot_service ;;
        3) stop_hotspot ;;
        4) stop_vpn ;;
        5) stop_ssh ;;
        6) stop_apache2 ;;
        7) stop_vsftpd ;;
        8) stop_postgresql ;;
        9) stop_lldpd ;;
        10) stop_smtp_sender ;;
        11) stop_all_adapters_and_ip_address ;;
        12) stop_vnc ;;
        13) stop_network_manager_web_interface ;;
        14) stop_launcher ;;
        15) manual_mode; return ;;
        *) echo "Invalid choice. Please select a valid option." ;;
    esac

    manual_mode
}

########################################################
# End of script
########################################################

main_program

# End of script
exit 0

########################################################