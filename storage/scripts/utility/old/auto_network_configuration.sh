#!/bin/bash

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
LOG_FILE="$LOG_DIR/auto_network_configuration_$(date '+%Y-%m-%d').log"
SMTP_SETTINGS_FILE="/nsatt/storage/settings/smtp_settings.conf"
ENCRYPTED_SMTP_SETTINGS_FILE="/nsatt/storage/settings/smtp_settings.enc"

########################################################
# Script Paths
########################################################

START_ALL_ADAPTERS_AND_IP_ADDRESS="/nsatt/start_all_adapters_and_ip_address.sh"

########################################################
# Settings File Locations
########################################################

FIRST_INSTALL_FILE="/nsatt/storage/settings/first_install.nsatt"
AUTOSTART_HOTSPOT="/nsatt/storage/settings/autostart_hotspot.nsatt"
AUTOSTART_VPN="/nsatt/storage/settings/autostart_vpn.nsatt"
AUTOSTART_SSH="/nsatt/storage/settings/autostart_ssh.nsatt"
AUTOSTART_APACHE2="/nsatt/storage/settings/autostart_apache2.nsatt"
AUTOSTART_VSFTPD="/nsatt/storage/settings/autostart_vsftpd.nsatt"
AUTOSTART_POSTGRESQL="/nsatt/storage/settings/autostart_postgresql.nsatt"
AUTOSTART_LLDP="/nsatt/storage/settings/autostart_lldpd.nsatt"
AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS="/nsatt/storage/settings/autostart_all_adapters_and_ip_address.nsatt"
AUTOSTART_SMTP_SENDER="/nsatt/storage/settings/autostart_smtp_sender.nsatt"
automatic_mode_file="/nsatt/storage/settings/automatic_mode.nsatt"
NSATT_ADMIN_EMAIL_FILE="/nsatt/storage/settings/nsatt_admin_email.nsatt"
automatic_mode=false
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
    autostart_files=("$AUTOSTART_HOTSPOT" "$AUTOSTART_VPN" "$AUTOSTART_SSH" "$AUTOSTART_APACHE2" "$AUTOSTART_VSFTPD" "$AUTOSTART_POSTGRESQL" "$AUTOSTART_LLDP" "$AUTOSTART_SMTP_SENDER" "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS")
    
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
    show_event "SMTP Sender: $(if [ -f "$AUTOSTART_SMTP_SENDER" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event "All Adapters and IP Address: $(if [ -f "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS" ]; then show_event "Enabled"; else show_event "Disabled"; fi)"
    show_event ""
}

########################################################
# SMTP Settings Functions
########################################################

