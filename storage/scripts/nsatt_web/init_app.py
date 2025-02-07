from flask import Flask
from routes import register_all_routes
from init_db import initialize_databases
import logging
import subprocess
import shutil
import os
import time

def create_app():
    print("NSATT Starting...")
    
    app = Flask(__name__)
    app.secret_key = 'your_secret_key_here'

    # Set up logging
    logging.basicConfig(filename='app.log', level=logging.ERROR,
                       format='%(asctime)s %(levelname)s:%(message)s')

    # Create required directories and set permissions
    subprocess.getoutput("cd /nsatt")
    subprocess.getoutput("chmod 755 /nsatt/storage/databases")
    initialize_databases()
    
    # Create directories with proper permissions
    dirs_to_create = [
        ("/nsatt/logs", "777"),
        ("/temp", "755"),
        ("/nsatt/settings", "777"),
        ("/nsatt/storage", "777")
    ]
    
    for dir_path, perms in dirs_to_create:
        os.makedirs(dir_path, exist_ok=True)
        subprocess.getoutput(f"sudo chmod {perms} {dir_path}")

    # Define script paths and copy/move files
    script_moves = {
        "nsatt/hid_script.sh": "/nsatt/storage/scripts/exploits/hid_script.sh",
        "nsatt/keyboard_script.sh": "/nsatt/storage/scripts/exploits/keyboard_script.sh", 
        "nsatt/restart_app.sh": "/nsatt/storage/scripts/utility/restart_app.sh",
        "nsatt/start_app_launcher.py": "/nsatt/storage/scripts/utility/start_app_launcher.py",
        "nsatt/start_app_launcher.service": "/etc/systemd/system/start_app_launcher.service",
        "nsatt/set_ip_address.sh": "/nsatt/storage/scripts/networking/set_ip_address.sh",
        "nsatt/set_ip_address.service": "/etc/systemd/system/set_ip_address.service",
        "nsatt/network_manager_web_interface.py": "/nsatt/storage/scripts/web_interface/network_manager_web_interface.py",
        "nsatt/network_manager_web_interface.service": "/etc/systemd/system/network_manager_web_interface.service"
    }

    for src, dst in script_moves.items():
        if os.path.exists(src):
            shutil.move(src, dst)

    # Special case for restart_launcher.sh - copy instead of move
    if os.path.exists("nsatt/restart_launcher.sh"):
        shutil.copy("nsatt/restart_launcher.sh", "/nsatt/storage/scripts/utility/restart_launcher.sh")

    # Set permissions and convert line endings
    script_permissions = {
        "/nsatt/storage/scripts/exploits/hid_script.sh": "+x",
        "/nsatt/storage/scripts/utility/restart_launcher.sh": "+x",
        "/nsatt/storage/scripts/exploits/keyboard_script.sh": "+x",
        "/nsatt/storage/scripts/utility/restart_app.sh": "+x",
        "/nsatt/storage/scripts/utility/start_app_launcher.py": "+x",
        "/etc/systemd/system/start_app_launcher.service": "755",
        "/nsatt/storage/scripts/networking/set_ip_address.sh": "755",
        "/etc/systemd/system/set_ip_address.service": "755"
    }

    for path, perm in script_permissions.items():
        subprocess.getoutput(f"sudo chmod {perm} {path}")
        subprocess.getoutput(f"dos2unix {path}")

    # Handle set_ip_address.log
    if os.path.exists("/nsatt/logs/set_ip_address.log"):
        subprocess.getoutput("sudo rm /nsatt/logs/set_ip_address.log")
    subprocess.getoutput("touch /nsatt/logs/set_ip_address.log")
    subprocess.getoutput("sudo chmod 755 /nsatt/logs/set_ip_address.log")

    # Start Metasploit RPC server
    subprocess.Popen(["msfrpcd", "-P", "password123", "-S", "-a", "127.0.0.1"])
    time.sleep(5)  # Give RPC server time to start

    # Register routes
    register_all_routes(app)
    
    print("NSATT Start Successful")
    return app