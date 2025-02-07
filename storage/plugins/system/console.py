#!/usr/bin/env python3
import logging
from pathlib import Path
from datetime import datetime
import subprocess
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QTextEdit, QTabWidget, QLineEdit)
from PyQt5.QtCore import Qt

plugin_image_value = "/nsatt/storage/images/icons/console_icon.png"

class ConsoleTab(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout()
        
        # Console output
        self.console = QTextEdit()
        self.console.setReadOnly(True)
        self.console.setMinimumHeight(140)
        layout.addWidget(self.console)
        
        # Input area
        input_layout = QHBoxLayout()
        
        self.input = QLineEdit()
        self.input.returnPressed.connect(self.send_command)
        input_layout.addWidget(self.input)
        
        send_btn = QPushButton("Send")
        send_btn.clicked.connect(self.send_command)
        input_layout.addWidget(send_btn)
        
        ctrl_c_btn = QPushButton("Ctrl+C")
        ctrl_c_btn.clicked.connect(self.send_ctrl_c)
        input_layout.addWidget(ctrl_c_btn)
        
        ctrl_z_btn = QPushButton("Ctrl+Z") 
        ctrl_z_btn.clicked.connect(self.send_ctrl_z)
        input_layout.addWidget(ctrl_z_btn)
        
        layout.addLayout(input_layout)
        self.setLayout(layout)
        
        # Initialize process
        self.process = subprocess.Popen(['bash'], 
                                      stdin=subprocess.PIPE,
                                      stdout=subprocess.PIPE,
                                      stderr=subprocess.PIPE,
                                      shell=True,
                                      text=True)

    def send_command(self):
        cmd = self.input.text() + '\n'
        self.process.stdin.write(cmd)
        self.process.stdin.flush()
        self.console.append(f"$ {cmd}")
        self.input.clear()
        
        # Get output
        output = self.process.stdout.readline()
        self.console.append(output)
        
    def send_ctrl_c(self):
        self.process.send_signal(2) # SIGINT
        self.console.append("^C")
        
    def send_ctrl_z(self):
        self.process.send_signal(20) # SIGTSTP
        self.console.append("^Z")

class Plugin:
    NAME = "Console"
    CATEGORY = "System"
    DESCRIPTION = "Interactive system console"

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        
        # Setup logging
        log_dir = Path("/nsatt/logs/system/console")
        if not log_dir.exists():
            log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"console_{timestamp}.log"

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            layout = QVBoxLayout()
            
            # Tab controls
            btn_layout = QHBoxLayout()
            
            new_tab_btn = QPushButton("New Console")
            new_tab_btn.clicked.connect(self.add_tab)
            btn_layout.addWidget(new_tab_btn)
            
            close_tab_btn = QPushButton("Close Console")
            close_tab_btn.clicked.connect(self.close_tab)
            btn_layout.addWidget(close_tab_btn)
            
            layout.addLayout(btn_layout)
            
            # Tab widget
            self.tabs = QTabWidget()
            self.tabs.setTabsClosable(True)
            self.tabs.tabCloseRequested.connect(self.close_tab)
            layout.addWidget(self.tabs)
            
            # Add initial tab
            self.add_tab()
            
            self.widget.setLayout(layout)
            
        return self.widget
        
    def add_tab(self):
        """Add new console tab"""
        new_tab = ConsoleTab()
        self.tabs.addTab(new_tab, f"Console {self.tabs.count() + 1}")
        
    def close_tab(self, index=None):
        """Close specified tab or current tab if none specified"""
        if index is None:
            index = self.tabs.currentIndex()
        if self.tabs.count() > 1:  # Keep at least one tab
            self.tabs.removeTab(index)
