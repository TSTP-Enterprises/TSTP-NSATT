import subprocess
import logging
import sqlite3
from datetime import datetime

# Set up logging
logging.basicConfig(filename='nmap_scans.log', level=logging.DEBUG, 
                    format='%(asctime)s %(levelname)s:%(message)s')

def run_nmap_scan(target, scan_type, options, custom_command=None):
    try:
        if custom_command:
            # Validate the custom command
            if not custom_command.startswith("nmap"):
                yield "Invalid command: Must start with 'nmap'."
                return
            if ";" in custom_command or "&" in custom_command:
                yield "Invalid command: Cannot contain ';' or '&' for security reasons."
                return
            scan_command = custom_command
        else:
            options_string = ' '.join(options)
            scan_command = f"nmap {scan_type} {options_string} {target}"

        logging.info(f"Starting Nmap scan with command: {scan_command}")

        process = subprocess.Popen(scan_command.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1, universal_newlines=True)

        # Open a connection to the database
        conn = sqlite3.connect('/nsatt/storage/databases/nmap_results.db')
        c = conn.cursor()
        c.execute('''INSERT INTO nmap_results (time, scan_type, options, target, result)
                     VALUES (?, ?, ?, ?, ?)''',
                  (datetime.now().strftime('%Y-%m-%d %H:%M:%S'), scan_type, ' '.join(options), target, ''))
        result_id = c.lastrowid
        conn.commit()

        result_data = ""

        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                break
            if output:
                result_data += output
                c.execute('''UPDATE nmap_results SET result = ? WHERE id = ?''',
                          (result_data, result_id))
                conn.commit()
                yield output.strip()

        stderr = process.stderr.read()
        if stderr:
            logging.error(f"Nmap error: {stderr}")
            yield f"Nmap error: {stderr}"

        rc = process.poll()
        if rc != 0:
            logging.error(f"Nmap process exited with return code {rc}")
            yield f"Nmap process exited with return code {rc}"

        conn.close()
        logging.info(f"Nmap scan completed for target: {target}")

    except Exception as e:
        logging.error(f"Failed to start or run Nmap scan: {e}")
        yield f"Error during Nmap scan: {e}"

def get_nmap_scan_types():
    try:
        return {
            '-sS': 'TCP SYN scan',
            '-sT': 'TCP connect scan',
            '-sU': 'UDP scan',
            '-sP': 'Ping scan',
            '-sV': 'Version detection',
            '-O': 'OS detection',
            '-A': 'Aggressive scan options',
            '-p-': 'Scan all ports',
            '-sC': 'Scan using default NSE scripts',
            '-sn': 'Ping scan (only determine if host is up)',
            '-n': 'No DNS resolution',
            '-r': 'Scan ports consecutively - do not randomize',
            '-Pn': 'Treat all hosts as online - skip discovery',
            '-f': 'Fragment packets (may evade firewalls)',
            '--mtu': 'Specifies the MTU for outgoing packets',
            '--scan-delay': 'Adjust delay between probes (ms)',
            '--max-scan-delay': 'Set maximum delay between probes (ms)',
            '--min-rate': 'Send packets no slower than per second',
            '--max-rate': 'Send packets no faster than per second',
            '--defeat-rst-ratelimit': 'Try to defeat RST rate limiting',
            '--max-retries': 'Caps number of port scan probe tx',
            '--host-timeout': 'Give up on target after this long',
            '--script': 'Specify a script to be run during the scan',
            '--data-length': 'Append extra data to sent packets',
            '--badsum': 'Send packets with a bad checksum',
            '--ip-options': 'Send packets with specified IP options',
        }
    except Exception as e:
        logging.error(f"Error retrieving scan types: {e}")
        return {}

def get_nmap_options():
    try:
        return {
            '--open': 'Show only open ports',
            '--top-ports': 'Scan top N most common ports',
            '--traceroute': 'Trace path to host',
            '--osscan-guess': 'Guess OS more aggressively',
            '--reason': 'Display port state reason',
            '--packet-trace': 'Show all packets sent and received',
            '--stats-every': 'Print periodic timing stats',
            '--append-output': 'Append to existing output files',
            '--resume': 'Resume aborted scan',
            '--style': 'Specify output style',
            '--ttl': 'Specify IP time-to-live field',
            '--randomize-hosts': 'Randomize target host order',
            '--spoof-mac': 'Spoof your MAC address',
            '--badsum': 'Send packets with a bad checksum',
            '--data-length': 'Append extra data to sent packets',
            '--mtu': 'Specify the MTU for outgoing packets',
            '--min-hostgroup': 'Minimum hosts to scan in parallel',
            '--max-hostgroup': 'Maximum hosts to scan in parallel',
            '--script-updatedb': 'Update the script database'
        }
    except Exception as e:
        logging.error(f"Error retrieving options: {e}")
        return {}

def get_old_nmap_results():
    try:
        conn = sqlite3.connect('/nsatt/storage/databases/nmap_results.db')
        c = conn.cursor()
        c.execute('SELECT id, time, scan_type, target FROM nmap_results ORDER BY time DESC')
        results = c.fetchall()
        conn.close()
        return results
    except Exception as e:
        logging.error(f"Error retrieving old Nmap results: {e}")
        return []

def manage_nmap_results(action, selected_ids=None):
    try:
        conn = sqlite3.connect('/nsatt/storage/databases/nmap_results.db')
        c = conn.cursor()

        if action == "delete_selected" and selected_ids:
            c.executemany("DELETE FROM nmap_results WHERE id=?", [(id,) for id in selected_ids])
        elif action == "delete_all":
            c.execute("DELETE FROM nmap_results")
        elif action == "export":
            results = []
            if selected_ids:
                c.executemany("SELECT * FROM nmap_results WHERE id=?", [(id,) for id in selected_ids])
            else:
                c.execute("SELECT * FROM nmap_results")
            results = c.fetchall()
            # Implement export logic here (e.g., save to a file or return results)
        
        conn.commit()
        conn.close()

        return "Action completed successfully."
    except Exception as e:
        logging.error(f"Error managing Nmap results: {e}")
        return f"Error: {e}"