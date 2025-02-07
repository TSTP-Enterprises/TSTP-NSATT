#!/usr/bin/env python3
import os
import subprocess
import sys
import time
import pwd
import grp
import shutil
from pathlib import Path

def run_command(cmd):
    try:
        subprocess.run(cmd, shell=True, check=True)
        print(f"Successfully executed: {cmd}")
    except subprocess.CalledProcessError as e:
        print(f"Error executing {cmd}: {e}")

def restart_lightdm():
    if os.geteuid() != 0:
        print("This command needs root privileges. Please run with sudo.")
        return
    run_command("systemctl restart lightdm")

def reset_usb():
    if os.geteuid() != 0:
        print("This command needs root privileges. Please run with sudo.")
        return
        
    try:
        # Get list of USB devices from sysfs
        result = subprocess.run("ls /sys/bus/usb/devices/", shell=True, capture_output=True, text=True)
        usb_devices = result.stdout.strip().split('\n')
        
        reset_count = 0
        for device in usb_devices:
            # Look for USB device interfaces
            if ':' in device:  # Interface like 1-0:1.0
                device_path = f"/sys/bus/usb/devices/{device}/authorized"
                if os.path.exists(device_path):
                    try:
                        # Deauthorize and reauthorize to reset
                        with open(device_path, 'w') as f:
                            f.write('0')
                        time.sleep(0.2)  # Short delay
                        with open(device_path, 'w') as f:
                            f.write('1')
                        print(f"Successfully reset USB device: {device}")
                        reset_count += 1
                    except OSError as e:
                        print(f"Failed to reset device {device}: {e}")
                        continue
        
        if reset_count == 0:
            print("No USB devices were successfully reset")
        else:
            print(f"Successfully reset {reset_count} USB devices")
            
    except Exception as e:
        print(f"Error resetting USB devices: {e}")

def wake_display():
    run_command("xset dpms force on")

def reboot_system():
    if os.geteuid() != 0:
        print("This command needs root privileges. Please run with sudo.")
        return
    run_command("reboot")

def fix_permissions():
    if os.geteuid() != 0:
        print("This command needs root privileges. Please run with sudo.")
        return
    
    try:
        # Set directory permissions to 755 (rwxr-xr-x)
        run_command("find /nsatt -type d -exec chmod 755 {} +")
        
        # Set .py files to 755 (rwxr-xr-x)
        run_command("find /nsatt -type f -name '*.py' -exec chmod 755 {} +")
        
        # Set .sh files to 755 (rwxr-xr-x)
        run_command("find /nsatt -type f -name '*.sh' -exec chmod 755 {} +")
        
        # Convert line endings to Unix format
        run_command("find /nsatt -type f -name '*.py' -exec dos2unix {} +")
        run_command("find /nsatt -type f -name '*.sh' -exec dos2unix {} +")
        
        print("Successfully updated permissions and line endings for /nsatt directory and its contents")
    except Exception as e:
        print(f"Error updating permissions and line endings: {e}")

def install_alfa_drivers():
    if os.geteuid() != 0:
        print("This command needs root privileges. Please run with sudo.")
        return
        
    try:
        print("Installing prerequisites...")
        run_command("apt install -y build-essential dkms git bc")
        
        print("\nCloning RTL8812AU driver repository...")
        if os.path.exists("rtl8812au"):
            print("Removing existing rtl8812au directory...")
            run_command("rm -rf rtl8812au")
        run_command("git clone https://github.com/aircrack-ng/rtl8812au.git")
        
        print("\nBuilding and installing drivers...")
        os.chdir("rtl8812au")
        run_command("make")
        run_command("make install")
        run_command("modprobe 8812au")
        
        print("\nInstalling DKMS...")
        run_command("apt install -y dkms")
        run_command("dkms add ./rtl8812au")
        run_command("dkms build 8812au/5.6.4.2")
        run_command("dkms install 8812au/5.6.4.2")
        
        print("\nChecking wireless interfaces...")
        run_command("iwconfig")
        
        print("\nAlfa AC1200 drivers installed successfully!")
        
    except Exception as e:
        print(f"Error installing Alfa drivers: {e}")
    finally:
        # Return to original directory
        os.chdir("..")

def user_exists(username):
    """Check if a user exists"""
    try:
        pwd.getpwnam(username)
        return True
    except KeyError:
        return False

