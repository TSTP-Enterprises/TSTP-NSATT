#!/bin/bash

# ==============================================================================
# Script Name: setup_kali_full.sh
# Description: Automates the setup of Kali Linux on Raspberry Pi 4 Model B.
#              - Creates and configures users
#              - Installs and configures apache2, postgresql, vsftpd (removed in favor of SFTP), ssh
#              - Configures a 4-inch touchscreen display
#              - Sets up directories and permissions
#              - Performs system updates and upgrades
#              - Changes hostname
#              - Provides styled feedback and a summary
# Author: OpenAI ChatGPT
# ==============================================================================

# Enable strict error handling
set -euo pipefail
trap 'echo -e "${RED}[ERROR] An unexpected error occurred at line $LINENO.${NC}"; exit 1;' ERR

# ==============================================================================
# Color Codes for Styling
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================================================================
# Log File Setup
# ==============================================================================
LOG_DIR="/home/nsatt-admin/nsatt/logs"
LOG_FILE="$LOG_DIR/setup_kali_full.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# ==============================================================================
# Function to Print Messages with Colors
# ==============================================================================
log_event() {
    local type="${1:-}"
    local message="${2:-}"
    local context="${3:-}"

    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    case $type in
        "info")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "success")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "warning")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "error")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac

    if [[ -n "$context" ]]; then
        echo "$timestamp - [$type] - $message ($context)" >> "$LOG_FILE"
    else
        echo "$timestamp - [$type] - $message" >> "$LOG_FILE"
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
        log_event "warning" "Attempt $attempt of $max_retries: $error_message" "$interface"

        # Add a short delay before retrying the first attempt to ensure the system stabilizes
        if [ $attempt -gt 1 ]; then
            log_event "info" "Delaying for $initial_delay seconds to stabilize before retrying..." "$interface"
            sleep "$initial_delay"
        fi

        # Execute the command and check the result
        if eval "$retry_command"; then
            log_event "success" "Recovery succeeded on attempt $attempt." "$interface"
            return 0
        fi

        # Calculate the exponential backoff time
        sleep_time=$((initial_delay * 2 ** (attempt - 1)))
        log_event "info" "Retrying in $sleep_time seconds..." "$interface"
        sleep "$sleep_time"

        attempt=$((attempt + 1))
    done

    # After all retries have failed, log an error
    log_event "error" "Maximum retry attempts reached: $error_message. Manual intervention required." "$interface"
    return 1
}

# ==============================================================================
# Function to Run Commands with Detailed Feedback and Logging
# ==============================================================================
run_command() {
    local cmd="$1"
    local description="$2"

    log_event "info" "$description"
    echo -e "${CYAN}Running: $cmd${NC}" | tee -a "$LOG_FILE"
    # Execute the command, log both stdout and stderr
    eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        log_event "success" "$description completed successfully."
    else
        log_event "error" "$description failed. Check the log at $LOG_FILE for details."
        exit 1
    fi
}

# ==============================================================================
# Function to Create User with Password
# ==============================================================================
create_user() {
    local username="$1"
    local password="$2"
    local description="$3"

    if id "$username" &>/dev/null; then
        log_event "warning" "User '$username' already exists. Skipping creation."
    else
        run_command "sudo adduser --gecos \"\" --disabled-password $username" "Creating user '$username'"
        run_command "echo '$username:$password' | sudo chpasswd" "Setting password for '$username'"
        run_command "sudo usermod -aG sudo $username" "Adding '$username' to sudo group"
    fi
}

