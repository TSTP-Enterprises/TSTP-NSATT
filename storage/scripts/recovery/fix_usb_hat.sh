#!/bin/bash

# Set up logging
LOG_DIR="/nsatt/logs/recovery"
LOG_FILE="$LOG_DIR/usb_hat_fix.log"
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
echo "1. Update /boot/cmdline.txt to load required modules"
echo "2. Update /boot/config.txt with required device tree overlay"
echo "3. Reboot the system to apply changes"
read -p "Do you want to continue? (y/N) " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_message "User declined to run script"
    echo "Operation cancelled."
    exit 0
fi

log_message "Starting USB/RJ45 hat fix script"

# Update cmdline.txt
log_message "Updating /boot/cmdline.txt..."
if ! sudo sed -i 's/$/ modules-load=dwc2,g_ether/' /boot/cmdline.txt; then
    handle_error "Failed to update cmdline.txt"
fi

# Update config.txt
log_message "Updating /boot/config.txt..."
if ! echo "dtoverlay=dwc2" | sudo tee -a /boot/config.txt >/dev/null; then
    handle_error "Failed to update config.txt"
fi

# Verify changes
log_message "Verifying changes..."
log_message "Contents of /boot/cmdline.txt:"
sudo cat /boot/cmdline.txt | sudo tee -a "$LOG_FILE" >/dev/null
log_message "Contents of /boot/config.txt:"
sudo cat /boot/config.txt | sudo tee -a "$LOG_FILE" >/dev/null

# Check if required changes are present
if ! grep -q "modules-load=dwc2,g_ether" /boot/cmdline.txt; then
    handle_error "modules-load=dwc2,g_ether not found in cmdline.txt"
fi

if ! grep -q "dtoverlay=dwc2" /boot/config.txt; then
    handle_error "dtoverlay=dwc2 not found in config.txt"
fi

log_message "Script completed successfully"
echo "All changes verified successfully. System will reboot now..."
sudo reboot