# Create smtp settings file if not found and ask user for settings
create_smtp_settings() {
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

# Load encrypted smtp settings file
load_smtp_settings() {
    show_event "Loading encrypted SMTP settings"
}

# Load smtp file, validate it, create encrypted smtp settings file, test them, confirm they are correct, and remove original file.
create_encrypted_smtp_settings() {
    show_event "Creating encrypted SMTP settings file"
    if ! openssl enc -aes-256-cbc -salt -in "$SMTP_SETTINGS_FILE" -out "$ENCRYPTED_SMTP_SETTINGS_FILE"; then
        show_event "ERROR - Failed to create encrypted SMTP settings file"
        return 1
    fi

    # Send test email to confirm settings are correct
    show_event "Sending test email to confirm settings are correct"
    if ! echo "Test email" | mail -s "Test Email" "$smtp_username"@"$smtp_server"; then
        show_event "ERROR - Failed to send test email"
        return 1
    fi
    show_event "Test email sent"

    show_event "Encrypted SMTP settings file created"
    if ! rm "$SMTP_SETTINGS_FILE"; then
        show_event "ERROR - Failed to remove original SMTP settings file"
        return 1
    fi
    show_event "Original SMTP settings file removed"
}

########################################################
# System Functions
########################################################

# Required packages (openssl, curl, wget, git, etc.)
REQUIRED_PACKAGES=("openssl" "curl" "wget" "git" "vsftpd" "apache2" "postgresql" "lldpd" 
    "openvpn" "ssh" "hostapd" "mailutils" "dnsmasq" "nmap" "python3-pip" "python3-requests"
    "python3-flask" "python3-netifaces" "python3-nmap" "python3-pymetasploit3" "python3-netmiko"
    "sqlite3" "jq" "libapache2-mod-wsgi-py3" "apache2-utils" "traceroute" "udev" "net-tools"
    "iptables-persistent")
PIP_PACKAGES=("requests" "netifaces" "netmiko" "pymetasploit3" "flask")

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

    show_event "Services setup"
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
    show_event "Setting up VPN"
    # Initial framework for setting up VPN
    if ! command -v openvpn &> /dev/null; then
        show_event "ERROR - OpenVPN is not installed. Please install it first."
        return 1
    fi

    # Install and configure OpenVPN
    if ! sudo apt-get install -y openvpn; then
        show_event "ERROR - Failed to install OpenVPN."
        return 1
    fi

    local openvpn_conf="/etc/openvpn/server.conf"
    echo "port 1194" | sudo tee "$openvpn_conf" > /dev/null
    echo "proto udp" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "dev tun" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "ca ca.crt" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "cert server.crt" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "key server.key" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "dh dh2048.pem" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "server 10.8.0.0 255.255.255.0" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "ifconfig-pool-persist ipp.txt" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "keepalive 10 120" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "cipher AES-256-CBC" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "user nobody" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "group nogroup" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "persist-key" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "persist-tun" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "status openvpn-status.log" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "log-append /var/log/openvpn.log" | sudo tee -a "$openvpn_conf" > /dev/null
    echo "verb 3" | sudo tee -a "$openvpn_conf" > /dev/null

    if ! sudo systemctl enable openvpn; then
        show_event "ERROR - Failed to enable OpenVPN service."
        return 1
    fi

    if ! sudo systemctl start openvpn; then
        show_event "ERROR - Failed to start OpenVPN service."
        return 1
    fi

    show_event "INFO - VPN setup completed successfully."
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

    # Check if jq is installed for CONF parsing
    if ! command -v jq &> /dev/null; then
        show_event "ERROR - jq is not installed. Please install it first."
        return 1
    fi

    # Remove existing service and script if they exist
    local service_file="/etc/systemd/system/smtp-sender.service"
    local smtp_script="/nsatt/storage/scripts/utility/smtp_sender.sh"

    if [ -f "$service_file" ]; then
        sudo systemctl stop smtp-sender
        sudo systemctl disable smtp-sender
        sudo rm -f "$service_file"
        show_event "Removed existing SMTP Sender service."
    fi

    if [ -f "$smtp_script" ]; then
        sudo rm -f "$smtp_script"
        show_event "Removed existing SMTP Sender script."
    fi

    # Create the smtp-sender.service file
    sudo bash -c "cat > $service_file" <<EOL
[Unit]
Description=SMTP Sender Service
After=network.target

[Service]
Type=simple
ExecStart=/nsatt/storage/scripts/utility/smtp_sender.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    # Create the script that will send the email
    sudo bash -c "cat > $smtp_script" <<'EOL'
#!/bin/bash

# Load SMTP configuration
config_file="/nsatt/settings/storage/smtp_config.conf"

# Check if the config file exists
if [ ! -f "$config_file" ]; then
    echo "ERROR - SMTP configuration file not found. Please create it at $config_file."
    exit 1
fi

# Read configuration values
smtp_server=$(jq -r '.smtp_server' "$config_file")
smtp_port=$(jq -r '.smtp_port' "$config_file")
smtp_user=$(jq -r '.smtp_user' "$config_file")
smtp_password=$(jq -r '.smtp_password_encrypted' "$config_file")
recipient_email=$(jq -r '.recipient_email' "$config_file")

# Confirm configurations
if [ -z "$smtp_server" ] || [ -z "$smtp_port" ] || [ -z "$smtp_user" ]; then
    echo "ERROR - SMTP configuration is incomplete. Please check the configuration file."
    exit 1
fi

# Ensure recipient_email is set
if [ -z "$recipient_email" ]; then
    echo "ERROR - Recipient email is not set. Please check the configuration file."
    exit 1
fi

# Example of sending an email
echo -e "Subject: Test Email\n\nThis is a test email." | /usr/sbin/sendmail -t "$recipient_email"
EOL

    # Make the script executable
    sudo chmod +x "$smtp_script"

    # Ask the user if they want to send a test email
    read -p "Do you want to send a test email now? (y/n): " send_email
    if [ "$send_email" = "y" ]; then
        # Use NSATT_ADMIN_EMAIL if recipient_email is empty
        local email_to_send="${recipient_email:-$NSATT_ADMIN_EMAIL}"

        # If both are empty, ask the user for a new email
        if [ -z "$email_to_send" ]; then
            read -p "No recipient email found. Please enter a new email address: " new_email
            email_to_send="$new_email"
            # Optionally, save the new email to NSATT_ADMIN_EMAIL_FILE
            echo "$new_email" > "$NSATT_ADMIN_EMAIL_FILE"
        fi

        # Ensure the email is in the correct format
        if ! echo "$email_to_send" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
            show_event "ERROR - Invalid email format: $email_to_send. Please check the email address."
            return 1
        fi

        # Prepare the email content
        email_content="To: $email_to_send\nSubject: Test Email\n\nThis is a test email."

        # Send the email and handle errors
        if ! echo -e "$email_content" | /usr/sbin/sendmail -t; then
            if [ "$debug_mode" = true ]; then
                show_event "DEBUG - Failed to send email to $email_to_send. Check SMTP configuration."
            fi
            show_event "ERROR - Failed to send test email. Please check your SMTP configuration."
            return 1
        fi

        show_event "INFO - Test email sent successfully to $email_to_send."
    else
        show_event "INFO - Test email not sent."
    fi

    # Reload systemd to recognize the new service
    if ! sudo systemctl daemon-reload; then
        show_event "ERROR - Failed to reload systemd daemon."
        return 1
    fi

    # Enable and start the smtp-sender service
    if ! sudo systemctl enable smtp-sender; then
        show_event "ERROR - Failed to enable smtp-sender service."
        return 1
    fi

    # Introduce a delay before starting the service
    sleep 2

    if ! sudo systemctl start smtp-sender; then
        show_event "ERROR - Failed to start smtp-sender service."
        return 1
    fi

    show_event "INFO - SMTP sender setup completed successfully."
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
    if [ -f "$AUTOSTART_ALL_ADAPTERS_AND_IP_ADDRESS" ]; then
        start_all_adapters_and_ip_address
    fi
    if [ -f "$AUTOSTART_SMTP_SENDER" ]; then
        start_smtp_sender
    fi
    show_event "Services started:"
    validate_settings
}

