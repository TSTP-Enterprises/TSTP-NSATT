import subprocess
import re
import os
import sqlite3
from datetime import datetime

def get_monitor_mode_interfaces():
    try:
        interfaces_output = subprocess.getoutput("iwconfig 2>/dev/null | grep 'Mode:Monitor' | awk '{print $1}'")
        interfaces = [interface.strip() for interface in interfaces_output.split('\n') if interface]
        return interfaces
    except Exception as e:
        print(f"Error getting monitor mode interfaces: {e}")
        return []

def run_wireless_scan(target, scan_type, options):
    try:
        options_string = ' '.join(options)
        scan_command = f"{scan_type} {options_string} {target}"
        
        # Open the log file in append mode
        with open('wireless_scans.log', 'a') as log_file:
            log_file.write(f"Running command: {scan_command}\n")  # Log the command

            process = subprocess.Popen(scan_command.split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

            output_lines = []
            max_lines = 100  # Limit the number of lines to prevent freezing
            line_count = 0
            for line in iter(process.stdout.readline, ''):
                if line_count >= max_lines:
                    break
                log_file.write(f"Output line: {line.strip()}\n")  # Log each line of output
                output_lines.append(line)
                yield line.strip()
                line_count += 1

            process.stdout.close()
            process.wait()

            if process.returncode != 0:
                error_message = f"Error: Scan command exited with code {process.returncode}"
                log_file.write(f"{error_message}\n")
                yield error_message

            save_scan_result(target, scan_type, options_string, ''.join(output_lines))

    except Exception as e:
        with open('wireless_scans.log', 'a') as log_file:
            log_file.write(f"Error running wireless scan: {e}\n")
        yield f"Error running wireless scan: {e}"

def save_scan_result(target, scan_type, options, scan_result):
    try:
        conn = sqlite3.connect('./db/wireless_results.db')
        c = conn.cursor()
        c.execute('''INSERT INTO wireless_results (time, scan_type, options, target, result)
                     VALUES (?, ?, ?, ?, ?)''',
                  (datetime.now().strftime('%Y-%m-%d %H:%M:%S'), scan_type, options, target, scan_result))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Error saving scan result: {e}")

def parse_scan_output(line):
    # Clean up the line to remove any non-printable characters and escape sequences
    cleaned_line = re.sub(r'\x1B[@-_][0-?]*[ -/]*[@-~]', '', line)
    cleaned_line = cleaned_line.strip()

    parts = cleaned_line.split()
    
    # Adjust parsing logic based on your specific output format
    try:
        if len(parts) >= 10:
            # BSSID, Power, Channel, Beacons, Frames, Rate, Cipher, Auth, Enc, ESSID
            essid_index = 9  # Assuming ESSID starts at index 9
            essid_parts = parts[essid_index:]  # Get all parts from the ESSID index onwards
            
            # Identify where the actual ESSID starts by finding the first part not in the security tags
            actual_essid_start = next((i for i, part in enumerate(essid_parts) if part not in ['PSK', 'MGT', 'SAE', 'CCMP', 'WPA2', 'WPA', 'WEP']), 0)
            essid = ' '.join(essid_parts[actual_essid_start:])  # Join parts starting from actual ESSID

            return {
                'bssid': parts[0],
                'power': int(parts[1]),
                'channel': parts[2],
                'beacons': int(parts[3]),
                'frames': int(parts[4]),
                'rate': parts[5],
                'cipher': parts[6],
                'auth': parts[7],
                'enc': parts[8],
                'essid': essid
            }
    except ValueError:
        pass
    return None

def format_networks_as_html(networks):
    html = ""
    for bssid, data in networks.items():
        html += f"<tr>"
        html += f"<td>{bssid}</td>"
        html += f"<td>{data.get('power', 'N/A')}</td>"
        html += f"<td>{data.get('channel', 'N/A')}</td>"
        html += f"<td>{data.get('beacons', 'N/A')}</td>"
        html += f"<td>{data.get('frames', 'N/A')}</td>"
        html += f"<td>{data.get('rate', 'N/A')}</td>"
        html += f"<td>{data.get('essid', 'N/A')}</td>"
        html += f"<td>{data.get('cipher', 'N/A')}</td>"
        html += f"<td>{data.get('auth', 'N/A')}</td>"
        html += f"<td>{data.get('enc', 'N/A')}</td>"
        html += f"</tr>"
    return html

def get_wireless_scan_types():
    try:
        return {
            'airodump-ng': 'Capture packets and display network information',
            'wash': 'Detect WPS-enabled networks',
            'wifite': 'Automated wireless network attacks',
            'airmon-ng': 'Enable monitor mode on wireless interfaces',
            'aireplay-ng': 'Inject packets into a network to test its security',
            'aircrack-ng': 'Crack WEP and WPA-PSK keys using captured packets'
        }
    except Exception as e:
        print(f"Error retrieving wireless scan types: {e}")
        return {}

def get_wireless_options(scan_type=None):
    try:
        options = {
            '--band': 'Specify band (e.g., --band a for 5GHz)',
            '--channel': 'Specify channel (e.g., --channel 6)',
            '--ignore-negative-one': 'Ignore negative one channel'
        }

        if scan_type == 'airodump-ng':
            options.update({
                '--write': 'Write output to a file',
                '--output-format': 'Specify output format (e.g., pcap, ivs)',
                '--bssid': 'Specify the BSSID of the target AP'
            })
        elif scan_type == 'wifite':
            options.update({
                '--kill': 'Kill conflicting processes',
                '--wep': 'Only target WEP-encrypted networks',
                '--wpa': 'Only target WPA-encrypted networks'
            })
        elif scan_type == 'aireplay-ng':
            options.update({
                '--deauth': 'Send deauthentication packets to a network',
                '--fakeauth': 'Fake authentication with a network',
                '--arpreplay': 'ARP request replay attack'
            })
        elif scan_type == 'aircrack-ng':
            options.update({
                '--bssid': 'Specify the BSSID of the target AP',
                '--key': 'Specify the key to test',
                '--ivs': 'Use only IVs for cracking'
            })
        elif scan_type == 'wash':
            options.update({
                '--interface': 'Specify the interface to use',
                '--ignore-fcs': 'Ignore frame check sequence errors'
            })

        return options
    except Exception as e:
        print(f"Error retrieving wireless options: {e}")
        return {}

def get_old_wireless_results():
    try:
        conn = sqlite3.connect('./db/wireless_results.db')
        c = conn.cursor()
        c.execute('SELECT id, time, target, scan_type FROM wireless_results ORDER BY time DESC')
        results = c.fetchall()
        conn.close()
        return results
    except Exception as e:
        print(f"Error retrieving old wireless results: {e}")
        return []

def get_wireless_result_details(result_id):
    try:
        conn = sqlite3.connect('./db/wireless_results.db')
        c = conn.cursor()
        c.execute('SELECT * FROM wireless_results WHERE id = ?', (result_id,))
        result = c.fetchone()
        conn.close()
        return result
    except Exception as e:
        print(f"Error retrieving wireless result details: {e}")
        return None
    
def save_scan_to_file_and_db(target, scan_type, options):
    try:
        # Generate the filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"./scans/{target}_{scan_type}_{timestamp}.log"

        # Save the scan results to a file
        with open(filename, 'w') as f:
            conn = sqlite3.connect('./db/wireless_results.db')
            c = conn.cursor()
            c.execute('SELECT result FROM wireless_results WHERE target=? AND scan_type=? ORDER BY time DESC LIMIT 1', 
                      (target, scan_type))
            result = c.fetchone()
            if result:
                f.write(result[0])
            conn.close()

        # You can add additional logging or database saving logic here if needed

    except Exception as e:
        print(f"Error saving scan to file and database: {e}")
        raise

def save_scan_result_to_file(scan_results, directory='./scans/', filename='wireless_scan_results.txt'):
    try:
        if not os.path.exists(directory):
            os.makedirs(directory)
        file_path = os.path.join(directory, filename)
        with open(file_path, 'w') as file:
            file.write(scan_results)
        return file_path
    except Exception as e:
        print(f"Error saving scan results to file: {e}")
        return None