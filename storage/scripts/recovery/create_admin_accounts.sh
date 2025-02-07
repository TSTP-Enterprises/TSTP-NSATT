#!/bin/bash

# Set up logging
LOG_DIR="/nsatt/logs/recovery"
LOG_FILE="$LOG_DIR/admin_accounts.log"
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
echo "1. Check if nsatt-admin and nsatt-superadmin users exist"
echo "2. Create these users if they don't exist"
echo "3. Ensure they have admin privileges"
read -p "Do you want to continue? (y/N) " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_message "User declined to run script"
    echo "Operation cancelled."
    exit 0
fi

log_message "Starting admin accounts creation/verification script"

# Function to check and create user
create_user_if_missing() {
    local username=$1
    if ! id "$username" &>/dev/null; then
        echo "Creating user $username..."
        sudo useradd -m "$username" || handle_error "Failed to create user $username"
        sudo passwd "$username" || handle_error "Failed to set password for $username"
        log_message "Created user $username"
    else
        echo "User $username already exists"
        log_message "User $username already exists"
    fi
}

# Function to ensure user is admin
ensure_admin_privileges() {
    local username=$1
    if ! groups "$username" | grep -q "sudo"; then
        echo "Adding $username to sudo group..."
        sudo usermod -aG sudo "$username" || handle_error "Failed to add $username to sudo group"
        log_message "Added $username to sudo group"
    else
        echo "User $username already has admin privileges"
        log_message "User $username already has admin privileges"
    fi
}

# Process nsatt-admin user
create_user_if_missing "nsatt-admin"
ensure_admin_privileges "nsatt-admin"

# Process nsatt-superadmin user
create_user_if_missing "nsatt-superadmin"
ensure_admin_privileges "nsatt-superadmin"

log_message "Script completed successfully"
echo "Admin accounts setup completed successfully"