create_boot_service() {
    show_event "Do you want to install the boot service? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        # Create a service from this script so that it is called on boot - After that, validate the boot service - send errors to show_event 
        if sudo chmod +x /nsatt/storage/scripts/utility/auto_network_configuration.sh && \
           sudo update-rc.d /nsatt/storage/scripts/utility/auto_network_configuration.sh defaults; then
            if validate_boot_service; then
                show_event "NSATT Boot service installed successfully."
            else
                show_event "ERROR - Failed to install NSATT Boot service."
            fi
        else
            show_event "ERROR - Failed to create NSATT Boot service."
        fi
    else
        show_event "NSATT Boot service installation canceled."
    fi
}

validate_boot_service() {
    if ! sudo systemctl is-enabled /nsatt/storage/scripts/utility/auto_network_configuration.sh; then
        if ! sudo systemctl enable /nsatt/storage/scripts/utility/auto_network_configuration.sh; then
            show_event "ERROR - Failed to enable NSATT Boot service."
        else
            show_event "NSATT Boot service enabled successfully."
        fi
    else
        show_event "NSATT Boot service is already enabled."
    fi
}

start_hotspot() {
    show_event "Checking hotspot configuration"
    if ! command -v hostapd &> /dev/null; then
        show_event "ERROR - hostapd is not installed. Please install it first."
        return 1
    fi

    if sudo systemctl is-active hostapd &> /dev/null; then
        show_event "Hotspot service is currently running. Bringing it down first."
        if ! sudo systemctl stop hostapd; then
            show_event "ERROR - Failed to stop hotspot service."
            return 1
        fi
    fi

    # Check for internet connectivity through eth0 or wlan1
    eth0_available=false
    wlan1_available=false

    if ip link show eth0 &> /dev/null && ip addr show eth0 | grep -q "inet "; then
        eth0_available=true
    fi

    if ip link show wlan1 &> /dev/null && ip addr show wlan1 | grep -q "inet "; then
        wlan1_available=true
    fi

    if [ "$automatic_mode" = true ]; then
        if [ "$eth0_available" = true ]; then
            show_event "Automatic mode: eth0 is available. Routing traffic through eth0."
            sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        elif [ "$wlan1_available" = true ]; then
            show_event "Automatic mode: eth0 is not available. Routing traffic through wlan1."
            sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
        else
            show_event "ERROR - Neither eth0 nor wlan1 is available for internet connectivity."
            return 1
        fi
    else
        if [ "$eth0_available" = true ] && [ "$wlan1_available" = true ]; then
            show_event "Both eth0 and wlan1 are available. Please select which one to use for routing:"
            select choice in "eth0" "wlan1"; do
                case $choice in
                    eth0)
                        show_event "Routing traffic through eth0."
                        sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
                        break
                        ;;
                    wlan1)
                        show_event "Routing traffic through wlan1."
                        sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
                        break
                        ;;
                    *)
                        show_event "Invalid selection. Please choose eth0 or wlan1."
                        ;;
                esac
            done
        elif [ "$eth0_available" = true ]; then
            show_event "Only eth0 is available. Routing traffic through eth0."
            sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        elif [ "$wlan1_available" = true ]; then
            show_event "Only wlan1 is available. Routing traffic through wlan1."
            sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
        else
            show_event "ERROR - Neither eth0 nor wlan1 is available for internet connectivity."
            return 1
        fi
    fi

    show_event "Starting hotspot"
    if ! sudo systemctl start hostapd; then
        show_event "Failed to start hotspot service. Checking if the service is masked."
        if sudo systemctl is-enabled hostapd 2>/dev/null | grep -q "masked"; then
            show_event "hostapd service is masked. Attempting to unmask."
            if sudo systemctl unmask hostapd; then
                show_event "Successfully unmasked hostapd. Attempting to start again."
                if ! sudo systemctl start hostapd; then
                    show_event "ERROR - Failed to start hotspot service after unmasking."
                fi
            else
                show_event "ERROR - Failed to unmask hostapd service."
            fi
        else
            show_event "ERROR - Failed to start hotspot service for an unknown reason."
        fi
    fi
}

