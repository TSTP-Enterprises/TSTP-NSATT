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

plugin_image_value = "/nsatt/storage/images/icons/ssh_manager_icon.png"

class Plugin:
    NAME = "SSH Manager"
    CATEGORY = "Services" 
    DESCRIPTION = "Manage OpenSSH server"

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        self.advanced_widget = None
        self.show_advanced = False
        
        # Setup logging
        log_dir = Path("/nsatt/logs/services/ssh")
        if not log_dir.exists():
            log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"ssh_service_{timestamp}.log"

        # Check if OpenSSH is installed
        try:
            subprocess.run(['which', 'sshd'], check=True)
            self.ssh_installed = True
        except subprocess.CalledProcessError:
            self.ssh_installed = False

        # Get current config
        self.config = self.get_current_config()

    def get_current_config(self):
        config = {}
        try:
            with open('/etc/ssh/sshd_config', 'r') as f:
                content = f.read()
                
                # Extract values using regex
                port_match = re.search(r'^Port\s+(\d+)', content, re.MULTILINE)
                config['port'] = int(port_match.group(1)) if port_match else 22
                
                permit_root = re.search(r'^PermitRootLogin\s+(\w+)', content, re.MULTILINE)
                config['permit_root_login'] = permit_root.group(1).lower() == 'yes' if permit_root else False
                
                pass_auth = re.search(r'^PasswordAuthentication\s+(\w+)', content, re.MULTILINE)
                config['password_auth'] = pass_auth.group(1).lower() == 'yes' if pass_auth else True
                
                pubkey_auth = re.search(r'^PubkeyAuthentication\s+(\w+)', content, re.MULTILINE)
                config['pubkey_auth'] = pubkey_auth.group(1).lower() == 'yes' if pubkey_auth else True
                
                x11_fwd = re.search(r'^X11Forwarding\s+(\w+)', content, re.MULTILINE)
                config['x11_forwarding'] = x11_fwd.group(1).lower() == 'yes' if x11_fwd else False
                
                tcp_fwd = re.search(r'^AllowTcpForwarding\s+(\w+)', content, re.MULTILINE)
                config['tcp_forwarding'] = tcp_fwd.group(1).lower() == 'yes' if tcp_fwd else True
                
                max_auth = re.search(r'^MaxAuthTries\s+(\d+)', content, re.MULTILINE)
                config['max_auth_tries'] = int(max_auth.group(1)) if max_auth else 6
                
                max_sess = re.search(r'^MaxSessions\s+(\d+)', content, re.MULTILINE)
                config['max_sessions'] = int(max_sess.group(1)) if max_sess else 10
                
                log_level = re.search(r'^LogLevel\s+(\w+)', content, re.MULTILINE)
                config['log_level'] = log_level.group(1) if log_level else 'INFO'
                
                banner = re.search(r'^Banner\s+(.+)', content, re.MULTILINE)
                config['banner_path'] = banner.group(1) if banner else '/etc/ssh/banner'
                
                # Check SFTP subsystem
                sftp_match = re.search(r'^Subsystem\s+sftp', content, re.MULTILINE)
                config['sftp_enable'] = bool(sftp_match)
                
                # Look for SFTP chroot in sshd_config
                chroot_match = re.search(r'^ChrootDirectory\s+(.+)', content, re.MULTILINE)
                config['sftp_chroot'] = chroot_match.group(1) if chroot_match else '/srv/sftp'
                
        except Exception as e:
            self.logger.error(f"Error reading SSH config: {str(e)}")
            # Return empty config - UI will show defaults
            config = {
                'port': 22,
                'permit_root_login': False,
                'password_auth': True,
                'pubkey_auth': True,
                'x11_forwarding': False,
                'tcp_forwarding': True,
                'max_auth_tries': 6,
                'max_sessions': 10,
                'log_level': 'INFO',
                'banner_path': '/etc/ssh/banner',
                'sftp_enable': True,
                'sftp_chroot': '/srv/sftp'
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
            
            port_layout.addWidget(QLabel("SSH Port:"))
            self.port = QSpinBox()
            self.port.setRange(1, 65535)
            self.port.setValue(self.config['port'])
            port_layout.addWidget(self.port)
            
            port_group.setLayout(port_layout)
            advanced_layout.addRow(port_group)
            
            # Authentication settings
            auth_group = QGroupBox("Authentication")
            auth_layout = QVBoxLayout()
            
            self.root_login = QCheckBox("Allow Root Login")
            self.root_login.setChecked(self.config['permit_root_login'])
            auth_layout.addWidget(self.root_login)
            
            self.pass_auth = QCheckBox("Password Authentication")
            self.pass_auth.setChecked(self.config['password_auth'])
            auth_layout.addWidget(self.pass_auth)
            
            self.pubkey_auth = QCheckBox("Public Key Authentication")
            self.pubkey_auth.setChecked(self.config['pubkey_auth'])
            auth_layout.addWidget(self.pubkey_auth)
            
            auth_tries_layout = QHBoxLayout()
            auth_tries_layout.addWidget(QLabel("Max Auth Tries:"))
            self.max_auth = QSpinBox()
            self.max_auth.setRange(1, 20)
            self.max_auth.setValue(self.config['max_auth_tries'])
            auth_tries_layout.addWidget(self.max_auth)
            auth_layout.addLayout(auth_tries_layout)
            
            auth_group.setLayout(auth_layout)
            advanced_layout.addRow(auth_group)
            
            # Forwarding settings
            fwd_group = QGroupBox("Forwarding")
            fwd_layout = QVBoxLayout()
            
            self.x11_fwd = QCheckBox("X11 Forwarding")
            self.x11_fwd.setChecked(self.config['x11_forwarding'])
            fwd_layout.addWidget(self.x11_fwd)
            
            self.tcp_fwd = QCheckBox("TCP Forwarding")
            self.tcp_fwd.setChecked(self.config['tcp_forwarding'])
            fwd_layout.addWidget(self.tcp_fwd)
            
            fwd_group.setLayout(fwd_layout)
            advanced_layout.addRow(fwd_group)
            
            # SFTP settings
            sftp_group = QGroupBox("SFTP")
            sftp_layout = QVBoxLayout()
            
            self.sftp_enable = QCheckBox("Enable SFTP")
            self.sftp_enable.setChecked(self.config['sftp_enable'])
            sftp_layout.addWidget(self.sftp_enable)
            
            sftp_root_layout = QHBoxLayout()
            sftp_root_layout.addWidget(QLabel("SFTP Chroot:"))
            self.sftp_root = QLineEdit(self.config['sftp_chroot'])
            sftp_root_layout.addWidget(self.sftp_root)
            sftp_layout.addLayout(sftp_root_layout)
            
            sftp_group.setLayout(sftp_layout)
            advanced_layout.addRow(sftp_group)
            
            # Logging settings
            log_group = QGroupBox("Logging")
            log_layout = QHBoxLayout()
            
            log_layout.addWidget(QLabel("Log Level:"))
            self.log_level = QLineEdit(self.config['log_level'])
            log_layout.addWidget(self.log_level)
            
            log_group.setLayout(log_layout)
            advanced_layout.addRow(log_group)
            
            # Banner settings
            banner_group = QGroupBox("Banner")
            banner_layout = QHBoxLayout()
            
            self.banner_path = QLineEdit(self.config['banner_path'])
            banner_layout.addWidget(self.banner_path)
            
            browse_btn = QPushButton("Browse")
            browse_btn.clicked.connect(self.browse_banner)
            banner_layout.addWidget(browse_btn)
            
            banner_group.setLayout(banner_layout)
            advanced_layout.addRow(banner_group)
            
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
                subprocess.run(['systemctl', 'start', 'sshd'])
                self.start_btn.setText("Stop Service")
            else:
                subprocess.run(['systemctl', 'stop', 'sshd'])
                self.start_btn.setText("Start Service")
        except Exception as e:
            self.logger.error(f"Error toggling service: {str(e)}")

    def toggle_enable(self):
        try:
            if self.enable_btn.text() == "Enable Service":
                subprocess.run(['systemctl', 'enable', 'sshd'])
                self.enable_btn.setText("Disable Service")
            else:
                subprocess.run(['systemctl', 'disable', 'sshd'])
                self.enable_btn.setText("Enable Service")
        except Exception as e:
            self.logger.error(f"Error toggling enable: {str(e)}")

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

    def toggle_advanced(self):
        self.show_advanced = not self.show_advanced
        if self.show_advanced:
            self.advanced_widget.show()
            self.advanced_btn.setText("Hide Advanced")
        else:
            self.advanced_widget.hide()
            self.advanced_btn.setText("Show Advanced")

    def browse_banner(self):
        file_path = QFileDialog.getOpenFileName(self.widget, "Select SSH Banner File")[0]
        if file_path:
            self.banner_path.setText(file_path)

    def check_service_status(self):
        try:
            result = subprocess.run(['systemctl', 'is-active', 'sshd'], 
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'active':
                self.start_btn.setText("Stop Service")
            else:
                self.start_btn.setText("Start Service")
                
            result = subprocess.run(['systemctl', 'is-enabled', 'sshd'],
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'enabled':
                self.enable_btn.setText("Disable Service")
            else:
                self.enable_btn.setText("Enable Service")
        except Exception as e:
            self.logger.error(f"Error checking service status: {str(e)}")
