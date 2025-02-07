#!/usr/bin/env python3
import os
import subprocess
import sys
import logging
import netifaces
import re
import socket
import requests
import nmap
from pathlib import Path
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QTextEdit, QLabel, QProgressBar, QMessageBox, QSizePolicy)
from PyQt5.QtCore import QThread, pyqtSignal, Qt, QSize, QTimer
import shutil
from typing import Dict, Tuple

plugin_image_value = "/nsatt/storage/images/icons/link_checker_icon.png"

class NmapScannerThread(QThread):
    finished = pyqtSignal(str)
    
    def __init__(self, target_network):
        super().__init__()
        self.target_network = target_network
        
    def run(self):
        try:
            nm = nmap.PortScanner()
            result = nm.scan(hosts=self.target_network, arguments='-sn')
            
            output = []
            output.append("\n=== Network Scan Results ===")
            
            for host in result['scan']:
                if 'hostname' in result['scan'][host]:
                    hostname = result['scan'][host]['hostname']
                    output.append(f"Host: {host} ({hostname})")
                else:
                    output.append(f"Host: {host}")
                    
            self.finished.emit("\n".join(output))
        except Exception as e:
            self.finished.emit(f"Scan error: {str(e)}")

class PackageInstallerThread(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)
    
    def __init__(self, package_name, service_name):
        super().__init__()
        self.package_name = package_name
        self.service_name = service_name
        
    def run(self):
        try:
            self.progress.emit(f"Updating package lists...")
            subprocess.run(['sudo', 'apt-get', 'update'], check=True)
            
            self.progress.emit(f"Installing {self.package_name}...")
            
            # Special handling for systemd-resolved
            if self.service_name == 'resolved':
                subprocess.run(['sudo', 'apt-get', 'install', '-y', 'systemd'], check=True)
                
            result = subprocess.run(
                ['sudo', 'apt-get', 'install', '-y', self.package_name],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                self.finished.emit(True, "Installation successful")
            else:
                self.finished.emit(False, f"Installation failed: {result.stderr}")
                
        except Exception as e:
            self.finished.emit(False, str(e))

class Plugin:
    NAME = "Link Checker (eth0)"
    CATEGORY = "Network"
    DESCRIPTION = "Detailed network analysis for eth0 interface"
    REQUIRED_PACKAGES = {
        'network-manager': 'network-manager',
        'dhcpcd': 'dhcpcd',
        'resolved': 'systemd-resolved',
        'nmap': 'nmap',
        'ethtool': 'ethtool',
        'lldpd': 'lldpd'
    }

    SERVICE_COMMANDS = {
        'network-manager': {
            'start': ['sudo', 'systemctl', 'start', 'NetworkManager'],
            'stop': ['sudo', 'systemctl', 'stop', 'NetworkManager'],
            'status': ['sudo', 'systemctl', 'is-active', 'NetworkManager']
        },
        'dhcpcd': {
            'start': ['sudo', 'systemctl', 'start', 'dhcpcd'],
            'stop': ['sudo', 'systemctl', 'stop', 'dhcpcd'],
            'status': ['sudo', 'systemctl', 'is-active', 'dhcpcd']
        },
        'resolved': {
            'start': ['sudo', 'systemctl', 'start', 'systemd-resolved'],
            'stop': ['sudo', 'systemctl', 'stop', 'systemd-resolved'],
            'status': ['sudo', 'systemctl', 'is-active', 'systemd-resolved']
        }
    }

    def __init__(self):
        self.widget = None
        self.logger = None
        self.console = None
        self.scan_thread = None
        self.services_status: Dict[str, Tuple[bool, bool]] = {
            'network-manager': (False, False),  # (installed, active)
            'dhcpcd': (False, False),
            'resolved': (False, False)
        }
        self.installer_thread = None
        self.initial_refresh_done = False
        self.refresh_thread = None

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            
            # Set up logging
            logging.basicConfig(level=logging.INFO)
            self.logger = logging.getLogger(__name__)
            
            # Create layout
            layout = QVBoxLayout()
            self.widget.setLayout(layout)
            
            # Create grid layout for buttons
            button_grid = QVBoxLayout()
            
            # First row of buttons
            row1 = QHBoxLayout()
            self.nm_button = QPushButton("NetworkManager")
            self.dhcp_button = QPushButton("DHCP Client")
            row1.addWidget(self.nm_button)
            row1.addWidget(self.dhcp_button)
            button_grid.addLayout(row1)
            
            # Second row of buttons
            row2 = QHBoxLayout()
            self.dns_button = QPushButton("DNS Resolver")
            scan_button = QPushButton("Run Network Scan")
            row2.addWidget(self.dns_button)
            row2.addWidget(scan_button)
            button_grid.addLayout(row2)
            
            # Connect button signals
            self.nm_button.clicked.connect(lambda: self.toggle_service('network-manager'))
            self.dhcp_button.clicked.connect(lambda: self.toggle_service('dhcpcd'))
            self.dns_button.clicked.connect(lambda: self.toggle_service('resolved'))
            scan_button.clicked.connect(self.start_network_scan)
            
            # Progress bar
            self.progress = QProgressBar()
            self.progress.hide()
            button_grid.addWidget(self.progress)
            
            # Progress text label (add below progress bar)
            self.progress_label = QLabel("")
            self.progress_label.hide()
            button_grid.addWidget(self.progress_label)
            
            # Add port control buttons
            port_controls = QHBoxLayout()
            self.port_info_btn = QPushButton("Port Info")
            self.blink_led_btn = QPushButton("Blink Port LED")
            self.port_info_btn.clicked.connect(self.show_port_info)
            self.blink_led_btn.clicked.connect(self.toggle_port_led)
            port_controls.addWidget(self.port_info_btn)
            port_controls.addWidget(self.blink_led_btn)
            button_grid.addLayout(port_controls)
            
            # Add button grid to main layout
            layout.addLayout(button_grid)
            
            # Refresh button
            refresh_btn = QPushButton("Refresh Information")
            refresh_btn.clicked.connect(self.refresh)
            layout.addWidget(refresh_btn)
            
            # Console output
            self.console = QTextEdit()
            self.console.setReadOnly(True)
            self.console.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            self.console.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            self.console.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            self.console.setMinimumHeight(100)
            self.console.document().setDocumentMargin(10)
            
            # Make console auto-resize to fit content
            def updateConsoleHeight():
                doc_height = self.console.document().size().height()
                self.console.setFixedHeight(int(doc_height + 20))
                self.widget.adjustSize()
            
            self.console.textChanged.connect(updateConsoleHeight)
            layout.addWidget(self.console)
            
            # Schedule initial refresh
            QTimer.singleShot(100, self.initial_refresh)

        return self.widget

    def get_switch_info(self):
        try:
            # Get switch information using ethtool
            ethtool_output = subprocess.check_output(['ethtool', 'eth0'], 
                                                   stderr=subprocess.STDOUT).decode()
            
            # Parse speed, duplex, port info
            speed_match = re.search(r'Speed: (\d+\w+)', ethtool_output)
            duplex_match = re.search(r'Duplex: (\w+)', ethtool_output)
            port_match = re.search(r'Port: (\w+)', ethtool_output)
            
            info = []
            if speed_match:
                info.append(f"Link Speed: {speed_match.group(1)}")
            if duplex_match:
                info.append(f"Duplex Mode: {duplex_match.group(1)}")
            if port_match:
                info.append(f"Port Type: {port_match.group(1)}")
                
            # Get additional switch details if available
            try:
                lldp_output = subprocess.check_output(['lldpctl'], 
                                                    stderr=subprocess.STDOUT).decode()
                if 'Interface: eth0' in lldp_output:
                    switch_info = re.findall(r'SysName:.*?(\S+)', lldp_output)
                    if switch_info:
                        info.append(f"Connected Switch: {switch_info[0]}")
            except:
                pass
                
            return "\n".join(info)
        except:
            return "Unable to retrieve switch information"

    def get_dns_info(self):
        try:
            with open('/etc/resolv.conf', 'r') as f:
                resolv_conf = f.read()
            
            nameservers = re.findall(r'nameserver\s+(\S+)', resolv_conf)
            search_domains = re.findall(r'search\s+(\S+)', resolv_conf)
            
            info = []
            info.append("=== DNS Configuration ===")
            info.append("Nameservers:")
            for ns in nameservers:
                info.append(f"  - {ns}")
            
            if search_domains:
                info.append("Search Domains:")
                for domain in search_domains:
                    info.append(f"  - {domain}")
                    
            return "\n".join(info)
        except:
            return "Unable to retrieve DNS information"

    def get_modem_info(self):
        try:
            # Try to get modem information using mmcli if ModemManager is available
            modem_info = subprocess.check_output(['mmcli', '-L'], 
                                               stderr=subprocess.STDOUT).decode()
            if 'No modems were found' in modem_info:
                return "No modems detected"
                
            info = []
            info.append("=== Modem Information ===")
            
            # Get detailed info for each modem
            modem_paths = re.findall(r'/org/freedesktop/ModemManager\S+', modem_info)
            for path in modem_paths:
                modem_details = subprocess.check_output(['mmcli', '-m', path], 
                                                      stderr=subprocess.STDOUT).decode()
                
                manufacturer = re.search(r'manufacturer: (\S+)', modem_details)
                model = re.search(r'model: (\S+)', modem_details)
                
                if manufacturer:
                    info.append(f"Manufacturer: {manufacturer.group(1)}")
                if model:
                    info.append(f"Model: {model.group(1)}")
                    
            return "\n".join(info)
        except:
            return "Unable to retrieve modem information"

    def check_package_installed(self, package_name: str) -> bool:
        """Check if a package is installed"""
        try:
            return shutil.which(package_name) is not None
        except Exception as e:
            self.logger.error(f"Error checking {package_name} installation: {str(e)}")
            return False

    def install_package(self, package_name: str) -> bool:
        """Install a package using apt"""
        try:
            result = subprocess.run(
                ['sudo', 'apt-get', 'install', '-y', package_name],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            self.logger.error(f"Error installing {package_name}: {str(e)}")
            return False

    def check_service_status(self, service: str) -> Tuple[bool, bool]:
        """Check if service is installed and active with improved error handling"""
        try:
            installed = self.check_package_installed(self.REQUIRED_PACKAGES[service])
            active = False
            
            if installed:
                try:
                    result = subprocess.run(
                        self.SERVICE_COMMANDS[service]['status'],
                        capture_output=True,
                        text=True
                    )
                    active = result.returncode == 0
                    
                    if not active and result.returncode == 5:  # Special handling for NetworkManager
                        if service == 'network-manager':
                            # Try to fix common NetworkManager issues
                            subprocess.run(['sudo', 'systemctl', 'daemon-reload'])
                            subprocess.run(['sudo', 'systemctl', 'reset-failed', 'NetworkManager'])
                except Exception as e:
                    self.logger.error(f"Error checking {service} status: {str(e)}")
            
            return installed, active
        except Exception as e:
            self.logger.error(f"Error in check_service_status: {str(e)}")
            return False, False

    def toggle_service(self, service):
        """Toggle service status with improved error handling"""
        try:
            installed, active = self.services_status[service]
            
            if not installed:
                reply = QMessageBox.question(
                    self.widget,
                    "Install Package",
                    f"Install {service}?",
                    QMessageBox.Yes | QMessageBox.No
                )
                
                if reply == QMessageBox.Yes:
                    self.progress.show()
                    self.progress.setRange(0, 0)
                    self.progress_label.show()
                    self.progress_label.setText("Preparing installation...")
                    
                    self.installer_thread = PackageInstallerThread(
                        self.REQUIRED_PACKAGES[service],
                        service
                    )
                    self.installer_thread.progress.connect(self.update_progress_label)
                    self.installer_thread.finished.connect(
                        lambda success, msg: self.installation_completed(success, msg, service)
                    )
                    self.installer_thread.start()
                    return
            
            if installed:
                action = 'stop' if active else 'start'
                try:
                    result = subprocess.run(
                        self.SERVICE_COMMANDS[service][action],
                        capture_output=True,
                        text=True
                    )
                    
                    if result.returncode != 0:
                        error_msg = f"Service {action} failed: {result.stderr}"
                        self.logger.error(error_msg)
                        QMessageBox.critical(self.widget, "Error", error_msg)
                except Exception as e:
                    self.logger.error(f"Error toggling service: {str(e)}")
                    QMessageBox.critical(self.widget, "Error", str(e))
            
            self.update_service_buttons()
            self.refresh()
            
        except Exception as e:
            self.logger.error(f"Error in toggle_service: {str(e)}")
            QMessageBox.critical(self.widget, "Error", str(e))

    def update_service_buttons(self):
        """Update button colors based on service status"""
        try:
            for service, button in [('network-manager', self.nm_button),
                                  ('dhcpcd', self.dhcp_button),
                                  ('resolved', self.dns_button)]:
                installed, active = self.check_service_status(service)
                self.services_status[service] = (installed, active)
                
                if not installed:
                    button.setStyleSheet("background-color: #f44336;")  # Red
                    button.setText(service)
                elif not active:
                    button.setStyleSheet("background-color: #ffeb3b;")  # Yellow
                    button.setText(service)
                else:
                    button.setStyleSheet("background-color: #4CAF50;")  # Green
                    button.setText(service)
        except Exception as e:
            self.logger.error(f"Error updating service buttons: {str(e)}")

    def start_network_scan(self):
        try:
            addresses = netifaces.ifaddresses('eth0')
            if netifaces.AF_INET not in addresses:
                QMessageBox.warning(self.widget, "Error", "No IPv4 address assigned to eth0")
                return
                
            ip = addresses[netifaces.AF_INET][0]['addr']
            network = '.'.join(ip.split('.')[:-1]) + '.0/24'
            
            self.progress.show()
            self.progress.setRange(0, 0)  # Indeterminate progress
            
            self.scan_thread = NmapScannerThread(network)
            self.scan_thread.finished.connect(self.scan_completed)
            self.scan_thread.start()
            
        except Exception as e:
            QMessageBox.warning(self.widget, "Error", f"Failed to start scan: {str(e)}")

    def scan_completed(self, result):
        self.progress.hide()
        current_text = self.console.toPlainText()
        self.console.setText(current_text + "\n" + result)
        self.widget.updateGeometry()

    def refresh(self):
        """Refresh the display with network information"""
        try:
            self.progress.show()
            self.progress.setRange(0, 0)
            self.progress_label.show()
            self.progress_label.setText("Refreshing network information...")
            
            # Create and start refresh thread
            if self.refresh_thread and self.refresh_thread.isRunning():
                self.refresh_thread.terminate()
                self.refresh_thread.wait()
                
            self.refresh_thread = QThread()
            self.refresh_thread.run = self._refresh_worker
            self.refresh_thread.finished.connect(self._refresh_completed)
            self.refresh_thread.start()
            
        except Exception as e:
            self.logger.error(f"Error starting refresh: {str(e)}")
            self.console.setText(f"Error: {str(e)}")
            self.widget.updateGeometry()

    def _refresh_worker(self):
        """Worker function for refresh thread"""
        try:
            output = []
            
            # Basic interface info
            output.append("=== eth0 Interface Information ===")
            
            # Get link status
            with open('/sys/class/net/eth0/operstate', 'r') as f:
                status = f.read().strip()
            output.append(f"Link Status: {status}")
            
            if status == "up":
                # Get addresses
                addresses = netifaces.ifaddresses('eth0')
                
                if netifaces.AF_LINK in addresses:
                    output.append(f"MAC Address: {addresses[netifaces.AF_LINK][0]['addr']}")
                
                if netifaces.AF_INET in addresses:
                    output.append("\nIPv4 Configuration:")
                    addr_info = addresses[netifaces.AF_INET][0]
                    output.append(f"Address: {addr_info.get('addr', 'N/A')}")
                    output.append(f"Netmask: {addr_info.get('netmask', 'N/A')}")
                    output.append(f"Broadcast: {addr_info.get('broadcast', 'N/A')}")
                
                # Get gateway information
                gateways = netifaces.gateways()
                if 'default' in gateways and netifaces.AF_INET in gateways['default']:
                    output.append(f"\nDefault Gateway: {gateways['default'][netifaces.AF_INET][0]}")
                
                # Add switch information
                output.append("\n=== Switch Information ===")
                output.append(self.get_switch_info())
                
                # Add DNS information
                output.append("\n" + self.get_dns_info())
                
                # Add modem information
                output.append("\n" + self.get_modem_info())
                
            self._refresh_output = output
        except Exception as e:
            self._refresh_error = str(e)

    def _refresh_completed(self):
        """Handle completion of refresh thread"""
        self.progress.hide()
        self.progress_label.hide()
        
        try:
            if hasattr(self, '_refresh_error'):
                self.console.setText(f"Error: {self._refresh_error}")
                delattr(self, '_refresh_error')
            else:
                self.console.setText("\n".join(self._refresh_output))
                delattr(self, '_refresh_output')
            
            self.widget.updateGeometry()
            
        except Exception as e:
            self.logger.error(f"Error in refresh completion: {str(e)}")
            self.console.setText(f"Error: {str(e)}")
            self.widget.updateGeometry()

    def initialize(self):
        """Initialize the plugin"""
        print(f"Initializing {self.NAME}")
        return True

    def terminate(self):
        """Clean up plugin resources"""
        try:
            if self.scan_thread and self.scan_thread.isRunning():
                self.scan_thread.terminate()
                self.scan_thread.wait()
                
            if self.installer_thread and self.installer_thread.isRunning():
                self.installer_thread.terminate()
                self.installer_thread.wait()
                
            if self.refresh_thread and self.refresh_thread.isRunning():
                self.refresh_thread.terminate()
                self.refresh_thread.wait()
                
            print(f"Terminating {self.NAME}")
        except Exception as e:
            print(f"Error during termination: {str(e)}")

    def get_port_info(self):
        """Get detailed port information"""
        try:
            info = []
            
            # Get port information using ethtool
            ethtool_output = subprocess.check_output(['sudo', 'ethtool', 'eth0'], 
                                                   stderr=subprocess.STDOUT).decode()
            
            # Get physical port information
            port_match = re.search(r'Port: (.+)', ethtool_output)
            if port_match:
                info.append(f"Port Type: {port_match.group(1)}")
            
            # Get switch port information via LLDP
            try:
                lldp_output = subprocess.check_output(['sudo', 'lldpctl', 'eth0'], 
                                                    stderr=subprocess.STDOUT).decode()
                port_id = re.search(r'Port:\s+(.+)', lldp_output)
                if port_id:
                    info.append(f"Switch Port: {port_id.group(1)}")
            except:
                pass
            
            return "\n".join(info)
        except Exception as e:
            return f"Error getting port info: {str(e)}"

    def show_port_info(self):
        """Display port information in a message box"""
        try:
            info = self.get_port_info()
            QMessageBox.information(self.widget, "Port Information", info)
        except Exception as e:
            self.logger.error(f"Error showing port info: {str(e)}")
            QMessageBox.critical(self.widget, "Error", str(e))

    def toggle_port_led(self):
        """Toggle the port LED blinking"""
        try:
            # Try different methods based on switch/NIC support
            methods = [
                ['sudo', 'ethtool', '--identify', 'eth0', '5'],  # Standard method
                ['sudo', 'ethtool', '-p', 'eth0', '5'],          # Alternative syntax
            ]
            
            success = False
            error_msgs = []
            
            for method in methods:
                try:
                    subprocess.run(method, check=True)
                    success = True
                    break
                except subprocess.CalledProcessError as e:
                    error_msgs.append(f"Method {' '.join(method)} failed: {str(e)}")
                except Exception as e:
                    error_msgs.append(f"Error with {' '.join(method)}: {str(e)}")
            
            if not success:
                raise Exception("All LED blink methods failed:\n" + "\n".join(error_msgs))
            
        except Exception as e:
            self.logger.error(f"Error toggling port LED: {str(e)}")
            QMessageBox.critical(self.widget, "Error", 
                               "Failed to blink port LED. Your hardware may not support this feature.")

    def initial_refresh(self):
        """Perform initial refresh when widget is first shown"""
        if not self.initial_refresh_done:
            self.refresh()
            self.update_service_buttons()
            self.initial_refresh_done = True

    def update_progress_label(self, text):
        """Update the progress label text"""
        self.progress_label.setText(text)

    def installation_completed(self, success, message, service):
        """Handle completion of package installation"""
        self.progress.hide()
        self.progress_label.hide()
        
        if success:
            self.update_service_buttons()
            self.refresh()
            
            # Try to start the service after successful installation
            try:
                subprocess.run(self.SERVICE_COMMANDS[service]['start'], check=True)
                self.update_service_buttons()
            except Exception as e:
                self.logger.error(f"Error starting service after install: {str(e)}")
        else:
            QMessageBox.critical(self.widget, "Installation Failed", message)
