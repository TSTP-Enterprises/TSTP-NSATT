#!/bin/bash

log_file="/nsatt/storage/logs/restart_launcher_$(date +%Y-%m-%d).log"

# Log the restart attempt
echo "$(date): Attempting to restart launcher..." >> "$log_file"

# Check if port 8080 is in use before restarting the launcher
if lsof -i:8080 > /dev/null; then
    echo "$(date): Port 8080 is in use. Main app is running." >> "$log_file"
    touch /nsatt/storage/settings/start_app
fi

# Kill any process using port 8081
fuser -k 8081/tcp >> "$log_file" 2>&1

# Small delay to ensure the port is freed
sleep 10

# Restart Launcher App
nohup python3 /nsatt/storage/scripts/utility/start_app_launcher.py >> "$log_file" 2>&1 &
if [ $? -eq 0 ]; then
    echo "$(date): Launcher restarted successfully." >> "$log_file"
else
    echo "$(date): Failed to restart launcher." >> "$log_file"
    exit 1
fi