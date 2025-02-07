#!/bin/bash

################################################################################
# Script Name: recover_lightdm.sh
# Description: Automates the diagnosis and repair of LightDM login loop issues
#              on Kali Linux. Includes advanced logging, error handling,
#              automated and manual recovery modes, and diagnostic tools.
#              Additionally, it restores display orientation, ensures startx runs
#              at launch, and fixes cursor visibility issues.
# Author: OpenAI ChatGPT
# Location: /home/<your_user>/nsatt/recovery/recover_lightdm.sh
################################################################################

# Exit on errors, undefined variables, and errors in pipelines
set -euo pipefail

# Constants
SCRIPT_VERSION="2.1"
DEFAULT_USER="${SUDO_USER:-$(logname)}"
USER_HOME="/home/$DEFAULT_USER"
LOG_DIR="$USER_HOME/nsatt/logs/recovery"
LOG_FILE="$LOG_DIR/recover_lightdm_$(date '+%Y-%m-%d').log"
LIGHTDM_LOG="/var/log/lightdm/lightdm.log"
XORG_LOG="/var/log/Xorg.0.log"
DAILY_LOG_RETENTION=30
REPO_URL="https://example.com/recovery_files"  # Replace with actual URL if needed

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo.${NC}"
    exit 1
fi

# Function to log events with color-coded messages
log_event() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)
            echo -e "${GREEN}${timestamp} - INFO: ${message}${NC}" | tee -a "$LOG_FILE"
            ;;
        WARNING)
            echo -e "${YELLOW}${timestamp} - WARNING: ${message}${NC}" | tee -a "$LOG_FILE"
            ;;
        ERROR)
            echo -e "${RED}${timestamp} - ERROR: ${message}${NC}" | tee -a "$LOG_FILE" >&2
            ;;
        *)
            echo -e "${timestamp} - ${level}: ${message}" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Function to ensure a directory exists
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_event "ERROR" "Failed to create directory $dir."
            exit 1
        }
        chmod 755 "$dir"
        log_event "INFO" "Created directory $dir."
    else
        log_event "INFO" "Directory $dir already exists."
    fi
}

# Function to rotate logs older than retention period
rotate_logs() {
    find "$LOG_DIR" -type f -name "recover_lightdm_*.log" -mtime +$DAILY_LOG_RETENTION -exec rm -f {} \; || {
        log_event "WARNING" "Failed to rotate old logs in $LOG_DIR."
    }
    log_event "INFO" "Log rotation completed. Logs older than $DAILY_LOG_RETENTION days have been deleted."
}

# Function to verify required commands are available
verify_command() {
    if ! command -v "$1" &>/dev/null; then
        log_event "ERROR" "Command '$1' not found. Please install it before running this script."
        exit 1
    fi
}

# Function to ensure dependencies are installed
ensure_dependencies() {
    log_event "INFO" "Ensuring required dependencies are installed."
    local dependencies=(apt-get dpkg lightdm dos2unix wget systemctl xrandr startx xinit nano)
    for cmd in "${dependencies[@]}"; do
        verify_command "$cmd"
    done
}

