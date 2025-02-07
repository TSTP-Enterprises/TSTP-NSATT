#!/bin/bash

# Script to setup, repair, trigger, and debug the 1.54-inch SPI display on Kali Linux
# Includes backup, restore, error handling, and automatic_mode

set -e  # Exit immediately on error

# Define constants
AUTOMATIC_MODE_FILE="/nsatt/settings/automatic_mode.nsatt"
BACKUP_DIR="/backup_1_54inch_spi_display"
CONFIG_FILE="/boot/config.txt"
BASH_PROFILE_PATH="/root/.bash_profile"
XORG_CONF_DIR="/usr/share/X11/xorg.conf.d"
DTBO_FILE="spotpear_240x240_st7789_lcd1inch54.dtbo"
DTBO_URL="https://cdn.static.spotpear.com/uploads/download/diver/gm154/spotpear_240x240_st7789_lcd1inch54.dtbo"
GPIO_MONITOR_SCRIPT="/usr/local/bin/gpio_monitor.py"
GPIO_SERVICE_FILE="/etc/systemd/system/gpio_monitor.service"
FBCP_SERVICE_FILE="/etc/systemd/system/fbcp.service"

# Helper function to log messages
log_message() {
    local message="$1"
    echo "[INFO] $message"
}

# Check for automatic_mode
AUTOMATIC_MODE=false
if [ -f "$AUTOMATIC_MODE_FILE" ]; then
    AUTOMATIC_MODE=true
fi

# Function to check if a package is installed
check_package() {
    dpkg -l "$1" &>/dev/null
}

# Function to check required packages and install missing ones
install_packages() {
    local packages=("xserver-xorg" "xinit" "git" "cmake" "libraspberrypi-dev" "xserver-xorg-input-evdev" "xinput-calibrator" "python3-gpiozero" "python3-rpi.gpio" "python3-pip" "image-magick")
    local missing_packages=()

    log_message "Checking required packages..."
    for pkg in "${packages[@]}"; do
        if ! check_package "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        log_message "Installing missing packages: ${missing_packages[*]}"
        apt update && apt install -y "${missing_packages[@]}"
    else
        log_message "All required packages are already installed."
    fi
}

# Function to download the DTBO file if not present
download_dtbo() {
    if [ ! -f "$DTBO_FILE" ]; then
        log_message "DTBO file not found. Downloading from SpotPear..."
        if ! wget "$DTBO_URL" -O "$DTBO_FILE"; then
            log_message "Error: Failed to download DTBO file"
            exit 1
        fi
    else
        log_message "DTBO file already exists."
    fi
}

# Function to create backups
backup_files() {
    log_message "Creating backups..."
    mkdir -p "$BACKUP_DIR"
    for file in "$CONFIG_FILE" "$BASH_PROFILE_PATH" "$XORG_CONF_DIR/99-calibration.conf" "/etc/rc.local"; do
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
        fi
    done
    log_message "Backups completed and stored in $BACKUP_DIR."
}

# Function to restore backups
restore_files() {
    log_message "Restoring backups..."
    for file in "$CONFIG_FILE" "$BASH_PROFILE_PATH" "$XORG_CONF_DIR/99-calibration.conf" "/etc/rc.local"; do
        backup_file="$BACKUP_DIR/$(basename "$file").bak"
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$file"
            log_message "Restored $(basename "$file")."
        else
            log_message "Backup for $(basename "$file") not found."
        fi
    done
    log_message "Restore completed."
}

# Function to configure /boot/config.txt
configure_boot() {
    log_message "Configuring /boot/config.txt..."

    # Comment out conflicting overlays
    sed -i 's/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/' "$CONFIG_FILE" || true
    sed -i 's/^max_framebuffers=2/#max_framebuffers=2/' "$CONFIG_FILE" || true

    # Check if the configuration already exists
    if ! grep -q "dtoverlay=spotpear_240x240_st7789_lcd1inch54" "$CONFIG_FILE"; then
        cat <<EOL >>"$CONFIG_FILE"

# SPI display configuration
dtparam=spi=on
dtoverlay=spotpear_240x240_st7789_lcd1inch54
hdmi_force_hotplug=1
max_usb_current=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt 480 480 60 6 0 0 0
hdmi_drive=2
display_rotate=0
EOL
        log_message "Updated $CONFIG_FILE with SPI display configuration."
    else
        log_message "$CONFIG_FILE already configured for SPI display."
    fi
}

