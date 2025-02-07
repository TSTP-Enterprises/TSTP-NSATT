#!/usr/bin/env python3

import os
import subprocess

# Set the path to your app.py
APP_PATH = "/nsatt/storage/scripts/nsatt_web/app.py"

# Check if autostart_app file exists
AUTOSTART_APP_PATH = "/nsatt/storage/settings/autostart_app"

# Run the app
subprocess.run(["python3", APP_PATH])