def verify_files():
    """Verify all required files and permissions"""
    required_paths = [
        '/etc/systemd/system/getty@tty1.service.d/override.conf',
        '/nsatt/nsatt.py',
        '/home/nsatt-admin/.bashrc',
        '/nsatt/storage/settings.json',
        '/nsatt/storage',
        '/nsatt/scripts'
    ]
    
    for path in required_paths:
        if not os.path.exists(path):
            print(f"Missing required file/directory: {path}")
            return False
            
    # Check and set permissions
    try:
        # Check override.conf is readable
        if not os.access('/etc/systemd/system/getty@tty1.service.d/override.conf', os.R_OK):
            print("Incorrect permissions on override.conf")
            return False
            
        # Check nsatt.py is executable
        if not os.access('/nsatt/nsatt.py', os.X_OK):
            print("nsatt.py must be executable")
            return False
            
        # Check .bashrc is readable and writable by owner
        if not os.access('/home/nsatt-admin/.bashrc', os.R_OK | os.W_OK):
            print("Incorrect permissions on .bashrc")
            return False
            
        # Set and check settings.json permissions
        os.chmod('/nsatt/storage/settings.json', 0o777)
        if not os.access('/nsatt/storage/settings.json', os.R_OK | os.W_OK):
            print("settings.json must be readable/writable by all users")
            return False
            
        # Set and check storage directory permissions
        storage_path = '/nsatt/storage'
        for root, dirs, files in os.walk(storage_path):
            os.chmod(root, 0o777)
            for file in files:
                file_path = os.path.join(root, file)
                if file.endswith(('.py', '.sh')):
                    os.chmod(file_path, 0o755)
                else:
                    os.chmod(file_path, 0o644)
                    
        # Set and check scripts directory permissions
        scripts_path = '/nsatt/scripts'
        for root, dirs, files in os.walk(scripts_path):
            os.chmod(root, 0o777)
            for file in files:
                file_path = os.path.join(root, file)
                if file.endswith(('.py', '.sh')):
                    os.chmod(file_path, 0o755)
                else:
                    os.chmod(file_path, 0o644)
                
    except Exception as e:
        print(f"Error checking/setting permissions: {e}")
        return False
        
    return True

def create_admin_user():
    """Create nsatt-admin and nsatt-superadmin users with sudo privileges"""
    admin_users = ['nsatt-admin', 'nsatt-superadmin']
    
    try:
        for username in admin_users:
            if user_exists(username):
                print(f"ERROR: User {username} already exists")
                confirm = input(f"Would you like to remove and recreate {username}? (yes/no): ")
                if confirm.lower() != 'yes':
                    print(f"Skipping {username} creation")
                    continue
                try:
                    remove_admin_user(username)
                    if user_exists(username):
                        print(f"Failed to remove existing user {username} - cannot continue")
                        continue
                except Exception as e:
                    print(f"Failed to remove existing user {username}: {e}")
                    continue
            
            confirm = input(f"This will create a new admin user '{username}'. Continue? (yes/no): ")
            if confirm.lower() != 'yes':
                print(f"Skipping {username} creation")
                continue

            try:
                subprocess.run(['useradd', '-m', username], check=True)
            except subprocess.CalledProcessError as e:
                print(f"Error creating user {username}: {e}")
                continue

            if not user_exists(username):
                print(f"ERROR: User creation failed - {username} does not exist after useradd")
                continue

            try:
                proc = subprocess.Popen(['passwd', username], stdin=subprocess.PIPE)
                if username == 'nsatt-admin':
                    proc.communicate(input=b'nsattadmin\nnsattadmin\n')
                else:  # nsatt-superadmin
                    proc.communicate(input=b'nsattsuperadmin\nnsattsuperadmin\n')
                if proc.returncode != 0:
                    raise subprocess.CalledProcessError(proc.returncode, 'passwd')
            except subprocess.CalledProcessError as e:
                print(f"Error setting password for {username}: {e}")
                subprocess.run(['userdel', '-r', username])
                continue

            try:
                subprocess.run(['usermod', '-aG', 'sudo', username], check=True)
            except subprocess.CalledProcessError as e:
                print(f"Error adding {username} to sudo group: {e}")
                subprocess.run(['userdel', '-r', username])
                continue

            if not user_exists(username):
                print(f"ERROR: User creation verification failed - {username} does not exist")
                continue

            print(f"{username} created successfully")

    except Exception as e:
        print(f"Unexpected error creating admin users: {e}")
        for username in admin_users:
            if user_exists(username):
                subprocess.run(['userdel', '-r', username])
        return

