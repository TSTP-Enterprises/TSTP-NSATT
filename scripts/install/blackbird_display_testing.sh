#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (use sudo)."
  exit 1
fi

# Variables
CONFIG_FILE="/boot/config.txt"
XORG_CONF_DIR="/etc/X11/xorg.conf.d"
XORG_CONF_FILE="$XORG_CONF_DIR/10-monitor.conf"
BACKUP_DIR="/boot/backup_configs"
LOG_DIR="/nsatt/logs/repair"
LOG_FILE="$LOG_DIR/refine_displays_log.txt"

# Create required directories
mkdir -p $LOG_DIR
mkdir -p $BACKUP_DIR
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==== Starting Refine Displays Script ===="

# Function: Backup Configurations
backup_configs() {
  echo "Backing up configuration files..."
  cp $CONFIG_FILE $BACKUP_DIR/config.txt.backup_$(date +%Y%m%d%H%M%S)
  cp $XORG_CONF_FILE $BACKUP_DIR/10-monitor.conf.backup_$(date +%Y%m%d%H%M%S) 2>/dev/null || true
}

# Function: Restore Configurations
restore_configs() {
  echo "Restoring the last backup..."
  if [ -f $BACKUP_DIR/config.txt.backup_* ]; then
    cp $(ls -t $BACKUP_DIR/config.txt.backup_* | head -n 1) $CONFIG_FILE
    echo "Restored /boot/config.txt"
  fi
  if [ -f $BACKUP_DIR/10-monitor.conf.backup_* ]; then
    cp $(ls -t $BACKUP_DIR/10-monitor.conf.backup_* | head -n 1) $XORG_CONF_FILE
    echo "Restored /etc/X11/xorg.conf.d/10-monitor.conf"
  fi
}

# Function: Apply Fixes
apply_fixes() {
  echo "Applying fixes to /boot/config.txt..."
  sudo bash -c "cat > $CONFIG_FILE" <<EOL
# Force HDMI even if unplugged
hdmi_force_hotplug=1

# Primary display: 1.5-inch touchscreen (HDMI-1)
hdmi_force_hotplug:0=1
hdmi_group:0=2
hdmi_mode:0=87
hdmi_cvt:0=480 480 60 6 0 0 0
hdmi_drive:0=2

# Secondary display: 24-inch monitor (HDMI-2)
hdmi_force_hotplug:1=1
hdmi_group:1=2
hdmi_mode:1=82  # 1920x1080 @ 60Hz
hdmi_drive:1=2

# Disable splash screen for consistent HDMI output during boot
disable_splash=1

# Touchscreen overlay for the 1.5-inch touchscreen
dtoverlay=spotpear_240x240_st7789_lcd1inch54
EOL

  echo "Resetting Xorg configuration..."
  sudo rm -f $XORG_CONF_FILE
  sudo mkdir -p $XORG_CONF_DIR

  sudo bash -c "cat > $XORG_CONF_FILE" <<EOL
Section "Device"
    Identifier "VC4 Graphics"
    Driver "fbdev"
EndSection

Section "Monitor"
    Identifier "HDMI-1"
    Option "PreferredMode" "480x480"
    Option "Primary" "true"
EndSection

Section "Monitor"
    Identifier "HDMI-2"
    Option "PreferredMode" "1920x1080"
EndSection

Section "Screen"
    Identifier "Screen 0"
    Device "VC4 Graphics"
    Monitor "HDMI-1"
    SubSection "Display"
        Modes "480x480"
    EndSubSection
EndSection

Section "Screen"
    Identifier "Screen 1"
    Device "VC4 Graphics"
    Monitor "HDMI-2"
    SubSection "Display"
        Modes "1920x1080"
    EndSubSection
EndSection
EOL
}

# Function: Validate Changes
validate_changes() {
  echo "Validating /boot/config.txt..."
  if grep -q "hdmi_force_hotplug=1" $CONFIG_FILE && \
     grep -q "hdmi_mode:1=82" $CONFIG_FILE && \
     grep -q "dtoverlay=spotpear_240x240_st7789_lcd1inch54" $CONFIG_FILE; then
    echo "Validation successful: /boot/config.txt is correctly configured."
  else
    echo "Validation failed: /boot/config.txt is not configured as expected."
    exit 1
  fi
}

# Function: Test Display Resolutions
test_resolutions() {
  echo "Testing resolutions dynamically..."
  xrandr --output HDMI-1 --mode 480x480 --primary
  xrandr --output HDMI-2 --mode 1920x1080 --right-of HDMI-1
  echo "Test complete. Verify the displays."
}

# Menu for user selection
echo "Choose an option:"
echo "1) Backup current configurations"
echo "2) Apply display fixes"
echo "3) Test resolutions dynamically"
echo "4) Restore last backup"
echo "5) Exit"
read -p "Enter your choice: " choice

case $choice in
  1)
    backup_configs
    ;;
  2)
    backup_configs
    apply_fixes
    validate_changes
    echo "Fixes applied successfully. Rebooting..."
    sudo reboot
    ;;
  3)
    test_resolutions
    ;;
  4)
    restore_configs
    echo "Restoration complete. Rebooting..."
    sudo reboot
    ;;
  5)
    echo "Exiting script."
    exit 0
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac
