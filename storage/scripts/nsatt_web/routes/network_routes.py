import subprocess
import os
from flask import jsonify, render_template, session, request, redirect, url_for, send_file
from modules.network_adapters import get_network_adapters, toggle_network_adapter, change_mac_address
from modules.network_info import get_network_info, get_old_findings, get_finding_details, clear_all_findings
from modules.switch_control import change_port_light_interface
import logging

def register_network_routes(app):
    def run_command(command):
        """
        Run a shell command and return the output.
        """
        try:
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                raise subprocess.CalledProcessError(result.returncode, command, result.stderr.strip())
        except subprocess.CalledProcessError as e:
            logging.error(f"Command '{' '.join(command)}' failed with error: {e.stderr}")
            raise RuntimeError(f"Command '{' '.join(command)}' failed: {e.stderr}")
        except Exception as e:
            logging.error(f"Unexpected error running command '{' '.join(command)}': {str(e)}")
            raise RuntimeError(f"Unexpected error running command '{' '.join(command)}': {str(e)}")

    @app.route('/network/adapters')
    def network_adapters():
        adapters = get_network_adapters()
        return jsonify({"adapters": adapters})

    @app.route('/network/adapter/<string:adapter>/toggle')
    def toggle_adapter(adapter):
        result = toggle_network_adapter(adapter)
        return result

    @app.route('/network/wireless_modes')
    def network_wireless_modes():
        try:
            modes_response = get_wireless_modes()
            modes = modes_response.get_json()
            if 'error' in modes:
                return jsonify({'error': modes['error']})
            return jsonify({'modes': modes['modes']})
        except Exception as e:
            logging.error(f"Error fetching wireless modes: {str(e)}")
            return jsonify({'error': f"Error fetching wireless modes: {e}"})
        
    def get_wireless_modes():
        try:
            interfaces_output = run_command(["iwconfig"])
            interfaces = []
            current_interface = None
            for line in interfaces_output.split('\n'):
                if line and not line.startswith(' '):
                    current_interface = line.split()[0]
                if "Mode:" in line and current_interface:
                    mode = line.split("Mode:")[1].split()[0]
                    interfaces.append({'interface': current_interface, 'status': mode})
            return jsonify({'modes': interfaces})
        except Exception as e:
            logging.error(f"Failed to fetch wireless modes: {str(e)}")
            return jsonify({'error': f"Failed to fetch wireless modes: {str(e)}"}), 500
        
    @app.route('/network/toggle_wireless_mode/<interface>/<current_mode>', methods=['POST'])
    def toggle_wireless_mode(interface, current_mode):
        try:
            new_mode = 'managed' if current_mode == 'monitor' else 'monitor'
            run_command(["sudo", "ifconfig", interface, "down"])
            run_command(["sudo", "iwconfig", interface, "mode", new_mode])
            run_command(["sudo", "ifconfig", interface, "up"])
            # Verify the mode change
            verify_mode = run_command(["iwconfig", interface])
            if f"Mode:{new_mode.capitalize()}" in verify_mode:
                return jsonify(message=f"Interface {interface} successfully switched to {new_mode} mode.")
            else:
                raise RuntimeError(f"Failed to switch {interface} to {new_mode} mode.")
        except Exception as e:
            return jsonify({'error': f"Error toggling wireless mode for {interface}: {str(e)}"}), 500        

    @app.route('/network/wireless_mode/<string:interface>/<string:mode>')
    def toggle_wireless_mode_route(interface, mode):
        try:
            result = toggle_wireless_mode(interface, mode)
            return result
        except Exception as e:
            logging.error(f"Error changing wireless mode for {interface}: {str(e)}")
            return jsonify({'error': f"Error changing wireless mode for {interface}: {e}"}), 400

    @app.route('/network/wireless_mode/<string:interface>/change_mac', methods=['POST'])
    def change_mac(interface):
        new_mac = request.form.get('new_mac')
        if not new_mac:
            return "No MAC address provided.", 400
        try:
            result = change_mac_address(interface, new_mac)
            return result
        except Exception as e:
            logging.error(f"Error changing MAC address for {interface}: {str(e)}")
            return f"Error changing MAC address for {interface}: {e}", 400

    @app.route('/')
    def base():
        return render_template('base.html')
    
    @app.route('/index')
    def index():
        network_info = get_network_info('/nsatt/storage/databases/network_info.db', save_to_db=session.get('save_lan_info', True))
        
        # Log the network_info to check what is being retrieved
        app.logger.debug(f"Network Info: {network_info}")
        
        return render_template('index.html', network_info=network_info)

    @app.route('/download')
    def download_info():
        network_info = get_network_info('/nsatt/storage/databases/network_info.db', save_to_db=False)
        filename = 'network_info.txt'
        filepath = f'./{filename}'

        with open(filepath, 'w') as file:
            file.write(f"Time: {network_info['time']}\n")
            file.write(f"LAN IP: {network_info['lan_ip']}\n")
            file.write(f"MAC: {network_info['mac']}\n")
            file.write(f"Gateway: {network_info['gateway']}\n")
            file.write(f"Hostname: {network_info['hostname']}\n")
            file.write(f"Switch Info: {network_info['switch_info']}\n")
            file.write(f"DNS Servers: {network_info['dns_servers']}\n")
            file.write(f"Subnet Mask: {network_info['subnet_mask']}\n")
            file.write(f"Broadcast IP: {network_info['broadcast_ip']}\n")
            file.write(f"ISP: {network_info['isp']}\n")
            file.write(f"WAN IP: {network_info['wan_ip']}\n")
            file.write(f"WAN Gateway: {network_info['wan_gateway']}\n")
            file.write(f"Region: {network_info['region']}\n")
            file.write(f"City: {network_info['city']}\n")
            file.write(f"Country: {network_info['country']}\n")
            file.write(f"Organization: {network_info['org']}\n")
            file.write(f"Requesting IP: {network_info['requesting_ip']}\n")
            file.write(f"Browser: {network_info['browser']}\n")
            file.write(f"Referer: {network_info['referer']}\n")
            file.write(f"User Agent Platform: {network_info['user_agent_platform']}\n")
            file.write(f"User Agent Version: {network_info['user_agent_version']}\n")
            file.write(f"User Agent Language: {network_info['user_agent_language']}\n")

        return send_file(filepath, as_attachment=True, attachment_filename=filename)

    @app.route('/settings', methods=['GET', 'POST'])
    def settings():
        if request.method == 'POST':
            session['show_lan_info'] = 'show_lan_info' in request.form
            session['save_lan_info'] = 'save_lan_info' in request.form
            session['show_wan_info'] = 'show_wan_info' in request.form
            session['save_wan_info'] = 'save_wan_info' in request.form
            session['show_request_info'] = 'show_request_info' in request.form
            session['save_request_info'] = 'save_request_info' in request.form
            return redirect(url_for('index'))
        return render_template('settings.html')

    @app.route('/findings')
    def findings():
        try:
            findings = get_old_findings('/nsatt/storage/databases/network_info.db')
            return render_template('findings.html', findings=findings)
        except Exception as e:
            logging.error(f"Error loading findings: {str(e)}")
            return f"Error loading findings: {e}"

    @app.route('/finding/<int:finding_id>')
    def finding_detail(finding_id):
        try:
            details = get_finding_details('/nsatt/storage/databases/network_info.db', finding_id)
            return render_template('finding_detail.html', details=details)
        except Exception as e:
            logging.error(f"Error loading finding details for ID {finding_id}: {str(e)}")
            return f"Error loading finding details: {e}"
        
    @app.route('/clear_findings', methods=['POST'])
    def clear_findings():
        try:
            clear_all_findings('/nsatt/storage/databases/network_info.db')
            return redirect(url_for('findings'))
        except Exception as e:
            logging.error(f"Error clearing findings: {str(e)}")
            return f"Error clearing findings: {e}"

    @app.route('/change_switch_port_light/<action>', methods=['POST'])
    def change_switch_port_light(action):
        if not request.is_json:
            return jsonify({'error': 'Request must be JSON'}), 415
        data = request.get_json()
        port = data.get('port', '')  # Empty string means all ports
        result = change_port_light_interface(action, port)
        if "Error" in result or "Failed" in result:
            return jsonify({'error': result}), 500
        return jsonify({'message': result})
    
    @app.route('/network/wired_settings')
    def get_wired_settings():
        try:
            # Fetch wired settings like IP, Subnet Mask, Gateway using `ip` command
            ip_info = run_command(["ip", "-4", "addr", "show", "eth0"])
            gateway_info = run_command(["ip", "route", "show", "default"])

            ip_address = subnet_mask = gateway = "Unavailable"

            # Log the output of the ip command for debugging
            app.logger.debug(f"ip command output: {ip_info}")

            # Extract IP address and CIDR notation
            for line in ip_info.splitlines():
                if "inet" in line:
                    ip_cidr = line.split()[1]
                    ip_address = ip_cidr.split('/')[0]
                    cidr_subnet_mask = ip_cidr.split('/')[1] if '/' in ip_cidr else None
                    if cidr_subnet_mask:
                        # Log the output of the ipcalc command for debugging
                        ipcalc_output = run_command(["ipcalc", "-m", ip_cidr])
                        app.logger.debug(f"ipcalc command output: {ipcalc_output}")
                        
                        subnet_mask = ipcalc_output.split("=")[1].strip()
                    break  # Found the IP info, exit loop

            # Extract gateway
            if "default via" in gateway_info:
                gateway = gateway_info.split()[2]

            wired_settings = {
                'ip': ip_address,
                'subnet_mask': subnet_mask,
                'gateway': gateway,
                'raw_data': ip_info
            }
            app.logger.info(f"Wired settings fetched successfully: {wired_settings}")
            return jsonify(wired_settings)
        except subprocess.CalledProcessError as e:
            logging.error(f"Error fetching wired settings: {str(e)} - Data: {ip_info}")
            return jsonify({'error': f"Failed to fetch wired settings: {str(e)} - Data: {ip_info}", 'raw_data': ip_info}), 500
        except IndexError as e:
            logging.error(f"Error fetching wired settings: {str(e)} - Data: {ip_info}")
            return jsonify({'error': f"Failed to fetch wired settings: Incorrect data format - Data: {ip_info}", 'raw_data': ip_info}), 500
        except Exception as e:
            logging.error(f"Unexpected error fetching wired settings: {str(e)} - Data: {ip_info}")
            return jsonify({'error': f"Failed to fetch wired settings: {str(e)} - Data: {ip_info}", 'raw_data': ip_info}), 500

    @app.route('/network/scan_wireless')
    def scan_wireless():
        adapter = request.args.get('adapter')
        if not adapter:
            return jsonify({'error': 'No network adapter specified'}), 400
        try:
            # Scan for wireless networks using `nmcli`
            networks = []
            scan_result = subprocess.run(
                ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "ifname", adapter],
                capture_output=True,
                text=True
            ).stdout

            for line in scan_result.splitlines():
                parts = line.split(":")
                ssid = parts[0] if parts[0] else 'Hidden Network'
                signal_strength = int(parts[1]) if len(parts) > 1 else 0
                security = parts[2] if len(parts) > 2 else 'None'
                networks.append({
                    'ssid': ssid,
                    'signal_strength': signal_strength,
                    'security': security
                })

            return jsonify(networks=networks)
        except Exception as e:
            logging.error(f"Failed to scan wireless networks: {str(e)}")
            return jsonify({'error': f"Failed to scan wireless networks: {str(e)}"}), 500

    @app.route('/network/connect_wireless/<ssid>', methods=['POST'])
    def connect_wireless(ssid):
        adapter = request.json.get('adapter')
        password = request.json.get('password')
        try:
            if not adapter:
                return jsonify({'error': 'No network adapter specified'}), 400

            # Use nmcli to connect to the wireless network using the specified adapter
            connect_result = subprocess.run(
                ["nmcli", "device", "wifi", "connect", ssid, "password", password, "ifname", adapter],
                capture_output=True,
                text=True
            )

            if connect_result.returncode == 0:
                return jsonify(message=f'Successfully connected to {ssid} on adapter {adapter}')
            else:
                return jsonify({'error': f'Failed to connect to {ssid}: {connect_result.stderr.strip()}'}), 400
        except Exception as e:
            return jsonify({'error': f"Failed to connect to {ssid}: {str(e)}"}), 500

    @app.route('/network/toggle_hotspot')
    def toggle_hotspot():
        try:
            # Check current status of the hotspot
            status_result = subprocess.run(["systemctl", "is-active", "hostapd"], capture_output=True, text=True)
            if status_result.returncode == 0 and status_result.stdout.strip() == "active":
                # Stop the hotspot and DHCP if it is currently running
                stop_hotspot_result = subprocess.run(["sudo", "systemctl", "stop", "hostapd"], capture_output=True, text=True)
                stop_dhcp_result = subprocess.run(["sudo", "systemctl", "stop", "isc-dhcp-server"], capture_output=True, text=True)
                if stop_hotspot_result.returncode == 0 and stop_dhcp_result.returncode == 0:
                    message = "Hotspot and DHCP server stopped successfully"
                else:
                    raise RuntimeError(f"Failed to stop hotspot or DHCP server: {stop_hotspot_result.stderr.strip()} {stop_dhcp_result.stderr.strip()}")
            else:
                # Start the hotspot and DHCP if it is not running
                start_hotspot_result = subprocess.run(["sudo", "systemctl", "start", "hostapd"], capture_output=True, text=True)
                start_dhcp_result = subprocess.run(["sudo", "systemctl", "start", "isc-dhcp-server"], capture_output=True, text=True)
                if start_hotspot_result.returncode == 0 and start_dhcp_result.returncode == 0:
                    message = "Hotspot and DHCP server started successfully"
                else:
                    raise RuntimeError(f"Failed to start hotspot or DHCP server: {start_hotspot_result.stderr.strip()} {start_dhcp_result.stderr.strip()}")
            
            return jsonify(message=message)
        except subprocess.CalledProcessError as e:
            logging.error(f"Subprocess error while toggling hotspot: {str(e)}")
            return jsonify({'error': f"Subprocess error while toggling hotspot: {str(e)}"}), 500
        except Exception as e:
            logging.error(f"Error toggling hotspot: {str(e)}")
            return jsonify({'error': f"Error toggling hotspot: {str(e)}"}), 500

    @app.route('/network/hotspot_status')
    def hotspot_status():
        try:
            # Check if the hotspot is running by checking the status of hostapd
            status_result = subprocess.run(["systemctl", "is-active", "hostapd"], capture_output=True, text=True)
            if status_result.returncode == 0:
                is_running = status_result.stdout.strip() == "active"
            else:
                is_running = False
            
            return jsonify(is_running=is_running)
        except subprocess.CalledProcessError as e:
            logging.error(f"Subprocess error while checking hotspot status: {str(e)}")
            return jsonify(is_running=False)
        except Exception as e:
            logging.error(f"Error fetching hotspot status: {str(e)}")
            return jsonify({'error': f"Error fetching hotspot status: {str(e)}"}), 500