start_vpn() {
    show_event "Checking VPN configuration"
    VPN_CONFIG_DIR="/etc/openvpn"
    VPN_CONFIG_FILE="$VPN_CONFIG_DIR/openvpn.conf"

    if ! command -v openvpn &> /dev/null; then
        show_event "ERROR - OpenVPN is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active openvpn &> /dev/null; then
        show_event "VPN service is not running."
        read -p "Would you like to configure the VPN now? (y/n): " answer
        if [ "$answer" = "y" ]; then
            setup_vpn
        else
            show_event "VPN setup aborted."
            return 1
        fi
    else
        show_event "Starting VPN"
        if ! sudo systemctl start openvpn; then
            show_event "ERROR - Failed to start VPN service."
        else
            show_event "VPN service started successfully."
        fi
    fi
}

start_ssh() {
    show_event "Checking SSH configuration"
    if ! command -v sshd &> /dev/null; then
        show_event "ERROR - OpenSSH server is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active ssh &> /dev/null; then
        show_event "SSH service is not running."
        read -p "Would you like to set up SSH now? (y/n): " answer
        if [ "$answer" = "y" ]; then
            setup_ssh
        else
            show_event "SSH setup aborted."
            return 1
        fi
    else
        show_event "Starting SSH"
        if ! sudo systemctl start ssh; then
            show_event "ERROR - Failed to start SSH service."
        fi
    fi
}

start_apache2() {
    show_event "Checking Apache2 configuration"
    if ! command -v apache2 &> /dev/null; then
        show_event "ERROR - Apache2 is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active apache2 &> /dev/null; then
        show_event "Apache2 service is not running."
        read -p "Would you like to set up Apache2 now? (y/n): " answer
        if [ "$answer" = "y" ]; then
            setup_apache2
        else
            show_event "Apache2 setup aborted."
            return 1
        fi
    else
        show_event "Starting Apache2"
        if ! sudo systemctl start apache2; then
            show_event "ERROR - Failed to start Apache2 service."
        fi
    fi
}

