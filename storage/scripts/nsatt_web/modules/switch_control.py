import logging
import subprocess
import netifaces
import nmap
from netmiko import ConnectHandler

def get_network_info():
    try:
        gateways = netifaces.gateways()
        default_gateway = gateways['default'][netifaces.AF_INET][0]
        interface = gateways['default'][netifaces.AF_INET][1]
        network = netifaces.ifaddresses(interface)[netifaces.AF_INET][0]
        ip_address = network['addr']
        netmask = network['netmask']
        logging.info(f"Network info - Gateway: {default_gateway}, IP: {ip_address}, Netmask: {netmask}")
        return default_gateway, ip_address, netmask
    except Exception as e:
        logging.error(f"Failed to get network info: {str(e)}")
        raise

def discover_switches(network):
    switches = []
    try:
        nm = nmap.PortScanner()
        logging.info(f"Scanning network: {network}")
        nm.scan(hosts=network, arguments='-p 22,23,80,443 --open')

        # First, try to find managed switches
        for host in nm.all_hosts():
            if nm[host].has_tcp(22) or nm[host].has_tcp(23):
                switches.append({'ip': host, 'managed': True})
        
        # If no managed switches found, try LLDP and ARP
        if not switches:
            logging.info("No managed switches found. Attempting LLDP discovery.")
            lldp_output = subprocess.getoutput("lldpctl")
            for line in lldp_output.splitlines():
                if 'Interface:' in line:
                    parts = line.split()
                    if len(parts) > 1:
                        interface = parts[1]
                        logging.info(f"LLDP found interface: {interface}")
                        switches.append({'interface': interface, 'managed': False})

            if not switches:
                logging.info("No devices found via LLDP. Attempting ARP scan.")
                arp_output = subprocess.getoutput("arp -a")
                for line in arp_output.splitlines():
                    if '(' in line and ')' in line:
                        ip = line.split('(')[1].split(')')[0]
                        logging.info(f"ARP found device: {ip}")
                        switches.append({'ip': ip, 'managed': False})
                        
        logging.info(f"Discovered switches: {switches}")
        return switches
    except Exception as e:
        logging.error(f"Failed to discover switches: {str(e)}")
        return switches

def get_credentials():
    return [
        {'username': '', 'password': ''},  # No credentials
        {'username': 'admin', 'password': ''},
        {'username': 'admin', 'password': 'admin'},
        {'username': 'admin', 'password': 'password'},
        {'username': 'cisco', 'password': 'cisco'},
        {'username': 'manager', 'password': 'manager'},
        # Add more common credentials
    ]

def change_port_light(action, port=''):
    try:
        gateway, ip_address, netmask = get_network_info()
        network = f"{ip_address}/{netmask}"
        switches = discover_switches(network)
        
        if not switches:
            logging.error("No switches discovered on the network.")
            return "Failed to change port light on any discovered switch or device"
        
        for switch in switches:
            if switch.get('managed'):
                ip = switch['ip']
                logging.info(f"Attempting to change port light on managed switch: {ip}")
                for cred in get_credentials():
                    logging.info(f"Trying credentials - Username: {cred['username']}, Password: {cred['password']}")
                    if try_connect(ip, action, port, cred['username'], cred['password']):
                        return f"Successfully changed port light on {ip}"
            else:
                interface = switch.get('interface')
                if interface:
                    logging.info(f"Found unmanaged device via interface: {interface}")
                    # Here you can try to interact or at least identify the port in a different way
                    # For example, using LLDP info or ARP info to map the device.
        
        logging.error("Failed to change port light on any discovered switch or device.")
        return "Failed to change port light on any discovered switch or device"
    except Exception as e:
        logging.error(f"Error in change_port_light function: {str(e)}")
        return f"Error in change_port_light function: {str(e)}"

def try_connect(ip, action, port, username, password):
    device_types = ['cisco_ios', 'hp_procurve', 'juniper', 'arista_eos']
    for device_type in device_types:
        try:
            device = {
                'device_type': device_type,
                'ip': ip,
                'username': username,
                'password': password,
                'timeout': 10,
            }
            logging.info(f"Attempting to connect to {ip} as {device_type}")
            with ConnectHandler(**device) as net_connect:
                commands = get_commands(device_type, action, port)
                output = net_connect.send_config_set(commands)
                logging.info(f"Successfully executed commands on {ip} with {device_type}: {output}")
                return True
        except Exception as e:
            logging.warning(f"Failed to connect to {ip} as {device_type} with username '{username}': {str(e)}")
    return False

def get_commands(device_type, action, port):
    if not port:
        return ["interface range Gi1/0/1 - 48", f"beacon {'on' if action in ['on', 'blink'] else 'off'}"]
    
    common_commands = {
        'on': [f"interface {port}", "beacon on"],
        'off': [f"interface {port}", "beacon off"],
        'blink': [f"interface {port}", "beacon off", "beacon on"],
    }
    
    device_specific_commands = {
        'hp_procurve': {
            'on': [f"interface {port}", "led-mode on"],
            'off': [f"interface {port}", "led-mode off"],
            'blink': [f"interface {port}", "led-mode on"],
        },
        'juniper': {
            'on': [f"set interfaces {port} led-mode on"],
            'off': [f"set interfaces {port} led-mode off"],
            'blink': [f"set interfaces {port} led-mode on"],
        },
    }
    
    return device_specific_commands.get(device_type, {}).get(action, common_commands[action])

def change_port_light_interface(action, port=''):
    try:
        result = change_port_light(action, port)
        return result
    except Exception as e:
        logging.error(f"Error in change_port_light_interface function: {str(e)}")
        return f"Error in change_port_light_interface function: {str(e)}"