def remove_admin_user(username=None):
    """Remove nsatt-admin and/or nsatt-superadmin users and associated files"""
    try:
        admin_users = ['nsatt-admin', 'nsatt-superadmin'] if username is None else [username]
        
        for user in admin_users:
            if not user_exists(user):
                print(f"ERROR: User {user} does not exist")
                continue

            confirm1 = input(f"WARNING: This will permanently delete the {user} user and all associated files.\nType 'delete' to confirm: ")
            if confirm1.lower() != 'delete':
                print(f"Skipping {user} removal")
                continue
                
            confirm2 = input(f"Are you absolutely sure about removing {user}? This cannot be undone (yes/no): ")
            if confirm2.lower() != 'yes':
                print(f"Skipping {user} removal")
                continue

            try:
                who_output = subprocess.check_output(['who']).decode()
                if user in who_output:
                    print(f"ERROR: Cannot remove {user} while they are logged in")
                    print("Please log out the user first")
                    continue
            except subprocess.CalledProcessError as e:
                print(f"Error checking logged in users: {e}")
                continue

            try:
                subprocess.run(['userdel', '-r', user], check=True)
            except subprocess.CalledProcessError as e:
                print(f"Error removing user {user}: {e}")
                
                try:
                    print(f"Attempting force removal of {user}...")
                    subprocess.run(['userdel', '-f', '-r', user], check=True)
                except subprocess.CalledProcessError as e2:
                    print(f"Force removal also failed for {user}: {e2}")
                    print("Please check system logs and remove user manually")
                    continue

            if user_exists(user):
                print(f"ERROR: User {user} still exists after removal attempt")
                print("Please check system logs and remove user manually")
                continue

            print(f"{user} and associated files successfully removed")

    except Exception as e:
        print(f"Unexpected error removing admin users: {e}")
        print("Please check system logs and remove users manually if needed")
        return

def configure_autologin():
    """Configure system to boot to console and autologin as nsatt-admin"""
    try:
        # Configure autologin
        override_dir = '/etc/systemd/system/getty@tty1.service.d'
        os.makedirs(override_dir, exist_ok=True)
        
        autologin_conf = """[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin nsatt-admin --noclear %I $TERM"""
        
        with open(f'{override_dir}/override.conf', 'w') as f:
            f.write(autologin_conf)
            
        print("Autologin configured successfully")
    except Exception as e:
        print(f"Error configuring autologin: {e}")
        sys.exit(1)

def remove_autologin():
    """Remove autologin and restore normal login behavior"""
    try:
        override_dir = '/etc/systemd/system/getty@tty1.service.d'
        override_file = f'{override_dir}/override.conf'
        
        if os.path.exists(override_file):
            os.remove(override_file)
            if not os.listdir(override_dir):
                os.rmdir(override_dir)
            print("Autologin removed successfully")
        else:
            print("Autologin was not configured")
            
    except Exception as e:
        print(f"Error removing autologin: {e}")
        sys.exit(1)

def setup_launcher_app():
    """Create and configure the NSATT service"""
    try:
        # Create plugins directory with correct permissions
        plugins_dir = '/nsatt/storage/plugins'
        os.makedirs(plugins_dir, exist_ok=True)
        os.chmod(plugins_dir, 0o777)
        print("Created plugins directory with permissions")

        # Create systemd service file
        service_file = '/etc/systemd/system/nsatt.service'
        service_content = """[Unit]
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
"""
        with open(service_file, 'w') as f:
            f.write(service_content)
        
        # Set service file permissions
        os.chmod(service_file, 0o644)
        print("Created systemd service file")

        # Create sudoers entry to allow NOPASSWD sudo access
        sudoers_file = '/etc/sudoers.d/nsatt'
        sudoers_content = "root ALL=(ALL) NOPASSWD: ALL\n"
        with open(sudoers_file, 'w') as f:
            f.write(sudoers_content)
        os.chmod(sudoers_file, 0o440)
        print("Created sudoers entry for passwordless sudo")

        # Reload systemd and enable/start service
        subprocess.run(['systemctl', 'daemon-reload'], check=True)
        subprocess.run(['systemctl', 'enable', 'nsatt.service'], check=True)
        subprocess.run(['systemctl', 'restart', 'nsatt.service'], check=True)

        # Verify service is running
        result = subprocess.run(['systemctl', 'is-active', '--quiet', 'nsatt.service'])
        if result.returncode == 0:
            print("NSATT service started successfully and enabled at boot")
        else:
            print("Failed to start NSATT service. Check logs for details:")
            print("  Log file: /var/log/nsatt.log") 
            print("  Error file: /var/log/nsatt.err")
            sys.exit(1)

    except Exception as e:
        print(f"Error setting up NSATT service: {e}")
        sys.exit(1)

def create_uninstall_script():
    """Uninstall NSATT service"""
    if os.geteuid() != 0:
        print("This operation needs root privileges. Please run with sudo.")
        return

    try:
        print("\nUninstalling NSATT service...")
        
        # Stop and remove service
        subprocess.run(['systemctl', 'stop', 'nsatt.service'], check=False)
        subprocess.run(['systemctl', 'disable', 'nsatt.service'], check=False)
        
        if os.path.exists('/etc/systemd/system/nsatt.service'):
            os.remove('/etc/systemd/system/nsatt.service')
            
        subprocess.run(['systemctl', 'daemon-reload'], check=False)
        print("NSATT service has been uninstalled")

    except Exception as e:
        print(f"Error uninstalling service: {e}")
        sys.exit(1)

