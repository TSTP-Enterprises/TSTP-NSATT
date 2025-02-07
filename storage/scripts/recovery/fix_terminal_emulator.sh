#!/bin/bash

# Set up logging
LOG_DIR="/nsatt/logs/recovery"
LOG_FILE="$LOG_DIR/terminal_emulator_fix.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    sudo mkdir -p "$LOG_DIR" || {
        echo "Error: Failed to create log directory"
        exit 1
    }
fi

log_message() {
    echo "[$TIMESTAMP] $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Error handling function
handle_error() {
    log_message "ERROR: $1"
    echo "Error: $1"
    exit 1
}

# Ask for permission
echo "This script will:"
echo "1. Set DISPLAY variable if needed"
echo "2. Update package lists"
echo "3. Reinstall terminal emulator related packages"
read -p "Do you want to continue? (y/N) " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_message "User declined to run script"
    echo "Operation cancelled."
    exit 0
fi

log_message "Starting terminal emulator fix script"

# Check and set DISPLAY if not set
if [ -z "$DISPLAY" ]; then
    log_message "Setting DISPLAY variable"
    export DISPLAY=:0
fi

# Update package lists
log_message "Updating package lists"
if ! apt update; then
    handle_error "Failed to update package lists"
fi

# Reinstall required packages
log_message "Reinstalling required packages"
if ! apt install --reinstall mesa-utils libgl1-mesa-dri libglx-mesa0 libegl-mesa0 xserver-xorg-core -y; then
    handle_error "Failed to reinstall required packages"
fi

log_message "Script completed successfully"
echo "Terminal emulator repair completed successfully"