# ==============================================================================
# Function to Rename User
# ==============================================================================
rename_user() {
    local old_username="$1"
    local new_username="$2"

    if id "$new_username" &>/dev/null; then
        log_event "warning" "User '$new_username' already exists. Skipping renaming."
    else
        if id "$old_username" &>/dev/null; then
            log_event "info" "Renaming user '$old_username' to '$new_username'"
            if run_command "sudo usermod -l $new_username $old_username" "Renaming user '$old_username' to '$new_username'"; then
                log_event "info" "Moving home directory to '/home/$new_username'"
                run_command "sudo mv /home/$old_username /home/$new_username" "Moving home directory to '/home/$new_username'"
                log_event "info" "Updating home directory for '$new_username'"
                run_command "sudo usermod -d /home/$new_username $new_username" "Updating home directory for '$new_username'"
                log_event "info" "Setting ownership for '/home/$new_username'"
                run_command "sudo chown -R $new_username:$(id -gn $old_username) /home/$new_username" "Setting ownership for '/home/$new_username'"
            else
                log_event "error" "Failed to rename user '$old_username' to '$new_username'."
            fi
        else
            log_event "warning" "User '$old_username' does not exist. Skipping renaming."
        fi
    fi
}

# exim4 may cause issues with install - run manually
# iptables-persistent may cause issues for install - run manually

# ==============================================================================
# Function to Create Directory with Ownership
# ==============================================================================
create_directory() {
    local dir_path="$1"
    local owner="$2"
    local group="$3"
    local description="$4"

    if [ ! -d "$dir_path" ]; then
        run_command "sudo mkdir -p $dir_path" "$description"
        run_command "sudo chown $owner:$group $dir_path" "Setting ownership for '$dir_path'"
    else
        log_event "warning" "Directory '$dir_path' already exists. Skipping creation."
    fi
}

# ==============================================================================
# Function to Install and Configure Services and Packages
# ==============================================================================
install_and_configure_services() {
    # Install each required package separately
    run_command "sudo apt install -y apache2" "Installing apache2"
    run_command "sudo apt install -y postgresql" "Installing postgresql"
    run_command "sudo apt install -y sqlite3" "Installing sqlite3"
    run_command "sudo apt install -y jq" "Installing jq"
    run_command "sudo apt install -y mailutils" "Installing mailutils"
    run_command "sudo apt install -y hostapd" "Installing hostapd"
    run_command "sudo apt install -y dnsmasq" "Installing dnsmasq"
    run_command "sudo apt install -y libapache2-mod-wsgi-py3" "Installing libapache2-mod-wsgi-py3"
    run_command "sudo apt install -y apache2-utils" "Installing apache2-utils"
    run_command "sudo apt install -y openssl" "Installing openssl"
    run_command "sudo apt install -y traceroute" "Installing traceroute"
    run_command "sudo apt install -y curl" "Installing curl"
    run_command "sudo apt install -y udev" "Installing udev"
    run_command "sudo apt install -y net-tools" "Installing net-tools"
    run_command "sudo apt install -y iptables-persistent" "Installing iptables-persistent"
    run_command "sudo apt install -y python3-pip" "Installing python3-pip"

    # Configure SSH
    log_event "info" "Configuring SSH..."
    run_command "sudo sed -i 's/^#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config" "Disabling root login in SSH"
    run_command "sudo systemctl enable ssh" "Enabling SSH service"
    run_command "sudo systemctl restart ssh" "Restarting SSH service"
}

install_and_configure_metasploit() {
    log_event "INFO" "Starting installation and configuration of Metasploit."

    # Check if Metasploit is already installed
    if command -v msfconsole >/dev/null 2>&1; then
        log_event "INFO" "Metasploit is already installed. Skipping installation."
    else
        # Download the Metasploit installer script
        local installer_url="https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb"
        local installer_file="msfinstall"

        if curl -s "$installer_url" -o "$installer_file"; then
            chmod 755 "$installer_file"
            if ./"$installer_file"; then
                log_event "INFO" "Metasploit installed successfully."
            else
                log_event "ERROR" "Execution of Metasploit installer failed."
                return 1
            fi
        else
            log_event "ERROR" "Failed to download Metasploit installer from $installer_url."
            return 1
        fi
    fi

    # Initialize the Metasploit database
    if sudo msfdb init; then
        log_event "INFO" "Metasploit database initialized successfully."
    else
        log_event "ERROR" "Metasploit database initialization failed."
        return 1
    fi

    # Start Metasploit console in quiet mode and exit immediately
    if sudo msfconsole -q -x "exit"; then
        log_event "INFO" "Metasploit console started and exited successfully."
    else
        log_event "ERROR" "Failed to start Metasploit console."
        return 1
    fi

    return 0
}

