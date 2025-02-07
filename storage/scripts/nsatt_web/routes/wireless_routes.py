from flask import render_template, request, Response, jsonify, redirect, url_for, send_file
from modules.wireless_scans import (
    run_wireless_scan, 
    get_wireless_scan_types, 
    get_wireless_options, 
    get_old_wireless_results, 
    get_wireless_result_details, 
    get_monitor_mode_interfaces,
    parse_scan_output, 
    format_networks_as_html,
    save_scan_result_to_file
)
import os
import logging

# Initialize logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

scanning = False
scan_results = ""

def register_wireless_routes(app):
    global scan_results

    @app.route('/wireless', methods=['GET', 'POST'])
    def wireless_scan():
        global scanning, scan_results
        try:
            if request.method == 'POST':
                target = request.form.get('target', '').strip()
                scan_type = request.form.get('scan_type')
                options = []

                # Basic options
                if request.form.get('show_ack'):
                    options.append('--showack')
                if request.form.get('ignore_negative'):
                    options.append('--ignore-negative-one')

                # Advanced options
                if request.form.get('use_band') and request.form.get('band'):
                    options.append(f"--band {request.form['band']}")
                if request.form.get('use_channel') and request.form.get('channel'):
                    options.append(f"--channel {request.form['channel']}")
                if request.form.get('use_bssid') and request.form.get('bssid'):
                    options.append(f"--bssid {request.form['bssid']}")
                if request.form.get('use_essid') and request.form.get('essid'):
                    options.append(f"--essid {request.form['essid']}")
                if request.form.get('use_deauth') and request.form.get('deauth'):
                    options.append(f"--deauth={request.form['deauth']}")
                
                # Custom command input
                custom_command = request.form.get('custom_command')
                if custom_command:
                    options.append(custom_command)

                if not target or not scan_type:
                    logging.error("Target interface or scan type not specified.")
                    return "Error: Target interface or scan type not specified.", 400

                scanning = True
                scan_results = ""  # Reset scan results for each new scan

                return redirect(url_for('wireless_scan_results', target=target, scan_type=scan_type, options=','.join(options)))

            scan_types = get_wireless_scan_types()
            interfaces = get_monitor_mode_interfaces()
            options = get_wireless_options()
            return render_template('wireless.html', scan_types=scan_types, options=options, interfaces=interfaces)
        except Exception as e:
            logging.exception("An error occurred during the wireless scan setup.")
            return f"Error: {e}", 500

    @app.route('/wireless/results/<target>/<scan_type>/', defaults={'options': None}, methods=['GET'])
    @app.route('/wireless/results/<target>/<scan_type>/<options>', methods=['GET'])
    def wireless_scan_results(target, scan_type, options):
        global scan_results
        try:
            if options:
                options = options.split(',')
            else:
                options = []
            return render_template('wireless_results.html', target=target, scan_type=scan_type, options=options, scan_results=scan_results)
        except Exception as e:
            logging.exception("An error occurred while loading the wireless scan results.")
            return f"Error loading wireless scan results: {e}", 500

    @app.route('/wireless/scan_stream/<target>/<scan_type>/<options>', methods=['GET'])
    def scan_stream(target, scan_type, options):
        global scanning, scan_results
        try:
            scanning = True
            options = options.split(',')

            def generate():
                global scan_results
                networks = {}  # Dictionary to store and organize data by BSSID
                try:
                    for line in run_wireless_scan(target, scan_type, options):
                        if not scanning:
                            break
                        parsed_data = parse_scan_output(line)
                        if parsed_data:
                            bssid = parsed_data['bssid']
                            if bssid in networks:
                                # Update existing network data
                                networks[bssid].update(parsed_data)
                            else:
                                # Add new network data
                                networks[bssid] = parsed_data

                            # Convert the organized data to HTML and send it as SSE
                            scan_results = format_networks_as_html(networks)
                            yield f"data: {scan_results}\n\n"
                except Exception as e:
                    logging.exception("An error occurred during the wireless scan.")
                    yield f"data: Error occurred during the scan: {e}\n\n"

            return Response(generate(), mimetype='text/event-stream')
        except Exception as e:
            logging.exception("An error occurred while setting up the scan stream.")
            return f"Error setting up scan stream: {e}", 500

    @app.route('/wireless/stop', methods=['POST'])
    def stop_wireless_scan():
        global scanning
        try:
            scanning = False
            return jsonify({"message": "Scan stopped"})
        except Exception as e:
            logging.exception("An error occurred while stopping the scan.")
            return jsonify({"message": f"Error stopping scan: {e}"}), 500

    @app.route('/wireless/save_scan', methods=['POST'])
    def save_scan():
        global scan_results
        try:
            if not scan_results:
                return jsonify({"message": "No scan data to save."})

            file_path = save_scan_result_to_file(scan_results)
            if file_path:
                return send_file(file_path, as_attachment=True)
            else:
                return jsonify({"message": "Error saving scan to file."}), 500
        except Exception as e:
            logging.exception("An error occurred while saving the scan results.")
            return jsonify({"message": f"Error saving scan: {e}"}), 500

    @app.route('/wireless/results')
    def wireless_results():
        try:
            results = get_old_wireless_results()
            return render_template('wireless_results_list.html', results=results)
        except Exception as e:
            logging.exception("An error occurred while loading old wireless results.")
            return f"Error loading wireless results: {e}", 500

    @app.route('/wireless/result/<int:result_id>')
    def wireless_result_detail(result_id):
        try:
            result_details = get_wireless_result_details(result_id)
            return render_template('wireless_result_detail.html', result_details=result_details)
        except Exception as e:
            logging.exception(f"An error occurred while loading details for result ID {result_id}.")
            return f"Error loading wireless result details: {e}", 500

    @app.route('/wireless/save_scan/<target>/<scan_type>/<options>', methods=['POST'])
    def save_wireless_scan(target, scan_type, options):
        try:
            options = options.split(',')
            log_file = 'wireless_scans.log'
            if os.path.exists(log_file):
                return send_file(log_file, as_attachment=True, download_name=f'{target}_{scan_type}_scan.log')
            else:
                logging.warning("No scan results found to save.")
                return jsonify({"message": "No scan results found to save."}), 404
        except Exception as e:
            logging.exception("An error occurred while saving the wireless scan.")
            return jsonify({"message": f"Error saving scan: {e}"}), 500