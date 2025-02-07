#!/bin/bash

# Load SMTP configuration
config_file="/nsatt/settings/storage/smtp_config.conf"

# Check if the config file exists
if [ ! -f "$config_file" ]; then
    echo "ERROR - SMTP configuration file not found. Please create it at $config_file."
    exit 1
fi

# Read configuration values
smtp_server=$(jq -r '.smtp_server' "$config_file")
smtp_port=$(jq -r '.smtp_port' "$config_file")
smtp_user=$(jq -r '.smtp_user' "$config_file")
smtp_password=$(jq -r '.smtp_password_encrypted' "$config_file")
recipient_email=$(jq -r '.recipient_email' "$config_file")

# Confirm configurations
if [ -z "$smtp_server" ] || [ -z "$smtp_port" ] || [ -z "$smtp_user" ]; then
    echo "ERROR - SMTP configuration is incomplete. Please check the configuration file."
    exit 1
fi

# Ensure recipient_email is set
if [ -z "$recipient_email" ]; then
    echo "ERROR - Recipient email is not set. Please check the configuration file."
    exit 1
fi

# Example of sending an email
echo -e "Subject: Test Email\n\nThis is a test email." | /usr/sbin/sendmail -t "$recipient_email"