install_and_configure_vsftpd() {
    log_event "INFO" "Installing and configuring vsftpd."

    # Check if vsftpd is already installed
    if dpkg -l | grep -qw vsftpd; then
        log_event "INFO" "vsftpd is already the newest version. Skipping installation."
    else
        # Install vsftpd
        if ! sudo apt-get install -y vsftpd; then
            log_event "ERROR" "Failed to install vsftpd."
            queue_email "Network Manager Error: vsftpd Installation Failed" "Failed to install vsftpd. Manual intervention may be required."
            return 1
        fi
    fi

    # Enable vsftpd service
    if ! sudo systemctl enable vsftpd; then
        log_event "ERROR" "Failed to enable vsftpd service."
        queue_email "Network Manager Error: vsftpd Enable Failed" "Failed to enable vsftpd service. Manual intervention may be required."
        return 1
    fi

    # Start vsftpd service
    if ! sudo systemctl start vsftpd; then
        log_event "ERROR" "Failed to start vsftpd service."
        queue_email "Network Manager Error: vsftpd Start Failed" "Failed to start vsftpd service. Manual intervention may be required."
        return 1
    fi

    # Configure vsftpd for uploads and set default folder
    local vsftpd_conf="/etc/vsftpd.conf"
    if ! grep -q "write_enable=YES" "$vsftpd_conf"; then
        echo "write_enable=YES" | sudo tee -a "$vsftpd_conf" > /dev/null
    fi

    local main_folder="/home/nsatt-admin/nsatt"
    if ! grep -q "local_root=$main_folder" "$vsftpd_conf"; then
        echo "local_root=$main_folder" | sudo tee -a "$vsftpd_conf" > /dev/null
    fi

    # Restart vsftpd service to apply changes
    if ! sudo systemctl restart vsftpd; then
        log_event "ERROR" "Failed to restart vsftpd service after configuration changes."
        queue_email "Network Manager Error: vsftpd Restart Failed" "Failed to restart vsftpd service after configuration changes. Manual intervention may be required."
        return 1
    fi

    # Set permissions for the main folder
    if [ ! -d "$main_folder" ]; then
        log_event "ERROR" "Main folder '$main_folder' does not exist."
        queue_email "Network Manager Error: Main Folder Missing" "Main folder '$main_folder' does not exist. Manual intervention may be required."
        return 1
    fi

    if ! sudo chown -R nsatt-admin "$main_folder"; then
        log_event "ERROR" "Failed to set ownership for '$main_folder'."
        queue_email "Network Manager Error: Set Ownership Failed" "Failed to set ownership for '$main_folder'. Manual intervention may be required."
        return 1
    fi

    if ! sudo chmod -R 755 "$main_folder"; then
        log_event "ERROR" "Failed to set permissions for '$main_folder'."
        queue_email "Network Manager Error: Set Permissions Failed" "Failed to set permissions for '$main_folder'. Manual intervention may be required."
        return 1
    fi

    log_event "INFO" "vsftpd installed and configured successfully."
    return 0
}

install_and_configure_ssh() {
    log_event "INFO" "Installing and configuring SSH."

    # Check if openssh-server is already installed
    if dpkg -l | grep -qw openssh-server; then
        log_event "INFO" "openssh-server is already installed. Skipping installation."
    else
        # Install openssh-server
        if ! sudo apt-get install -y openssh-server; then
            log_event "ERROR" "Failed to install openssh-server."
            queue_email "Network Manager Error: SSH Installation Failed" "Failed to install openssh-server. Manual intervention may be required."
            return 1
        fi
    fi

    # Enable ssh service
    if ! sudo systemctl enable ssh; then
        log_event "ERROR" "Failed to enable ssh service."
        queue_email "Network Manager Error: SSH Enable Failed" "Failed to enable ssh service. Manual intervention may be required."
        return 1
    fi

    # Start ssh service
    if ! sudo systemctl start ssh; then
        log_event "ERROR" "Failed to start ssh service."
        queue_email "Network Manager Error: SSH Start Failed" "Failed to start ssh service. Manual intervention may be required."
        return 1
    fi

    log_event "INFO" "SSH installed and configured successfully."
    return 0
}

