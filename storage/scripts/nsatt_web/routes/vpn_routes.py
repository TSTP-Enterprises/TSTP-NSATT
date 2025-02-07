from flask import jsonify, request
from modules.tailscale_control import (
    check_tailscale_installed,
    get_tailscale_status,
    install_tailscale,
    toggle_tailscale,
    get_tailscale_config,
    update_tailscale_config
)

def register_vpn_routes(app):
    @app.route('/api/vpn/status', methods=['GET'])
    def vpn_status():
        """Get Tailscale status and installation state"""
        is_installed = check_tailscale_installed()
        if not is_installed:
            return jsonify({
                "installed": False,
                "message": "Tailscale is not installed"
            })
        
        status = get_tailscale_status()
        return jsonify({
            "installed": True,
            "status": status
        })

    @app.route('/api/vpn/install', methods=['POST'])
    def vpn_install():
        """Install Tailscale"""
        result = install_tailscale()
        return jsonify(result)

    @app.route('/api/vpn/toggle', methods=['POST'])
    def vpn_toggle():
        """Toggle Tailscale connection"""
        action = request.json.get('action')
        if action not in ['up', 'down']:
            return jsonify({"success": False, "error": "Invalid action"}), 400
        
        result = toggle_tailscale(action)
        return jsonify(result)

    @app.route('/api/vpn/config', methods=['GET'])
    def vpn_get_config():
        """Get Tailscale configuration"""
        config = get_tailscale_config()
        return jsonify(config)

    @app.route('/api/vpn/config', methods=['POST'])
    def vpn_update_config():
        """Update Tailscale configuration"""
        config_params = request.json
        result = update_tailscale_config(config_params)
        return jsonify(result) 