# Function to install and configure fbcp
install_fbcp() {
    log_message "Installing fbcp..."
    if [ ! -f "/usr/local/bin/fbcp" ]; then
        git clone https://github.com/tasanakorn/rpi-fbcp.git
        cd rpi-fbcp
        mkdir -p build
        cd build
        cmake ..
        make
        make install
        cd ../../
        rm -rf rpi-fbcp
        log_message "fbcp installed successfully."
    else
        log_message "fbcp is already installed."
    fi

    # Create systemd service for fbcp
    if [ ! -f "$FBCP_SERVICE_FILE" ]; then
        log_message "Creating systemd service for fbcp..."
        cat <<EOL >"$FBCP_SERVICE_FILE"
[Unit]
Description=Framebuffer Copy Driver
After=network.target

[Service]
ExecStart=/usr/local/bin/fbcp
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL
        systemctl enable fbcp.service
        systemctl start fbcp.service
        log_message "fbcp systemd service created and started."
    else
        log_message "fbcp systemd service already exists."
    fi
}

# Function to configure touch calibration
configure_touch() {
    log_message "Configuring touch calibration..."

    # Copy evdev configuration if not already present
    if [ ! -f "$XORG_CONF_DIR/45-evdev.conf" ]; then
        cp -rf "$XORG_CONF_DIR/10-evdev.conf" "$XORG_CONF_DIR/45-evdev.conf"
        log_message "Copied 10-evdev.conf to 45-evdev.conf."
    else
        log_message "45-evdev.conf already exists."
    fi

    # Create or overwrite 99-calibration.conf
    cat <<EOL >"$XORG_CONF_DIR/99-calibration.conf"
Section "InputClass"
    Identifier      "calibration"
    MatchProduct    "ADS7846 Touchscreen"
    Option  "Calibration"   "326 3536 3509 256"
    Option  "SwapAxes"      "1"
    Option "EmulateThirdButton" "1"
    Option "EmulateThirdButtonTimeout" "1000"
    Option "EmulateThirdButtonMoveThreshold" "300"
EndSection
EOL
    log_message "Touch calibration configured."
}

# Function to set up GPIO monitoring
setup_gpio_monitor() {
    log_message "Setting up GPIO monitoring for buttons and joystick..."

    # Create virtual environment for GPIO monitor if it doesn't exist
    if [ ! -d "/usr/local/bin/gpio_venv" ]; then
        python3 -m venv /usr/local/bin/gpio_venv
        source /usr/local/bin/gpio_venv/bin/activate
        pip3 install RPi.GPIO pynput
    fi

    # Create the GPIO monitoring script
    cat <<'EOL' >"$GPIO_MONITOR_SCRIPT"
#!/usr/bin/env python3

import RPi.GPIO as GPIO
import time
import sys
import os
from pynput.keyboard import Controller, Key

def ensure_gpio_access():
    """Ensure GPIO device permissions are correct"""
    try:
        if not os.access("/dev/gpiomem", os.R_OK | os.W_OK):
            os.system("sudo chmod a+rw /dev/gpiomem")
            time.sleep(1)
    except Exception as e:
        print(f"Error setting GPIO permissions: {str(e)}")

# Initialize keyboard controller
keyboard = Controller()

# Define GPIO pins for buttons and joystick
buttons = [17, 22, 23, 27]  # Example GPIO pins for buttons
joystick = {
    'up': 5,
    'down': 6,
    'left': 13,
    'right': 19,
    'press': 26
}

def reset_gpio():
    """Reset GPIO in case of issues"""
    try:
        GPIO.cleanup()
        time.sleep(2)
    except:
        pass

def setup_gpio_with_recovery(max_attempts=5):
    """Setup GPIO with automatic recovery attempts"""
    for attempt in range(max_attempts):
        try:
            reset_gpio()
            ensure_gpio_access()
            
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            
            # Test setup each pin individually with recovery
            for pin in buttons:
                try:
                    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
                except:
                    reset_gpio()
                    GPIO.setmode(GPIO.BCM)
                    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
                time.sleep(0.2)

            for _, pin in joystick.items():
                try:
                    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
                except:
                    reset_gpio()
                    GPIO.setmode(GPIO.BCM)
                    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
                time.sleep(0.2)
                
            return True
        except Exception as e:
            print(f"GPIO setup attempt {attempt + 1} failed: {str(e)}")
            if attempt < max_attempts - 1:
                print(f"Retrying in {2 ** attempt} seconds...")
                time.sleep(2 ** attempt)  # Exponential backoff
    return False

def on_button_press(pin):
    try:
        if pin in buttons:
            print(f"Button on GPIO {pin} pressed!")
            # Map buttons to keyboard keys as needed
            if pin == 17:
                keyboard.press('a')
                keyboard.release('a')
            elif pin == 22:
                keyboard.press('b')
                keyboard.release('b')
            elif pin == 23:
                keyboard.press('c')
                keyboard.release('c')
            elif pin == 27:
                keyboard.press('d')
                keyboard.release('d')
    except Exception as e:
        print(f"Error in button press handler: {str(e)}")

def on_joystick_move(direction):
    try:
        print(f"Joystick {direction} moved!")
        # Map joystick directions to keyboard keys as needed
        if direction == 'up':
            keyboard.press(Key.up)
            keyboard.release(Key.up)
        elif direction == 'down':
            keyboard.press(Key.down)
            keyboard.release(Key.down)
        elif direction == 'left':
            keyboard.press(Key.left)
            keyboard.release(Key.left)
        elif direction == 'right':
            keyboard.press(Key.right)
            keyboard.release(Key.right)
        elif direction == 'press':
            keyboard.press(Key.enter)
            keyboard.release(Key.enter)
    except Exception as e:
        print(f"Error in joystick handler: {str(e)}")

def monitor_gpio():
    while True:  # Keep trying until successful
        if setup_gpio_with_recovery():
            try:
                print("Monitoring GPIO for button and joystick inputs...")
                while True:
                    for pin in buttons:
                        if GPIO.input(pin) == GPIO.LOW:
                            on_button_press(pin)
                    for direction, pin in joystick.items():
                        if GPIO.input(pin) == GPIO.LOW:
                            on_joystick_move(direction)
                    time.sleep(0.1)
            except Exception as e:
                print(f"Error in monitor loop: {str(e)}")
                print("Attempting recovery...")
                time.sleep(5)
            finally:
                reset_gpio()
        else:
            print("Failed to initialize GPIO, retrying in 10 seconds...")
            time.sleep(10)

if __name__ == "__main__":
    # Initial delay to ensure system is ready
    time.sleep(15)
    monitor_gpio()
EOL

    chmod +x "$GPIO_MONITOR_SCRIPT"

    # Create systemd service for GPIO monitor with recovery options
    if [ ! -f "$GPIO_SERVICE_FILE" ]; then
        log_message "Creating systemd service for GPIO monitor..."
        cat <<EOL >"$GPIO_SERVICE_FILE"
[Unit]
Description=GPIO Monitor for SPI Display Buttons and Joystick
After=multi-user.target fbcp.service
Requires=fbcp.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 15
ExecStart=/usr/local/bin/gpio_venv/bin/python3 $GPIO_MONITOR_SCRIPT
Restart=always
RestartSec=10
StartLimitInterval=0
StartLimitBurst=0
User=root
Environment=PYTHONUNBUFFERED=1
StandardOutput=append:/var/log/gpio_monitor.log
StandardError=append:/var/log/gpio_monitor.log

[Install]
WantedBy=multi-user.target
EOL
        systemctl enable gpio_monitor.service
        systemctl start gpio_monitor.service
        log_message "GPIO monitor systemd service created and started."
    else
        log_message "GPIO monitor systemd service already exists."
        systemctl restart gpio_monitor.service
    fi
}

