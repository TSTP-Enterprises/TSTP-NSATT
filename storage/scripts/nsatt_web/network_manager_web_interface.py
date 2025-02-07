import os
import json
import sqlite3
import subprocess
from flask import Flask, render_template, request, redirect, url_for, send_file, flash
from flask_sqlalchemy import SQLAlchemy
from werkzeug.utils import secure_filename
from datetime import datetime
from flask import jsonify
import smtplib
from email.mime.text import MIMEText
import logging
from cryptography.fernet import Fernet

# ---------------------------- Logging Configuration ----------------------------

# Define log directory and file
LOG_DIR = '/nsatt/storage/logs'
LOG_FILE = os.path.join(LOG_DIR, 'network_manager.log')

# Ensure the log directory exists
os.makedirs(LOG_DIR, exist_ok=True)

# Configure logging
logger = logging.getLogger('network_manager_logger')
logger.setLevel(logging.DEBUG)  # Set to DEBUG to capture all levels of logs

# Create file handler which logs even debug messages
file_handler = logging.FileHandler(LOG_FILE)
file_handler.setLevel(logging.DEBUG)

# Create console handler with a higher log level (optional)
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)

# Create formatter and add it to the handlers
formatter = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
file_handler.setFormatter(formatter)
console_handler.setFormatter(formatter)

# Add the handlers to the logger
logger.addHandler(file_handler)
logger.addHandler(console_handler)

# ---------------------------- Flask App Initialization ----------------------------

app = Flask(
    __name__,
    template_folder="/nsatt/storage/scripts/nsatt_web/web_interface/templates",
    static_folder="/nsatt/storage/scripts/nsatt_web/web_interface/static"
)
app.secret_key = 'your_secure_secret_key'  # Use environment variable for security

# Configuration
DATABASE = '/nsatt/storage/databases/network_manager.db'
SMTP_CONFIG_FILE = '/nsatt/storage/settings/smtp_config.json'
SMTP_KEY_FILE = '/nsatt/storage/settings/smtp_key.key'
AUTOSTART_FILE = '/nsatt/storage/settings/network_manager_autostart'
LOG_FILE_PATH = '/nsatt/storage/logs/network_manager.log'

app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{DATABASE}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

logger.info("Flask application initialized.")

# ---------------------------- Database Models ----------------------------

class NetworkLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    interface = db.Column(db.String(50), nullable=False)
    event = db.Column(db.String(100), nullable=False)
    details = db.Column(db.Text, nullable=True)

    def __repr__(self):
        return f'<NetworkLog {self.id} - {self.event}>'

# Ensure database tables exist
with app.app_context():
    db.create_all()
    logger.info("Database tables ensured.")

# ---------------------------- Helper Functions ----------------------------

def load_smtp_config():
    logger.debug("Loading SMTP configuration.")
    if os.path.exists(SMTP_CONFIG_FILE):
        try:
            with open(SMTP_CONFIG_FILE, 'r') as f:
                config = json.load(f)
                logger.info("SMTP configuration loaded successfully.")
                return config
        except json.JSONDecodeError as e:
            logger.error(f"Error decoding SMTP config: {e}")
            flash('Invalid SMTP configuration file.', 'danger')
            return {}
    else:
        logger.warning("SMTP configuration file not found. Using default empty configuration.")
        return {
            "smtp_server": "",
            "smtp_port": 587,
            "smtp_user": "",
            "smtp_password_encrypted": "",
            "recipient_email": ""
        }

def get_cipher():
    logger.debug("Retrieving cipher for encryption/decryption.")
    if not os.path.exists(SMTP_KEY_FILE):
        logger.critical('SMTP key file not found.')
        flash('SMTP key file not found. Cannot perform encryption/decryption.', 'danger')
        return None
    try:
        with open(SMTP_KEY_FILE, 'rb') as key_file:
            key = key_file.read()
            logger.info("Encryption key loaded successfully.")
            return Fernet(key)
    except Exception as e:
        logger.error(f"Error loading encryption key: {e}")
        flash('Error loading encryption key.', 'danger')
        return None

