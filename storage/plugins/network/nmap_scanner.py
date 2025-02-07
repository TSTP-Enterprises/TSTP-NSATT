#!/usr/bin/env python3
import os
import subprocess
import logging
import platform
import netifaces
from pathlib import Path
from datetime import datetime
# Import QT
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QTextEdit, QLabel, QLineEdit, QCheckBox, QFrame,
                            QScrollArea, QGroupBox, QProgressBar, QSizePolicy,
                            QStackedWidget)
from PyQt5.QtCore import QThread, pyqtSignal, QTimer
import signal
import re

plugin_image_value = "/nsatt/storage/images/icons/nmap_scanner_icon.png"

class NmapScannerThread(QThread):
    scan_complete = pyqtSignal(str)
    scan_progress = pyqtSignal(str)
    
    def __init__(self, command):
        super().__init__()
        self.command = command
        self.running = True
        self.process = None
        
    def run(self):
        try:
            self.process = subprocess.Popen(
                self.command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                shell=True,
                bufsize=1,
                preexec_fn=os.setsid  # Create new process group on Linux
            )
            
            output = []
            while self.running:
                return_code = self.process.poll()
                
                if return_code is not None:
                    break
                    
                # Use readline with timeout to avoid blocking
                try:
                    line = self.process.stdout.readline()
                    if line:
                        output.append(line)
                        self.scan_progress.emit(line)
                except:
                    break
                    
            if not self.running and self.process:
                # Kill entire process group on Linux
                os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
                self.process.wait()
                output.append("\nScan terminated by user")
            else:
                stdout, stderr = self.process.communicate()
                if stdout:
                    output.append(stdout)
                if stderr:
                    output.append(f"\nErrors:\n{stderr}")
                    
            self.scan_complete.emit("".join(output))
            
        except Exception as e:
            self.scan_complete.emit(f"Error during scan: {str(e)}")
            if self.process:
                try:
                    os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
                except:
                    pass

