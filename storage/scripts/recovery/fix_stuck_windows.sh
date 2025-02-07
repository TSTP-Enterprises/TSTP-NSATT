#!/bin/bash

# Set up logging
LOG_DIR="/nsatt/logs/recovery"
LOG_FILE="$LOG_DIR/stuck_windows_fix.log"
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
echo "1. Check X server status"
echo "2. Restart the window manager (xfwm4)"
read -p "Do you want to continue? (y/N) " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_message "User declined to run script"
    echo "Operation cancelled."
    exit 0
fi

log_message "Starting stuck windows fix script"

# Check if display is available
if [ -z "$DISPLAY" ]; then
    handle_error "No display found. Are you running in a graphical environment?"
fi

# Check if X server is running
if ! xset q &>/dev/null; then
    handle_error "X server is not running"
fi

# Execute xfwm4 replace command and check if it exists first
if ! command -v xfwm4 >/dev/null 2>&1; then
    handle_error "xfwm4 not found. Please ensure XFCE is installed properly."
fi

echo "Restarting window manager..."
xfwm4 --replace &
log_message "Executed xfwm4 --replace command"

# Wait briefly to check if process is still running
sleep 2
if ! pgrep xfwm4 >/dev/null; then
    handle_error "Window manager failed to start and stay running"
fi

log_message "Script completed successfully"
echo "Window manager restarted successfully"