# Function to check and clean disk space if necessary
check_disk_space() {
    log_event "INFO" "Checking disk space."
    local usage
    usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -ge 90 ]; then
        log_event "WARNING" "Root partition is $usage% full. Cleaning up unnecessary files."
        apt-get clean || log_event "ERROR" "Failed to clean apt cache."
        rm -rf /var/cache/apt/archives/* || log_event "ERROR" "Failed to remove cached packages."
    else
        log_event "INFO" "Sufficient disk space available."
    fi
}

# Function to analyze LightDM logs
analyze_lightdm_logs() {
    log_event "INFO" "Analyzing LightDM logs..."
    if [ -f "$LIGHTDM_LOG" ]; then
        if grep -E "ERROR|WARNING" "$LIGHTDM_LOG" | tee -a "$LOG_FILE"; then
            log_event "INFO" "Found issues in LightDM logs."
        else
            log_event "INFO" "No ERROR or WARNING found in LightDM logs."
        fi
    else
        log_event "WARNING" "LightDM log file not found at $LIGHTDM_LOG."
    fi
}

# Function to analyze Xorg logs
analyze_xorg_logs() {
    log_event "INFO" "Analyzing Xorg logs..."
    if [ -f "$XORG_LOG" ]; then
        if grep -E "\(EE\)|\(WW\)" "$XORG_LOG" | tee -a "$LOG_FILE"; then
            log_event "INFO" "Found issues in Xorg logs."
        else
            log_event "INFO" "No critical errors found in Xorg logs."
        fi
    else
        log_event "WARNING" "Xorg log file not found at $XORG_LOG."
    fi
}

# Function to reset display orientation to landscape
reset_display_orientation() {
    log_event "INFO" "Resetting display orientation to landscape."

    # Identify the connected display
    local display_output
    display_output=$(xrandr | grep " connected" | awk '{print $1}' | head -n1)
    
    if [ -z "$display_output" ]; then
        log_event "ERROR" "No connected display detected."
        return 1
    fi

    log_event "INFO" "Detected display output: $display_output"

    # Set orientation to normal (landscape)
    if xrandr --output "$display_output" --rotate normal &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully set orientation to landscape for $display_output."
    else
        log_event "ERROR" "Failed to set orientation to landscape for $display_output."
        return 1
    fi

    # Make the change permanent by creating/updating X configuration
    local config_dir="/etc/X11/xorg.conf.d"
    local config_file="$config_dir/10-monitor.conf"

    ensure_directory "$config_dir"

    cat <<EOF > "$config_file"
Section "Monitor"
    Identifier "$display_output"
    Option "Rotate" "normal"
EndSection

Section "Screen"
    Identifier "Screen0"
    Monitor "$display_output"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080"
    EndSubSection
EndSection
EOF

    log_event "INFO" "Created/Updated display configuration at $config_file."

    # Validate the configuration by testing Xorg
    if X -configure &>> "$LOG_FILE"; then
        log_event "INFO" "Xorg configuration validated successfully."
    else
        log_event "WARNING" "Xorg configuration validation encountered issues."
    fi
}

# Function to ensure startx runs at launch
ensure_startx_at_launch() {
    log_event "INFO" "Configuring system to start graphical interface automatically using startx."

    # Install necessary packages
    if apt-get install -y xinit xfce4 &>> "$LOG_FILE"; then
        log_event "INFO" "Installed xinit and xfce4 packages."
    else
        log_event "ERROR" "Failed to install xinit and/or xfce4."
        return 1
    fi

    # Configure .bash_profile to startx automatically
    local bash_profile="$USER_HOME/.bash_profile"
    ensure_directory "$(dirname "$bash_profile")"

    if grep -q "startx" "$bash_profile" 2>/dev/null; then
        log_event "INFO" "startx is already configured to run at login."
    else
        cat <<EOF >> "$bash_profile"

# Start graphical interface automatically
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    startx
fi
EOF
        log_event "INFO" "Configured .bash_profile to startx automatically."
    fi

    # Create or update .xinitrc to start the desktop environment
    local xinitrc="$USER_HOME/.xinitrc"
    cat <<EOF > "$xinitrc"
#!/bin/sh
exec startxfce4
EOF

    chmod +x "$xinitrc"
    log_event "INFO" "Created/Updated .xinitrc to start Xfce."

    # Validate startx by attempting to run it in a test mode
    if su - "$DEFAULT_USER" -c "startx -- :1 vt2" &>/dev/null; then
        log_event "INFO" "startx is configured correctly."
    else
        log_event "WARNING" "startx configuration may have issues. Please verify manually."
    fi
}

# Function to restore cursor visibility
restore_cursor_visibility() {
    log_event "INFO" "Restoring cursor visibility settings."

    local cursor_config_file="/etc/X11/xorg.conf.d/90-cursor.conf"

    if [ -f "$cursor_config_file" ]; then
        log_event "INFO" "Cursor configuration file exists. Verifying settings."
    else
        log_event "INFO" "Creating cursor visibility configuration at $cursor_config_file."
        ensure_directory "$(dirname "$cursor_config_file")"
        cat <<EOF > "$cursor_config_file"
Section "Device"
    Identifier "Device0"
    Option "SWCursor" "off"
EndSection
EOF
        log_event "INFO" "Created cursor configuration at $cursor_config_file."
    fi

    # Ensure cursor themes are installed
    if apt-get install -y xcursor-themes &>> "$LOG_FILE"; then
        log_event "INFO" "Installed xcursor-themes."
    else
        log_event "ERROR" "Failed to install xcursor-themes."
    fi

    # Set a default cursor theme
    if update-alternatives --set x-cursor-theme /usr/share/icons/Adwaita/cursor.theme &>> "$LOG_FILE"; then
        log_event "INFO" "Set default cursor theme to Adwaita."
    else
        log_event "WARNING" "Failed to set default cursor theme. Please set it manually."
    fi

    # Restart LightDM to apply cursor settings
    if systemctl restart lightdm &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully restarted LightDM to apply cursor settings."
    else
        log_event "ERROR" "Failed to restart LightDM after modifying cursor settings."
    fi
}

# Function to reconfigure LightDM
reconfigure_lightdm() {
    log_event "INFO" "Reconfiguring LightDM."
    if dpkg-reconfigure lightdm &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully reconfigured LightDM."
        if systemctl restart lightdm &>> "$LOG_FILE"; then
            log_event "INFO" "Successfully restarted LightDM."
        else
            log_event "ERROR" "Failed to restart LightDM after reconfiguration."
        fi
    else
        log_event "ERROR" "Failed to reconfigure LightDM."
    fi
}

# Function to reinstall LightDM
reinstall_lightdm() {
    log_event "INFO" "Reinstalling LightDM."
    if apt-get purge -y lightdm &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully purged LightDM."
    else
        log_event "ERROR" "Failed to purge LightDM."
        return 1
    fi

    if apt-get install -y lightdm &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully installed LightDM."
    else
        log_event "ERROR" "Failed to install LightDM."
        return 1
    fi

    reconfigure_lightdm
}

# Function to fix user permissions
fix_permissions() {
    log_event "INFO" "Fixing permissions for the home directory of $DEFAULT_USER."

    if chown -R "$DEFAULT_USER":"$DEFAULT_USER" "$USER_HOME" &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully reset ownership for home directory."
    else
        log_event "ERROR" "Failed to reset ownership for home directory."
    fi

    if chmod 700 "$USER_HOME" &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully set permissions for home directory."
    else
        log_event "ERROR" "Failed to set permissions for home directory."
    fi
}

# Function to reinstall desktop environment
reinstall_desktop_environment() {
    log_event "INFO" "Reinstalling the desktop environment (Xfce)."
    if apt-get install --reinstall -y kali-desktop-xfce &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully reinstalled Xfce desktop environment."
    else
        log_event "ERROR" "Failed to reinstall Xfce desktop environment."
    fi
}

# Function to clean .Xauthority file
clean_xauthority() {
    log_event "INFO" "Cleaning .Xauthority file for $DEFAULT_USER."
    if rm -f "$USER_HOME/.Xauthority" &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully removed .Xauthority file."
    else
        log_event "ERROR" "Failed to remove .Xauthority file."
    fi
}

# Function to create a test user
create_test_user() {
    log_event "INFO" "Creating a test user for diagnostics."
    if id "testuser" &>/dev/null; then
        log_event "INFO" "Test user 'testuser' already exists."
    else
        if adduser --disabled-password --gecos "" testuser &>> "$LOG_FILE"; then
            log_event "INFO" "Successfully created testuser."
        else
            log_event "ERROR" "Failed to create testuser."
        fi

        if usermod -aG sudo testuser &>> "$LOG_FILE"; then
            log_event "INFO" "Granted sudo privileges to testuser."
        else
            log_event "ERROR" "Failed to grant sudo privileges to testuser."
        fi
    fi
}

# Function to update and repair packages
update_and_repair_packages() {
    log_event "INFO" "Updating package lists."
    if apt-get update &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully updated package lists."
    else
        log_event "ERROR" "Failed to update package lists."
    fi

    log_event "INFO" "Upgrading packages."
    if apt-get upgrade -y &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully upgraded packages."
    else
        log_event "ERROR" "Failed to upgrade packages."
    fi

    log_event "INFO" "Fixing broken packages."
    if apt-get install -f -y &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully fixed broken packages."
    else
        log_event "ERROR" "Failed to fix broken packages."
    fi

    log_event "INFO" "Reconfiguring packages."
    if dpkg --configure -a &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully reconfigured packages."
    else
        log_event "ERROR" "Failed to reconfigure packages."
    fi
}

# Function to download alternate files if needed
download_alternate_files() {
    log_event "INFO" "Downloading alternate recovery files from $REPO_URL."
    local alternate_files_dir="$USER_HOME/nsatt/recovery/alternate_files"
    ensure_directory "$alternate_files_dir"

    if wget -r -np -nH --cut-dirs=3 -P "$alternate_files_dir" "$REPO_URL" &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully downloaded alternate files."
    else
        log_event "ERROR" "Failed to download alternate files."
    fi
}

# Function to perform automated recovery
automated_recovery() {
    log_event "INFO" "Starting automated recovery process."

    rotate_logs
    check_disk_space
    analyze_lightdm_logs
    analyze_xorg_logs

    # Diagnose and fix issues based on log analysis
    diagnose_issues --auto

    log_event "INFO" "Automated recovery process completed. Rebooting the system."
    reboot
}

# Function to prompt the user for confirmation
prompt_user() {
    local prompt_message="$1"
    while true; do
        read -rp "$prompt_message [y/n]: " yn
        case "$yn" in
            [Yy]* ) return 0;;
            [Nn]* ) log_event "INFO" "User declined: $prompt_message"; return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to handle unexpected errors
handle_unexpected_error() {
    log_event "ERROR" "An unexpected error occurred. Exiting the script."
    exit 1
}

# Function to set the script to run at boot via systemd
setup_service() {
    log_event "INFO" "Setting up the recovery script to run at boot."

    local service_file="/etc/systemd/system/recover_lightdm.service"

    cat <<EOF > "$service_file"
[Unit]
Description=Recover LightDM Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash $0 --auto
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    if systemctl enable recover_lightdm.service &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully enabled recover_lightdm.service to run at boot."
    else
        log_event "ERROR" "Failed to enable recover_lightdm.service."
    fi
}

# Function to perform manual recovery
manual_recovery() {
    log_event "INFO" "Entering manual recovery mode."
    PS3="Select an option: "
    options=(
        "Reconfigure LightDM"
        "Reinstall LightDM"
        "Fix User Permissions"
        "Reinstall Desktop Environment"
        "Clean .Xauthority File"
        "Create Test User"
        "Update and Repair Packages"
        "Enable Autologin"
        "Download Alternate Files"
        "Set Script to Run at Boot"
        "Reset Display Orientation"
        "Ensure startx Runs at Launch"
        "Restore Cursor Visibility"
        "Exit Manual Mode"
    )
    select opt in "${options[@]}"; do
        case "$opt" in
            "Reconfigure LightDM") reconfigure_lightdm ;;
            "Reinstall LightDM") reinstall_lightdm ;;
            "Fix User Permissions") fix_permissions ;;
            "Reinstall Desktop Environment") reinstall_desktop_environment ;;
            "Clean .Xauthority File") clean_xauthority ;;
            "Create Test User") create_test_user ;;
            "Update and Repair Packages") update_and_repair_packages ;;
            "Enable Autologin") enable_autologin ;;
            "Download Alternate Files") download_alternate_files ;;
            "Set Script to Run at Boot") setup_service ;;
            "Reset Display Orientation") reset_display_orientation ;;
            "Ensure startx Runs at Launch") ensure_startx_at_launch ;;
            "Restore Cursor Visibility") restore_cursor_visibility ;;
            "Exit Manual Mode") log_event "INFO" "Exiting manual recovery mode."; break ;;
            *) log_event "WARNING" "Invalid option. Please select a valid option." ;;
        esac
    done
}

# Function to diagnose and fix issues based on logs
diagnose_issues() {
    local mode="$1"

    log_event "INFO" "Diagnosing issues based on log analysis."

    # Check if LightDM is active
    if ! systemctl is-active --quiet lightdm; then
        log_event "WARNING" "LightDM is not active. Attempting to start it."
        if [ "$mode" == "--auto" ]; then
            if systemctl start lightdm &>> "$LOG_FILE"; then
                log_event "INFO" "Successfully started LightDM."
            else
                log_event "ERROR" "Failed to start LightDM."
            fi
        else
            prompt_user "Do you want to start LightDM?" && systemctl start lightdm
        fi
    else
        log_event "INFO" "LightDM is active."
    fi

    # Check for Xorg errors
    if grep -q "(EE)" "$XORG_LOG"; then
        log_event "ERROR" "Xorg has errors. Reconfiguring LightDM."
        if [ "$mode" == "--auto" ]; then
            reconfigure_lightdm
        else
            prompt_user "Do you want to reconfigure LightDM?" && reconfigure_lightdm
        fi
    else
        log_event "INFO" "No critical errors found in Xorg logs."
    fi

    # Check for LightDM errors
    if grep -q "ERROR" "$LIGHTDM_LOG"; then
        log_event "ERROR" "LightDM log contains errors. Reinstalling LightDM."
        if [ "$mode" == "--auto" ]; then
            reinstall_lightdm
        else
            prompt_user "Do you want to reinstall LightDM?" && reinstall_lightdm
        fi
    else
        log_event "INFO" "No critical errors found in LightDM logs."
    fi

    # Check if desktop environment is installed
    if ! dpkg -l | grep -q kali-desktop-xfce; then
        log_event "WARNING" "Desktop environment (Xfce) is not installed."
        if [ "$mode" == "--auto" ]; then
            reinstall_desktop_environment
        else
            prompt_user "Do you want to reinstall the desktop environment?" && reinstall_desktop_environment
        fi
    else
        log_event "INFO" "Desktop environment (Xfce) is installed."
    fi

    # Check permissions
    local ownership
    ownership=$(stat -c %U "$USER_HOME")
    if [ "$ownership" != "$DEFAULT_USER" ]; then
        log_event "WARNING" "Home directory ownership is incorrect."
        if [ "$mode" == "--auto" ]; then
            fix_permissions
        else
            prompt_user "Do you want to fix home directory permissions?" && fix_permissions
        fi
    else
        log_event "INFO" "Home directory ownership is correct."
    fi

    # Clean .Xauthority if present
    if [ -f "$USER_HOME/.Xauthority" ]; then
        log_event "INFO" "Cleaning .Xauthority file."
        if [ "$mode" == "--auto" ]; then
            clean_xauthority
        else
            prompt_user "Do you want to clean the .Xauthority file?" && clean_xauthority
        fi
    fi

    # Update and repair packages
    log_event "INFO" "Ensuring all packages are up to date and configured correctly."
    if [ "$mode" == "--auto" ]; then
        update_and_repair_packages
    else
        prompt_user "Do you want to update and repair packages?" && update_and_repair_packages
    fi

    # Additional Diagnostics

    # Check if input devices are recognized
    log_event "INFO" "Checking input devices."
    if [ -d /proc/bus/input/devices ]; then
        if grep -i "mouse\|keyboard" /proc/bus/input/devices | tee -a "$LOG_FILE"; then
            log_event "INFO" "Input devices are recognized."
        else
            log_event "WARNING" "No mouse or keyboard devices detected."
            if [ "$mode" == "--auto" ]; then
                check_and_reinitialize_input_devices
            else
                prompt_user "Do you want to reinitialize input devices?" && check_and_reinitialize_input_devices
            fi
        fi
    else
        log_event "WARNING" "Cannot access input devices information."
    fi

    # Check display settings
    log_event "INFO" "Checking display settings."
    if command -v xdpyinfo &>/dev/null; then
        if xdpyinfo | tee -a "$LOG_FILE"; then
            log_event "INFO" "Display settings retrieved successfully."
        else
            log_event "ERROR" "Failed to retrieve display information."
        fi
    else
        log_event "WARNING" "xdpyinfo not installed. Installing now."
        if apt-get install -y xdpyinfo &>> "$LOG_FILE"; then
            log_event "INFO" "Installed xdpyinfo."
            if xdpyinfo &>> "$LOG_FILE"; then
                log_event "INFO" "Display settings retrieved successfully."
            else
                log_event "ERROR" "Failed to retrieve display information after installation."
            fi
        else
            log_event "ERROR" "Failed to install xdpyinfo."
        fi
    fi

    # Ensure terminal emulator is installed
    log_event "INFO" "Verifying terminal emulator installation."
    if ! command -v xfce4-terminal &>/dev/null && ! command -v xterm &>/dev/null; then
        log_event "WARNING" "No terminal emulator found. Installing xfce4-terminal."
        if apt-get install -y xfce4-terminal &>> "$LOG_FILE"; then
            log_event "INFO" "Successfully installed xfce4-terminal."
        else
            log_event "ERROR" "Failed to install xfce4-terminal."
        fi
    else
        log_event "INFO" "Terminal emulator is installed."
    fi

    # Check for cursor issues
    log_event "INFO" "Checking cursor visibility settings."
    local cursor_config_file="/etc/X11/xorg.conf.d/90-cursor.conf"
    if [ -f "$cursor_config_file" ]; then
        if grep -q "SWCursor" "$cursor_config_file"; then
            log_event "INFO" "Cursor settings already configured."
        else
            log_event "INFO" "Adding cursor visibility configuration to $cursor_config_file."
            cat <<EOF >> "$cursor_config_file"
Section "Device"
    Identifier "Device0"
    Option "SWCursor" "off"
EndSection
EOF
            log_event "INFO" "Added cursor visibility settings to $cursor_config_file."
        fi
    else
        log_event "INFO" "Creating cursor visibility configuration at $cursor_config_file."
        ensure_directory "$(dirname "$cursor_config_file")"
        cat <<EOF > "$cursor_config_file"
Section "Device"
    Identifier "Device0"
    Option "SWCursor" "off"
EndSection
EOF
        log_event "INFO" "Created cursor visibility configuration at $cursor_config_file."
    fi

    # Restart LightDM to apply cursor settings
    log_event "INFO" "Restarting LightDM to apply cursor settings."
    if systemctl restart lightdm &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully restarted LightDM."
    else
        log_event "ERROR" "Failed to restart LightDM."
    fi
}

# Function to enable autologin
enable_autologin() {
    log_event "INFO" "Configuring LightDM for autologin."
    local config_dir="/etc/lightdm/lightdm.conf.d"
    local config_file="$config_dir/50-autologin.conf"

    ensure_directory "$config_dir"

    cat <<EOF > "$config_file"
[Seat:*]
autologin-user=$DEFAULT_USER
autologin-user-timeout=0
EOF

    log_event "INFO" "Autologin configuration added to $config_file."

    if systemctl restart lightdm &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully restarted LightDM after enabling autologin."
    else
        log_event "ERROR" "Failed to restart LightDM after enabling autologin."
    fi
}

# Function to check and reinitialize input devices
check_and_reinitialize_input_devices() {
    log_event "INFO" "Checking and reinitializing input devices."
    if ls /proc/bus/input/devices &>/dev/null; then
        if grep -i "mouse\|keyboard" /proc/bus/input/devices | tee -a "$LOG_FILE"; then
            log_event "INFO" "Input devices are recognized."
        else
            log_event "WARNING" "No mouse or keyboard detected. Attempting to reinitialize input drivers."
            if modprobe -r usbhid && modprobe usbhid; then
                log_event "INFO" "Successfully reinitialized USB HID drivers."
            else
                log_event "ERROR" "Failed to reinitialize USB HID drivers."
            fi
        fi
    else
        log_event "WARNING" "Input devices information unavailable."
    fi
}

# Trap unexpected errors
trap 'handle_unexpected_error' ERR

# Function to set up input device reinitialization
setup_input_device_reinit() {
    log_event "INFO" "Setting up input device reinitialization service."

    local service_file="/etc/systemd/system/input_reinit.service"

    cat <<EOF > "$service_file"
[Unit]
Description=Reinitialize USB HID Drivers
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe -r usbhid
ExecStartPost=/sbin/modprobe usbhid

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    if systemctl enable input_reinit.service &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully enabled input_reinit.service."
    else
        log_event "ERROR" "Failed to enable input_reinit.service."
    fi
}

# Function to display the main menu
main_menu() {
    log_event "INFO" "Starting LightDM Recovery Script v$SCRIPT_VERSION."
    ensure_directory "$LOG_DIR"
    rotate_logs
    ensure_dependencies

    PS3="Select an option: "
    options=(
        "Automatic Recovery"
        "Manual Recovery"
        "Exit"
    )
    select opt in "${options[@]}"; do
        case "$opt" in
            "Automatic Recovery")
                automated_recovery
                ;;
            "Manual Recovery")
                manual_recovery
                ;;
            "Exit")
                log_event "INFO" "Exiting the recovery script."
                exit 0
                ;;
            *)
                log_event "WARNING" "Invalid option. Please select a valid option."
                ;;
        esac
    done
}

# Function to reset display settings to defaults
reset_display_settings() {
    log_event "INFO" "Resetting display settings to defaults."

    local display_output
    display_output=$(xrandr | grep " connected" | awk '{print $1}' | head -n1)

    if [ -z "$display_output" ]; then
        log_event "ERROR" "No connected display detected. Cannot reset display settings."
        return 1
    fi

    log_event "INFO" "Detected display output: $display_output"

    if xrandr --output "$display_output" --auto &>> "$LOG_FILE"; then
        log_event "INFO" "Successfully reset display settings for $display_output."
    else
        log_event "ERROR" "Failed to reset display settings for $display_output."
    fi
}

# Start the script by displaying the main menu
main_menu
