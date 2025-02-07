#!/usr/bin/env python3
import os
import subprocess
from datetime import datetime
import sys
import logging
import netifaces
import socket
from pathlib import Path
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QTextEdit, QLabel, QComboBox
from PyQt5.QtCore import QThread, pyqtSignal

plugin_image_value = "/nsatt/storage/images/icons/port_scanner_icon.png"

class PortScannerThread(QThread):
    scan_complete = pyqtSignal(str)
    
    def __init__(self, start_port, end_port, interface):
        super().__init__()
        self.start_port = start_port
        self.end_port = end_port
        self.interface = interface
        self.running = True

    def run(self):
        results = []
        if self.interface != "all":
            ip = netifaces.ifaddresses(self.interface)[netifaces.AF_INET][0]['addr']
            results.append(f"Scanning interface {self.interface} ({ip})")
        else:
            results.append("Scanning all interfaces")

        for port in range(self.start_port, self.end_port + 1):
            if not self.running:
                break
                
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.1)
            try:
                result = sock.connect_ex(('127.0.0.1', port))
                if result == 0:
                    try:
                        service = socket.getservbyport(port)
                    except:
                        service = "unknown"
                    results.append(f"Port {port} is open - Service: {service}")
            except:
                pass
            finally:
                sock.close()
                
        self.scan_complete.emit("\n".join(results))

class Plugin:
    NAME = "Port Scanner"
    CATEGORY = "Network" 
    DESCRIPTION = "Scan and monitor local network ports"

    def __init__(self):
        self.widget = None
        self.scanner_thread = None
        self.logger = None
        self.save_dir = None
        self.interfaces = None
        self.selected_interface = None
        self.console = None
        self.iface_combo = None

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            
            logging.basicConfig(level=logging.INFO)
            self.logger = logging.getLogger(__name__)
            
            try:
                self.save_dir = Path.home() / ".blackbird/scans"
                self.save_dir.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                self.logger.error(f"Error creating save directory: {str(e)}")
                self.save_dir = None
                
            self.interfaces = netifaces.interfaces()
            self.selected_interface = "all"
            
            layout = QVBoxLayout()
            self.widget.setLayout(layout)
            
            iface_layout = QHBoxLayout()
            iface_label = QLabel("Interface:")
            self.iface_combo = QComboBox()
            self.iface_combo.addItem("All Interfaces")
            self.iface_combo.addItems(self.interfaces)
            self.iface_combo.currentTextChanged.connect(self.select_interface)
            iface_layout.addWidget(iface_label)
            iface_layout.addWidget(self.iface_combo)
            layout.addLayout(iface_layout)
            
            self.console = QTextEdit()
            self.console.setReadOnly(True)
            layout.addWidget(self.console)
            
            button_layout = QHBoxLayout()
            
            start_btn = QPushButton("Start")
            start_btn.clicked.connect(self.start)
            button_layout.addWidget(start_btn)
            
            stop_btn = QPushButton("Stop")
            stop_btn.clicked.connect(self.stop)
            button_layout.addWidget(stop_btn)
            
            save_btn = QPushButton("Save")
            save_btn.clicked.connect(self.save)
            button_layout.addWidget(save_btn)
            
            common_btn = QPushButton("Common Ports")
            common_btn.clicked.connect(self.scan_common)
            button_layout.addWidget(common_btn)
            
            all_btn = QPushButton("All Ports")
            all_btn.clicked.connect(self.scan_all)
            button_layout.addWidget(all_btn)
            
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
        
    def select_interface(self, interface):
        if interface == "All Interfaces":
            self.selected_interface = "all"
        else:
            self.selected_interface = interface
        self.logger.info(f"Selected interface: {interface}")
        
    def start(self):
        try:
            if self.scanner_thread and self.scanner_thread.isRunning():
                self.logger.warning("Scanner already running")
                return
            self.scan_common()
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
                self.logger.warning("No scanner running")
        except Exception as e:
            self.logger.error(f"Error stopping scan: {str(e)}")
    
    def save(self):
        if not self.save_dir:
            self.logger.error("Save directory not available")
            return
            
        if not self.console.toPlainText():
            self.logger.warning("No scan output to save")
            return
            
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = self.save_dir / f"local_ports_{timestamp}.log"
            
            with open(filename, 'w') as f:
                f.write(self.console.toPlainText())
            self.logger.info(f"Scan results saved to {filename}")
        except Exception as e:
            self.logger.error(f"Error saving scan results: {str(e)}")
    
    def scan_complete(self, results):
        self.console.setText(results)
    
    def scan_common(self):
        try:
            self.console.clear()
            self.console.append("Starting common ports scan...")
            self.scanner_thread = PortScannerThread(1, 1024, self.selected_interface)
            self.scanner_thread.scan_complete.connect(self.scan_complete)
            self.scanner_thread.start()
        except Exception as e:
            self.logger.error(f"Error initiating common ports scan: {str(e)}")
        
    def scan_all(self):
        try:
            self.console.clear() 
            self.console.append("Starting full port scan...")
            self.scanner_thread = PortScannerThread(1, 65535, self.selected_interface)
            self.scanner_thread.scan_complete.connect(self.scan_complete)
            self.scanner_thread.start()
        except Exception as e:
            self.logger.error(f"Error initiating full port scan: {str(e)}")