start_vsftpd() {
    show_event "Checking VSFTPD configuration"
    if ! command -v vsftpd &> /dev/null; then
        show_event "ERROR - VSFTPD is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active vsftpd &> /dev/null; then
        show_event "VSFTPD service is not running."
        read -p "Would you like to set up VSFTPD now? (y/n): " answer
        if [ "$answer" = "y" ]; then
            setup_vsftpd
        else
            show_event "VSFTPD setup aborted."
            return 1
        fi
    else
        show_event "Starting VSFTPD"
        if ! sudo systemctl start vsftpd; then
            show_event "ERROR - Failed to start VSFTPD service."
        fi
    fi
}

start_postgresql() {
    show_event "Checking PostgreSQL configuration"
    if ! command -v psql &> /dev/null; then
        show_event "ERROR - PostgreSQL is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active postgresql &> /dev/null; then
        show_event "PostgreSQL service is not running."
        read -p "Would you like to set up PostgreSQL now? (y/n): " answer
        if [ "$answer" = "y" ]; then
            setup_postgresql
        else
            show_event "PostgreSQL setup aborted."
            return 1
        fi
    else
        show_event "Starting PostgreSQL"
        if ! sudo systemctl start postgresql; then
            show_event "ERROR - Failed to start PostgreSQL service."
        fi
    fi
}

start_lldpd() {
    show_event "Checking LLDP configuration"
    if ! command -v lldpd &> /dev/null; then
        show_event "ERROR - LLDP is not installed. Please install it first."
        return 1
    fi

    if ! sudo systemctl is-active lldpd &> /dev/null; then
        show_event "LLDP service is not running."
        read -p "Would you like to set up LLDP now? (y/n): " answer
        if [ "$answer" = "y" ]; then
            setup_lldpd
        else
            show_event "LLDP setup aborted."
            return 1
        fi
    else
        show_event "Starting LLDP"
        if ! sudo systemctl start lldpd; then
            show_event "ERROR - Failed to start LLDP service."
        fi
    fi
}

