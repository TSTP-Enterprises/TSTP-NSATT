#!/usr/bin/env python3
import logging
from pathlib import Path
from datetime import datetime
import subprocess
import re
import time
import threading
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QGridLayout, QPushButton,
                            QTextEdit, QHBoxLayout)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QObject
from PyQt5.QtGui import QFont

plugin_image_value = "/nsatt/storage/images/icons/wifi_manager_icon.png"

class RefreshSignals(QObject):
    refresh = pyqtSignal()

class Plugin:
    NAME = "WiFi Manager"
    CATEGORY = "Networking"
    DESCRIPTION = "Toggle wireless adapters between managed and monitor modes"

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        self.console = None
        self.adapter_buttons = {}
        self.refresh_timer = None
        self.signals = RefreshSignals()
        
        # Setup logging
        log_dir = Path("/nsatt/logs/network/management")
        if not log_dir.exists():
            log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"adapter_manager_{timestamp}.log"

    def get_widget(self):
        if not self.widget:
            try:
                self.widget = QWidget()
                layout = QVBoxLayout()
                
                # Add refresh button at top
                refresh_layout = QHBoxLayout()
                self.refresh_btn = QPushButton("Refresh Adapters")
                self.signals.refresh.connect(self.refresh_adapters)
                self.refresh_btn.clicked.connect(lambda: self.signals.refresh.emit())
                refresh_layout.addWidget(self.refresh_btn)
                refresh_layout.addStretch()
                layout.addLayout(refresh_layout)
                
                # Grid for adapter buttons
                self.grid = QGridLayout()
                layout.addLayout(self.grid)
                
                # Console output
                self.console = QTextEdit()
                self.console.setReadOnly(True)
                self.console.setFont(QFont("Monospace"))
                self.console.setMinimumHeight(200)
                layout.addWidget(self.console)
                
                self.widget.setLayout(layout)
                
                # Initial adapter refresh
                self.refresh_adapters()
                
                # Setup periodic refresh using QTimer
                self.refresh_timer = QTimer(self.widget)
                self.refresh_timer.timeout.connect(self.refresh_adapters)
                self.refresh_timer.start(5000)  # 5 second interval
                
            except Exception as e:
                self.log_error(f"Error initializing widget: {str(e)}")
                
        return self.widget

    def refresh_adapters(self):
        """Find wireless adapters and create/update buttons"""
        try:
            # Get list of all network interfaces
            interfaces = []
            try:
                output = subprocess.check_output(["ip", "link", "show"], universal_newlines=True)
                interfaces = re.findall(r"\d+: ([^:@]+)[:@]", output)
            except subprocess.CalledProcessError as e:
                self.log_error(f"Failed to get interface list using ip command: {str(e)}")
                return
            
            # Check which interfaces are wireless
            current_adapters = []
            for interface in interfaces:
                try:
                    output = subprocess.check_output(["iwconfig", interface], 
                                                   stderr=subprocess.DEVNULL,
                                                   universal_newlines=True)
                    if "no wireless extensions" not in output:
                        current_adapters.append(interface)
                except subprocess.CalledProcessError:
                    continue

            # Remove buttons for adapters that no longer exist
            for adapter in list(self.adapter_buttons.keys()):
                if adapter not in current_adapters:
                    try:
                        btn = self.adapter_buttons[adapter]
                        self.grid.removeWidget(btn)
                        btn.setParent(None)
                        btn.deleteLater()
                        del self.adapter_buttons[adapter]
                        self.log_message(f"Removed adapter: {adapter}")
                    except Exception as e:
                        self.log_error(f"Error removing button for {adapter}: {str(e)}")

            # Create/update buttons for current adapters
            try:
                row = 0
                col = 0
                for adapter in current_adapters:
                    if adapter not in self.adapter_buttons:
                        try:
                            btn = QPushButton(adapter, self.widget)
                            btn.clicked.connect(lambda checked, a=adapter: self.toggle_mode(a))
                            self.adapter_buttons[adapter] = btn
                            self.grid.addWidget(btn, row, col)
                            self.log_message(f"Added new adapter: {adapter}")
                        except Exception as e:
                            self.log_error(f"Error creating button for {adapter}: {str(e)}")
                            continue
                        
                        col += 1
                        if col > 3:  # 4 buttons per row
                            col = 0
                            row += 1
                    else:
                        # Reposition existing buttons
                        try:
                            btn = self.adapter_buttons[adapter]
                            self.grid.addWidget(btn, row, col)
                            col += 1
                            if col > 3:
                                col = 0
                                row += 1
                        except Exception as e:
                            self.log_error(f"Error repositioning button for {adapter}: {str(e)}")
                    
                    # Update button color based on current mode
                    self.update_adapter_status(adapter)

            except Exception as e:
                self.log_error(f"Error updating adapter buttons: {str(e)}")

        except Exception as e:
            self.log_error(f"Error in refresh_adapters: {str(e)}")

    def update_adapter_status(self, adapter):
        """Update button color based on adapter mode"""
        try:
            if adapter not in self.adapter_buttons:
                return
                
            output = subprocess.check_output(["iwconfig", adapter], stderr=subprocess.STDOUT, universal_newlines=True)
            
            btn = self.adapter_buttons[adapter]
            
            if "No such device" in output:
                btn.setStyleSheet("background-color: red")
                return
                
            if "Mode:Monitor" in output:
                btn.setStyleSheet("background-color: green")
            else:
                btn.setStyleSheet("background-color: blue")
                
        except subprocess.CalledProcessError:
            if adapter in self.adapter_buttons:
                self.adapter_buttons[adapter].setStyleSheet("background-color: red")
        except Exception as e:
            self.log_error(f"Error checking adapter {adapter} status: {str(e)}")

    def toggle_mode(self, adapter):
        """Toggle adapter between managed and monitor modes"""
        try:
            # Get current mode
            output = subprocess.check_output(["iwconfig", adapter], stderr=subprocess.STDOUT, universal_newlines=True)
            current_mode = "monitor" if "Mode:Monitor" in output else "managed"
            new_mode = "monitor" if current_mode == "managed" else "managed"
            
            # Remove from NetworkManager if switching to monitor mode
            if new_mode == "monitor":
                try:
                    subprocess.check_call(["nmcli", "device", "set", adapter, "managed", "no"])
                    time.sleep(1)  # Wait for NetworkManager to release device
                except subprocess.CalledProcessError as e:
                    self.log_error(f"Error removing {adapter} from NetworkManager: {str(e)}")
                    return
            
            # Bring interface down
            if not self.set_interface_state(adapter, "down"):
                raise Exception(f"Failed to bring {adapter} down")
                
            # Change mode
            if not self.change_adapter_mode(adapter, new_mode):
                raise Exception(f"Failed to change {adapter} to {new_mode} mode")
                
            # Bring interface back up
            if not self.set_interface_state(adapter, "up"):
                raise Exception(f"Failed to bring {adapter} up")
            
            # Add back to NetworkManager if switching to managed mode
            if new_mode == "managed":
                try:
                    subprocess.check_call(["nmcli", "device", "set", adapter, "managed", "yes"])
                except subprocess.CalledProcessError as e:
                    self.log_error(f"Error adding {adapter} back to NetworkManager: {str(e)}")
            
            self.log_message(f"Successfully changed {adapter} to {new_mode} mode")
            self.update_adapter_status(adapter)
            
        except Exception as e:
            self.log_error(f"Error changing adapter mode: {str(e)}")
            # Attempt recovery
            self.set_interface_state(adapter, "up")
            if current_mode == "managed":
                try:
                    subprocess.check_call(["nmcli", "device", "set", adapter, "managed", "yes"])
                except:
                    pass

    def set_interface_state(self, adapter, state):
        """Set adapter interface state to up or down"""
        max_attempts = 3
        for attempt in range(max_attempts):
            try:
                # Try both ifconfig and ip commands
                try:
                    subprocess.check_call(["ifconfig", adapter, state], stderr=subprocess.DEVNULL)
                except subprocess.CalledProcessError:
                    subprocess.check_call(["ip", "link", "set", adapter, state], stderr=subprocess.DEVNULL)
                
                time.sleep(1)  # Allow time for state change
                
                # Verify state change
                try:
                    output = subprocess.check_output(["ifconfig", adapter], 
                        stderr=subprocess.DEVNULL, universal_newlines=True)
                except subprocess.CalledProcessError:
                    output = subprocess.check_output(["ip", "link", "show", adapter],
                        stderr=subprocess.DEVNULL, universal_newlines=True)
                
                if state == "up":
                    if "UP" in output or "state UP" in output:
                        return True
                else:
                    if "UP" not in output and "state UP" not in output:
                        return True
                        
            except (subprocess.CalledProcessError, subprocess.TimeoutError) as e:
                self.log_error(f"Attempt {attempt+1} failed to set interface state: {str(e)}")
                if attempt == max_attempts - 1:
                    return False
                time.sleep(1)
        return False

    def change_adapter_mode(self, adapter, mode):
        """Change adapter mode to monitor or managed"""
        max_attempts = 3
        for attempt in range(max_attempts):
            try:
                subprocess.check_call(["iwconfig", adapter, "mode", mode], stderr=subprocess.DEVNULL)
                time.sleep(1)  # Allow time for mode change
                
                # Verify mode change
                try:
                    output = subprocess.check_output(["iwconfig", adapter],
                        stderr=subprocess.DEVNULL, universal_newlines=True, timeout=5)
                        
                    if mode == "monitor":
                        if "Mode:Monitor" in output:
                            return True
                    else:
                        if "Mode:Managed" in output:
                            return True
                            
                except subprocess.TimeoutExpired:
                    self.log_error("Timeout while verifying mode change")
                    
            except subprocess.CalledProcessError as e:
                self.log_error(f"Attempt {attempt+1} failed to change mode: {str(e)}")
                if attempt == max_attempts - 1:
                    return False
                time.sleep(1)
        return False

    def log_message(self, message):
        """Log informational message"""
        if self.console:
            try:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self.console.append(f"[{timestamp}] [INFO] {message}")
                with open(self.log_file, "a") as f:
                    f.write(f"[{timestamp}] [INFO] {message}\n")
            except Exception:
                pass

    def log_error(self, message):
        """Log error message"""
        if self.console:
            try:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self.console.append(f"[{timestamp}] [ERROR] {message}")
                with open(self.log_file, "a") as f:
                    f.write(f"[{timestamp}] [ERROR] {message}\n")
            except Exception:
                pass

    def initialize(self):
        try:
            return True
        except Exception as e:
            self.log_error(f"Error in initialization: {str(e)}")
            return False

    def terminate(self):
        try:
            if hasattr(self, 'refresh_timer'):
                self.refresh_timer.stop()
        except Exception as e:
            self.log_error(f"Error in termination: {str(e)}")
