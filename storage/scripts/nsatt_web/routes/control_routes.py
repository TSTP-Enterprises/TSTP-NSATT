import logging
from flask import jsonify
import subprocess
import os
from modules.service_control import control_service, get_service_status, restart_device, stop_script
from modules.restart_script import restart_script

def register_control_routes(app):
    @app.route('/control/<string:service>/<string:action>')
    def control_services(service, action):
        logging.info(f"Received service: {service}, action: {action}")
        valid_services = ['vsftpd', 'lldpd', 'ssh', 'apache2', 'postgresql']
        if service not in valid_services or action not in ['start', 'stop', 'restart']:
            logging.error(f"Invalid service or action: {service}, {action}")
            return jsonify({"error": "Invalid service or action."}), 400
        message = control_service(service, action)
        return jsonify({"message": message}), 200

    @app.route('/control/<string:service>/status')
    def control_services_status(service):
        status = get_service_status(service)
        return jsonify(status)

    @app.route('/control/restart_device')
    def restart_device_route():
        return jsonify({"message": restart_device()})

    @app.route('/stop')
    def stop_script_route():
        return jsonify({"message": stop_script()})

    @app.route('/restart')
    def restart_script_route():
        try:
            # Get the directory of the current script
            script_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Build the path to the 'restart_app.sh' script relative to this script's directory
            script_path = "/usr/local/bin/restart_app.sh"
            
            # Make sure the script exists and is executable
            if not os.path.exists(script_path):
                return jsonify({"error": f"Script {script_path} not found."}), 500
            if not os.access(script_path, os.X_OK):
                return jsonify({"error": f"Script {script_path} is not executable."}), 500
            
            # Execute the script
            print(f"Script path: {script_path}")
            subprocess.Popen([script_path], shell=True)

            return jsonify({"message": "Script is restarting..."}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500