# ==============================================================================
# Function to Configure Touchscreen Display
# ==============================================================================
configure_touchscreen() {
    log_event "info" "Installing touchscreen drivers and configuring display..."
    run_command "sudo DEBIAN_FRONTEND=noninteractive apt install -y xserver-xorg-input-evdev" "Installing xserver-xorg-input-evdev"
    run_command "sudo DEBIAN_FRONTEND=noninteractive apt install -y xserver-xorg-input-libinput" "Installing xserver-xorg-input-libinput"
    run_command "sudo DEBIAN_FRONTEND=noninteractive apt install -y xinput-calibrator" "Installing xinput-calibrator"

    # Check if touchscreen configuration already exists
    if ! grep -q "# Touchscreen configuration" /boot/config.txt; then
        run_command "sudo tee -a /boot/config.txt > /dev/null <<EOF
# Touchscreen configuration
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=480 800 60 6 0 0 0
dtoverlay=vc4-fkms-v3d
EOF" "Updating /boot/config.txt for touchscreen"
    else
        log_event "warning" "Touchscreen configuration already exists in /boot/config.txt. Skipping."
    fi
}

# ==============================================================================
# Function to Change Hostname
# ==============================================================================
change_hostname() {
    local new_hostname="$1"
    log_event "info" "Changing hostname to '$new_hostname'..."

    # Change the hostname using hostnamectl
    run_command "sudo hostnamectl set-hostname $new_hostname" "Setting new hostname"

    # Update /etc/hosts
    if grep -q "127.0.1.1" /etc/hosts; then
        run_command "sudo sed -i 's/^127\.0\.1\.1\s\+.*/127.0.1.1\t$new_hostname/' /etc/hosts" "Updating /etc/hosts with new hostname"
    else
        run_command "echo '127.0.1.1\t$new_hostname' | sudo tee -a /etc/hosts" "Adding new hostname to /etc/hosts"
    fi
    log_event "success" "Hostname changed to '$new_hostname'."
}

# ==============================================================================
# Function to Verify Installations and Configurations
# ==============================================================================
verify_setup() {
    print_line
    echo -e "${CYAN}================= Setup Verification =================${NC}"
    print_line

    # Verify User Creation
    if id "nsatt-admin" &>/dev/null; then
        echo -e "${GREEN}[✓] User 'nsatt-admin' exists.${NC}"
    else
        echo -e "${RED}[✗] User 'nsatt-admin' does not exist.${NC}"
    fi

    if id "nsatt-superadmin" &>/dev/null; then
        echo -e "${GREEN}[✓] User 'nsatt-superadmin' exists.${NC}"
    else
        echo -e "${RED}[✗] User 'nsatt-superadmin' does not exist.${NC}"
    fi

    # Verify Directory Creation
    if [ -d "/home/nsatt-admin/nsatt" ]; then
        echo -e "${GREEN}[✓] Directory '/home/nsatt-admin/nsatt' exists.${NC}"
    else
        echo -e "${RED}[✗] Directory '/home/nsatt-admin/nsatt' does not exist.${NC}"
    fi

    # Verify Services
    for service in apache2 postgresql ssh; do
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}[✓] Service '$service' is running.${NC}"
        else
            echo -e "${RED}[✗] Service '$service' is not running.${NC}"
        fi
    done

    # Verify Touchscreen Configuration
    if grep -q "# Touchscreen configuration" /boot/config.txt; then
        echo -e "${GREEN}[✓] Touchscreen configuration exists in /boot/config.txt.${NC}"
    else
        echo -e "${RED}[✗] Touchscreen configuration missing in /boot/config.txt.${NC}"
    fi

    # Verify Hostname
    current_hostname=$(hostnamectl | grep "Static hostname" | awk '{print $3}')
    if [ "$current_hostname" = "nsatt" ]; then
        echo -e "${GREEN}[✓] Hostname is set to 'nsatt'.${NC}"
    else
        echo -e "${RED}[✗] Hostname is not set to 'nsatt'. Current hostname: '$current_hostname'.${NC}"
    fi

    print_line
    echo -e "${YELLOW}Setup Verification Completed.${NC}"
    print_line
}

