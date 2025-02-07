#!/usr/bin/env python3

import os
import subprocess
import logging
import sys

# Constants
LOG_DIR = "/nsatt/logs"
LOG_FILE_CONTROL = os.path.join(LOG_DIR, "nsatt_control.log")

def setup_logging():
    """Sets up logging for the control script."""
    os.makedirs(LOG_DIR, exist_ok=True)
    logging.basicConfig(
        filename=LOG_FILE_CONTROL,
        level=logging.INFO,
        format='%(asctime)s %(levelname)s:%(message)s'
    )
    logging.info("Control script logging initialized.")

def run_command(command):
    """Runs a command and returns its output."""
    try:
        result = subprocess.check_output(command, shell=True, text=True, stderr=subprocess.STDOUT)
        logging.debug(f"Executed command: {command}")
        logging.debug(f"Command output: {result}")
        return result.strip()
    except subprocess.CalledProcessError as e:
        logging.error(f"Error executing '{command}': {e.output}")
        return f"Error executing {command}: {e.output}"

def determine_model():
    """Determines the Raspberry Pi model."""
    model_info = run_command("cat /proc/device-tree/model")
    if "Raspberry Pi Zero 2" in model_info:
        return "Zero 2 W"
    elif "Raspberry Pi 4" in model_info:
        return "4 B"
    else:
        return "Unknown"

def configure_usb_mode(model):
    """Configures how the Raspberry Pi appears when connected via USB."""
    logging.info(f"Configuring USB mode for model: {model}...")
    changes_made = False

    # Determine the appropriate overlay and modules based on the model
    if model == "Zero 2 W":
        overlay = "dtoverlay=dwc2"
        cmd_modules = "rootwait modules-load=dwc2,g_ether"
        usb_modes = {
            "1": ("Ethernet Gadget", "g_ether"),
            "2": ("Serial Gadget", "g_serial"),
            "3": ("Mass Storage", "g_mass_storage"),
            "4": ("Multi-function (CDC + Mass Storage)", "g_multi")
        }
    elif model == "4 B":
        overlay = "dtoverlay=dwc2"
        cmd_modules = "rootwait modules-load=dwc2,g_multi"
        usb_modes = {
            "1": ("Ethernet Gadget", "g_ether"),
            "2": ("Serial Gadget", "g_serial"),
            "3": ("Mass Storage", "g_mass_storage"),
            "4": ("Multi-function (CDC + Mass Storage)", "g_multi"),
            "5": ("RNDIS Ethernet", "g_rndis")
        }
    else:
        logging.warning("Unknown model. USB configuration not supported.")
        print("Unknown model. USB configuration not supported.")
        return False

    print("\nAvailable USB modes:")
    for key, (name, _) in usb_modes.items():
        print(f"{key}. {name}")
    print("R. Return to normal USB operation")

    choice = input("\nSelect USB mode: ").strip().upper()

    if choice == "R":
        # Remove USB gadget configuration
        try:
            with open("/boot/config.txt", "r") as f:
                config_lines = f.readlines()
            with open("/boot/config.txt", "w") as f:
                for line in config_lines:
                    if overlay not in line:
                        f.write(line)
            
            with open("/boot/cmdline.txt", "r") as f:
                cmdline = f.read()
            cmdline = cmdline.replace(cmd_modules, "").strip()
            with open("/boot/cmdline.txt", "w") as f:
                f.write(cmdline)
            
            logging.info("USB gadget configuration removed")
            changes_made = True
            print("USB gadget configuration removed. Device will operate as normal USB device after reboot.")
        except Exception as e:
            logging.error(f"Error removing USB gadget configuration: {e}")
            print("Error removing USB gadget configuration. Check the logs.")
            return False

    elif choice in usb_modes:
        mode_name, module = usb_modes[choice]
        try:
            # Update config.txt
            with open("/boot/config.txt", "r") as f:
                config_content = f.read()
            if overlay not in config_content:
                with open("/boot/config.txt", "a") as f:
                    f.write(f"\n{overlay}\n")

            # Update cmdline.txt
            with open("/boot/cmdline.txt", "r") as f:
                cmdline = f.read()
            new_modules = f"rootwait modules-load=dwc2,{module}"
            if "modules-load=dwc2" in cmdline:
                cmdline = cmdline.replace(cmd_modules, new_modules)
            else:
                cmdline = cmdline.strip() + " " + new_modules
            
            with open("/boot/cmdline.txt", "w") as f:
                f.write(cmdline)

            logging.info(f"USB mode configured as {mode_name}")
            changes_made = True
            print(f"USB mode will be set to {mode_name} after reboot.")
        except Exception as e:
            logging.error(f"Error configuring USB mode: {e}")
            print("Error configuring USB mode. Check the logs.")
            return False

    else:
        print("Invalid selection")
        return False

    if changes_made:
        reboot = input("Reboot required to apply changes. Reboot now? (y/n): ").strip().lower()
        if reboot == "y":
            logging.info("Rebooting system to apply USB mode changes")
            print("Rebooting...")
            run_command("sudo reboot")
        else:
            print("Please reboot manually to apply changes.")

    return changes_made

if __name__ == "__main__":
    # Ensure the script is run with root privileges
    if os.geteuid() != 0:
        print("Please run this script with sudo or as root.")
        sys.exit(1)

    setup_logging()
    model = determine_model()
    print(f"Detected Raspberry Pi model: {model}")
    configure_usb_mode(model)
