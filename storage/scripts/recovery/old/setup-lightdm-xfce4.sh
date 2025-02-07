#!/bin/bash

# Ensure the script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Update package list
echo "Updating package list..."
apt update

# Remove GNOME and other desktop environments
echo "Removing unnecessary desktop environments..."
apt purge -y kali-desktop-gnome gdm3 xfce4-session gnome-session \
    mate-desktop-environment lxde lxqt cinnamon kde-plasma-desktop

# Remove residual packages and auto-remove unused dependencies
echo "Cleaning up unused packages..."
apt autoremove --purge -y
apt autoclean -y

# Install only LightDM and XFCE4
echo "Installing LightDM and XFCE4..."
apt install -y lightdm lightdm-gtk-greeter xfce4 xfce4-goodies xorg mesa-utils

# Configure LightDM
echo "Setting LightDM as the default display manager..."
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
dpkg-reconfigure lightdm

# Ensure Xorg configuration is minimal
echo "Ensuring a minimal Xorg configuration..."
cat > /etc/X11/xorg.conf <<EOF
Section "Device"
    Identifier "Default Device"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
EndSection

Section "Screen"
    Identifier "Default Screen"
    Device "Default Device"
EndSection
EOF

# Set up .xinitrc to start XFCE
echo "Configuring .xinitrc for XFCE..."
echo "exec startxfce4" > ~/.xinitrc

# Enable the vc4-fkms-v3d overlay for Raspberry Pi
echo "Configuring /boot/config.txt..."
if ! grep -q "dtoverlay=vc4-fkms-v3d" /boot/config.txt; then
    cat >> /boot/config.txt <<EOF
dtoverlay=vc4-fkms-v3d
max_framebuffers=2
EOF
fi

# Clear XFCE configuration and session cache
echo "Resetting XFCE configuration..."
rm -rf ~/.config/xfce4 ~/.cache/sessions

# Reboot to apply changes
echo "Installation complete. Rebooting now..."
reboot
