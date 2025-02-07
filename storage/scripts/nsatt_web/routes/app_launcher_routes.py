import subprocess
import socket
import netifaces
from flask import redirect

def get_host_ip():
    try:
        # Attempt to get the IP address from all available network interfaces
        interfaces = netifaces.interfaces()
        for interface in interfaces:
            addresses = netifaces.ifaddresses(interface)
            if netifaces.AF_INET in addresses:
                for link in addresses[netifaces.AF_INET]:
                    ip = link.get('addr')
                    if ip and not ip.startswith('127.'):
                        return ip
    except Exception as e:
        # Log the exception if needed
        print(f"Error obtaining host IP: {e}")
    return '127.0.0.1'

def register_app_launcher_routes(app):
    @app.route('/app_launcher')
    def app_launcher():
        host_ip = get_host_ip()
        return redirect(f"http://{host_ip}:8081")