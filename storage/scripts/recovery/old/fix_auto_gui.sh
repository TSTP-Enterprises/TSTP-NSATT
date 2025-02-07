#!/bin/bash

LOG_FILE="/home/nsatt-admin/nsatt/logs/recovery/gui_autologin_fix.log"

log_event() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | sudo tee -a "$LOG_FILE"
}

fix_autologin() {
    log_event "INFO" "Starting fix for GUI autologin."

    # Ensure LightDM or GDM3 is installed
    if ! dpkg -l | grep -q "lightdm"; then
        log_event "INFO" "LightDM not found. Installing LightDM."
        sudo apt-get update && sudo apt-get install -y lightdm || {
            log_event "ERROR" "Failed to install LightDM."
            exit 1
        }
    else
        log_event "INFO" "LightDM is already installed."
    fi

    # Set LightDM as the default display manager
    sudo debconf-set-selections <<< "lightdm shared/default-x-display-manager select lightdm"
    sudo dpkg-reconfigure -f noninteractive lightdm || {
        log_event "ERROR" "Failed to set LightDM as default display manager."
        exit 1
    }
    log_event "INFO" "LightDM set as default display manager."

    # Enable autologin for the current user
    local user
    user=$(whoami)
    local autologin_conf="/etc/lightdm/lightdm.conf.d/10-autologin.conf"

    sudo mkdir -p "$(dirname "$autologin_conf")"
    sudo tee "$autologin_conf" > /dev/null <<EOF
[Seat:*]
autologin-user=$user
autologin-user-timeout=0
user-session=ubuntu
greeter-session=lightdm-gtk-greeter
EOF

    log_event "INFO" "Configured autologin for user: $user."

    # Enable graphical target as the default
    sudo systemctl set-default graphical.target || {
        log_event "ERROR" "Failed to set graphical target as default."
        exit 1
    }
    log_event "INFO" "Set graphical target as the default boot target."

    # Restart display manager
    sudo systemctl restart lightdm || {
        log_event "ERROR" "Failed to restart LightDM."
        exit 1
    }

    log_event "INFO" "GUI autologin fix applied successfully."
}

# Main execution
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

fix_autologin
log_event "INFO" "Script execution completed."
