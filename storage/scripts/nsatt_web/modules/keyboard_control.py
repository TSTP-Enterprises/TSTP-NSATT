import os
import subprocess

def send_keyboard_command(command):
    try:
        os.system(f"echo {command} > /dev/hidg0")
        return f"Sent command: {command}"
    except Exception as e:
        return f"Error sending keyboard command: {e}"

def load_and_execute_script(script_path):
    try:
        if os.path.exists(script_path):
            with open(script_path, 'r') as script_file:
                commands = script_file.read()
            for command in commands.splitlines():
                send_keyboard_command(command)
            return f"Executed script {script_path} successfully."
        else:
            return f"Script {script_path} not found."
    except Exception as e:
        return f"Error executing script: {e}"

def toggle_usb_mode(mode):
    try:
        if mode == 'HID':
            subprocess.getoutput("modprobe -r g_mass_storage")
            subprocess.getoutput("modprobe g_hid")
            return "Switched to HID mode."
        elif mode == 'MassStorage':
            subprocess.getoutput("modprobe -r g_hid")
            subprocess.getoutput("modprobe g_mass_storage")
            return "Switched to Mass Storage mode."
        else:
            return "Invalid mode specified."
    except Exception as e:
        return f"Error toggling USB mode: {e}"