class Plugin:
    NAME = "Nmap Scanner"
    CATEGORY = "Network"
    DESCRIPTION = "Perform network scans using nmap"

    def __init__(self):
        self.widget = None
        self.scanner_thread = None
        self.logger = None
        self.save_dir = None
        self.console = None
        self.target_input = None
        self.options_frame = None
        self.scan_options = {}
        self.custom_command = None
        self.initial_refresh_done = False
        
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
                try:
                    self.save_dir = Path("/nsatt/storage/saves/nmap")
                    self.save_dir.mkdir(parents=True, exist_ok=True)
                except Exception as e:
                    self.logger.error(f"Error creating save directory: {str(e)}")
                
                # Target input section
                target_group = QGroupBox("Standard Scan")
                target_layout = QHBoxLayout()
                target_label = QLabel("Target:")
                self.target_input = QLineEdit()
                
                # Get wlan0 IP and set default target
                try:
                    addrs = netifaces.ifaddresses('wlan0')
                    if netifaces.AF_INET in addrs:
                        ip = addrs[netifaces.AF_INET][0]['addr']
                        if ip and not ip.startswith('127.'):
                            # Convert IP to network range (e.g. 192.168.1.1 -> 192.168.1.0/24)
                            network = '.'.join(ip.split('.')[:-1]) + '.0/24'
                            self.target_input.setText(network)
                        else:
                            self.target_input.setPlaceholderText("Enter IP/hostname (e.g. 192.168.1.1) or range (e.g. 192.168.1.1-254)")
                    else:
                        self.target_input.setPlaceholderText("No wlan0 IP found - Enter target manually")
                except Exception as e:
                    self.logger.error(f"Error getting wlan0 IP: {str(e)}")
                    self.target_input.setPlaceholderText("Error getting wlan0 IP - Enter target manually")
                
                target_layout.addWidget(target_label)
                target_layout.addWidget(self.target_input)
                target_group.setLayout(target_layout)
                layout.addWidget(target_group)
                
                # Create button grid
                button_grid = QVBoxLayout()
                
                # Main button row
                row1 = QHBoxLayout()
                
                start_btn = QPushButton("Start")
                start_btn.clicked.connect(self.start)
                row1.addWidget(start_btn)
                
                stop_btn = QPushButton("Stop")
                stop_btn.clicked.connect(self.stop)
                row1.addWidget(stop_btn)
                
                save_btn = QPushButton("Save")
                save_btn.clicked.connect(self.save)
                row1.addWidget(save_btn)
                
                clear_btn = QPushButton("Clear")
                clear_btn.clicked.connect(self.clear)
                row1.addWidget(clear_btn)
                
                self.view_toggle_btn = QPushButton("Advanced")
                self.view_toggle_btn.setCheckable(True)
                self.view_toggle_btn.clicked.connect(self.toggle_view)
                row1.addWidget(self.view_toggle_btn)
                
                button_grid.addLayout(row1)
                
                # Progress indicators
                self.progress = QProgressBar()
                self.progress.hide()
                button_grid.addWidget(self.progress)
                
                self.progress_label = QLabel("")
                self.progress_label.hide()
                button_grid.addWidget(self.progress_label)
                
                # Add button grid to main layout
                layout.addLayout(button_grid)
                
                # Options frame (moved above results area)
                self.options_frame = QFrame()
                self.options_frame.setVisible(False)
                options_layout = QVBoxLayout(self.options_frame)
                
                # Advanced options section
                advanced_group = QGroupBox("Advanced Options")
                advanced_layout = QVBoxLayout()
                
                # Custom command section at top of options
                custom_group = QGroupBox("Custom Nmap Command")
                custom_layout = QHBoxLayout()
                custom_label = QLabel("nmap")
                self.custom_command = QLineEdit()
                self.custom_command.setPlaceholderText("Enter custom nmap arguments (e.g. -sS -p 80 192.168.1.1)")
                custom_layout.addWidget(custom_label)
                custom_layout.addWidget(self.custom_command)
                custom_group.setLayout(custom_layout)
                advanced_layout.addWidget(custom_group)
                
                # Add scan options
                scan_options = {
                    "sS": "TCP SYN scan (-sS)",
                    "sU": "UDP scan (-sU)", 
                    "sV": "Service/version detection (-sV)",
                    "O": "OS detection (-O)",
                    "A": "Aggressive scan (-A)",
                    "v": "Verbose (-v)",
                    "vv": "Very verbose (-vv)",
                    "oN": "Normal output (-oN)",
                    "oX": "XML output (-oX)",
                    "oG": "Grepable output (-oG)"
                }
                
                for opt, desc in scan_options.items():
                    cb = QCheckBox(desc)
                    self.scan_options[opt] = cb
                    advanced_layout.addWidget(cb)
                    
                # Port range input
                port_layout = QHBoxLayout()
                port_label = QLabel("Port range:")
                self.port_input = QLineEdit()
                self.port_input.setPlaceholderText("e.g. 80 or 1-100 or - for all ports")
                port_layout.addWidget(port_label)
                port_layout.addWidget(self.port_input)
                advanced_layout.addLayout(port_layout)
                
                advanced_group.setLayout(advanced_layout)
                options_layout.addWidget(advanced_group)
                layout.addWidget(self.options_frame)
                
                # Results area container
                results_container = QWidget()
                results_container_layout = QVBoxLayout(results_container)
                results_container_layout.setContentsMargins(0, 0, 0, 0)
                
                # View toggle button
                view_controls = QHBoxLayout()
                self.view_mode_btn = QPushButton("Toggle View Mode")
                self.view_mode_btn.clicked.connect(self.toggle_view_mode)
                view_controls.addWidget(self.view_mode_btn)
                view_controls.addStretch()
                results_container_layout.addLayout(view_controls)
                
                # Stacked widget to hold both view modes
                self.results_stack = QStackedWidget()
                
                # Section view
                self.results_area = QScrollArea()
                self.results_area.setWidgetResizable(True)
                self.results_area.setFrameShape(QFrame.NoFrame)
                
                self.results_widget = QWidget()
                self.results_layout = QVBoxLayout(self.results_widget)
                self.results_layout.setSpacing(10)
                self.results_area.setWidget(self.results_widget)
                
                # Console view
                self.console = QTextEdit()
                self.console.setReadOnly(True)
                
                # Add both views to stack
                self.results_stack.addWidget(self.results_area)
                self.results_stack.addWidget(self.console)
                
                results_container_layout.addWidget(self.results_stack)
                layout.addWidget(results_container)
                
                # Keep console for progress updates but hide it
                self.console = QTextEdit()
                self.console.setReadOnly(True)
                self.console.hide()
                
                # Schedule initial refresh
                QTimer.singleShot(100, self.initial_refresh)
                
            except Exception as e:
                self.logger.error(f"Error in get_widget: {str(e)}")
                # Create minimal error widget
                self.widget = QWidget()
                error_layout = QVBoxLayout()
                self.widget.setLayout(error_layout)
                error_label = QLabel(f"Error initializing plugin: {str(e)}")
                error_layout.addWidget(error_label)
        
        return self.widget

    def toggle_view(self):
        is_full_view = self.view_toggle_btn.isChecked()
        if is_full_view:
            self.view_toggle_btn.setText("Simple")
            self.options_frame.setVisible(True)
        else:
            self.view_toggle_btn.setText("Advanced")
            self.options_frame.setVisible(False)

    def initialize(self):
        print(f"Initializing {self.NAME}")
        return True

    def terminate(self):
        if self.scanner_thread:
            self.scanner_thread.running = False
            self.scanner_thread.wait()
        print(f"Terminating {self.NAME}")
        
    def toggle_options(self):
        self.options_frame.setVisible(not self.options_frame.isVisible())
        
    def get_scan_command(self):
        if self.custom_command.text():
            return f"nmap {self.custom_command.text()}"
            
        options = []
        has_scan_type = False
        
        for opt, cb in self.scan_options.items():
            if cb.isChecked():
                if opt in ['sS', 'sU', 'sV']:
                    has_scan_type = True
                options.append(f"-{opt}")
                
        # Add ping scan if no scan type selected
        if not has_scan_type:
            options.append("-sn")
                
        if self.port_input.text():
            options.extend(["-p", self.port_input.text()])
            
        target = self.target_input.text()
        if not target:
            raise ValueError("No target specified")
            
        return f"nmap {' '.join(options)} {target}"
        
    def start(self):
        try:
            if self.scanner_thread and self.scanner_thread.isRunning():
                self.logger.warning("Scanner already running")
                return
                
            command = self.get_scan_command()
            
            self.console.clear()
            self.console.append(f"Executing: {command}\n")
            
            self.scanner_thread = NmapScannerThread(command)
            self.scanner_thread.scan_complete.connect(self.scan_complete)
            self.scanner_thread.scan_progress.connect(self.scan_progress)
            self.scanner_thread.start()
            
        except Exception as e:
            self.logger.error(f"Error starting scan: {str(e)}")
            self.console.append(f"Error: {str(e)}")
    
    def stop(self):
        try:
            if self.scanner_thread and self.scanner_thread.isRunning():
                self.scanner_thread.running = False
                # Send a signal to terminate the process group
                if self.scanner_thread.process:
                    os.killpg(os.getpgid(self.scanner_thread.process.pid), signal.SIGTERM)
                # Wait for the thread to finish
                self.scanner_thread.wait()
                self.scanner_thread = None
                self.logger.info("Scanner stopped")
            else:
                self.logger.warning("No scan running")
        except Exception as e:
            self.logger.error(f"Error stopping scan: {str(e)}")
    
    def save(self):
        if not self.save_dir:
            self.logger.error("Save directory not available")
            return
            
        if not self.console.toPlainText():
            self.logger.warning("No scan results to save")
            return
            
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            target = self.target_input.text() or "custom"
            target = target.replace("/","_").replace(" ","_")
            filename = self.save_dir / f"nmap_{target}_{timestamp}.txt"
            
            with open(filename, 'w') as f:
                f.write(self.console.toPlainText())
            self.logger.info(f"Scan results saved to {filename}")

            # Create custom save confirmation dialog
            dialog = QWidget(self.widget)
            dialog.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
            dialog.setObjectName("confirmDialog")
            
            layout = QVBoxLayout(dialog)
            layout.setContentsMargins(20, 20, 20, 20)
            layout.setSpacing(15)
            
            # Message
            message = QLabel(f"Results saved successfully!\n\nLocation:\n{filename}")
            message.setAlignment(Qt.AlignCenter)
            layout.addWidget(message)
            
            # OK button
            button_layout = QHBoxLayout()
            ok_button = QPushButton("OK")
            ok_button.clicked.connect(dialog.close)
            button_layout.addWidget(ok_button)
            layout.addLayout(button_layout)
            
            # Show dialog
            dialog.setFixedSize(400, 250)
            dialog.move(
                self.widget.frameGeometry().center() - dialog.rect().center()
            )
            dialog.show()
            
        except Exception as e:
            self.logger.error(f"Error saving scan results: {str(e)}")
            self.console.append(f"\nError saving results: {str(e)}")
    
    def clear(self):
        """Clear all results"""
        # Clear console
        self.console.clear()
        
        # Remove all result sections
        while self.results_layout.count():
            child = self.results_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()

    def scan_complete(self, results):
        try:
            # Clear previous results
            self.clear()
            
            # Check if this is an error message
            if results.startswith("Error"):
                self.add_result_section("Error", results)
                return
                
            # Parse the results into individual devices
            devices = self.parse_nmap_output(results)
            
            # Create a section for each device
            for device in devices:
                # Extract device name/IP from the first line
                first_line = device.split('\n')[0]
                title = first_line.replace('Nmap scan report for ', '')
                self.add_result_section(title, device)
            
            # Update console view as well
            self.console.clear()
            for i in range(self.results_layout.count()):
                widget = self.results_layout.itemAt(i).widget()
                if widget:
                    text_display = widget.findChild(QTextEdit)
                    if text_display:
                        self.console.append(text_display.toPlainText())
                        if i < self.results_layout.count() - 1:
                            self.console.append("\n" + "="*50 + "\n")
                
        except Exception as e:
            self.logger.error(f"Error parsing scan results: {str(e)}")
            self.add_result_section("Error", f"Error parsing results: {str(e)}\n\nOriginal output:\n{results}")

    def add_result_section(self, title, content):
        """Add a new section to display scan results"""
        section = QGroupBox(title)
        section_layout = QVBoxLayout()
        
        # Create text display for this section
        text_display = QTextEdit()
        text_display.setReadOnly(True)
        text_display.setText(content)
        text_display.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        text_display.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        
        # Set size policy to expand
        text_display.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        
        section_layout.addWidget(text_display)
        section.setLayout(section_layout)
        
        # Set section to expand
        section.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        
        self.results_layout.addWidget(section)

    def scan_progress(self, line):
        """Handle incremental scan progress updates"""
        if not line.strip():
            return
        
        # Don't add running scan lines (they'll be in final output)
        if "Scanning" in line and "in progress" in line:
            return
            
        # Add progress updates to a temporary section
        if not self.results_layout.count():
            self.add_result_section("Scan in Progress", "")
            
        progress_section = self.results_layout.itemAt(0).widget()
        if progress_section:
            text_display = progress_section.findChild(QTextEdit)
            if text_display:
                text_display.append(line)

    def initial_refresh(self):
        """Perform initial refresh when widget is first shown"""
        if not self.initial_refresh_done:
            self.refresh()
            self.initial_refresh_done = True

    def refresh(self):
        """Refresh the display"""
        try:
            self.console.clear()
            self.console.append("Ready to scan. Enter target and click Start.")
        except Exception as e:
            self.logger.error(f"Error in refresh: {str(e)}")

    def parse_nmap_output(self, output):
        """Parse nmap output and split it by device"""
        # Split output into devices
        devices = []
        current_device = []
        
        # Regular expressions for matching device boundaries
        host_start = re.compile(r'Nmap scan report for .*')
        
        lines = output.split('\n')
        for line in lines:
            if host_start.match(line):
                if current_device:
                    devices.append('\n'.join(current_device))
                    current_device = []
            current_device.append(line)
        
        # Add the last device
        if current_device:
            devices.append('\n'.join(current_device))
        
        return devices

    def toggle_view_mode(self):
        """Toggle between section view and console view"""
        current_index = self.results_stack.currentIndex()
        new_index = 1 if current_index == 0 else 0
        self.results_stack.setCurrentIndex(new_index)
        
        # Update button text
        if new_index == 0:
            self.view_mode_btn.setText("Show Console View")
        else:
            self.view_mode_btn.setText("Show Section View")
            # Update console with all content
            self.console.clear()
            for i in range(self.results_layout.count()):
                widget = self.results_layout.itemAt(i).widget()
                if widget:
                    text_display = widget.findChild(QTextEdit)
                    if text_display:
                        self.console.append(text_display.toPlainText())
                        if i < self.results_layout.count() - 1:
                            self.console.append("\n" + "="*50 + "\n")
