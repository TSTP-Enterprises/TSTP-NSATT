#!/usr/bin/env python3
import logging
from pathlib import Path
from datetime import datetime
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                            QTextEdit, QLabel, QComboBox)
from PyQt5.QtCore import QThread, pyqtSignal
import socket
import subprocess
import os
import platform
import shutil

plugin_image_value = "/nsatt/storage/images/icons/smb_scanner_icon.png"

class SMBScannerThread(QThread):
    scan_complete = pyqtSignal(str)
    
    def __init__(self, target_ip):
        super().__init__()
        self.running = True
        self.target_ip = target_ip
        self.system = platform.system().lower()

    def run(self):
        results = []
        results.append(f"Scanning {self.target_ip} for SMB shares...")
        
        try:
            if self.system == 'linux':
                # Check if smbclient is installed
                if not shutil.which('smbclient'):
                    results.append("Error: smbclient not found. Please install samba-client package.")
                    self.scan_complete.emit("\n".join(results))
                    return

                # Use smbclient on Linux
                cmd = ['smbclient', '-L', self.target_ip, '-N']
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate()
                
                if process.returncode == 0:
                    shares = stdout.decode().split('\n')
                    for line in shares:
                        if 'Disk' in line or 'Printer' in line:
                            results.append(line.strip())
                else:
                    error = stderr.decode()
                    results.append(f"Error scanning shares: {error}")

            elif self.system == 'windows':
                # Use net view on Windows
                cmd = ['net', 'view', self.target_ip]
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
                                        universal_newlines=True)
                stdout, stderr = process.communicate()
                
                if process.returncode == 0:
                    shares = stdout.split('\n')
                    for line in shares:
                        # Filter for share lines (usually start with whitespace)
                        if line.strip() and line[0].isspace():
                            results.append(line.strip())
                else:
                    results.append(f"Error scanning shares: {stderr}")
            else:
                results.append(f"Unsupported operating system: {self.system}")
                
        except Exception as e:
            results.append(f"Error during scan: {str(e)}")
                
        self.scan_complete.emit("\n".join(results))

class Plugin:
    NAME = "SMB Scanner"
    CATEGORY = "Network" 
    DESCRIPTION = "Scan network for SMB shares"

    def __init__(self):
        self.widget = None
        self.scanner_thread = None
        self.logger = None
        self.save_dir = None
        self.console = None
        self.target_ip = None

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            
            logging.basicConfig(level=logging.INFO)
            self.logger = logging.getLogger(__name__)
            
            try:
                # Create .blackbird save directory
                self.save_dir = Path.home() / ".blackbird/smb_scans"
                self.save_dir.mkdir(parents=True, exist_ok=True)
                
                # Only try to create nsatt directory on Linux
                if platform.system().lower() == 'linux':
                    nsatt_save_dir = Path("/nsatt/storage/scans")
                    nsatt_save_dir.mkdir(parents=True, exist_ok=True)
                
            except Exception as e:
                self.logger.error(f"Error creating save directories: {str(e)}")
                self.save_dir = None
            
            layout = QVBoxLayout()
            self.widget.setLayout(layout)
            
            # Target IP input
            ip_layout = QHBoxLayout()
            ip_label = QLabel("Target IP:")
            self.target_ip = QComboBox()
            self.target_ip.setEditable(True)
            self.target_ip.addItem("127.0.0.1")
            ip_layout.addWidget(ip_label)
            ip_layout.addWidget(self.target_ip)
            layout.addLayout(ip_layout)
            
            self.console = QTextEdit()
            self.console.setReadOnly(True)
            layout.addWidget(self.console)
            
            button_layout = QHBoxLayout()
            
            start_btn = QPushButton("Start Scan")
            start_btn.clicked.connect(self.start)
            button_layout.addWidget(start_btn)
            
            stop_btn = QPushButton("Stop") 
            stop_btn.clicked.connect(self.stop)
            button_layout.addWidget(stop_btn)
            
            save_btn = QPushButton("Save Results")
            save_btn.clicked.connect(self.save)
            button_layout.addWidget(save_btn)
            
            clear_btn = QPushButton("Clear")
            clear_btn.clicked.connect(self.clear)
            button_layout.addWidget(clear_btn)
            
            layout.addLayout(button_layout)

        return self.widget

    def initialize(self):
        print(f"Initializing {self.NAME}")
        return True

    def terminate(self):
        if self.scanner_thread:
            self.scanner_thread.running = False
            self.scanner_thread.wait()
        print(f"Terminating {self.NAME}")
        
    def start(self):
        try:
            if self.scanner_thread and self.scanner_thread.isRunning():
                self.logger.warning("Scanner already running")
                return
                
            target = self.target_ip.currentText()
            if not target:
                self.logger.warning("Please enter a target IP")
                return
                
            self.console.clear()
            self.console.append(f"Starting SMB scan of {target}...")
            self.scanner_thread = SMBScannerThread(target)
            self.scanner_thread.scan_complete.connect(self.scan_complete)
            self.scanner_thread.start()
            
        except Exception as e:
            self.logger.error(f"Error starting scan: {str(e)}")
    
    def stop(self):
        try:
            if self.scanner_thread:
                self.scanner_thread.running = False
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
            
            # Save to .blackbird directory
            blackbird_filename = self.save_dir / f"smb_scan_{timestamp}.log"
            with open(blackbird_filename, 'w') as f:
                f.write(self.console.toPlainText())
            self.logger.info(f"Scan results saved to {blackbird_filename}")
            
            # Only try to save to nsatt directory on Linux
            if platform.system().lower() == 'linux':
                nsatt_filename = Path(f"/nsatt/storage/scans/smb_{timestamp}.log")
                with open(nsatt_filename, 'w') as f:
                    f.write(self.console.toPlainText())
                self.logger.info(f"Scan results saved to {nsatt_filename}")
            
        except Exception as e:
            self.logger.error(f"Error saving scan results: {str(e)}")
    
    def clear(self):
        self.console.clear()
    
    def scan_complete(self, results):
        self.console.setText(results)
