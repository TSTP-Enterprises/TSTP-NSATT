#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path
import pwd
import grp
import shutil




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
            # Check if user already exists first
            if user_exists(username):
                print(f"ERROR: User {username} already exists")
                confirm = input(f"Would you like to remove and recreate {username}? (yes/no): ")
                if confirm.lower() != 'yes':
                    print(f"Skipping {username} creation")
                    continue
                # Remove existing user first
                try:
                    remove_admin_user(username)
                    if user_exists(username):
                        print(f"Failed to remove existing user {username} - cannot continue")
                        continue
                except Exception as e:
                    print(f"Failed to remove existing user {username}: {e}")
                    continue
            
            # Get confirmation for creation
            confirm = input(f"This will create a new admin user '{username}'. Continue? (yes/no): ")
            if confirm.lower() != 'yes':
                print(f"Skipping {username} creation")
                continue

            # Create user
            try:
                subprocess.run(['useradd', '-m', username], check=True)
            except subprocess.CalledProcessError as e:
                print(f"Error creating user {username}: {e}")
                continue

            # Verify user was created
            if not user_exists(username):
                print(f"ERROR: User creation failed - {username} does not exist after useradd")
                continue

            # Set password with error handling
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
                # Cleanup - remove user if password set fails
                subprocess.run(['userdel', '-r', username])
                continue

            # Add to sudo group
            try:
                subprocess.run(['usermod', '-aG', 'sudo', username], check=True)
            except subprocess.CalledProcessError as e:
                print(f"Error adding {username} to sudo group: {e}")
                # Cleanup - remove user if sudo add fails
                subprocess.run(['userdel', '-r', username])
                continue

            # Final verification
            if not user_exists(username):
                print(f"ERROR: User creation verification failed - {username} does not exist")
                continue

            print(f"{username} created successfully")

    except Exception as e:
        print(f"Unexpected error creating admin users: {e}")
        # Attempt cleanup
        for username in admin_users:
            if user_exists(username):
                subprocess.run(['userdel', '-r', username])
        return

def remove_admin_user(username=None):
    """Remove nsatt-admin and/or nsatt-superadmin users and associated files"""
    try:
        admin_users = ['nsatt-admin', 'nsatt-superadmin'] if username is None else [username]
        
        for user in admin_users:
            # Check if user exists first
            if not user_exists(user):
                print(f"ERROR: User {user} does not exist")
                continue

            # Double confirmation due to destructive nature
            confirm1 = input(f"WARNING: This will permanently delete the {user} user and all associated files.\nType 'delete' to confirm: ")
            if confirm1.lower() != 'delete':
                print(f"Skipping {user} removal")
                continue
                
            confirm2 = input(f"Are you absolutely sure about removing {user}? This cannot be undone (yes/no): ")
            if confirm2.lower() != 'yes':
                print(f"Skipping {user} removal")
                continue

            # Check if user is currently logged in
            try:
                who_output = subprocess.check_output(['who']).decode()
                if user in who_output:
                    print(f"ERROR: Cannot remove {user} while they are logged in")
                    print("Please log out the user first")
                    continue
            except subprocess.CalledProcessError as e:
                print(f"Error checking logged in users: {e}")
                continue

            # Remove user and home directory
            try:
                subprocess.run(['userdel', '-r', user], check=True)
            except subprocess.CalledProcessError as e:
                print(f"Error removing user {user}: {e}")
                
                # Try force remove if normal remove failed
                try:
                    print(f"Attempting force removal of {user}...")
                    subprocess.run(['userdel', '-f', '-r', user], check=True)
                except subprocess.CalledProcessError as e2:
                    print(f"Force removal also failed for {user}: {e2}")
                    print("Please check system logs and remove user manually")
                    continue

            # Verify removal
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
    """Create the uninstall script"""
    uninstall_script = """#!/usr/bin/env python3
import os
import subprocess
import sys
import shutil

def remove_service():
    try:
        subprocess.run(['systemctl', 'stop', 'nsatt.service'], check=False)
        subprocess.run(['systemctl', 'disable', 'nsatt.service'], check=False)
        if os.path.exists('/etc/systemd/system/nsatt.service'):
            os.remove('/etc/systemd/system/nsatt.service')
        subprocess.run(['systemctl', 'daemon-reload'], check=False)
        print("Removed NSATT service")
    except Exception as e:
        print(f"Error removing service: {e}")

def restore_system_settings():
    try:
        # Remove plugins directory
        shutil.rmtree('/nsatt/storage/plugins', ignore_errors=True)
        print("Restored system settings")
    except Exception as e:
        print(f"Error restoring system settings: {e}")

def main():
    if os.geteuid() != 0:
        print("This script must be run as root")
        sys.exit(1)
        
    print("Uninstalling NSATT...")
    
    remove_service()
    restore_system_settings()
    
    # Remove uninstall script itself
    os.remove(__file__)
    
    print("Uninstallation complete!")

if __name__ == "__main__":
    main()
"""
    
    try:
        uninstall_path = '/usr/local/bin/nsatt_uninstall.py'
        with open(uninstall_path, 'w') as f:
            f.write(uninstall_script)
        os.chmod(uninstall_path, 0o755)
        print("Uninstall script created successfully")
    except Exception as e:
        print(f"Error creating uninstall script: {e}")
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

def main():
    # Check if running as root
    if os.geteuid() != 0:
        print("This script must be run as root")
        sys.exit(1)
        
    print("Starting Blackbird installation...")
    
    # Check if already installed
    if verify_files():
        print("Blackbird appears to be already installed.")
        print("\nOptions:")
        print("1. Reinstall")
        print("2. Remove sudoers entry")
        print("3. Exit")
        
        choice = input("\nEnter choice (1-3): ")
        
        if choice == '1':
            pass  # Continue with installation
        elif choice == '2':
            remove_sudoers()
            sys.exit(0)
        else:
            sys.exit(0)
        
    create_admin_user()
    configure_autologin()
    setup_launcher_app()
    create_uninstall_script()
    configure_sudoers()
    
    # Install required packages
    subprocess.run(['apt-get', 'update'], check=True)
    subprocess.run(['apt-get', 'install', '-y', 'python3-pyqt5', 'xorg'], check=True)
    
    # Verify installation
    if verify_files():
        print("Installation complete and verified! Please reboot the system.")
    else:
        print("Installation completed but verification failed. Please check the logs.")

if __name__ == "__main__":
    main()


