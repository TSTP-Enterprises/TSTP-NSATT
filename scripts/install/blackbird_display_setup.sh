#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (use sudo)."
  exit 1
fi

echo "Restoring default graphical packages and settings..."
sudo apt update
sudo apt install --reinstall -y xserver-xorg xinit xserver-xorg-video-fbdev xserver-xorg-video-modesetting

echo "Resetting /boot/config.txt..."
CONFIG_FILE="/boot/config.txt"
sudo cp $CONFIG_FILE "$CONFIG_FILE.backup"

sudo bash -c "cat > $CONFIG_FILE" <<EOL
# Force HDMI even if unplugged
hdmi_force_hotplug=1

# Primary display: 1.5-inch touchscreen (HDMI-1)
hdmi_group:0=2
hdmi_mode:0=87
hdmi_cvt:0=480 480 60 6 0 0 0
hdmi_drive:0=2

# Secondary display: 24-inch monitor (HDMI-2)
hdmi_group:1=2
hdmi_mode:1=82  # 1920x1080 @ 60Hz
hdmi_drive:1=2

# Disable splash screen for consistent HDMI output during boot
disable_splash=1

# Touchscreen overlay for the 1.5-inch touchscreen
dtoverlay=spotpear_240x240_st7789_lcd1inch54
EOL

echo "Resetting Xorg configuration..."
XORG_CONF_DIR="/etc/X11/xorg.conf.d"
XORG_CONF_FILE="$XORG_CONF_DIR/10-monitor.conf"

sudo rm -f $XORG_CONF_FILE
sudo mkdir -p $XORG_CONF_DIR

# Minimal Xorg configuration
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

echo "Setting GUI to start on boot..."
sudo systemctl set-default graphical.target

echo "Rebooting to apply changes..."
sudo reboot
