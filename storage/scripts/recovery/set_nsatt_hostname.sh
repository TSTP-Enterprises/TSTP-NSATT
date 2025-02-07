#!/bin/bash

# Set up logging
LOG_DIR="/nsatt/logs/recovery"
LOG_FILE="$LOG_DIR/hostname_change.log"
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

# Ask user for confirmation
echo "This script will:"
echo "1. Change system hostname to NSATT"
echo "2. Update /etc/hosts file"
read -p "Do you want to continue? (y/N) " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_message "User declined to run script"
    echo "Operation cancelled."
    exit 0
fi

# Change hostname
log_message "Changing hostname to NSATT..."
if ! sudo hostnamectl set-hostname NSATT; then
    handle_error "Failed to change hostname"
fi

# Update /etc/hosts
log_message "Updating /etc/hosts..."
if ! sudo sed -i "s/127.0.1.1 .*/127.0.1.1 NSATT/" /etc/hosts; then
    handle_error "Failed to update /etc/hosts"
fi

# Confirmation
log_message "Hostname successfully changed to NSATT"
echo "Hostname change completed successfully"

# Ask about reboot
read -p "A reboot is recommended for changes to take full effect. Reboot now? (y/N) " reboot
if [[ "$reboot" =~ ^[Yy]$ ]]; then
    log_message "User requested reboot. Rebooting system..."
    sudo reboot
else
    log_message "Reboot skipped by user"
    echo "Reboot skipped. Please reboot manually later for changes to take full effect."
fi
