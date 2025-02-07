#!/bin/bash

# Script to create and configure a 2GB swap file on Kali Linux
# Supports automatic_mode for silent operation with clear feedback.

# Define variables
AUTOMATIC_MODE_FILE="/nsatt/settings/automatic_mode.nsatt"

# Function to log feedback
log_message() {
    local message="$1"
    if [ "$AUTOMATIC_MODE" = true ]; then
        echo "$message"
    else
        echo "$message"
    fi
}

# Check if automatic_mode is enabled
if [ -f "$AUTOMATIC_MODE_FILE" ]; then
    AUTOMATIC_MODE=true
else
    AUTOMATIC_MODE=false
fi

log_message "Starting swap file configuration..."

# Disable any active swap
log_message "Disabling any active swap..."
if ! sudo swapoff -a > /dev/null 2>&1; then
    log_message "Error: Failed to disable swap. Exiting."
    exit 1
fi

# Create the swap file
log_message "Creating a 2GB swap file..."
if command -v fallocate > /dev/null 2>&1; then
    if ! sudo fallocate -l 2G /swapfile > /dev/null 2>&1; then
        log_message "Error: Failed to create swap file using fallocate. Exiting."
        exit 1
    fi
else
    log_message "fallocate not available, using dd to create the swap file..."
    if ! sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 > /dev/null 2>&1; then
        log_message "Error: Failed to create swap file using dd. Exiting."
        exit 1
    fi
fi

# Set correct permissions
log_message "Setting correct permissions for the swap file..."
if ! sudo chmod 600 /swapfile > /dev/null 2>&1; then
    log_message "Error: Failed to set permissions for the swap file. Exiting."
    exit 1
fi

# Set up the swap area
log_message "Setting up the swap area..."
if ! sudo mkswap /swapfile > /dev/null 2>&1; then
    log_message "Error: Failed to set up the swap area. Exiting."
    exit 1
fi

# Enable the swap file
log_message "Enabling the swap file..."
if ! sudo swapon /swapfile > /dev/null 2>&1; then
    log_message "Error: Failed to enable the swap file. Exiting."
    exit 1
fi

# Make the swap file persistent
log_message "Making the swap file persistent across reboots..."
if ! echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null 2>&1; then
    log_message "Error: Failed to update /etc/fstab. Exiting."
    exit 1
fi

# Verify the swap configuration
log_message "Verifying the swap file configuration..."
if swapon --show > /dev/null 2>&1 && free -h > /dev/null 2>&1; then
    log_message "Swap file successfully created and configured."
else
    log_message "Error: Swap file configuration verification failed. Exiting."
    exit 1
fi
