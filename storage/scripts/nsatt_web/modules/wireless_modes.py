import subprocess

def get_wireless_modes():
    try:
        interfaces_output = subprocess.getoutput("iwconfig 2>/dev/null | grep 'Mode:'")
        interfaces = []
        for line in interfaces_output.split('\n'):
            if "Mode:" in line:
                interface = line.split()[0]
                mode = line.split("Mode:")[1].split()[0]
                interfaces.append({'interface': interface, 'status': mode})
        return interfaces
    except Exception as e:
        return {'error': str(e)}

def toggle_wireless_mode(interface, current_mode):
    try:
        new_mode = 'managed' if current_mode == 'monitor' else 'monitor'
        subprocess.getoutput(f"sudo ifconfig {interface} down")
        subprocess.getoutput(f"sudo iwconfig {interface} mode {new_mode}")
        subprocess.getoutput(f"sudo ifconfig {interface} up")
        return f"Interface {interface} switched to {new_mode} mode."
    except Exception as e:
        return f"Error toggling wireless mode for {interface}: {e}"