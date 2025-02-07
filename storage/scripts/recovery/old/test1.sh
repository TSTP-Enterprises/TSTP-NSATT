#!/bin/bash

# Script to fix LightDM, XFCE4, and login issues

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

echo "Starting troubleshooting and fixes for LightDM and XFCE4..."

# Step 1: Fix PAM configuration for LightDM
echo "Fixing PAM configuration for LightDM..."
cat <<EOL > /etc/pam.d/lightdm
#%PAM-1.0
auth      requisite pam_nologin.so
auth      required  pam_env.so
auth      required  pam_unix.so nullok
account   required  pam_unix.so
session   required  pam_limits.so
session   required  pam_unix.so
EOL

# Step 2: Reset user configurations
USER_HOME="/home/nsatt-admin"
echo "Resetting user configurations for $USER_HOME..."
rm -rf "$USER_HOME/.cache/sessions"
mv "$USER_HOME/.config/xfce4" "$USER_HOME/.config/xfce4.backup" 2>/dev/null
rm -f "$USER_HOME/.Xauthority"
chown -R nsatt-admin:nsatt-admin "$USER_HOME"
chmod -R 700 "$USER_HOME"

# Step 3: Fix orientation in /boot/config.txt
echo "Fixing screen orientation in /boot/config.txt..."
sed -i '/^display_rotate=/d' /boot/config.txt
echo "display_rotate=0" >> /boot/config.txt

# Step 4: Reconfigure LightDM
echo "Reconfiguring LightDM..."
dpkg-reconfigure lightdm

# Step 5: Reinstall XFCE4 and LightDM (optional, ensure packages are present)
echo "Reinstalling XFCE4 and LightDM..."
apt update
apt install --reinstall -y xfce4 xfce4-session lightdm

# Step 6: Create and configure a test user
TEST_USER="testuser1"
if ! id "$TEST_USER" &>/dev/null; then
    echo "Creating test user '$TEST_USER'..."
    adduser --disabled-password --gecos "" "$TEST_USER"
    echo "$TEST_USER:password" | chpasswd
    usermod -aG sudo "$TEST_USER"
fi

# Step 7: Set permissions for /tmp
echo "Fixing permissions for /tmp..."
chmod 1777 /tmp

# Step 8: Clean logs for easier troubleshooting
echo "Cleaning old logs..."
rm -f /var/log/lightdm/lightdm.log
rm -f /var/log/Xorg.0.log

# Step 9: Restart services and reboot
echo "Restarting LightDM service..."
systemctl restart lightdm

echo "Fixes applied. Please reboot the system to apply changes."
echo "Use 'sudo reboot' to restart."
