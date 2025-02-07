#!/usr/bin/env python3
import logging
from pathlib import Path
from datetime import datetime
import subprocess
import re
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QLabel, QLineEdit, QCheckBox, QSpinBox,
                            QGroupBox, QFormLayout, QFileDialog, QMessageBox)
from PyQt5.QtCore import Qt

plugin_image_value = "/nsatt/storage/images/icons/http_manager_icon.png"

class Plugin:
    NAME = "HTTP Manager" 
    CATEGORY = "Services"
    DESCRIPTION = "Manage Apache2 HTTP server"

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        self.advanced_widget = None
        self.show_advanced = False
        
        # Setup logging
        log_dir = Path("/nsatt/logs/services/http")
        if not log_dir.exists():
            log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"http_service_{timestamp}.log"

        # Check if Apache2 is installed
        try:
            subprocess.run(['which', 'apache2'], check=True)
            self.apache_installed = True
        except subprocess.CalledProcessError:
            self.apache_installed = False

        # Get current config
        self.config = self.get_current_config()

    def get_current_config(self):
        config = {}
        try:
            with open('/etc/apache2/apache2.conf', 'r') as f:
                content = f.read()
                
                # Extract values using regex
                port_match = re.search(r'Listen\s+(\d+)', content)
                config['port'] = int(port_match.group(1)) if port_match else 80
                
                server_tokens = re.search(r'ServerTokens\s+(\w+)', content)
                config['server_tokens'] = server_tokens.group(1) if server_tokens else 'Full'
                
                server_signature = re.search(r'ServerSignature\s+(\w+)', content)
                config['server_signature'] = server_signature.group(1).lower() == 'on' if server_signature else True
                
                trace_enable = re.search(r'TraceEnable\s+(\w+)', content)
                config['trace_enable'] = trace_enable.group(1).lower() == 'on' if trace_enable else True
                
                timeout = re.search(r'Timeout\s+(\d+)', content)
                config['timeout'] = int(timeout.group(1)) if timeout else 300
                
                keep_alive = re.search(r'KeepAlive\s+(\w+)', content)
                config['keep_alive'] = keep_alive.group(1).lower() == 'on' if keep_alive else True
                
                max_keep_alive = re.search(r'MaxKeepAliveRequests\s+(\d+)', content)
                config['max_keep_alive'] = int(max_keep_alive.group(1)) if max_keep_alive else 100
                
                keep_alive_timeout = re.search(r'KeepAliveTimeout\s+(\d+)', content)
                config['keep_alive_timeout'] = int(keep_alive_timeout.group(1)) if keep_alive_timeout else 5
                
                server_root = re.search(r'DocumentRoot\s+"([^"]+)"', content)
                config['server_root'] = server_root.group(1) if server_root else '/var/www/html'
                
        except Exception as e:
            self.logger.error(f"Error reading Apache config: {str(e)}")
            # Return defaults if config read fails
            config = {
                'port': 80,
                'server_tokens': 'Full',
                'server_signature': True,
                'trace_enable': True,
                'timeout': 300,
                'keep_alive': True,
                'max_keep_alive': 100,
                'keep_alive_timeout': 5,
                'server_root': '/var/www/html'
            }
        return config

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            layout = QVBoxLayout()
            
            # Basic controls
            basic_group = QGroupBox("Basic Controls")
            basic_layout = QVBoxLayout()
            
            # Top row of buttons
            top_row = QHBoxLayout()
            
            self.start_btn = QPushButton("Start Service")
            self.start_btn.clicked.connect(self.toggle_service)
            top_row.addWidget(self.start_btn)
            
            self.enable_btn = QPushButton("Enable Service")
            self.enable_btn.clicked.connect(self.toggle_enable)
            top_row.addWidget(self.enable_btn)
            
            basic_layout.addLayout(top_row)
            
            # Bottom row of buttons
            bottom_row = QHBoxLayout()
            
            self.autostart_btn = QPushButton("Enable Autostart")
            self.autostart_btn.clicked.connect(self.toggle_autostart)
            bottom_row.addWidget(self.autostart_btn)
            
            self.advanced_btn = QPushButton("Show Advanced")
            self.advanced_btn.clicked.connect(self.toggle_advanced)
            bottom_row.addWidget(self.advanced_btn)
            
            basic_layout.addLayout(bottom_row)
            
            basic_group.setLayout(basic_layout)
            layout.addWidget(basic_group)
            
            # Advanced settings
            self.advanced_widget = QGroupBox("Advanced Settings")
            advanced_layout = QFormLayout()
            
            # Port settings
            port_group = QGroupBox("Network")
            port_layout = QHBoxLayout()
            
            port_layout.addWidget(QLabel("HTTP Port:"))
            self.port = QSpinBox()
            self.port.setRange(1, 65535)
            self.port.setValue(self.config['port'])
            port_layout.addWidget(self.port)
            
            port_group.setLayout(port_layout)
            advanced_layout.addRow(port_group)
            
            # Server settings
            server_group = QGroupBox("Server Settings")
            server_layout = QVBoxLayout()
            
            self.server_signature = QCheckBox("Server Signature")
            self.server_signature.setChecked(self.config['server_signature'])
            server_layout.addWidget(self.server_signature)
            
            self.trace_enable = QCheckBox("Enable TRACE Method")
            self.trace_enable.setChecked(self.config['trace_enable'])
            server_layout.addWidget(self.trace_enable)
            
            tokens_layout = QHBoxLayout()
            tokens_layout.addWidget(QLabel("Server Tokens:"))
            self.server_tokens = QLineEdit(self.config['server_tokens'])
            tokens_layout.addWidget(self.server_tokens)
            server_layout.addLayout(tokens_layout)
            
            server_group.setLayout(server_layout)
            advanced_layout.addRow(server_group)
            
            # Connection settings
            conn_group = QGroupBox("Connection Settings")
            conn_layout = QVBoxLayout()
            
            self.keep_alive = QCheckBox("Keep Alive")
            self.keep_alive.setChecked(self.config['keep_alive'])
            conn_layout.addWidget(self.keep_alive)
            
            timeout_layout = QHBoxLayout()
            timeout_layout.addWidget(QLabel("Timeout (seconds):"))
            self.timeout = QSpinBox()
            self.timeout.setRange(1, 3600)
            self.timeout.setValue(self.config['timeout'])
            timeout_layout.addWidget(self.timeout)
            conn_layout.addLayout(timeout_layout)
            
            keep_alive_layout = QHBoxLayout()
            keep_alive_layout.addWidget(QLabel("Keep Alive Timeout:"))
            self.keep_alive_timeout = QSpinBox()
            self.keep_alive_timeout.setRange(1, 300)
            self.keep_alive_timeout.setValue(self.config['keep_alive_timeout'])
            keep_alive_layout.addWidget(self.keep_alive_timeout)
            conn_layout.addLayout(keep_alive_layout)
            
            max_keep_alive_layout = QHBoxLayout()
            max_keep_alive_layout.addWidget(QLabel("Max Keep Alive Requests:"))
            self.max_keep_alive = QSpinBox()
            self.max_keep_alive.setRange(0, 1000)
            self.max_keep_alive.setValue(self.config['max_keep_alive'])
            max_keep_alive_layout.addWidget(self.max_keep_alive)
            conn_layout.addLayout(max_keep_alive_layout)
            
            conn_group.setLayout(conn_layout)
            advanced_layout.addRow(conn_group)
            
            # Document root settings
            root_group = QGroupBox("Document Root")
            root_layout = QHBoxLayout()
            
            self.server_root = QLineEdit(self.config['server_root'])
            root_layout.addWidget(self.server_root)
            
            browse_btn = QPushButton("Browse")
            browse_btn.clicked.connect(self.browse_root)
            root_layout.addWidget(browse_btn)
            
            root_group.setLayout(root_layout)
            advanced_layout.addRow(root_group)
            
            self.advanced_widget.setLayout(advanced_layout)
            self.advanced_widget.hide()
            layout.addWidget(self.advanced_widget)
            
            self.widget.setLayout(layout)
            
            # Initial state check
            self.check_service_status()
            
        return self.widget

    def toggle_service(self):
        try:
            if self.start_btn.text() == "Start Service":
                subprocess.run(['systemctl', 'start', 'apache2'], check=True)
                self.start_btn.setText("Stop Service")
            else:
                subprocess.run(['systemctl', 'stop', 'apache2'], check=True)
                self.start_btn.setText("Start Service")
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error toggling service: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Failed to toggle service: {str(e)}")
        except Exception as e:
            self.logger.error(f"Unexpected error toggling service: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Unexpected error: {str(e)}")

    def toggle_enable(self):
        try:
            if self.enable_btn.text() == "Enable Service":
                subprocess.run(['systemctl', 'enable', 'apache2'], check=True)
                self.enable_btn.setText("Disable Service")
            else:
                subprocess.run(['systemctl', 'disable', 'apache2'], check=True)
                self.enable_btn.setText("Enable Service")
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error toggling enable: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Failed to toggle enable: {str(e)}")
        except Exception as e:
            self.logger.error(f"Unexpected error toggling enable: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Unexpected error: {str(e)}")

    def toggle_autostart(self):
        try:
            if self.autostart_btn.text() == "Enable Autostart":
                # Enable autostart logic
                self.autostart_btn.setText("Disable Autostart")
            else:
                # Disable autostart logic
                self.autostart_btn.setText("Enable Autostart")
        except Exception as e:
            self.logger.error(f"Error toggling autostart: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Failed to toggle autostart: {str(e)}")

    def toggle_advanced(self):
        try:
            self.show_advanced = not self.show_advanced
            if self.show_advanced:
                self.advanced_widget.show()
                self.advanced_btn.setText("Hide Advanced")
            else:
                self.advanced_widget.hide()
                self.advanced_btn.setText("Show Advanced")
        except Exception as e:
            self.logger.error(f"Error toggling advanced settings: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Failed to toggle advanced settings: {str(e)}")

    def browse_root(self):
        try:
            dir_path = QFileDialog.getExistingDirectory(self.widget, "Select Document Root Directory")
            if dir_path:
                self.server_root.setText(dir_path)
        except Exception as e:
            self.logger.error(f"Error browsing for document root: {str(e)}")
            QMessageBox.critical(self.widget, "Error", f"Failed to browse directory: {str(e)}")

    def check_service_status(self):
        try:
            result = subprocess.run(['systemctl', 'is-active', 'apache2'], 
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'active':
                self.start_btn.setText("Stop Service")
            else:
                self.start_btn.setText("Start Service")
                
            result = subprocess.run(['systemctl', 'is-enabled', 'apache2'],
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'enabled':
                self.enable_btn.setText("Disable Service")
            else:
                self.enable_btn.setText("Enable Service")
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Error checking service status: {str(e)}")
        except Exception as e:
            self.logger.error(f"Unexpected error checking status: {str(e)}")
