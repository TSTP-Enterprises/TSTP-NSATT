import subprocess
import logging
from pathlib import Path
from datetime import datetime
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QPushButton, 
                            QMessageBox, QLabel)
from PyQt5.QtCore import Qt

plugin_image_value = "/nsatt/storage/images/icons/nsatt_settings_icon.png"

class Plugin:
    NAME = "NSATT Settings"
    CATEGORY = "Utility" 
    DESCRIPTION = "Control system settings and services"
    

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        self.web_server_running = False
        
        # Setup logging
        log_dir = Path("/nsatt/logs/utility/settings")
        log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"settings_{timestamp}.log"

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            layout = QVBoxLayout()
            layout.setContentsMargins(10, 10, 10, 10)
            layout.setSpacing(10)

            # Status Label
            self.status_label = QLabel("Web Server Status: Stopped")
            layout.addWidget(self.status_label)

            # Web Server Button
            self.web_server_btn = QPushButton("Start Web Server (Port 8081)")
            self.web_server_btn.clicked.connect(self.toggle_web_server)
            layout.addWidget(self.web_server_btn)

            # Restart Button
            restart_btn = QPushButton("Restart System")
            restart_btn.clicked.connect(self.restart_system)
            layout.addWidget(restart_btn)

            # Shutdown Button
            shutdown_btn = QPushButton("Shutdown System")
            shutdown_btn.clicked.connect(self.shutdown_system)
            layout.addWidget(shutdown_btn)

            self.widget.setLayout(layout)

        return self.widget

    def toggle_web_server(self):
        try:
            if not self.web_server_running:
                # Configure Apache to listen on port 8081
                apache_config = """
Listen 8081
<VirtualHost *:8081>
    DocumentRoot /nsatt/storage/www
    <Directory /nsatt/storage/www>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
"""
                # Write config to ports.conf
                with open('/etc/apache2/ports.conf', 'w') as f:
                    f.write(apache_config)
                
                # Start Apache web server
                subprocess.run(['sudo', 'chmod', '-R', '755', '/nsatt/storage/www'], check=True)
                subprocess.run(['sudo', 'chown', '-R', 'www-data:www-data', '/nsatt/storage/www'], check=True)
                subprocess.run(['sudo', 'systemctl', 'restart', 'apache2'], check=True)
                self.web_server_running = True
                self.web_server_btn.setText("Stop Web Server") 
                self.status_label.setText("Web Server Status: Running")
                self.logger.info("Web server started on port 8081")
            else:
                # Stop Apache web server
                subprocess.run(['sudo', 'systemctl', 'stop', 'apache2'], check=True)
                self.web_server_running = False
                self.web_server_btn.setText("Start Web Server")
                self.status_label.setText("Web Server Status: Stopped")
                self.logger.info("Web server stopped")
        except Exception as e:
            self.logger.error(f"Error toggling web server: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Failed to toggle web server: {str(e)}")

    def restart_system(self):
        reply = QMessageBox.question(
            self.widget,
            "Restart System",
            "Are you sure you want to restart the system?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            try:
                self.logger.info("System restart initiated")
                subprocess.run(['sudo', 'reboot'], check=True)
            except Exception as e:
                self.logger.error(f"Error restarting system: {str(e)}")
                QMessageBox.critical(self.widget, "Error", f"Failed to restart system: {str(e)}")

    def shutdown_system(self):
        reply = QMessageBox.question(
            self.widget,
            "Shutdown System",
            "Are you sure you want to shutdown the system?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            try:
                self.logger.info("System shutdown initiated")
                subprocess.run(['sudo', 'shutdown', '-h', 'now'], check=True)
            except Exception as e:
                self.logger.error(f"Error shutting down system: {str(e)}")
                QMessageBox.critical(self.widget, "Error", f"Failed to shutdown system: {str(e)}")