def decrypt_password(encrypted_password):
    logger.debug("Decrypting SMTP password.")
    cipher = get_cipher()
    if cipher is None:
        logger.error("Cipher not available for decryption.")
        return None
    try:
        decrypted = cipher.decrypt(encrypted_password.encode())
        logger.info("SMTP password decrypted successfully.")
        return decrypted.decode()
    except Exception as e:
        logger.error(f"Decryption failed: {e}")
        flash('Failed to decrypt SMTP password.', 'danger')
        return None

def encrypt_password(plain_password):
    logger.debug("Encrypting SMTP password.")
    cipher = get_cipher()
    if cipher is None:
        logger.error("Cipher not available for encryption.")
        return None
    try:
        encrypted = cipher.encrypt(plain_password.encode())
        logger.info("SMTP password encrypted successfully.")
        return encrypted.decode()
    except Exception as e:
        logger.error(f"Encryption failed: {e}")
        flash('Failed to encrypt SMTP password.', 'danger')
        return None

def get_all_network_interfaces():
    logger.debug("Fetching all active network interfaces.")
    try:
        result = subprocess.run(['ip', '-o', 'link', 'show', 'up'],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True,
                                check=True)
        interfaces = []
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split(': ')
                iface = parts[1].split('@')[0]
                if iface != 'lo':
                    interfaces.append(iface)
        logger.info(f"Active network interfaces fetched: {interfaces}")
        return interfaces
    except subprocess.CalledProcessError as e:
        logger.error(f"Error fetching network interfaces: {e.stderr}")
        flash('Failed to retrieve network interfaces.', 'danger')
        return []

def get_interface_status(interface):
    logger.debug(f"Getting status for interface: {interface}")
    try:
        result = subprocess.run(['ip', 'addr', 'show', interface],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True,
                                check=True)
        output = result.stdout
        for line in output.split('\n'):
            if 'inet ' in line:
                ip = line.strip().split(' ')[1].split('/')[0]
                logger.info(f"Interface {interface} has IP: {ip}")
                return ip
        logger.info(f"Interface {interface} has no IP assigned.")
        return 'No IP'
    except subprocess.CalledProcessError as e:
        logger.error(f"Error fetching status for {interface}: {e.stderr}")
        return 'Error'

def toggle_service(enable=True):
    action = "Enabling" if enable else "Disabling"
    logger.debug(f"{action} Network Manager service.")
    try:
        if enable:
            # Create autostart file
            open(AUTOSTART_FILE, 'a').close()
            logger.info(f"Autostart file created at {AUTOSTART_FILE}.")
            # Enable and start the service
            subprocess.run(['systemctl', 'enable', 'network_manager.service'], check=True)
            logger.info("Network Manager service enabled.")
            subprocess.run(['systemctl', 'start', 'network_manager.service'], check=True)
            logger.info("Network Manager service started.")
            flash('Network Manager service enabled.', 'success')
        else:
            # Remove autostart file
            if os.path.exists(AUTOSTART_FILE):
                os.remove(AUTOSTART_FILE)
                logger.info(f"Autostart file {AUTOSTART_FILE} removed.")
            # Stop and disable the service
            subprocess.run(['systemctl', 'stop', 'network_manager.service'], check=True)
            logger.info("Network Manager service stopped.")
            subprocess.run(['systemctl', 'disable', 'network_manager.service'], check=True)
            logger.info("Network Manager service disabled.")
            flash('Network Manager service disabled.', 'success')
    except subprocess.CalledProcessError as e:
        logger.error(f"Service toggle failed: {e.stderr}")
        flash('Failed to toggle Network Manager service.', 'danger')

def get_logs():
    """Get the contents of the network log file."""
    logger.debug("Fetching network logs.")
    try:
        log_file = '/nsatt/storage/logs/networking/set_ip_address.log'
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                # Read last 1000 lines to avoid overwhelming the browser
                lines = f.readlines()[-1000:]
                return ''.join(lines)
        else:
            logger.warning(f"Log file not found at {log_file}")
            return "No logs available - log file not found"
    except Exception as e:
        logger.error(f"Error reading log file: {e}")
        return f"Error reading logs: {str(e)}"

@app.route('/get_logs')
def get_logs_route():
    """API endpoint to fetch logs."""
    return jsonify({'logs': get_logs()})


