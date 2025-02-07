#!/bin/bash

# Set up logging
LOG_DIR="/nsatt/logs/recovery"
LOG_FILE="$LOG_DIR/kali_gui_fix.log"
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
echo "1. Reset home directory permissions"
echo "2. Remove .Xauthority file"
echo "3. Reinstall Kali desktop environment"
echo "4. Restart the display manager"
read -p "Do you want to continue? (y/N) " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_message "User declined to run script"
    echo "Operation cancelled."
    exit 0
fi

log_message "Starting Kali GUI fix script"

# Reset home directory permissions
echo "Resetting home directory permissions..."
sudo chown -R $(whoami):$(whoami) $HOME || handle_error "Failed to reset home directory permissions"
log_message "Reset home directory permissions"

# Delete .Xauthority file
echo "Removing .Xauthority file..."
rm -f ~/.Xauthority || handle_error "Failed to remove .Xauthority file"
log_message "Removed .Xauthority file"

# Reinstall desktop environment
echo "Reinstalling Kali desktop environment..."
sudo apt update || handle_error "Failed to update package list"
log_message "Updated package list"
sudo apt install --reinstall -y kali-desktop-xfce || handle_error "Failed to reinstall desktop environment"
log_message "Reinstalled Kali desktop environment"

# Restart display manager
echo "Restarting display manager..."
sudo systemctl restart lightdm || handle_error "Failed to restart display manager"
log_message "Restarted display manager"

log_message "Script completed successfully"
echo "Fix applied! Try logging into the GUI again."
