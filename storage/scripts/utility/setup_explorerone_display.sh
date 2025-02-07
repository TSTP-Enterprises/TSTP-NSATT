#!/bin/bash

# These are notes for the future of this script and project.
# There are files and packages which must be obtained and installed for this project to work properly.
# There are also configuration changes that must take place and scripts that must be in specific folders.
# This script is a work in progress and is not yet ready for use by the public.

# Installs Needed Packages
# sudo apt install python3-gpiozero python3-rpi.gpio -y
# 
#
# Need to make this a run on each startup:
# sudo fbcp &

# Script to setup or repair the LCD display on Kali Linux
# Includes backup, restore, error handling, and automatic_mode

set -e  # Exit immediately if a command exits with a non-zero status

# Define constants
AUTOMATIC_MODE_FILE="/nsatt/settings/automatic_mode.nsatt"
BACKUP_DIR="/backup_lcd_display"
CONFIG_FILE="/boot/config.txt"
BASH_PROFILE_PATH="/root/.bash_profile"
XORG_CONF_DIR="/usr/share/X11/xorg.conf.d"
LOG_FILE="/var/log/Xorg.0.log"

# Helper function to log messages
log_message() {
    local message="$1"
    echo "$message"
}

# Check for automatic_mode
if [ -f "$AUTOMATIC_MODE_FILE" ]; then
    AUTOMATIC_MODE=true
else
    AUTOMATIC_MODE=false
fi

# Function to check if a package is installed
check_package() {
    dpkg -l "$1" &> /dev/null
}

# Function to check required packages and files
check_requirements() {
    local missing_packages=()
    local packages=("xserver-xorg" "xinit" "lightdm" "kali-desktop-xfce" "chromium" "git")
    
    log_message "Checking required packages..."
    for pkg in "${packages[@]}"; do
        if ! check_package "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        log_message "All required packages are installed."
        return 0
    else
        log_message "Missing packages: ${missing_packages[*]}"
        return 1
    fi
}

# Function to create backups
backup_files() {
    log_message "Creating backups..."
    mkdir -p "$BACKUP_DIR"
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$BACKUP_DIR/config.txt.bak"
    fi
    if [ -f "$BASH_PROFILE_PATH" ]; then
        cp "$BASH_PROFILE_PATH" "$BACKUP_DIR/bash_profile.bak"
    fi
    log_message "Backups completed and stored in $BACKUP_DIR."
}

# Function to restore backups
restore_files() {
    log_message "Restoring backups..."
    if [ -f "$BACKUP_DIR/config.txt.bak" ]; then
        cp "$BACKUP_DIR/config.txt.bak" "$CONFIG_FILE"
    fi
    if [ -f "$BACKUP_DIR/bash_profile.bak" ]; then
        cp "$BACKUP_DIR/bash_profile.bak" "$BASH_PROFILE_PATH"
    fi
    log_message "Restore completed."
}

# Function to install the display
install_display() {
    log_message "Starting installation for the LCD display..."

    # Check requirements first
    if ! check_requirements; then
        # Update the system
        log_message "Updating the system..."
        apt update -y && apt upgrade -y

        # Install necessary software
        log_message "Installing required software..."
        apt-get install --no-install-recommends xserver-xorg xinit -y
        apt install lightdm kali-desktop-xfce chromium git -y
    fi

    # Check if X server is running
    if ! pgrep X >/dev/null; then
        log_message "X server is not running. Starting X server..."
        if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
            # Over SSH, start X detached
            DISPLAY=:0 startx -- :0 &
        else
            # Local, can start normally
            startx &
        fi
        sleep 5
    fi

    # Install LCD drivers if not present
    if [ ! -d "LCD-show" ]; then
        log_message "LCD drivers not found. Installing LCD drivers..."
        git clone https://github.com/goodtft/LCD-show.git
        chmod -R 755 LCD-show
        cd LCD-show
        sudo ./MPI4008-show
    fi

    # Install fbcp if not already running
    if ! pgrep fbcp >/dev/null; then
        log_message "Starting fbcp..."
        fbcp &
    fi

    log_message "Installation completed successfully."
}

# Main script execution
if [ "$AUTOMATIC_MODE" = true ]; then
    install_display
else
    echo "Choose an option:"
    sudo fbcp &
    echo "1) Install"
    echo "2) Restore"
    read -rp "Enter your choice (1/2): " choice
    case $choice in
        1)
            backup_files
            install_display
            ;;
        2)
            restore_files
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi