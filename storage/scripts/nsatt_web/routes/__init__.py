from .control_routes import register_control_routes
from .network_routes import register_network_routes
from .nmap_routes import register_nmap_routes
from .wireless_routes import register_wireless_routes
from .console_routes import register_console_routes
from .metasploit_routes import register_metasploit_routes
from .hid_routes import register_hid_routes  # New HID routes
from .app_launcher_routes import register_app_launcher_routes  # New App Launcher routes
from .live_feed_routes import register_live_feed_routes  # New Live Feed routes
from .file_browser_routes import register_file_browser_routes  # New File Browser routes
from .vnc_routes import register_vnc_routes  # New VNC routes
from .vpn_routes import register_vpn_routes  # New VPN routes

def register_all_routes(app):
    register_control_routes(app)
    register_network_routes(app)
    register_nmap_routes(app)
    register_wireless_routes(app)
    register_console_routes(app)
    register_metasploit_routes(app)
    register_hid_routes(app)  # Register HID routes
    register_app_launcher_routes(app)  # Register App Launcher routes
    register_live_feed_routes(app)  # Register Live Feed routes
    register_file_browser_routes(app)  # Register File Browser routes
    register_vnc_routes(app)  # Register VNC routes
    register_vpn_routes(app)  # Register VPN routes
