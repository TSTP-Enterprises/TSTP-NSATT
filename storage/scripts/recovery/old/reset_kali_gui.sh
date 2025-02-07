#!/bin/bash

# ==============================================================================
# Script Name: reset_kali_gui.sh
# Description: This script resets and reinstalls the GUI components on Kali Linux.
#              It includes extensive error handling, verbosity, and adaptability
#              to handle errors, missing files, or permission issues.
# ==============================================================================

LOG_FILE="/home/nsatt-admin/nsatt/logs/reset_kali_gui.log"

# Ensure the log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to execute commands with error handling and verbosity
execute_command() {
    local description="$1"
    shift
    local command=("$@")

    log_message "INFO: $description"
    "${command[@]}" 2>&1 | tee -a "$LOG_FILE"
    local status=${PIPESTATUS[0]}

    if [ $status -ne 0 ]; then
        log_message "ERROR: Failed to $description. Exit status: $status"
    else
        log_message "SUCCESS: Completed $description."
    fi

    return $status
}

# Start of the script
log_message "Starting GUI reset and reinstallation script."

# Step 1: Stop any running display managers
execute_command "stop display managers" sudo systemctl stop lightdm gdm3 sddm

# Kill any remaining X server processes
execute_command "kill X server processes" sudo pkill -9 Xorg X

# Step 2: Remove all desktop environments and X-related packages
execute_command "purge desktop environments and X server packages" \
    sudo apt-get purge -y lightdm gdm3 sddm xserver-xorg-core xserver-xorg* x11-* \
    xfce4 xfce4-* gnome gnome-* plasma-desktop kde-* mate-* cinnamon-* lxde lxqt

execute_command "autoremove unnecessary packages" sudo apt-get autoremove -y
execute_command "autoclean package cache" sudo apt-get autoclean

# Step 3: Clean up residual configuration files
residual_files=(
    /etc/X11
    /etc/lightdm
    /etc/gdm3
    /etc/sddm.conf
    /usr/share/xsessions
    ~/.Xauthority
    ~/.xinitrc
    ~/.config/xfce4
)

for file in "${residual_files[@]}"; do
    if [ -e "$file" ]; then
        execute_command "remove $file" sudo rm -rf "$file"
    else
        log_message "INFO: $file does not exist. Skipping."
    fi
done

# Step 4: Reinstall the default Kali Linux desktop environment (XFCE)
execute_command "update package lists" sudo apt-get update

execute_command "install XFCE desktop environment" \
    sudo apt-get install -y kali-desktop-xfce xserver-xorg lightdm

# Step 5: Reconfigure LightDM as the default display manager
execute_command "configure LightDM as the default display manager" \
    sudo dpkg-reconfigure lightdm

# Ensure the default-display-manager file is set correctly
execute_command "set /etc/X11/default-display-manager to /usr/sbin/lightdm" \
    echo "/usr/sbin/lightdm" | sudo tee /etc/X11/default-display-manager

# Step 6: Enable LightDM service to start at boot
execute_command "enable LightDM service" sudo systemctl enable lightdm

# Step 7: Prompt for reboot
log_message "The GUI reset and reinstallation process is complete."

read -p "Do you want to reboot now? (y/n): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    log_message "Rebooting the system to apply changes..."
    execute_command "reboot the system" sudo reboot
else
    log_message "Please reboot the system manually to apply changes."
fi
