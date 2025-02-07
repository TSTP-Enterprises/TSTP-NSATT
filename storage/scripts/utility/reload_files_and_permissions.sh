#!/bin/bash

# Function to reload files and permissions
reload_files_and_permissions() {
    # Paths
    base_dir="/nsatt"
    storage_dir="/nsatt/storage"
    scripts_dir="$storage_dir/scripts"
    scripts_defenses_dir="$scripts_dir/defense"
    scripts_exploits_dir="$scripts_dir/exploits"
    scripts_utility_dir="$scripts_dir/utility"
    scripts_web_dir="$scripts_dir/nsatt_web"
    scripts_network_dir="$scripts_dir/networking"
    scripts_plugins_dir="$scripts_dir/plugins"
    scripts_recon_dir="$scripts_dir/recon"
    scripts_security_dir="$scripts_dir/security"
    scripts_software_dir="$scripts_dir/software"
    scripts_testing_dir="$scripts_dir/testing"
    systemd_dir="/etc/systemd/system"
    log_dir="$base_dir/logs"
    debug_mode2=true

    # Excluded folders
    excluded_folders=(
        "/nsatt/storage/scripts/nsatt_web/venv/"
        # Add more folders to exclude here
    )

    # Start time
    start_time=$(date +%s)

    # Set directory permissions first
    echo "Setting directory permissions..."
    find "$scripts_dir" -type d -exec chmod 755 {} \;

    # Checkpoint: Directory permissions set
    elapsed_time=$(( $(date +%s) - start_time ))
    echo "Checkpoint: Directory permissions set in $elapsed_time seconds."

    # Permissions for files
    permissions=()
    while IFS= read -r -d '' file; do
        # Check if the file is in an excluded folder
        exclude=false
        for folder in "${excluded_folders[@]}"; do
            if [[ "$file" == "$folder"* ]]; then
                exclude=true
                break
            fi
        done
        if [ "$exclude" = false ]; then
            permissions+=("$file")
        fi
    done < <(find "$scripts_dir" -type f \( -name "*.sh" -o -name "*.py" \) -print0)

    # Checkpoint: Files identified
    elapsed_time=$(( $(date +%s) - start_time ))
    echo "Checkpoint: Files identified in $elapsed_time seconds."

    # Ensure log directory exists
    if [ ! -d "$log_dir" ]; then
        if ! mkdir -p "$log_dir"; then
            echo "ERROR: Failed to create log directory $log_dir"
        fi
        chmod 755 "$log_dir"
    fi

    # Checkpoint: Log directory ensured
    elapsed_time=$(( $(date +%s) - start_time ))
    echo "Checkpoint: Log directory ensured in $elapsed_time seconds."

    # Debug-specific operations
    if [ "$debug_mode2" = true ]; then
        debug_log="$log_dir/set_ip_address.log"
        if [ -f "$debug_log" ]; then
            rm -f "$debug_log"
        fi
        touch "$debug_log"
        chmod 755 "$debug_log"
    fi

    # Checkpoint: Debug operations completed
    elapsed_time=$(( $(date +%s) - start_time ))
    echo "Checkpoint: Debug operations completed in $elapsed_time seconds."

    # Set permissions
    for file in "${permissions[@]}"; do
        if [ -f "$file" ]; then
            if ! chmod 755 "$file"; then
                echo "ERROR: Failed to update permissions for $file"
            fi
        fi
    done

    # Checkpoint: Permissions set
    elapsed_time=$(( $(date +%s) - start_time ))
    echo "Checkpoint: Permissions set in $elapsed_time seconds."

    # Convert files to Unix format
    for file in "${permissions[@]}"; do
        if [ -f "$file" ]; then
            dos2unix "$file" >/dev/null 2>&1
        fi
    done

    # Checkpoint: Files converted to Unix format
    elapsed_time=$(( $(date +%s) - start_time ))
    echo "Checkpoint: Files converted to Unix format in $elapsed_time seconds."

    # Success message
    echo ""
    echo ""
    echo "       _   _______ ___  ____________    "
    echo "      / | / / ___//   |/_  __/_  __/    "
    echo "     /  |/ /\__ \/ /| | / /   / /       "
    echo "    / /|  /___/ / ___ |/ /   / /        "
    echo "   /_/ |_//____/_/  |_/_/   /_/         "
    echo "                                        "
    echo "----------------------------------------"
    echo "----------------------------------------"
    echo ""
    echo "     All files reloaded successfully."
    echo ""
    echo "----------------------------------------"
    echo "----------------------------------------"
}

reload_files_and_permissions