#!/usr/bin/env python3
import logging
import logging.handlers
from pathlib import Path
from datetime import datetime
import subprocess
import re
import time
import threading
import netifaces
import os
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QGridLayout, QPushButton,
                            QTextEdit, QGroupBox, QLabel, QLineEdit, QComboBox,
                            QCheckBox, QSpinBox, QMessageBox, QTableWidget,
                            QTableWidgetItem, QHeaderView)
from PyQt5.QtCore import Qt, QTimer
from PyQt5.QtGui import QFont

plugin_image_value = "/nsatt/storage/images/icons/hotspot_manager_icon.png"

class Plugin:
    NAME = "WiFi Hotspot"
    CATEGORY = "Networking" 
    DESCRIPTION = "Create and manage WiFi hotspots using hostapd and dnsmasq"

    def __init__(self):
        self.widget = None
        self.setup_logging()
        self.console = None
        self.hotspot_active = False
        self.advanced_visible = False
        self.console_visible = True
        self.connected_clients = {}
        self.client_update_timer = None
        
        # Default config
        self.config = {
            'interface': 'wlan0',
            'virtual_interface': 'wlan0_hotspot',
            'ssid': 'NSATT-Hotspot',
            'wpa_passphrase': 'nsattpass',
            'channel': 6,
            'hw_mode': 'g',
            'auth_algs': 1,
            'wpa': 2,
            'wpa_key_mgmt': 'WPA-PSK',
            'wpa_pairwise': 'TKIP CCMP',
            'rsn_pairwise': 'CCMP',
            'ignore_broadcast_ssid': 0,
            'country_code': 'US',
            'ip_range': '192.168.4.0/24',
            'dhcp_range': '192.168.4.2,192.168.4.254'
        }

    def setup_logging(self):
        """Setup rotating file logger"""
        log_dir = Path("/nsatt/logs/network/hotspot")
        log_dir.mkdir(parents=True, exist_ok=True)
        
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.DEBUG)
        
        handler = logging.handlers.TimedRotatingFileHandler(
            log_dir / "hotspot.log",
            when="midnight",
            interval=1,
            backupCount=30
        )
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            self.main_layout = QVBoxLayout()
            
            # Basic controls
            basic_group = QGroupBox("Hotspot Controls")
            basic_layout = QVBoxLayout()
            
            # Interface selection
            interface_layout = QGridLayout()
            interface_label = QLabel("Main Interface:")
            self.interface_combo = QComboBox()
            self.refresh_interfaces()
            refresh_btn = QPushButton("Refresh")
            refresh_btn.clicked.connect(self.refresh_interfaces)
            
            interface_layout.addWidget(interface_label, 0, 0)
            interface_layout.addWidget(self.interface_combo, 0, 1)
            interface_layout.addWidget(refresh_btn, 0, 2)
            basic_layout.addLayout(interface_layout)

            # SSID and password
            ssid_layout = QGridLayout()
            ssid_label = QLabel("SSID:")
            self.ssid_edit = QLineEdit(self.config['ssid'])
            pass_label = QLabel("Password:")
            self.pass_edit = QLineEdit(self.config['wpa_passphrase'])
            
            ssid_layout.addWidget(ssid_label, 0, 0)
            ssid_layout.addWidget(self.ssid_edit, 0, 1)
            ssid_layout.addWidget(pass_label, 1, 0)
            ssid_layout.addWidget(self.pass_edit, 1, 1)
            basic_layout.addLayout(ssid_layout)

            # Start/Stop button
            self.toggle_btn = QPushButton("Start Hotspot")
            self.toggle_btn.clicked.connect(self.toggle_hotspot)
            basic_layout.addWidget(self.toggle_btn)

            # Show/Hide Advanced button
            self.advanced_btn = QPushButton("Show Advanced Settings")
            self.advanced_btn.clicked.connect(self.toggle_advanced)
            basic_layout.addWidget(self.advanced_btn)

            basic_group.setLayout(basic_layout)
            self.main_layout.addWidget(basic_group)

            # Advanced settings
            self.advanced_group = QGroupBox("Advanced Settings")
            self.advanced_group.setVisible(False)
            advanced_layout = QGridLayout()

            # Channel
            channel_label = QLabel("Channel:")
            self.channel_spin = QSpinBox()
            self.channel_spin.setRange(1, 14)
            self.channel_spin.setValue(self.config['channel'])
            advanced_layout.addWidget(channel_label, 0, 0)
            advanced_layout.addWidget(self.channel_spin, 0, 1)

            # Mode
            mode_label = QLabel("Mode:")
            self.mode_combo = QComboBox()
            self.mode_combo.addItems(['g', 'n', 'ac'])
            self.mode_combo.setCurrentText(self.config['hw_mode'])
            advanced_layout.addWidget(mode_label, 1, 0)
            advanced_layout.addWidget(self.mode_combo, 1, 1)

            # IP Range
            ip_label = QLabel("IP Range:")
            self.ip_edit = QLineEdit(self.config['ip_range'])
            advanced_layout.addWidget(ip_label, 2, 0)
            advanced_layout.addWidget(self.ip_edit, 2, 1)

            # Hidden SSID
            hidden_label = QLabel("Hidden SSID:")
            self.hidden_check = QCheckBox()
            self.hidden_check.setChecked(bool(self.config['ignore_broadcast_ssid']))
            advanced_layout.addWidget(hidden_label, 3, 0)
            advanced_layout.addWidget(self.hidden_check, 3, 1)

            # Country code
            country_label = QLabel("Country Code:")
            self.country_edit = QLineEdit(self.config['country_code'])
            advanced_layout.addWidget(country_label, 4, 0)
            advanced_layout.addWidget(self.country_edit, 4, 1)

            # Connected Clients Table
            clients_label = QLabel("Connected Clients:")
            advanced_layout.addWidget(clients_label, 5, 0, 1, 2)
            
            self.clients_table = QTableWidget()
            self.clients_table.setColumnCount(3)
            self.clients_table.setHorizontalHeaderLabels(["MAC Address", "IP Address", "Hostname"])
            self.clients_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
            advanced_layout.addWidget(self.clients_table, 6, 0, 1, 2)

            self.advanced_group.setLayout(advanced_layout)
            self.main_layout.addWidget(self.advanced_group)

            # Console
            console_group = QGroupBox("Console Output")
            console_layout = QVBoxLayout()
            
            # Show/Hide Console button
            self.console_btn = QPushButton("Hide Console")
            self.console_btn.clicked.connect(self.toggle_console)
            console_layout.addWidget(self.console_btn)
            
            self.console = QTextEdit()
            self.console.setReadOnly(True)
            self.console.setFont(QFont("Monospace"))
            self.console.setMinimumHeight(200)
            console_layout.addWidget(self.console)
            
            console_group.setLayout(console_layout)
            self.main_layout.addWidget(console_group)
            
            self.widget.setLayout(self.main_layout)
            
            # Start client update timer
            self.client_update_timer = QTimer()
            self.client_update_timer.timeout.connect(self.update_connected_clients)
            self.client_update_timer.start(5000)  # Update every 5 seconds
            
        return self.widget

    def toggle_advanced(self):
        """Toggle visibility of advanced settings"""
        self.advanced_visible = not self.advanced_visible
        self.advanced_group.setVisible(self.advanced_visible)
        self.advanced_btn.setText("Hide Advanced Settings" if self.advanced_visible else "Show Advanced Settings")

    def toggle_console(self):
        """Toggle visibility of console output"""
        self.console_visible = not self.console_visible
        self.console.setVisible(self.console_visible)
        self.console_btn.setText("Show Console" if not self.console_visible else "Hide Console")

    def refresh_interfaces(self):
        """Refresh list of wireless interfaces"""
        try:
            self.interface_combo.clear()
            output = subprocess.check_output(["iwconfig"], stderr=subprocess.STDOUT, universal_newlines=True)
            interfaces = re.findall(r"(\w+)\s+IEEE", output)
            
            # Filter out interfaces in monitor mode
            valid_interfaces = []
            for interface in interfaces:
                mode = subprocess.check_output(["iwconfig", interface], stderr=subprocess.STDOUT, universal_newlines=True)
                if "Mode:Monitor" not in mode:
                    valid_interfaces.append(interface)
            
            self.interface_combo.addItems(valid_interfaces)
            
            # Set default to wlan0 if available
            default_idx = self.interface_combo.findText("wlan0")
            if default_idx >= 0:
                self.interface_combo.setCurrentIndex(default_idx)
                
        except Exception as e:
            self.log_error(f"Error refreshing interfaces: {str(e)}")

    def setup_interface(self):
        """Set interface to AP mode"""
        interface = self.interface_combo.currentText()
        
        try:
            # Bring interface down
            subprocess.run(["sudo", "ifconfig", interface, "down"], check=True)
            
            # Check current mode
            iwconfig_output = subprocess.check_output(["iwconfig", interface], universal_newlines=True)
            current_mode = re.search(r"Mode:(\w+)", iwconfig_output).group(1)
            
            # Get interface capabilities
            iw_info = subprocess.check_output(["iw", interface, "info"], universal_newlines=True)
            
            # Try to set interface to AP mode
            subprocess.run(["sudo", "iwconfig", interface, "mode", "managed"], check=True)
            
            # Configure IP address with netmask
            ip_addr = self.ip_edit.text()
            if '/' not in ip_addr:
                ip_addr += '/24'  # Add default netmask if not specified
            
            # Bring interface up
            subprocess.run(["sudo", "ifconfig", interface, ip_addr, "up"], check=True)
            
            return interface
            
        except Exception as e:
            self.log_error(f"Failed to setup interface: {str(e)}")
            raise

    def setup_dnsmasq(self, interface):
        """Configure and start dnsmasq for DHCP"""
        try:
            # Get interface IP and calculate DHCP range
            ip_parts = self.ip_edit.text().split('.')
            dhcp_start = f"{ip_parts[0]}.{ip_parts[1]}.{ip_parts[2]}.100"
            dhcp_end = f"{ip_parts[0]}.{ip_parts[1]}.{ip_parts[2]}.200"
            
            config = f"""
interface={interface}
bind-interfaces
dhcp-range={dhcp_start},{dhcp_end},12h
dhcp-option=3,{self.ip_edit.text().split('/')[0]}
dhcp-option=6,8.8.8.8,8.8.4.4
no-hosts
no-resolv
log-queries
log-dhcp
dhcp-authoritative
dhcp-leasefile=/tmp/dnsmasq.leases
"""
            with open("/tmp/dnsmasq.conf", 'w') as f:
                f.write(config)
                
            # Kill any existing dnsmasq and start new instance
            subprocess.run(["sudo", "pkill", "dnsmasq"], stderr=subprocess.DEVNULL)
            time.sleep(1)  # Wait for process to fully terminate
            subprocess.Popen(["sudo", "dnsmasq", "-C", "/tmp/dnsmasq.conf", "--no-daemon"])
            
        except Exception as e:
            self.log_error(f"Failed to setup DHCP: {str(e)}")
            raise

    def setup_forwarding(self):
        """Setup IP forwarding and NAT"""
        try:
            # Enable IP forwarding
            subprocess.run(["sudo", "sysctl", "-w", "net.ipv4.ip_forward=1"], check=True)
            
            # Clear existing rules
            subprocess.run(["sudo", "iptables", "-F"], check=True)
            subprocess.run(["sudo", "iptables", "-t", "nat", "-F"], check=True)
            
            # Get default interface with internet connection
            route = subprocess.check_output(["ip", "route", "show", "default"]).decode()
            internet_iface = route.split()[4]
            
            # Setup NAT
            hotspot_iface = self.interface_combo.currentText()
            subprocess.run(["sudo", "iptables", "-t", "nat", "-A", "POSTROUTING", "-o", internet_iface, "-j", "MASQUERADE"], check=True)
            subprocess.run(["sudo", "iptables", "-A", "FORWARD", "-i", hotspot_iface, "-o", internet_iface, "-j", "ACCEPT"], check=True)
            subprocess.run(["sudo", "iptables", "-A", "FORWARD", "-i", internet_iface, "-o", hotspot_iface, "-m", "state", "--state", "RELATED,ESTABLISHED", "-j", "ACCEPT"], check=True)
            
        except Exception as e:
            self.log_error(f"Failed to setup forwarding: {str(e)}")
            raise

    def update_connected_clients(self):
        """Update table of connected clients"""
        if not self.hotspot_active:
            return
            
        try:
            if os.path.exists("/tmp/dnsmasq.leases"):
                with open("/tmp/dnsmasq.leases") as f:
                    leases = f.readlines()
                    
                self.clients_table.setRowCount(len(leases))
                for i, lease in enumerate(leases):
                    timestamp, mac, ip, hostname, _ = lease.split()
                    self.clients_table.setItem(i, 0, QTableWidgetItem(mac))
                    self.clients_table.setItem(i, 1, QTableWidgetItem(ip))
                    self.clients_table.setItem(i, 2, QTableWidgetItem(hostname))
                    
        except Exception as e:
            self.log_error(f"Error updating client list: {str(e)}")

    def generate_hostapd_config(self):
        """Generate hostapd configuration file"""
        try:
            # Set default password if none provided
            if not self.pass_edit.text():
                self.pass_edit.setText("nsatt-admin")
                self.log_message("No password set, using default: nsatt-admin")

            config = {
                'interface': self.interface_combo.currentText(),
                'driver': 'nl80211',
                'ssid': self.ssid_edit.text(),
                'wpa_passphrase': self.pass_edit.text(),
                'channel': str(self.channel_spin.value()),
                'hw_mode': self.mode_combo.currentText(),
                'ignore_broadcast_ssid': str(int(self.hidden_check.isChecked())),
                'country_code': self.country_edit.text(),
                'auth_algs': '1',
                'wpa': '2',
                'wpa_key_mgmt': 'WPA-PSK',
                'rsn_pairwise': 'CCMP'
            }

            # Create polkit rule for hostapd
            polkit_rule = """polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "hostapd.service" &&
        subject.isInGroup("nsatt-admin")) {
        return polkit.Result.YES;
    }
});"""
            
            with open("/etc/polkit-1/rules.d/99-hostapd-nsatt.rules", 'w') as f:
                f.write(polkit_rule)
                
            subprocess.run(["sudo", "systemctl", "restart", "polkit"])

            with open("/tmp/hostapd.conf", 'w') as f:
                for key, value in config.items():
                    f.write(f"{key}={value}\n")

            return "/tmp/hostapd.conf"
        except Exception as e:
            self.log_error(f"Error generating config: {str(e)}")
            raise

    def toggle_hotspot(self):
        """Toggle hotspot on/off"""
        if not self.hotspot_active:
            try:
                interface = self.interface_combo.currentText()
                if not interface:
                    raise Exception("No interface selected")

                # Generate and start hostapd first
                config_file = self.generate_hostapd_config()
                subprocess.run(["sudo", "-u", "nsatt-admin", "systemctl", "start", "hostapd.service"])
                
                # Wait briefly to ensure hostapd starts
                time.sleep(2)
                
                # Check if hostapd is running
                result = subprocess.run(["systemctl", "is-active", "hostapd"], capture_output=True, text=True)
                if result.stdout.strip() != "active":
                    raise Exception("Failed to start hostapd")

                # Setup remaining components
                self.setup_interface()
                self.setup_dnsmasq(interface)
                self.setup_forwarding()
                
                self.hotspot_active = True
                self.toggle_btn.setText("Stop Hotspot")
                self.toggle_btn.setStyleSheet("background-color: #90EE90")
                self.log_message("Hotspot started successfully")

            except Exception as e:
                self.log_error(f"Failed to start hotspot: {str(e)}")
                QMessageBox.critical(self.widget, "Error", str(e))

        else:
            try:
                interface = self.interface_combo.currentText()
                
                # Stop services
                subprocess.run(["sudo", "-u", "nsatt-admin", "systemctl", "stop", "hostapd.service"])
                subprocess.run(["sudo", "pkill", "dnsmasq"])
                
                # Reset interface
                subprocess.run(["sudo", "ifconfig", interface, "down"])
                subprocess.run(["sudo", "ifconfig", interface, "up"])
                
                # Clear iptables
                subprocess.run(["sudo", "iptables", "-F"])
                subprocess.run(["sudo", "iptables", "-t", "nat", "-F"])
                
                # Disable IP forwarding
                subprocess.run(["sudo", "sysctl", "-w", "net.ipv4.ip_forward=0"])
                
                self.hotspot_active = False
                self.toggle_btn.setText("Start Hotspot")
                self.toggle_btn.setStyleSheet("")
                self.log_message("Hotspot stopped")

            except Exception as e:
                self.log_error(f"Failed to stop hotspot: {str(e)}")
                QMessageBox.critical(self.widget, "Error", str(e))

    def log_message(self, message):
        """Log informational message"""
        self.logger.info(message)
        if self.console:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            self.console.append(f"[{timestamp}] [INFO] {message}")

    def log_error(self, message):
        """Log error message"""
        self.logger.error(message)
        if self.console:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            self.console.append(f"[{timestamp}] [ERROR] {message}")

    def initialize(self):
        try:
            # Check for required packages
            for pkg in ["hostapd", "dnsmasq"]:
                if subprocess.run(["which", pkg], capture_output=True).returncode != 0:
                    raise Exception(f"{pkg} not found - please install {pkg} package")
            return True
        except Exception as e:
            self.log_error(f"Error in initialization: {str(e)}")
            return False

    def terminate(self):
        try:
            if self.hotspot_active:
                subprocess.run(["sudo", "pkill", "hostapd"])
                subprocess.run(["sudo", "pkill", "dnsmasq"])
                subprocess.run(["sudo", "iw", "dev", self.config['virtual_interface'], "del"])
                subprocess.run(["sudo", "iptables", "-F"])
                subprocess.run(["sudo", "iptables", "-t", "nat", "-F"])
            if self.client_update_timer:
                self.client_update_timer.stop()
        except Exception as e:
            self.log_error(f"Error in termination: {str(e)}")