def remove_connection_sharing(target_iface):
    logger.debug(f"Removing shared connection from {target_iface}.")
    try:
        # Disable IP forwarding
        subprocess.run(['sysctl', '-w', 'net.ipv4.ip_forward=0'], check=True)
        logger.info("IP forwarding disabled.")

        # Remove iptables rules
        subprocess.run(['iptables', '-t', 'nat', '-D', 'POSTROUTING', '-o', target_iface, '-j', 'MASQUERADE'], check=True)
        logger.info(f"Removed NAT on interface {target_iface}.")

        # Remove forward rules
        subprocess.run(['iptables', '-D', 'FORWARD', '-i', target_iface, '-j', 'ACCEPT'], check=True)
        subprocess.run(['iptables', '-D', 'FORWARD', '-o', target_iface, '-m', 'state', '--state', 'RELATED,ESTABLISHED', '-j', 'ACCEPT'], check=True)
        logger.info(f"Removed FORWARD rules for interface {target_iface}.")

        # Save iptables rules
        with open('/etc/iptables.rules', 'w') as f:
            subprocess.run(['iptables-save'], stdout=f, check=True)
        logger.info("Updated iptables rules saved.")

        # Log the action
        log = NetworkLog(
            timestamp=datetime.utcnow(),
            interface=target_iface,
            event='Remove Connection Share',
            details=f"Removed connection sharing from {target_iface}"
        )
        db.session.add(log)
        db.session.commit()
        logger.info("Connection share removal logged in database.")

        # Send notification
        smtp_config = load_smtp_config()
        send_email_via_python(smtp_config, "Network Manager Info: Connection Share Removed",
                            f"Removed connection sharing from {target_iface}.")
        logger.info("Email notification sent for connection share removal.")

    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to remove connection sharing: {e.stderr}")
        flash('Failed to remove connection sharing.', 'danger')
    except Exception as e:
        logger.exception(f"Unexpected error removing connection sharing: {e}")
        flash('An unexpected error occurred while removing connection sharing.', 'danger')