# Function to download and install the DTBO file
install_dtbo() {
    log_message "Installing DTBO file..."
    download_dtbo
    cp "$DTBO_FILE" /boot/overlays/
    log_message "DTBO file installed to /boot/overlays/."
}

# Function to install all components
install_display() {
    log_message "Starting installation for the 1.54-inch SPI display on Kali Linux..."

    install_packages
    install_dtbo
    configure_boot
    install_fbcp
    configure_touch
    setup_gpio_monitor

    log_message "Installation completed successfully. Please reboot your system to apply changes."
}

# Function to trigger the display (restart fbcp and GPIO monitor)
trigger_display() {
    log_message "Triggering the display..."

    systemctl restart fbcp.service
    systemctl restart gpio_monitor.service

    log_message "Display and GPIO monitor restarted."
}

# Function to debug SPI and framebuffer
debug_gpio() {
    log_message "Debugging SPI and framebuffer status..."
    log_message "SPI devices: $(ls /dev/spi* 2>/dev/null || echo 'None')"
    log_message "Framebuffer devices: $(ls /dev/fb* 2>/dev/null || echo 'None')"
    log_message "Kernel messages related to SPI:"
    dmesg | grep spi || log_message "No SPI-related messages found."

    log_message "Checking fbcp service status:"
    systemctl status fbcp.service --no-pager

    log_message "Checking GPIO monitor service status:"
    systemctl status gpio_monitor.service --no-pager
}

# Main script execution
if [ "$AUTOMATIC_MODE" = true ]; then
    backup_files
    install_display
else
    echo "Choose an option:"
    echo "1) Install"
    echo "2) Restore"
    echo "3) Trigger Display"
    echo "4) Debug SPI and Framebuffer"
    read -rp "Enter your choice (1/2/3/4): " choice
    case $choice in
        1)
            backup_files
            install_display
            ;;
        2)
            restore_files
            ;;
        3)
            trigger_display
            ;;
        4)
            debug_gpio
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi
