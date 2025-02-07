#!/usr/bin/env python3
import os
import subprocess
import sys
import logging
import netifaces
import re
import socket
import requests
from pathlib import Path
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QTextEdit, QLabel, QComboBox)

plugin_image_value = "/nsatt/storage/images/icons/network_info_icon.png"

class Plugin:
    NAME = "Network Info"
    CATEGORY = "Network"
    DESCRIPTION = "View detailed network adapter properties and configuration"

    def __init__(self):
        self.widget = None
        self.process = None
        self.logger = None
        self.interfaces = None
        self.selected_interface = None
        self.console = None
        self.iface_combo = None
        self.current_output = None

    def get_widget(self):
        if not self.widget:
            # Initialize widget and components
            self.widget = QWidget()
            
            # Set up logging
            logging.basicConfig(level=logging.INFO)
            self.logger = logging.getLogger(__name__)
            
            # Get list of network interfaces
            self.interfaces = netifaces.interfaces()
            self.selected_interface = "all"
            
            # Create layout
            layout = QVBoxLayout()
            self.widget.setLayout(layout)
            
            # Title section with background
            title_widget = QWidget()
            title_widget.setStyleSheet("background-color: #2e2e2e; padding: 10px;")
            title_layout = QHBoxLayout()
            title_label = QLabel(self.NAME)
            title_label.setStyleSheet("color: white; font-size: 16px; font-weight: bold;")
            title_layout.addWidget(title_label)
            title_widget.setLayout(title_layout)
            layout.addWidget(title_widget)
            
            # Interface selection
            iface_layout = QHBoxLayout()
            iface_label = QLabel("Interface:")
            self.iface_combo = QComboBox()
            self.iface_combo.addItem("All Interfaces")
            self.iface_combo.addItems(self.interfaces)
            self.iface_combo.currentTextChanged.connect(self.select_interface)
            iface_layout.addWidget(iface_label)
            iface_layout.addWidget(self.iface_combo)
            layout.addLayout(iface_layout)
            
            # Console output
            self.console = QTextEdit()
            self.console.setReadOnly(True)
            layout.addWidget(self.console)
            
            # Refresh button - now takes full width
            refresh_btn = QPushButton("Refresh")
            refresh_btn.clicked.connect(self.refresh)
            layout.addWidget(refresh_btn)
            
            # Initial output
            self.current_output = self.get_properties()
            self.console.setText(self.current_output)

        return self.widget

    def initialize(self):
        """Initialize the plugin"""
        print(f"Initializing {self.NAME}")
        return True

    def terminate(self):
        """Clean up plugin resources"""
        if self.process:
            self.process.terminate()
        print(f"Terminating {self.NAME}")
        
    def select_interface(self, interface):
        if interface == "All Interfaces":
            self.selected_interface = "all"
        else:
            self.selected_interface = interface
        self.logger.info(f"Selected interface: {interface}")
        self.refresh()
        
    def toggle_console(self):
        if self.console.isVisible():
            self.console.hide()
        else:
            self.console.show()
        
    def refresh(self):
        self.current_output = self.get_properties()
        self.console.setText(self.current_output)

    def check_internet_connectivity(self):
        try:
            # Try to connect to Google's DNS server
            socket.create_connection(("8.8.8.8", 53), timeout=3)
            return True
        except OSError:
            return False

    def get_wan_ip(self):
        try:
            # Try multiple IP lookup services
            services = [
                "https://api.ipify.org",
                "https://ifconfig.me/ip",
                "https://icanhazip.com"
            ]
            for service in services:
                try:
                    response = requests.get(service, timeout=5)
                    if response.status_code == 200:
                        return response.text.strip()
                except:
                    continue
        except:
            pass
        return "Unable to determine"
        
    def get_wireless_info(self, interface):
        info = []
        try:
            # Check if wireless
            wireless_path = Path(f"/sys/class/net/{interface}/wireless")
            is_wireless = wireless_path.exists()
            
            if is_wireless:
                # Get operation mode
                try:
                    iwconfig = subprocess.check_output(['iwconfig', interface], stderr=subprocess.STDOUT).decode()
                    mode = re.search(r"Mode:(.*?) ", iwconfig)
                    if mode:
                        info.append(f"Mode: {mode.group(1).strip()}")
                    
                    # Get frequency/channel
                    freq = re.search(r"Frequency:(.*?) ", iwconfig)
                    if freq:
                        info.append(f"Frequency: {freq.group(1).strip()}")
                    
                    # Check if in monitor mode
                    if "Mode:Monitor" in iwconfig:
                        info.append("Monitor Mode: Enabled")
                    else:
                        info.append("Monitor Mode: Disabled")
                        
                    # Get signal strength if connected
                    signal = re.search(r"Signal level=(.*?) ", iwconfig)
                    if signal:
                        info.append(f"Signal Strength: {signal.group(1).strip()}")

                    # Get ESSID if connected
                    essid = re.search(r'ESSID:"(.*?)"', iwconfig)
                    if essid:
                        info.append(f"SSID: {essid.group(1)}")

                    # Get bit rate
                    bitrate = re.search(r"Bit Rate=(.*?/s)", iwconfig)
                    if bitrate:
                        info.append(f"Bit Rate: {bitrate.group(1)}")
                        
                except subprocess.CalledProcessError:
                    info.append("Error getting wireless details")
                    
                return "Wireless", info
            else:
                return "Wired", []
                
        except Exception as e:
            self.logger.error(f"Error getting wireless info: {str(e)}")
            return "Unknown", []
            
    def get_link_status(self, interface):
        try:
            with open(f"/sys/class/net/{interface}/operstate", 'r') as f:
                return f.read().strip()
        except:
            return "unknown"
            
    def get_speed(self, interface):
        try:
            with open(f"/sys/class/net/{interface}/speed", 'r') as f:
                speed = f.read().strip()
                return f"{speed} Mbps"
        except:
            return "unknown"
            
    def get_properties(self):
        try:
            output = []
            output.append("=== Network Interface Properties ===\n")

            # Check internet connectivity and WAN IP first
            internet_available = self.check_internet_connectivity()
            output.append(f"Internet Connectivity: {'Available' if internet_available else 'Not Available'}")
            if internet_available:
                wan_ip = self.get_wan_ip()
                output.append(f"WAN IP Address: {wan_ip}")
            output.append("")
            
            interfaces = [self.selected_interface] if self.selected_interface != "all" else self.interfaces
            
            for interface in interfaces:
                if interface == "lo":  # Skip loopback
                    continue
                    
                output.append(f"\n{'='*10} Interface: {interface} {'='*20}")
                
                # Get interface type and wireless info
                iface_type, wireless_info = self.get_wireless_info(interface)
                output.append(f"Type: {iface_type}")
                
                if wireless_info:
                    output.extend(wireless_info)
                
                # Get link status and speed
                status = self.get_link_status(interface)
                output.append(f"Status: {status}")
                
                if status == "up":
                    speed = self.get_speed(interface)
                    output.append(f"Speed: {speed}")

                    # Get interface statistics
                    try:
                        with open(f"/sys/class/net/{interface}/statistics/rx_bytes", 'r') as f:
                            rx_bytes = int(f.read().strip())
                        with open(f"/sys/class/net/{interface}/statistics/tx_bytes", 'r') as f:
                            tx_bytes = int(f.read().strip())
                        output.append(f"Received: {rx_bytes/1024/1024:.2f} MB")
                        output.append(f"Transmitted: {tx_bytes/1024/1024:.2f} MB")
                    except:
                        pass
                
                # Get addresses (IPv4, IPv6)
                try:
                    addresses = netifaces.ifaddresses(interface)
                    
                    # MAC address
                    if netifaces.AF_LINK in addresses:
                        for addr in addresses[netifaces.AF_LINK]:
                            output.append(f"MAC Address: {addr.get('addr', 'N/A')}")
                    
                    # IPv4 addresses
                    if netifaces.AF_INET in addresses:
                        output.append("\nIPv4 Configuration:")
                        for addr in addresses[netifaces.AF_INET]:
                            output.append(f"  Address: {addr.get('addr', 'N/A')}")
                            output.append(f"  Netmask: {addr.get('netmask', 'N/A')}")
                            output.append(f"  Broadcast: {addr.get('broadcast', 'N/A')}")
                    
                    # IPv6 addresses        
                    if netifaces.AF_INET6 in addresses:
                        output.append("\nIPv6 Configuration:")
                        for addr in addresses[netifaces.AF_INET6]:
                            output.append(f"  Address: {addr.get('addr', 'N/A')}")
                            
                except ValueError as e:
                    output.append(f"Error getting addresses: {str(e)}")
                    
                # Get gateway information
                try:
                    gateways = netifaces.gateways()
                    output.append("\nGateway Configuration:")
                    if 'default' in gateways:
                        if netifaces.AF_INET in gateways['default']:
                            output.append(f"  Default IPv4 Gateway: {gateways['default'][netifaces.AF_INET][0]}")
                        if netifaces.AF_INET6 in gateways['default']:
                            output.append(f"  Default IPv6 Gateway: {gateways['default'][netifaces.AF_INET6][0]}")
                except Exception as e:
                    output.append(f"Error getting gateway info: {str(e)}")
                
                # Get driver information
                try:
                    driver_path = Path(f"/sys/class/net/{interface}/device/driver")
                    if driver_path.exists():
                        driver = driver_path.resolve().name
                        output.append(f"\nDriver: {driver}")
                except:
                    pass
                    
                # MTU size
                try:
                    with open(f"/sys/class/net/{interface}/mtu", 'r') as f:
                        mtu = f.read().strip()
                        output.append(f"MTU: {mtu}")
                except:
                    pass
                    
            return "\n".join(output)
            
        except Exception as e:
            self.logger.error(f"Error getting interface properties: {str(e)}")
            return f"Error: {str(e)}"
