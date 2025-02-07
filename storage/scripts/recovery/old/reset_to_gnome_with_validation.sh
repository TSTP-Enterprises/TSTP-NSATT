#!/bin/bash

# Ensure the script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

log_file="/var/log/reset_to_gnome.log"
echo "Logging to $log_file"
exec > >(tee -a "$log_file") 2>&1

echo "Starting cleanup and fresh GNOME installation with validation..."

# Function to check for errors in logs
check_logs_for_errors() {
    log_path="$1"
    echo "Checking $log_path for errors..."
    if [ -f "$log_path" ]; then
        grep -iE "error|fail|warning|critical" "$log_path" && echo "Issues found in $log_path!" || echo "No critical issues found in $log_path."
    else
        echo "$log_path not found!"
    fi
}

# Function to verify file existence and permissions
verify_file_permissions() {
    file_path="$1"
    echo "Verifying $file_path..."
    if [ -e "$file_path" ]; then
        ls -l "$file_path"
    else
        echo "$file_path does not exist."
    fi
}

# Step 1: Detect and remove existing desktop environments and display managers
echo "Detecting and removing existing desktop environments and display managers..."

DESKTOP_ENVIRONMENTS=("xfce4" "kde-plasma-desktop" "lxde" "mate-desktop-environment")
DISPLAY_MANAGERS=("lightdm" "sddm" "xdm")

for env in "${DESKTOP_ENVIRONMENTS[@]}"; do
    if dpkg -l | grep -q "$env"; then
        echo "Removing $env..."
        apt purge -y "$env"
    fi
done

for dm in "${DISPLAY_MANAGERS[@]}"; do
    if dpkg -l | grep -q "$dm"; then
        echo "Removing $dm..."
        apt purge -y "$dm"
    fi
done

# Step 2: Remove X server and residual configurations
echo "Removing X server and residual configurations..."
apt purge -y xserver-xorg-core
apt autoremove -y --purge
rm -rf /etc/X11 /etc/xdg /var/lib/lightdm /var/lib/sddm /var/lib/xdm
rm -rf /tmp/* /var/tmp/*
rm -rf /home/*/.cache /home/*/.config /home/*/.local

# Verify removal
verify_file_permissions "/etc/X11"
verify_file_permissions "/var/lib/lightdm"
verify_file_permissions "/tmp"

# Step 3: Reinstall and configure X server, GNOME, and GDM
echo "Installing GNOME desktop environment and GDM..."
apt update
apt install -y xserver-xorg-core xserver-xorg gnome gdm3 --no-install-recommends

# Set GDM3 as the default display manager
echo "Setting GDM3 as the default display manager..."
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager
dpkg-reconfigure gdm3

# Step 4: Validate installation
echo "Validating installation..."
dpkg -l | grep -E "gnome|gdm3|xserver-xorg"

# Step 5: Fix user permissions and settings
echo "Fixing user permissions and configurations..."
for user in $(ls /home); do
    echo "Applying settings for user: $user"
    chown -R "$user":"$user" "/home/$user"
    chmod -R 700 "/home/$user"
    rm -rf "/home/$user/.cache" "/home/$user/.config" "/home/$user/.local"
done

# Verify permissions
for user in $(ls /home); do
    echo "Verifying permissions for /home/$user..."
    ls -ld "/home/$user"
done

# Step 6: Configure screen rotation
echo "Configuring screen rotation..."
if ! grep -q "display_rotate=2" /boot/config.txt; then
    echo "display_rotate=2" >> /boot/config.txt
    echo "Screen rotation set to 2."
else
    echo "Screen rotation already set to 2."
fi

# Verify /boot/config.txt
verify_file_permissions "/boot/config.txt"
grep "display_rotate" /boot/config.txt

# Step 7: Check logs for errors
echo "Checking system logs for errors..."
check_logs_for_errors "/var/log/lightdm/lightdm.log"
check_logs_for_errors "/var/log/Xorg.0.log"
check_logs_for_errors "/var/log/syslog"

# Step 8: Restart services and reboot
echo "Restarting display manager and services..."
systemctl restart gdm3

echo "Rebooting the system to apply changes..."
reboot

exit 0