def share_connection(source_iface, target_iface):
    logger.debug(f"Sharing connection from {source_iface} to {target_iface}.")
    try:
        # Check if target interface is already being shared to
        iptables_check = subprocess.run(
            ['iptables', '-t', 'nat', '-L', 'POSTROUTING', '-v', '-n'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        
        if target_iface in iptables_check.stdout:
            logger.error(f"Interface {target_iface} is already a target for connection sharing")
            flash(f'Interface {target_iface} is already being shared to by another interface.', 'danger')
            return False

        # Enable IP forwarding
        subprocess.run(['sysctl', '-w', 'net.ipv4.ip_forward=1'], check=True)
        logger.info("IP forwarding enabled.")

        # Configure iptables for NAT
        subprocess.run(['iptables', '-t', 'nat', '-A', 'POSTROUTING', '-o', source_iface, '-j', 'MASQUERADE'], check=True)
        logger.info(f"Configured NAT on interface {source_iface}.")
        subprocess.run(['iptables', '-A', 'FORWARD', '-i', target_iface, '-o', source_iface, '-j', 'ACCEPT'], check=True)
        logger.info(f"Configured FORWARD rule from {target_iface} to {source_iface}.")
        subprocess.run(['iptables', '-A', 'FORWARD', '-i', source_iface, '-o', target_iface, '-m', 'state', '--state', 'RELATED,ESTABLISHED', '-j', 'ACCEPT'], check=True)
        logger.info(f"Configured RELATED,ESTABLISHED FORWARD rule from {source_iface} to {target_iface}.")

        # Persist iptables rules
        with open('/etc/iptables.rules', 'w') as f:
            subprocess.run(['iptables-save'], stdout=f, check=True)
            logger.info("iptables rules saved to /etc/iptables.rules.")

        # Enable iptables-persistent
        subprocess.run(['apt-get', 'install', '-y', 'iptables-persistent'], check=True)
        logger.info("iptables-persistent installed.")
        subprocess.run(['systemctl', 'enable', 'netfilter-persistent'], check=True)
        logger.info("netfilter-persistent service enabled.")
        subprocess.run(['systemctl', 'start', 'netfilter-persistent'], check=True)
        logger.info("netfilter-persistent service started.")

        # Log the action in the database
        log = NetworkLog(
            timestamp=datetime.utcnow(),
            interface=source_iface,
            event='Share Connection',
            details=f"Shared connection from {source_iface} to {target_iface}"
        )
        db.session.add(log)
        db.session.commit()
        logger.info("Connection sharing event logged in the database.")

        # Send email notification
        smtp_config = load_smtp_config()
        send_email_via_python(smtp_config, "Network Manager Info: Connection Shared",
                              f"Shared connection from {source_iface} to {target_iface}.")
        logger.info("Email notification sent for connection sharing.")
        return True

    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to share connection: {e.stderr}")
        flash('Failed to share the connection.', 'danger')
        return False
    except Exception as e:
        logger.exception(f"Unexpected error in share_connection: {e}")
        flash('An unexpected error occurred while sharing the connection.', 'danger')
        return False

def send_email_via_python(smtp_config, subject, body):
    logger.debug(f"Preparing to send email: {subject}")
    if not all([smtp_config.get('smtp_server'), smtp_config.get('smtp_port'), smtp_config.get('recipient_email')]):
        logger.warning('Incomplete SMTP configuration. Cannot send email.')
        flash('Incomplete SMTP configuration. Cannot send email.', 'warning')
        return

    smtp_password_encrypted = smtp_config.get('smtp_password_encrypted', '')
    if not smtp_password_encrypted:
        logger.warning('SMTP password is not set. Cannot send email.')
        flash('SMTP password is not set. Cannot send email.', 'warning')
        return

    smtp_password = decrypt_password(smtp_password_encrypted)
    if not smtp_password:
        # Error already flashed in decrypt_password
        logger.error('SMTP password decryption failed. Email not sent.')
        return

    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = smtp_config.get('smtp_user')
    msg['To'] = smtp_config.get('recipient_email')

    try:
        with smtplib.SMTP(smtp_config.get('smtp_server'), smtp_config.get('smtp_port')) as server:
            server.starttls()
            logger.info("Started TLS for SMTP connection.")
            if smtp_config.get('smtp_user') and smtp_password:
                server.login(smtp_config.get('smtp_user'), smtp_password)
                logger.info("Logged in to SMTP server.")
            server.sendmail(smtp_config.get('smtp_user'), [smtp_config.get('recipient_email')], msg.as_string())
            logger.info(f"Email sent to {smtp_config.get('recipient_email')}: {subject}")
        flash('Email notification sent successfully.', 'success')
    except Exception as e:
        logger.exception(f"Failed to send email: {e}")
        flash(f'Failed to send email notification: {e}', 'danger')

# ---------------------------- Routes ----------------------------

@app.route('/')
def index():
    logger.debug("Accessed index route.")
    smtp_config = load_smtp_config()
    logs = NetworkLog.query.order_by(NetworkLog.timestamp.desc()).limit(100).all()
    interfaces = get_all_network_interfaces()
    interface_info = []
    for iface in interfaces:
        ip = get_interface_status(iface)
        interface_info.append({'name': iface, 'ip': ip if ip else 'No IP'})
    logger.info("Rendered index page.")
    return render_template('index.html', smtp_config=smtp_config, logs=logs, interfaces=interface_info)

@app.route('/update_smtp', methods=['POST'])
def update_smtp():
    logger.debug("Accessed update_smtp route.")
    smtp_server = request.form.get('smtp_server')
    smtp_port = request.form.get('smtp_port')
    smtp_user = request.form.get('smtp_user')
    smtp_password = request.form.get('smtp_password')
    recipient_email = request.form.get('recipient_email')

    logger.info("Received SMTP update request.")

    if not all([smtp_server, smtp_port, recipient_email]):
        logger.warning("SMTP Server, Port, or Recipient Email missing in the request.")
        flash('SMTP Server, Port, and Recipient Email are required.', 'warning')
        return redirect(url_for('index'))

    encrypted_password = encrypt_password(smtp_password) if smtp_password else ""
    if smtp_password and not encrypted_password:
        logger.error("Failed to encrypt SMTP password.")
        flash('Failed to encrypt SMTP password. Please try again.', 'danger')
        return redirect(url_for('index'))

    config = {
        "smtp_server": smtp_server,
        "smtp_port": int(smtp_port),
        "smtp_user": smtp_user,
        "smtp_password_encrypted": encrypted_password,
        "recipient_email": recipient_email
    }

    try:
        with open(SMTP_CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=4)
        logger.info("SMTP settings updated successfully and written to configuration file.")
        flash('SMTP settings updated successfully.', 'success')

        # Log the update in the database
        log = NetworkLog(
            timestamp=datetime.utcnow(),
            interface='N/A',
            event='SMTP Update',
            details='SMTP settings updated via web interface.'
        )
        db.session.add(log)
        db.session.commit()
        logger.info("SMTP update event logged in the database.")

        # Send email notification
        send_email_via_python(config, "Network Manager Info: SMTP Settings Updated",
                              "SMTP settings have been updated successfully via the web interface.")
        logger.info("Email notification sent for SMTP settings update.")

    except Exception as e:
        logger.exception(f"Failed to update SMTP settings: {e}")
        flash('Failed to update SMTP settings.', 'danger')

    return redirect(url_for('index'))

@app.route('/logs', methods=['GET'])
def view_logs():
    logger.debug("Accessed view_logs route.")
    logs = NetworkLog.query.order_by(NetworkLog.timestamp.desc()).all()
    logger.info("Rendered logs page.")
    return render_template('logs.html', logs=logs)

@app.route('/delete_logs', methods=['POST'])
def delete_logs():
    logger.debug("Accessed delete_logs route.")
    log_ids = request.form.getlist('log_ids')
    logger.info(f"Received request to delete logs: {log_ids}")
    if log_ids:
        try:
            NetworkLog.query.filter(NetworkLog.id.in_(log_ids)).delete(synchronize_session=False)
            db.session.commit()
            logger.info(f"Deleted logs with IDs: {log_ids}")
            flash('Selected logs have been deleted.', 'success')
        except Exception as e:
            logger.exception(f"Failed to delete logs: {e}")
            flash('Failed to delete selected logs.', 'danger')
    else:
        logger.warning("No logs selected for deletion.")
        flash('No logs selected for deletion.', 'warning')
    return redirect(url_for('view_logs'))

@app.route('/download_logs')
def download_logs():
    logger.debug("Accessed download_logs route.")
    filepath = LOG_FILE_PATH
    if os.path.exists(filepath):
        try:
            logger.info(f"Sending log file for download: {filepath}")
            return send_file(filepath, as_attachment=True)
        except Exception as e:
            logger.exception(f"Failed to send log file: {e}")
            flash('Failed to download log file.', 'danger')
            return redirect(url_for('view_logs'))
    else:
        logger.warning("Log file does not exist.")
        flash('Log file does not exist.', 'warning')
        return redirect(url_for('view_logs'))

@app.route('/merge_logs', methods=['POST'])
def merge_logs():
    logger.debug("Accessed merge_logs route.")
    # Implement merge functionality as needed
    flash('Merge functionality not yet implemented.', 'info')
    logger.info("Merge functionality accessed but not implemented.")
    return redirect(url_for('view_logs'))

@app.route('/manual_connect', methods=['GET', 'POST'])
def manual_connect():
    logger.debug("Accessed manual_connect route.")
    fallback_mode = os.path.exists(AUTOSTART_FILE)
    logger.info(f"Fallback mode is {'enabled' if fallback_mode else 'disabled'}.")
    if not fallback_mode:
        logger.warning("Manual connection attempted without enabling fallback mode.")
        flash('Manual connection is disabled. Enable fallback mode first.', 'warning')
        return redirect(url_for('index'))

    if request.method == 'POST':
        logger.info("Received manual connect form submission.")
        selected_iface = request.form.get('interface')
        ssid = request.form.get('ssid')
        password = request.form.get('password')

        if selected_iface and ssid and password:
            logger.info(f"Attempting to connect to SSID '{ssid}' on interface '{selected_iface}'.")
            try:
                # Configure wpa_supplicant for the selected interface
                config = f"""
network={{
    ssid="{ssid}"
    psk="{password}"
}}
"""
                config_file = f"/etc/wpa_supplicant/wpa_supplicant_{selected_iface}.conf"
                with open(config_file, 'w') as f:
                    f.write(config)
                logger.info(f"wpa_supplicant configuration written to {config_file}.")

                # Connect to the network
                subprocess.run(['wpa_supplicant', '-B', '-i', selected_iface, '-c', config_file], check=True)
                logger.info(f"wpa_supplicant started for interface {selected_iface}.")
                subprocess.run(['dhclient', selected_iface], check=True)
                logger.info(f"dhclient executed on interface {selected_iface}.")

                # Log the connection in the database
                log = NetworkLog(
                    timestamp=datetime.utcnow(),
                    interface=selected_iface,
                    event='Manual Connect',
                    details=f"Connected to {ssid} on {selected_iface}."
                )
                db.session.add(log)
                db.session.commit()
                logger.info(f"Manual connection event logged in the database for SSID '{ssid}' on '{selected_iface}'.")

                # Send email notification
                smtp_config = load_smtp_config()
                send_email_via_python(smtp_config, "Network Manager Info: Manual Connection",
                                      f"Connected to {ssid} on {selected_iface}.")
                logger.info(f"Email notification sent for manual connection to SSID '{ssid}' on '{selected_iface}'.")

                flash(f'Connected to {ssid} on {selected_iface}.', 'success')
                return redirect(url_for('index'))
            except subprocess.CalledProcessError as e:
                logger.error(f"Failed to connect to network: {e.stderr}")
                flash('Failed to connect to the network. Please check the details and try again.', 'danger')
            except Exception as e:
                logger.exception(f"Unexpected error during manual connect: {e}")
                flash('An unexpected error occurred while connecting to the network.', 'danger')
        else:
            logger.warning("Incomplete manual connect form submission.")
            flash('All fields are required.', 'warning')

    interfaces = get_all_network_interfaces()
    logger.info("Rendered manual_connect page.")
    return render_template('manual_connect.html', interfaces=interfaces)

@app.route('/toggle_service', methods=['POST'])
def toggle_service_route():
    logger.debug("Accessed toggle_service route.")
    action = request.form.get('action')
    logger.info(f"Received request to toggle service: {action}")
    if action == 'enable':
        toggle_service(enable=True)
    elif action == 'disable':
        toggle_service(enable=False)
    else:
        logger.warning(f"Invalid action received: {action}")
        flash('Invalid action.', 'danger')
    return redirect(url_for('index'))

@app.route('/share_connection', methods=['POST'])
def share_connection_route():
    logger.debug("Accessed share_connection route.")
    source_iface = request.form.get('source_iface')
    target_iface = request.form.get('target_iface')
    logger.info(f"Received request to share connection from {source_iface} to {target_iface}")
    if source_iface and target_iface:
        share_connection(source_iface, target_iface)
        flash(f'Connection shared from {source_iface} to {target_iface}', 'success')
    else:
        logger.warning("Both source and target interfaces are required to share connection.")
        flash('Both source and target interfaces are required.', 'warning')
    return redirect(url_for('index'))

@app.route('/remove_shared_connection', methods=['POST'])
def remove_shared_connection_route():
    logger.debug("Accessed remove_shared_connection route.")
    target_iface = request.form.get('target_iface')
    logger.info(f"Received request to remove shared connection from {target_iface}")
    if target_iface:
        remove_connection_sharing(target_iface)
        flash(f'Removed shared connection from {target_iface}', 'success')
    else:
        logger.warning("Target interface is required to remove shared connection.")
        flash('Target interface is required.', 'warning')
    return redirect(url_for('index'))

@app.route('/show_share_connection', methods=['GET'])
def show_share_connection_route():
    logger.debug("Accessed show_share_connection route.")
    interfaces = get_all_network_interfaces()
    logger.info("Rendered share_connection page.")
    return render_template('share_connection.html', interfaces=interfaces)

# ---------------------------- Run the App ----------------------------

if __name__ == '__main__':
    logger.info("Starting Flask application.")
    # It's recommended to run Flask with a production-ready server like Gunicorn
    # and behind a reverse proxy like Nginx for better performance and security.
    app.run(host='0.0.0.0', port=8079, debug=False)