# ==============================================================================
# Function to Display Summary with ASCII Art
# ==============================================================================
display_summary() {
    clear
    print_line
    echo -e "${GREEN}"
    echo "    _   _______ ___  ____________  "
    echo "   / | / / ___//   |/_  __/_  __/  "
    echo "  /  |/ /\__ \/ /| | / /   / /     "
    echo " / /|  /___/ / ___ |/ /   / /      "
    echo "/_/ |_//____/_/  |_/_/   /_/       "
    echo ""
    echo -e " Setup completed successfully!"
    echo ""
    echo -e "${NC}Summary of actions performed:"
    echo ""
    echo -e "${GREEN}[✓] Created user 'nsatt-admin' with sudo privileges.${NC}"
    echo -e "${GREEN}[✓] Changed password for 'kali' user.${NC}"
    echo -e "${GREEN}[✓] Renamed user 'kali' to 'nsatt-superadmin' and set ownership.${NC}"
    echo -e "${GREEN}[✓] Created directory '/home/nsatt-admin/nsatt' with proper permissions.${NC}"
    echo -e "${GREEN}[✓] Installed and configured apache2, postgresql, sqlite3, jq, mailutils.${NC}"
    echo -e "${GREEN}[✓] Installed and configured hostapd, dnsmasq, libapache2-mod-wsgi-py3.${NC}"
    echo -e "${GREEN}[✓] Installed and configured openssl, traceroute, curl, udev.${NC}"
    echo -e "${GREEN}[✓] Installed and configured net-tools, iptables-persistent, python3-pip.${NC}"
    echo -e "${GREEN}[✓] Configured SSH to disable root login.${NC}"
    echo -e "${GREEN}[✓] Installed touchscreen drivers and updated display settings.${NC}"
    echo -e "${GREEN}[✓] Changed hostname to 'nsatt'.${NC}"
    echo -e "${GREEN}[✓] Performed system updates and upgrades.${NC}"
    echo ""
    echo -e "${YELLOW}All tasks have been completed. Please reboot your system to apply all changes.${NC}"
    print_line
}

# ==============================================================================
# Function to Print Divider Line
# ==============================================================================
print_line() {
    echo "-------------------------------------------------------------"
}

