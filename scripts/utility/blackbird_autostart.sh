#!/bin/bash

# Ensure /nsatt/storage/plugins has the correct permissions
echo "Setting permissions for /nsatt/storage/plugins..."
sudo mkdir -p /nsatt/storage/plugins
sudo chmod -R 777 /nsatt/storage/plugins

# Create systemd service file
SERVICE_FILE="/etc/systemd/system/nsatt.service"
cat << EOF | sudo tee "$SERVICE_FILE"
[Unit]
Description=NSATT Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /nsatt/nsatt.py
Environment=PYTHONPATH=/nsatt
Environment=SUDO_ASKPASS=/bin/true
Environment=SUDO_COMMAND=/bin/true
Environment=SUDO_USER=root
Environment=SUDO_UID=0
Environment=SUDO_GID=0
Restart=always
RestartSec=10
StartLimitIntervalSec=0
User=root
Group=root
WorkingDirectory=/nsatt
StandardOutput=append:/var/log/nsatt.log
StandardError=append:/var/log/nsatt.err

[Install]
WantedBy=multi-user.target
EOF

# Set permissions for the service file
sudo chmod 644 "$SERVICE_FILE"

# Create sudoers entry for passwordless sudo
SUDOERS_FILE="/etc/sudoers.d/nsatt"
echo "root ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE"
sudo chmod 440 "$SUDOERS_FILE"

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting nsatt.service..."
sudo systemctl enable nsatt.service
sudo systemctl restart nsatt.service

# Check service status
if systemctl is-active --quiet nsatt.service; then
    echo "NSATT service started successfully and enabled at boot."
else
    echo "Failed to start NSATT service. Check logs for details:"
    echo "  Log file: /var/log/nsatt.log"
    echo "  Error file: /var/log/nsatt.err"
    exit 1
fi
