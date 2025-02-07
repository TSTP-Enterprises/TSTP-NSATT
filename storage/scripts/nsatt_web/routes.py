from flask import render_template, request, redirect, url_for, jsonify
from modules.service_control import control_service, get_service_status, restart_device, stop_script
from modules.restart_script import restart_script

def register_routes(app):

    @app.route('/control/<string:service>/<string:action>')
    def control_services(service, action):
        return control_service(service, action)

    @app.route('/control/<string:service>/status')
    def control_services_status(service):
        return get_service_status(service)

    @app.route('/restart')
    def restart_script_route():
        try:
            restart_script()  # This will restart the script in place
            return jsonify({"message": "Script is restarting..."}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    @app.route('/stop')
    def stop_script_route():
        return stop_script()

    @app.route('/control/restart_device')
    def restart_device_route():
        return jsonify({"message": restart_device()})
