#!/bin/bash

log_file="/nsatt/storage/logs/restart_app_$(date +%Y-%m-%d).log"

# Log the restart attempt
echo "$(date): Attempting to restart app..." >> "$log_file"

# Kill any process using port 8080
fuser -k 8080/tcp >> "$log_file" 2>&1

# Small delay to ensure the port is freed
sleep 5

# Start the Flask app in the background
nohup python3 /nsatt/storage/scripts/nsatt_web/app.py >> "$log_file" 2>&1 &
if [ $? -eq 0 ]; then
    echo "$(date): App restarted successfully." >> "$log_file"
else
    echo "$(date): Failed to restart app." >> "$log_file"
fi