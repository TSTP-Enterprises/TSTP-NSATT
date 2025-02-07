#!/usr/bin/env python3
import logging
from pathlib import Path
from datetime import datetime
import subprocess
import re
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QLabel, QLineEdit, QCheckBox, QSpinBox,
                            QGroupBox, QFormLayout, QFileDialog)
from PyQt5.QtCore import Qt

plugin_image_value = "/nsatt/storage/images/icons/ftp_manager_icon.png"

class Plugin:
    NAME = "FTP Manager"
    CATEGORY = "Services" 
    DESCRIPTION = "Manage VSFTPD FTP server"

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        self.advanced_widget = None
        self.show_advanced = False
        
        # Setup logging
        log_dir = Path("/nsatt/logs/services/ftp")
        if not log_dir.exists():
            log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"ftp_service_{timestamp}.log"

        # Config defaults
        self.config = {
            'anonymous_enable': False,
            'local_enable': True,
            'chroot_local_user': True,
            'local_root': '/srv/ftp',
            'write_enable': True,
            'local_umask': '022',
            'ssl_enable': True,
            'pasv_min_port': 30000,
            'pasv_max_port': 31000,
            'max_clients': 50,
            'max_per_ip': 10,
            'xferlog_enable': True,
            'xferlog_file': '/var/log/vsftpd.log'
        }

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
            
            # Authentication settings
            auth_group = QGroupBox("Authentication")
            auth_layout = QVBoxLayout()
            
            self.anon_enable = QCheckBox("Allow Anonymous Login")
            self.anon_enable.setChecked(self.config['anonymous_enable'])
            auth_layout.addWidget(self.anon_enable)
            
            self.local_enable = QCheckBox("Allow Local Users")
            self.local_enable.setChecked(self.config['local_enable'])
            auth_layout.addWidget(self.local_enable)
            
            self.chroot_enable = QCheckBox("Enable Chroot Jail")
            self.chroot_enable.setChecked(self.config['chroot_local_user'])
            auth_layout.addWidget(self.chroot_enable)
            
            auth_group.setLayout(auth_layout)
            advanced_layout.addRow(auth_group)
            
            # Directory settings
            dir_group = QGroupBox("Directory Settings")
            dir_layout = QHBoxLayout()
            
            self.root_dir = QLineEdit(self.config['local_root'])
            dir_layout.addWidget(self.root_dir)
            
            browse_btn = QPushButton("Browse")
            browse_btn.clicked.connect(self.browse_root_dir)
            dir_layout.addWidget(browse_btn)
            
            dir_group.setLayout(dir_layout)
            advanced_layout.addRow(dir_group)
            
            # Permissions
            perm_group = QGroupBox("Permissions")
            perm_layout = QVBoxLayout()
            
            self.write_enable = QCheckBox("Enable Write Access")
            self.write_enable.setChecked(self.config['write_enable'])
            perm_layout.addWidget(self.write_enable)
            
            umask_layout = QHBoxLayout()
            umask_layout.addWidget(QLabel("Umask:"))
            self.umask = QLineEdit(self.config['local_umask'])
            umask_layout.addWidget(self.umask)
            perm_layout.addLayout(umask_layout)
            
            perm_group.setLayout(perm_layout)
            advanced_layout.addRow(perm_group)
            
            # Security
            sec_group = QGroupBox("Security")
            sec_layout = QVBoxLayout()
            
            self.ssl_enable = QCheckBox("Enable SSL/TLS")
            self.ssl_enable.setChecked(self.config['ssl_enable'])
            sec_layout.addWidget(self.ssl_enable)
            
            sec_group.setLayout(sec_layout)
            advanced_layout.addRow(sec_group)
            
            # Passive Mode
            pasv_group = QGroupBox("Passive Mode Ports")
            pasv_layout = QHBoxLayout()
            
            pasv_layout.addWidget(QLabel("Min Port:"))
            self.pasv_min = QSpinBox()
            self.pasv_min.setRange(1024, 65535)
            self.pasv_min.setValue(self.config['pasv_min_port'])
            pasv_layout.addWidget(self.pasv_min)
            
            pasv_layout.addWidget(QLabel("Max Port:"))
            self.pasv_max = QSpinBox()
            self.pasv_max.setRange(1024, 65535)
            self.pasv_max.setValue(self.config['pasv_max_port'])
            pasv_layout.addWidget(self.pasv_max)
            
            pasv_group.setLayout(pasv_layout)
            advanced_layout.addRow(pasv_group)
            
            # Connection Limits
            conn_group = QGroupBox("Connection Limits")
            conn_layout = QHBoxLayout()
            
            conn_layout.addWidget(QLabel("Max Clients:"))
            self.max_clients = QSpinBox()
            self.max_clients.setRange(1, 1000)
            self.max_clients.setValue(self.config['max_clients'])
            conn_layout.addWidget(self.max_clients)
            
            conn_layout.addWidget(QLabel("Max Per IP:"))
            self.max_per_ip = QSpinBox()
            self.max_per_ip.setRange(1, 100)
            self.max_per_ip.setValue(self.config['max_per_ip'])
            conn_layout.addWidget(self.max_per_ip)
            
            conn_group.setLayout(conn_layout)
            advanced_layout.addRow(conn_group)
            
            # Logging
            log_group = QGroupBox("Logging")
            log_layout = QVBoxLayout()
            
            self.xferlog_enable = QCheckBox("Enable Transfer Logging")
            self.xferlog_enable.setChecked(self.config['xferlog_enable'])
            log_layout.addWidget(self.xferlog_enable)
            
            log_path_layout = QHBoxLayout()
            log_path_layout.addWidget(QLabel("Log File:"))
            self.log_path = QLineEdit(self.config['xferlog_file'])
            log_path_layout.addWidget(self.log_path)
            log_layout.addLayout(log_path_layout)
            
            log_group.setLayout(log_layout)
            advanced_layout.addRow(log_group)
            
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
                subprocess.run(['systemctl', 'start', 'vsftpd'])
                self.start_btn.setText("Stop Service")
            else:
                subprocess.run(['systemctl', 'stop', 'vsftpd'])
                self.start_btn.setText("Start Service")
        except Exception as e:
            self.logger.error(f"Error toggling service: {str(e)}")

    def toggle_enable(self):
        try:
            if self.enable_btn.text() == "Enable Service":
                subprocess.run(['systemctl', 'enable', 'vsftpd'])
                self.enable_btn.setText("Disable Service")
            else:
                subprocess.run(['systemctl', 'disable', 'vsftpd'])
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

    def browse_root_dir(self):
        dir_path = QFileDialog.getExistingDirectory(self.widget, "Select FTP Root Directory")
        if dir_path:
            self.root_dir.setText(dir_path)

    def check_service_status(self):
        try:
            result = subprocess.run(['systemctl', 'is-active', 'vsftpd'], 
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'active':
                self.start_btn.setText("Stop Service")
            else:
                self.start_btn.setText("Start Service")
                
            result = subprocess.run(['systemctl', 'is-enabled', 'vsftpd'],
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'enabled':
                self.enable_btn.setText("Disable Service")
            else:
                self.enable_btn.setText("Enable Service")
        except Exception as e:
            self.logger.error(f"Error checking service status: {str(e)}")
