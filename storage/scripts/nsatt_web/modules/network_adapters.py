import subprocess

def get_network_adapters():
    try:
        adapters_output = subprocess.getoutput("ip link show | awk -F: '/^[0-9]+: / {print $2}'")
        adapters = [adapter.strip() for adapter in adapters_output.split('\n') if adapter]
        return [{'name': adapter, 'status': get_adapter_status(adapter)} for adapter in adapters]
    except Exception as e:
        return {'error': str(e)}

def toggle_network_adapter(adapter_name):
    try:
        # Get the current status of the adapter (up or down)
        current_status = get_adapter_status(adapter_name)
        
        # Determine the action (down if currently up, up if currently down)
        action = 'down' if current_status == 'up' else 'up'
        
        # Perform the action
        subprocess.getoutput(f"sudo ip link set {adapter_name} {action}")
        
        # Return a message indicating the new state
        return f"Adapter {adapter_name} turned {action}."
    except Exception as e:
        return f"Error toggling adapter {adapter_name}: {e}"

import subprocess

def get_adapter_status(adapter_name):
    try:
        # Get the full output of ifconfig
        ifconfig_output = subprocess.getoutput("ifconfig")
        
        # Check if the adapter name is in the output and has 'UP' in its configuration
        if adapter_name in ifconfig_output:
            return 'up'
        else:
            return 'down'
    except Exception as e:
        return f"Error fetching status for {adapter_name}: {e}"

def toggle_wireless_mode(interface, _):
    try:
        # Get the current mode from iwconfig
        current_config = subprocess.getoutput(f"iwconfig {interface}")
        
        if "Mode:Monitor" in current_config:
            new_mode = "managed"
        elif "Mode:Managed" in current_config:
            new_mode = "monitor"
        else:
            return f"Error: Could not determine current mode for {interface}."

        # Log the intended mode change
        print(f"Switching {interface} to {new_mode} mode.")

        # Set the interface down before changing the mode
        interface_down_result = subprocess.getoutput(f"sudo ifconfig {interface} down")
        print(f"Interface down result: {interface_down_result}")

        # Change the mode
        mode_change_result = subprocess.getoutput(f"sudo iwconfig {interface} mode {new_mode}")
        print(f"Mode change result: {mode_change_result}")
        
        # Bring the interface back up
        interface_up_result = subprocess.getoutput(f"sudo ifconfig {interface} up")
        print(f"Interface up result: {interface_up_result}")

        # Verify the mode change
        verification_result = subprocess.getoutput(f"iwconfig {interface}")
        print(f"Verification result: {verification_result}")

        if new_mode in verification_result.lower():
            return f"Interface {interface} successfully switched to {new_mode} mode."
        else:
            return f"Failed to switch {interface} to {new_mode} mode. Current mode: {verification_result}"

    except Exception as e:
        return f"Error toggling mode for {interface}: {e}"

def change_mac_address(interface, new_mac):
    try:
        # Set the interface down before changing the MAC address
        subprocess.getoutput(f"sudo ifconfig {interface} down")
        subprocess.getoutput(f"sudo ifconfig {interface} hw ether {new_mac}")
        subprocess.getoutput(f"sudo ifconfig {interface} up")
        return f"MAC address for {interface} changed to {new_mac}."
    except Exception as e:
        return f"Error changing MAC address for {interface}: {e}"

def get_wireless_modes():
    try:
        modes_output = subprocess.getoutput("iwconfig 2>/dev/null")
        modes = []
        interface = None
        
        for line in modes_output.split('\n'):
            if not line.strip():
                continue  # Skip empty lines

            # Identify the interface line
            if not line.startswith(' '):
                parts = line.split()
                interface = parts[0]  # First part should be the interface name

            # Identify the mode within the interface details
            if "Mode:" in line:
                mode = line.split('Mode:')[1].split()[0]
                modes.append({'interface': interface, 'status': mode})

        if modes:
            return modes
        else:
            return {'error': 'No wireless interfaces found'}
    except Exception as e:
        return {'error': str(e)}