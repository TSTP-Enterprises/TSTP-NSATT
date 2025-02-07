#!/usr/bin/env python3
import logging
from pathlib import Path
from datetime import datetime
import subprocess
import re
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QLabel, QFrame)
from PyQt5.QtCore import Qt, QThread, pyqtSignal

plugin_image_value = "/nsatt/storage/images/icons/service_manager_icon.png"

class ServiceManagerThread(QThread):
    services_refreshed = pyqtSignal(list)
    error_occurred = pyqtSignal(str)

    def run(self):
        try:
            services = subprocess.check_output(['systemctl', 'list-units', '--type=service', '--no-pager', '--no-legend'], 
                                               universal_newlines=True).splitlines()
            self.services_refreshed.emit(services)
        except Exception as e:
            self.error_occurred.emit(str(e))

class Plugin:
    NAME = "Service Manager"
    CATEGORY = "Services"
    DESCRIPTION = "Manage system services"

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        
        # Setup logging
        log_dir = Path("/nsatt/logs/services/manager")
        if not log_dir.exists():
            log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"service_manager_{timestamp}.log"

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            layout = QVBoxLayout()
            layout.setContentsMargins(0, 0, 0, 0)
            layout.setSpacing(0)

            # Refresh button at top
            refresh_btn = QPushButton("Refresh Services")
            refresh_btn.clicked.connect(self.refresh_services)
            layout.addWidget(refresh_btn)

            # Container for services
            self.services_widget = QWidget()
            self.services_layout = QVBoxLayout()
            self.services_layout.setSpacing(5)
            self.services_layout.setContentsMargins(0, 0, 0, 0)
            self.services_widget.setLayout(self.services_layout)
            
            layout.addWidget(self.services_widget)
            layout.addStretch()

            self.widget.setLayout(layout)
            
            # Initial service load
            self.refresh_services()

        return self.widget

    def refresh_services(self):
        # Clear existing services
        for i in reversed(range(self.services_layout.count())): 
            self.services_layout.itemAt(i).widget().setParent(None)

        self.thread = ServiceManagerThread()
        self.thread.services_refreshed.connect(self.update_services)
        self.thread.error_occurred.connect(self.handle_error)
        self.thread.start()

    def update_services(self, services):
        for service in services:
            if service.strip():
                # Parse service info
                parts = service.split()
                if len(parts) >= 4:
                    service_name = parts[0]
                    service_status = parts[3]

                    # Create service row
                    row = QWidget()
                    row_layout = QHBoxLayout()
                    row_layout.setContentsMargins(5, 2, 5, 2)

                    # Service name label
                    name_label = QLabel(service_name)
                    name_label.setFixedWidth(240)
                    row_layout.addWidget(name_label)

                    # Start/Stop button
                    start_stop_btn = QPushButton()
                    start_stop_btn.setFixedWidth(80)
                    if service_status == "running":
                        start_stop_btn.setText("Stop")
                        start_stop_btn.setStyleSheet("background-color: #28a745;")
                    else:
                        start_stop_btn.setText("Start") 
                        start_stop_btn.setStyleSheet("background-color: #dc3545;")
                    start_stop_btn.clicked.connect(lambda checked, s=service_name: self.toggle_service(s))
                    row_layout.addWidget(start_stop_btn)

                    # Enable/Disable button
                    enable_btn = QPushButton()
                    enable_btn.setFixedWidth(80)
                    try:
                        result = subprocess.run(['systemctl', 'is-enabled', service_name],
                                              capture_output=True, text=True)
                        if result.stdout.strip() == 'enabled':
                            enable_btn.setText("Disable")
                            enable_btn.setStyleSheet("background-color: #28a745;")
                        else:
                            enable_btn.setText("Enable")
                            enable_btn.setStyleSheet("background-color: #dc3545;")
                    except:
                        enable_btn.setText("Enable")
                        enable_btn.setStyleSheet("background-color: #dc3545;")
                    enable_btn.clicked.connect(lambda checked, s=service_name: self.toggle_enable(s))
                    row_layout.addWidget(enable_btn)

                    row_layout.addStretch()
                    row.setLayout(row_layout)
                    self.services_layout.addWidget(row)

    def handle_error(self, error_message):
        self.logger.error(f"Error refreshing services: {error_message}")

    def toggle_service(self, service_name):
        try:
            result = subprocess.run(['systemctl', 'is-active', service_name],
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'active':
                subprocess.run(['systemctl', 'stop', service_name], check=True)
            else:
                subprocess.run(['systemctl', 'start', service_name], check=True)
            self.refresh_services()
        except Exception as e:
            self.logger.error(f"Error toggling service {service_name}: {str(e)}")

    def toggle_enable(self, service_name):
        try:
            result = subprocess.run(['systemctl', 'is-enabled', service_name],
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'enabled':
                subprocess.run(['systemctl', 'disable', service_name], check=True)
            else:
                subprocess.run(['systemctl', 'enable', service_name], check=True)
            self.refresh_services()
        except Exception as e:
            self.logger.error(f"Error toggling enable for {service_name}: {str(e)}")
