#!/bin/bash

script_name="Fix Login Issue (Might Be Broken)"


# Enhanced fix_login_issue.sh
# A script to troubleshoot and fix login issues on Kali Linux safely

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
LOG_DIR="/var/log/login_fix_logs"
FULL_LOG="$LOG_DIR/full_fix_log_$(date +%F_%T).log"
FILTERED_LOG="$LOG_DIR/filtered_fix_log_$(date +%F_%T).log"
USERNAME=$(logname 2>/dev/null || echo "$SUDO_USER")
PAM_CONF="/etc/pam.d/common-auth"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
XSESSION_ERRORS="/home/$USERNAME/.xsession-errors"
BACKUP_DIR="/backup_login_fix_$(date +%F_%T)"
XORG_CONF_BACKUP="/etc/X11/xorg.conf.bak"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run with sudo." >&2
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Initialize log files
touch "$FULL_LOG" "$FILTERED_LOG"

# Function to log messages
log() {
    echo -e "$1" | tee -a "$FULL_LOG" "$FILTERED_LOG"
}

# Function to execute commands and handle errors
execute() {
    eval "$1" >> "$FULL_LOG" 2>&1
    if [ $? -ne 0 ]; then
        log "❌ Error executing: $1"
    else
        log "✅ Successfully executed: $1"
    fi
}

# Introduction
log "==============================="
log "Enhanced Login Issue Fix Script Started"
log "Date: $(date)"
log "Username: $USERNAME"
log "==============================="

# Step 1: Backup Configuration Files
log "\n🔒 Backing up critical configuration files..."
mkdir -p "$BACKUP_DIR"
cp -p "$PAM_CONF" "$BACKUP_DIR/" || log "❌ Failed to backup $PAM_CONF"
cp -p "$LIGHTDM_CONF" "$BACKUP_DIR/" || log "❌ Failed to backup $LIGHTDM_CONF"
if [ -f /etc/X11/xorg.conf ]; then
    cp -p /etc/X11/xorg.conf "$XORG_CONF_BACKUP" || log "❌ Failed to backup Xorg configuration"
fi
log "✅ Backups created at $BACKUP_DIR"

# Step 2: Validate PAM Configuration
log "\n🛡️ Validating PAM configuration..."
if grep -q "pam_unix.so" "$PAM_CONF"; then
    log "✅ pam_unix.so found in $PAM_CONF."
else
    log "❌ pam_unix.so missing in $PAM_CONF. Adding it..."
    echo "auth    required    pam_unix.so nullok_secure debug" >> "$PAM_CONF"
fi

if grep -q "pam_winbind.so" "$PAM_CONF"; then
    log "🛠️ Disabling pam_winbind.so in $PAM_CONF..."
    sed -i.bak '/pam_winbind.so/s/^/#/' "$PAM_CONF"
    log "✅ Disabled pam_winbind.so"
fi

# Step 3: Verify LightDM Configuration
log "\n🔧 Verifying LightDM configuration..."
if [ -f "$LIGHTDM_CONF" ]; then
    log "✅ LightDM configuration file exists."
    if ! grep -q "^autologin-user=" "$LIGHTDM_CONF"; then
        log "ℹ️ Adding autologin-user to LightDM configuration..."
        echo "autologin-user=$USERNAME" >> "$LIGHTDM_CONF"
    fi
else
    log "❌ LightDM configuration file missing. Reinstalling LightDM..."
    execute "apt install --reinstall lightdm -y"
fi

# Step 4: Check and Configure Xorg
log "\n🖥️ Checking Xorg configuration..."
if [ -f "$XORG_CONF_BACKUP" ]; then
    log "✅ Xorg configuration backup found."
else
    log "ℹ️ No Xorg configuration backup found. Generating new configuration..."
    execute "Xorg -configure"
    if [ -f /root/xorg.conf.new ]; then
        mv /root/xorg.conf.new /etc/X11/xorg.conf
        log "✅ New Xorg configuration generated."
    else
        log "❌ Failed to generate Xorg configuration."
    fi
fi

# Step 5: Ensure User is in Required Groups
log "\n👥 Adding $USERNAME to required groups..."
execute "usermod -aG video,input,render $USERNAME"

# Step 6: Validate and Configure User Session Files
log "\n🔧 Validating and configuring user session files..."
if [ ! -f "/home/$USERNAME/.xsession" ]; then
    echo "startxfce4" > "/home/$USERNAME/.xsession"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession"
    chmod 700 "/home/$USERNAME/.xsession"
    log "✅ .xsession file created for $USERNAME."
else
    log "✅ .xsession file exists for $USERNAME."
fi

if [ ! -f "/home/$USERNAME/.xinitrc" ]; then
    echo "exec startxfce4" > "/home/$USERNAME/.xinitrc"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xinitrc"
    chmod 700 "/home/$USERNAME/.xinitrc"
    log "✅ .xinitrc file created for $USERNAME."
else
    log "✅ .xinitrc file exists for $USERNAME."
fi

# Step 7: Reinstall Essential Packages
log "\n🔄 Reinstalling essential packages..."
execute "apt update && apt install --reinstall kali-desktop-xfce xserver-xorg-core mesa-utils lightdm -y"

# Step 8: Clean Up Stale Files
log "\n🧹 Cleaning up stale files..."
execute "rm -rf /tmp/.X0-lock /tmp/.ICE-unix /tmp/.X11-unix"

# Step 9: Restart LightDM
log "\n🔄 Restarting LightDM..."
execute "systemctl restart lightdm"

# Step 10: Test Display
log "\n🖥️ Testing display setup..."
if command -v xrandr >/dev/null 2>&1; then
    CONNECTED_DISPLAYS=$(xrandr --query | grep " connected")
    if [ -n "$CONNECTED_DISPLAYS" ]; then
        log "✅ Display detected: $CONNECTED_DISPLAYS"
    else
        log "❌ No connected displays detected. Check connections or logs."
    fi
else
    log "❌ xrandr not found. Ensure Xorg is installed correctly."
fi

# Step 11: Reboot System
log "\n🔄 Rebooting the system to apply all changes..."
execute "reboot"

# End of Script