def configure_sudoers():
    """Configure sudoers entry for nsatt-admin user"""
    username = "nsatt-admin"
    command = "/usr/bin/python3 /nsatt/nsatt.py"
    sudoers_line = f"{username} ALL=(ALL) NOPASSWD: {command}"
    
    try:
        # Check if entry exists
        result = subprocess.run(['grep', '-Fxq', sudoers_line, '/etc/sudoers'],
                              capture_output=True)
        if result.returncode != 0:
            # Add entry using visudo
            print("Adding sudoers entry for nsatt-admin user...")
            echo_proc = subprocess.Popen(['echo', sudoers_line], stdout=subprocess.PIPE)
            visudo_proc = subprocess.Popen(['sudo', 'EDITOR=tee -a', 'visudo'],
                                         stdin=echo_proc.stdout)
            visudo_proc.communicate()
            print("Sudoers entry added successfully")
        else:
            print("Sudoers entry already exists")
    except Exception as e:
        print(f"Error configuring sudoers: {e}")

def remove_sudoers():
    """Remove sudoers entry for nsatt-admin user"""
    username = "nsatt-admin"
    command = "/usr/bin/python3 /nsatt/nsatt.py"
    sudoers_line = f"{username} ALL=(ALL) NOPASSWD: {command}"
    
    try:
        # Create temp file
        with open('/etc/sudoers', 'r') as f:
            lines = f.readlines()
        with open('/etc/sudoers.tmp', 'w') as f:
            for line in lines:
                if line.strip() != sudoers_line:
                    f.write(line)
        
        # Replace using visudo
        subprocess.run(['visudo', '-c', '-f', '/etc/sudoers.tmp'], check=True)
        shutil.move('/etc/sudoers.tmp', '/etc/sudoers')
        print("Removed sudoers entry for nsatt-admin")
    except Exception as e:
        print(f"Error removing sudoers entry: {e}")
        if os.path.exists('/etc/sudoers.tmp'):
            os.remove('/etc/sudoers.tmp')

def change_kali_password():
    """Change password for kali user"""
    if os.geteuid() != 0:
        print("This operation needs root privileges. Please run with sudo.")
        return
        
    try:
        if not user_exists('kali'):
            print("Error: kali user does not exist on this system")
            return
            
        print("\nChanging password for kali user...")
        proc = subprocess.Popen(['passwd', 'kali'], stdin=subprocess.PIPE)
        
        # Get new password
        while True:
            new_pass = input("Enter new password for kali: ")
            confirm_pass = input("Confirm new password: ")
            
            if new_pass == confirm_pass:
                break
            print("Passwords do not match. Please try again.")
        
        # Send password to passwd command
        proc.communicate(input=f"{new_pass}\n{new_pass}\n".encode())
        
        if proc.returncode == 0:
            print("Password changed successfully for kali user")
        else:
            print("Failed to change password")
            
    except Exception as e:
        print(f"Error changing password: {e}")

def main():
    while True:
        print("\nSystem Management Menu:")
        print("1. Restart LightDM")
        print("2. Reset USB Devices") 
        print("3. Wake Display")
        print("4. Reboot System")
        print("5. Fix /nsatt Permissions")
        print("6. Install Alfa AC1200 Drivers")
        print("7. Create Admin Users")
        print("8. Remove Admin Users")
        print("9. Configure Autologin")
        print("10. Remove Autologin")
        print("11. Install NSATT Service")
        print("12. Uninstall NSATT Service")
        print("13. Configure Sudoers")
        print("14. Remove Sudoers")
        print("15. Verify Files")
        print("16. Change Kali Password")
        print("17. Exit")

        choice = input("\nEnter your choice (1-17): ")

        if choice == "1":
            restart_lightdm()
        elif choice == "2":
            reset_usb()
        elif choice == "3":
            wake_display()
        elif choice == "4":
            confirm = input("Are you sure you want to reboot? (y/n): ")
            if confirm.lower() == 'y':
                reboot_system()
        elif choice == "5":
            fix_permissions()
        elif choice == "6":
            install_alfa_drivers()
        elif choice == "7":
            create_admin_user()
        elif choice == "8":
            remove_admin_user()
        elif choice == "9":
            configure_autologin()
        elif choice == "10":
            remove_autologin()
        elif choice == "11":
            setup_launcher_app()
        elif choice == "12":
            create_uninstall_script()
        elif choice == "13":
            configure_sudoers()
        elif choice == "14":
            remove_sudoers()
        elif choice == "15":
            verify_files()
        elif choice == "16":
            change_kali_password()
        elif choice == "17":
            print("Exiting...")
            sys.exit(0)
        else:
            print("Invalid choice. Please try again.")

if __name__ == "__main__":
    main()