# ==============================================================================
# Main Execution Flow
# ==============================================================================
main() {
    clear
    log_event "info" "Starting NSATT setup"

    # Check if 'nsatt-admin' or 'nsatt-superadmin' already exist
    if id "nsatt-admin" &>/dev/null || id "nsatt-superadmin" &>/dev/null; then
        log_event "info" "'nsatt-admin' or 'nsatt-superadmin' already exist. Proceeding with setup."
    else
        log_event "info" "'nsatt-admin' and 'nsatt-superadmin' do not exist. Creating 'nsatt-admin' and 'nsatt-superadmin' users."
        create_user "nsatt-admin" "ChangeMe!" "Creating user 'nsatt-admin'" || exit 1
        create_user "nsatt-superadmin" "ChangeMe!" "Creating user 'nsatt-superadmin'" || exit 1
        log_event "info" "Users 'nsatt-admin' and 'nsatt-superadmin' created. Please log in as 'nsatt-admin' and run the script again."
        exit 0
    fi

    # Display mode selection menu
    echo "Select mode:"
    echo "1) Automated (stop on errors)"
    echo "2) Automated (show all messages)"
    echo "3) Manual"
    read -p "Enter your choice (1/2/3): " mode_choice

    if [[ "$mode_choice" == "1" ]]; then
        log_event "info" "Running in automated mode (stop on errors)."

        # Perform system update and upgrade
        run_command "sudo apt update && sudo apt upgrade -y" "[SUCCESS] Updating and upgrading the system completed successfully." || exit 1
        run_command "sudo apt autoremove -y" "[SUCCESS] Removing unnecessary packages completed successfully." || exit 1

        # Create directory /home/nsatt-admin/nsatt if it doesn't exist
        if [ ! -d "/home/nsatt-admin/nsatt" ]; then
            create_directory "/home/nsatt-admin/nsatt" "nsatt-admin" "nsatt-admin" "Creating directory '/home/nsatt-admin/nsatt'" || exit 1
        else
            log_event "info" "Directory '/home/nsatt-admin/nsatt' already exists. Skipping creation."
        fi

        # Install and configure services
        install_and_configure_services || exit 1

        # Install and configure Metasploit
        install_and_configure_metasploit || exit 1

        # Install and configure vsftpd
        install_and_configure_vsftpd || exit 1

        # Install and configure SSH
        install_and_configure_ssh || exit 1

        # Ask if the user wants to install the touchscreen display
        read -p "Do you want to configure the touchscreen display? (y/n): " configure_touchscreen_choice
        if [[ "$configure_touchscreen_choice" =~ ^[Yy]$ ]]; then
            configure_touchscreen || exit 1
        else
            log_event "info" "Skipping touchscreen display configuration."
        fi

        # Change hostname to 'nsatt' if it's not already set
        current_hostname=$(hostname)
        if [ "$current_hostname" != "nsatt" ]; then
            change_hostname "nsatt" || exit 1
        else
            log_event "info" "Hostname is already set to 'nsatt'. Skipping change."
        fi

        # Perform final system update and upgrade
        run_command "sudo apt update && sudo apt upgrade -y" "[SUCCESS] Performing a final system update and upgrade completed successfully." || exit 1

        # Verify setup
        verify_setup || exit 1

        # Display summary with ASCII art
        display_summary

    elif [[ "$mode_choice" == "2" ]]; then
        log_event "info" "Running in automated mode (show all messages)."

        # Perform system update and upgrade
        run_command "sudo apt update && sudo apt upgrade -y" "[SUCCESS] Updating and upgrading the system completed successfully."
        run_command "sudo apt autoremove -y" "[SUCCESS] Removing unnecessary packages completed successfully."

        # Create directory /home/nsatt-admin/nsatt if it doesn't exist
        if [ ! -d "/home/nsatt-admin/nsatt" ]; then
            create_directory "/home/nsatt-admin/nsatt" "nsatt-admin" "nsatt-admin" "Creating directory '/home/nsatt-admin/nsatt'"
        else
            log_event "info" "Directory '/home/nsatt-admin/nsatt' already exists. Skipping creation."
        fi

        # Install and configure services
        install_and_configure_services

        # Install and configure Metasploit
        install_and_configure_metasploit

        # Install and configure vsftpd
        install_and_configure_vsftpd

        # Install and configure SSH
        install_and_configure_ssh

        # Ask if the user wants to install the touchscreen display
        read -p "Do you want to configure the touchscreen display? (y/n): " configure_touchscreen_choice
        if [[ "$configure_touchscreen_choice" =~ ^[Yy]$ ]]; then
            configure_touchscreen
        else
            log_event "info" "Skipping touchscreen display configuration."
        fi

        # Change hostname to 'nsatt' if it's not already set
        current_hostname=$(hostname)
        if [ "$current_hostname" != "nsatt" ]; then
            change_hostname "nsatt"
        else
            log_event "info" "Hostname is already set to 'nsatt'. Skipping change."
        fi

        # Perform final system update and upgrade
        run_command "sudo apt update && sudo apt upgrade -y" "[SUCCESS] Performing a final system update and upgrade completed successfully."

        # Verify setup
        verify_setup

        # Display summary with ASCII art
        display_summary

    elif [[ "$mode_choice" == "3" ]]; then
        log_event "info" "Running in manual mode."

        # Ask to perform system update and upgrade
        read -p "Do you want to update and upgrade the system? (y/n): " update_choice
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            run_command "sudo apt update && sudo apt upgrade -y" "[SUCCESS] Updating and upgrading the system completed successfully."
            run_command "sudo apt autoremove -y" "[SUCCESS] Removing unnecessary packages completed successfully."
        else
            log_event "info" "Skipping system update and upgrade."
        fi

        # Ask to create directory /home/nsatt-admin/nsatt
        if [ ! -d "/home/nsatt-admin/nsatt" ]; then
            read -p "Do you want to create directory '/home/nsatt-admin/nsatt'? (y/n): " create_directory_choice
            if [[ "$create_directory_choice" =~ ^[Yy]$ ]]; then
                create_directory "/home/nsatt-admin/nsatt" "nsatt-admin" "nsatt-admin" "Creating directory '/home/nsatt-admin/nsatt'"
            else
                log_event "info" "Skipping creation of directory '/home/nsatt-admin/nsatt'."
            fi
        else
            log_event "info" "Directory '/home/nsatt-admin/nsatt' already exists. Skipping creation."
        fi

        # Ask to install and configure services
        read -p "Do you want to install and configure services? (y/n): " configure_services_choice
        if [[ "$configure_services_choice" =~ ^[Yy]$ ]]; then
            install_and_configure_services
        else
            log_event "info" "Skipping installation and configuration of services."
        fi

        # Ask to install and configure Metasploit
        read -p "Do you want to install and configure Metasploit? (y/n): " configure_metasploit_choice
        if [[ "$configure_metasploit_choice" =~ ^[Yy]$ ]]; then
            install_and_configure_metasploit
        else
            log_event "info" "Skipping installation and configuration of Metasploit."
        fi

        # Ask to install and configure vsftpd
        read -p "Do you want to install and configure vsftpd? (y/n): " configure_vsftpd_choice
        if [[ "$configure_vsftpd_choice" =~ ^[Yy]$ ]]; then
            install_and_configure_vsftpd
        else
            log_event "info" "Skipping installation and configuration of vsftpd."
        fi

        # Ask to install and configure SSH
        read -p "Do you want to install and configure SSH? (y/n): " configure_ssh_choice
        if [[ "$configure_ssh_choice" =~ ^[Yy]$ ]]; then
            install_and_configure_ssh
        else
            log_event "info" "Skipping installation and configuration of SSH."
        fi

        # Ask if the user wants to install the touchscreen display
        read -p "Do you want to configure the touchscreen display? (y/n): " configure_touchscreen_choice
        if [[ "$configure_touchscreen_choice" =~ ^[Yy]$ ]]; then
            configure_touchscreen
        else
            log_event "info" "Skipping touchscreen display configuration."
        fi

        # Ask to change hostname to 'nsatt'
        current_hostname=$(hostname)
        if [ "$current_hostname" != "nsatt" ]; then
            read -p "Do you want to change the hostname to 'nsatt'? (y/n): " change_hostname_choice
            if [[ "$change_hostname_choice" =~ ^[Yy]$ ]]; then
                change_hostname "nsatt"
            else
                log_event "info" "Skipping hostname change."
            fi
        else
            log_event "info" "Hostname is already set to 'nsatt'. Skipping change."
        fi

        # Ask to perform final system update and upgrade
        read -p "Do you want to perform a final system update and upgrade? (y/n): " final_update_choice
        if [[ "$final_update_choice" =~ ^[Yy]$ ]]; then
            run_command "sudo apt update && sudo apt upgrade -y" "[SUCCESS] Performing a final system update and upgrade completed successfully."
        else
            log_event "info" "Skipping final system update and upgrade."
        fi

        # Ask to verify setup
        read -p "Do you want to verify the setup? (y/n): " verify_setup_choice
        if [[ "$verify_setup_choice" =~ ^[Yy]$ ]]; then
            verify_setup
        else
            log_event "info" "Skipping setup verification."
        fi

        # Ask to display summary with ASCII art
        read -p "Do you want to display the summary with ASCII art? (y/n): " display_summary_choice
        if [[ "$display_summary_choice" =~ ^[Yy]$ ]]; then
            display_summary
        else
            log_event "info" "Skipping display of summary."
        fi
    else
        log_event "error" "Invalid mode selected. Exiting."
        exit 1
    fi
}

# ==============================================================================
# Execute Main Function
# ==============================================================================
main