send_startup_email() {
    # Load SMTP configuration from the CONF file
    local config_file="/nsatt/settings/storage/smtp_config.enc"
    if [ ! -f "$config_file" ]; then
        show_event "ERROR - SMTP configuration file not found."
        return 1
    fi

    smtp_server=$(jq -r '.smtp_server' "$config_file")
    smtp_port=$(jq -r '.smtp_port' "$config_file")
    smtp_user=$(jq -r '.smtp_user' "$config_file")
    smtp_password=$(jq -r '.smtp_password' "$config_file")
    recipient_email=$(jq -r '.recipient_email' "$config_file")
    from_email=$(jq -r '.from_email' "$config_file")

    # Check if recipient email is empty or not valid
    while [[ -z "$recipient_email" || ! "$recipient_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
        NSATT_ADMIN_EMAIL=$(cat /nsatt/storage/settings/nsatt_admin_email.txt 2>/dev/null)
        if [[ -z "$NSATT_ADMIN_EMAIL" ]]; then
            read -p "Recipient email is not valid. Please enter an email to use: " NSATT_ADMIN_EMAIL
            echo "$NSATT_ADMIN_EMAIL" > /nsatt/storage/settings/nsatt_admin_email.txt
        fi
        recipient_email="$NSATT_ADMIN_EMAIL"
    done

    # Gather information for the email body
    timestamp=$(date)
    network_info=$(ifconfig)
    errors=$(grep "ERROR" /var/log/syslog)
    started_services=$(systemctl list-units --type=service --state=running | awk '{print $1}')
    logged_in_users=$(who)

    # Create the email body
    email_body="NSATT Startup Report\n\n"
    email_body+="Timestamp: $timestamp\n\n"
    email_body+="Network Information:\n$network_info\n\n"
    email_body+="Errors:\n$errors\n\n"
    email_body+="Started Services:\n$started_services\n\n"
    email_body+="Logged In Users:\n$logged_in_users\n"

    # Send the email using sendmail
    {
        echo "Subject: NSATT Startup Report"
        echo "From: $from_email"
        echo "To: $recipient_email"
        echo "Content-Type: text/plain"
        echo
        echo -e "$email_body"
    } | sendmail -S "$smtp_server:$smtp_port" -au"$smtp_user" -ap"$smtp_password" "$recipient_email"
}

start_smtp_sender() {
    show_event "Checking SMTP Sender configuration"
    if ! sudo systemctl is-active smtp-sender &> /dev/null; then
        show_event "SMTP Sender service is not running."
        read -p "Would you like to set up the SMTP Sender now? (y/n): " answer
        if [ "$answer" = "y" ]; then
            create_smtp_settings
            setup_smtp_sender
        else
            show_event "SMTP Sender setup aborted."
            return 1
        fi
    else
        show_event "Starting SMTP Sender"
        if [ "$automatic_mode" != true ]; then
            # Ask to send startup email
            read -p "Would you like to send a startup email now? (y/n): " send_email_answer
            if [ "$send_email_answer" = "y" ]; then
                send_startup_email
            fi
        else
            send_startup_email
        fi
        if ! sudo systemctl start smtp-sender; then
            show_event "ERROR - Failed to start SMTP Sender service."
        fi
    fi
}

start_all_adapters_and_ip_address() {
    show_event "Starting All Adapters and IP Address"
    if ! sudo /nsatt/storage/scripts/networking/set_ip_address.sh; then
        show_event "ERROR - Failed to start All Adapters and IP Address service."
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
    echo "5 - Exit Manual Mode"
    read -p "Enter your choice (1-5): " main_choice

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
            echo "Exiting Manual Mode."
            return
            ;;
        *)
            echo "Invalid choice. Please select 1, 2, 3, 4, or 5."
            ;;
    esac
}

manual_setup_mode() {
    echo ""
    echo ""
    echo ""
    echo "----------------------------------------"
    echo "Listing services to setup:"
    echo "----------------------------------------"
    services=("Hotspot" "VPN" "SSH" "Apache2" "VSFTPD" "PostgreSQL" "LLDPD" "SMTP Sender" "All Adapters and IP Address")
    echo "Select a service to setup:"
    for i in "${!services[@]}"; do
        echo "$((i + 1)) - ${services[$i]}"
    done
    read -p "Enter your choice (1-9): " setup_choice
    case $setup_choice in
        1) setup_hotspot ;;
        2) setup_vpn ;;
        3) setup_ssh ;;
        4) setup_apache2 ;;
        5) setup_vsftpd ;;
        6) setup_postgresql ;;
        7) setup_lldpd ;;
        8) setup_smtp_sender ;;
        9) setup_all_adapters_and_ip_address ;;
        *) echo "Invalid choice. Please select a valid option." ;;
    esac

    if [[ $setup_choice -ge 1 && $setup_choice -le 9 ]]; then
        read -p "Do you want to start the selected service? (y/n): " start_input
        if [[ "$start_input" == "yes" || "$start_input" == "y" ]]; then
            case $setup_choice in
                1) start_hotspot ;;
                2) start_vpn ;;
                3) start_ssh ;;
                4) start_apache2 ;;
                5) start_vsftpd ;;
                6) start_postgresql ;;
                7) start_lldpd ;;
                8) start_smtp_sender ;;
                9) start_all_adapters_and_ip_address ;;
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
    services=("Hotspot" "VPN" "SSH" "Apache2" "VSFTPD" "PostgreSQL" "LLDPD" "SMTP Sender" "All Adapters and IP Address")
    echo "Select a service to start:"
    for i in "${!services[@]}"; do
        echo "$((i + 1)) - ${services[$i]}"
    done
    read -p "Enter your choice (1-9): " start_choice
    case $start_choice in
        1) start_hotspot ;;
        2) start_vpn ;;
        3) start_ssh ;;
        4) start_apache2 ;;
        5) start_vsftpd ;;
        6) start_postgresql ;;
        7) start_lldpd ;;
        8) start_smtp_sender ;;
        9) start_all_adapters_and_ip_address ;;
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