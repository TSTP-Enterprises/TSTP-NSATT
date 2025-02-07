#!/usr/bin/env python3
import os
import subprocess
import logging
import shutil
import time
from pathlib import Path
from datetime import datetime
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QLabel, QGroupBox, QTextEdit, QFileDialog, QComboBox,
                            QSpinBox, QCheckBox, QMessageBox, QTextEdit, QLineEdit, 
                            QListWidget, QListWidgetItem, QAbstractItemView, QDialog)
from PyQt5.QtCore import pyqtSignal, QThread, Qt

# Create required directories
def ensure_directories():
    dirs = [
        '/nsatt/storage/images/icons',
        '/nsatt/logs/emulation', 
        '/nsatt/storage/emulation/storage',
        '/nsatt/storage/emulation/keyboard_scripts'
    ]
    try:
        for d in dirs:
            Path(d).mkdir(parents=True, exist_ok=True)
            logging.info(f"Created directory: {d}")
    except Exception as e:
        logging.error(f"Failed to create directories: {str(e)}")
        return False
    return True

# Ensure icon exists
plugin_image_path = Path("/nsatt/storage/images/icons/storage_emulation_icon.png") 
if not plugin_image_path.exists():
    try:
        plugin_image_path.touch()
        logging.info(f"Created placeholder icon at {plugin_image_path}")
    except Exception as e:
        logging.error(f"Failed to create icon: {str(e)}")

plugin_image_value = str(plugin_image_path)

class EmulationThread(QThread):
    status_update = pyqtSignal(str)
    device_info = pyqtSignal(dict)
    error_occurred = pyqtSignal(str)
    
    def __init__(self):
        super().__init__()
        self.running = False
        self.process = None
        self.logger = logging.getLogger('EmulationThread')
        
    def run(self):
        self.logger.info("Emulation monitoring thread started")
        while self.running:
            try:
                # Get USB device info
                lsusb_output = subprocess.check_output(['lsusb'], universal_newlines=True)
                devices = {}
                for line in lsusb_output.splitlines():
                    if 'Mass Storage' in line or 'Keyboard' in line or 'Network' in line:
                        bus_id = line.split()[1]
                        dev_id = line.split()[3].rstrip(':')
                        desc = ' '.join(line.split()[6:])
                        dev_type = 'Mass Storage'
                        if 'Keyboard' in line:
                            dev_type = 'Keyboard'
                        elif 'Network' in line:
                            dev_type = 'Network'
                        devices[f"{bus_id}:{dev_id}"] = {
                            'description': desc,
                            'type': dev_type,
                            'status': 'Connected'
                        }
                self.device_info.emit(devices)
                
                # Check gadget status
                status = []
                if os.path.exists('/sys/kernel/config/usb_gadget/pi_storage'):
                    status.append("Storage gadget active")
                    # Check mount status
                    try:
                        mount_output = subprocess.check_output(['mount'], universal_newlines=True)
                        if '/nsatt/storage/emulation/storage' in mount_output:
                            status.append("Storage mounted")
                    except Exception as e:
                        self.logger.error(f"Failed to check mount status: {e}")
                        
                if os.path.exists('/sys/kernel/config/usb_gadget/pi_keyboard'):
                    status.append("Keyboard gadget active")
                    
                if os.path.exists('/sys/kernel/config/usb_gadget/pi_network'):
                    status.append("Network gadget active")
                    # Check network interface status
                    try:
                        ip_output = subprocess.check_output(['ip', 'addr'], universal_newlines=True)
                        if 'usb0' in ip_output:
                            status.append("Network interface up")
                    except Exception as e:
                        self.logger.error(f"Failed to check network status: {e}")
                        
                if not status:
                    status.append("No gadgets active")
                    
                self.status_update.emit(", ".join(status))
                
            except Exception as e:
                error_msg = f"Error in monitoring thread: {str(e)}"
                self.logger.error(error_msg)
                self.error_occurred.emit(error_msg)
                
            time.sleep(1)
            
    def stop(self):
        self.logger.info("Stopping emulation monitoring thread")
        self.running = False
        self.wait()

class Plugin:
    NAME = "USB Emulation"
    CATEGORY = "System"
    DESCRIPTION = "Emulate USB storage, keyboard and network devices"

    def __init__(self):
        self.widget = None
        self.show_console = True  # Show console by default
        self.storage_active = False
        self.keyboard_active = False
        self.network_active = False
        self.selected_storage_path = None
        self.selected_network_interfaces = []
        self.keyboard_script_path = None
        
        # Initialize monitoring thread
        self.emulation_thread = EmulationThread()
        self.emulation_thread.status_update.connect(self.update_status)
        self.emulation_thread.device_info.connect(self.update_device_info)
        self.emulation_thread.error_occurred.connect(self.handle_error)
        
        # Setup logging
        self.log_dir = Path("/nsatt/logs/emulation")
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = self.log_dir / f"usb_emulation_{timestamp}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('usb_emulation')
        self.logger.info("USB Emulation plugin initialized")

        # Create required directories
        self.storage_dir = Path("/nsatt/storage/emulation/storage")
        self.keyboard_scripts_dir = Path("/nsatt/storage/emulation/keyboard_scripts")
        try:
            self.storage_dir.mkdir(parents=True, exist_ok=True)
            self.keyboard_scripts_dir.mkdir(parents=True, exist_ok=True)
            self.logger.info("Created required directories")
        except Exception as e:
            self.logger.error(f"Failed to create directories: {e}")

    def validate_system_requirements(self):
        """Check if required modules and tools are available"""
        try:
            # Check for required kernel modules
            modules = ['dwc2', 'libcomposite']
            for module in modules:
                self.logger.debug(f"Checking for module: {module}")
                result = subprocess.run(['modprobe', '-n', module], 
                                     capture_output=True, text=True)
                if result.returncode != 0:
                    raise Exception(f"Module {module} not available")
                    
            # Check for required tools
            tools = ['dd', 'mkfs.fat', 'mount', 'umount']
            for tool in tools:
                self.logger.debug(f"Checking for tool: {tool}")
                result = subprocess.run(['which', tool], 
                                     capture_output=True, text=True)
                if result.returncode != 0:
                    raise Exception(f"Tool {tool} not found")
                    
            self.logger.info("System requirements validated successfully")
            return True
            
        except Exception as e:
            error_msg = f"System requirements validation failed: {str(e)}"
            self.logger.error(error_msg)
            self.update_status(error_msg)
            return False
        
    def toggle_keyboard(self):
        """Toggle USB keyboard emulation"""
        try:
            if not self.keyboard_active:
                self.logger.info("Starting keyboard emulation...")
                self.update_status("Starting keyboard emulation...")
                
                if not self.setup_keyboard_gadget():
                    raise Exception("Failed to setup keyboard gadget")
                    
                self.keyboard_active = True
                self.keyboard_btn.setStyleSheet("background-color: #90EE90")
                self.keyboard_btn.setText("Keyboard")
                if not self.emulation_thread.running:
                    self.emulation_thread.running = True
                    self.emulation_thread.start()
                self.logger.info("Keyboard emulation started successfully")
                self.update_status("Keyboard emulation started successfully")
            else:
                self.logger.info("Stopping keyboard emulation...")
                self.update_status("Stopping keyboard emulation...")
                
                try:
                    subprocess.run(['rm', '-rf', '/sys/kernel/config/usb_gadget/pi_keyboard'], 
                                check=True, capture_output=True, text=True)
                except subprocess.CalledProcessError as e:
                    raise Exception(f"Failed to cleanup keyboard gadget: {e.stderr}")
                
                self.keyboard_active = False
                self.keyboard_btn.setStyleSheet("background-color: #87CEEB")
                self.keyboard_btn.setText("Keyboard")
                if not (self.storage_active or self.network_active):
                    self.emulation_thread.stop()
                self.logger.info("Keyboard emulation stopped successfully")
                self.update_status("Keyboard emulation stopped successfully")
            return True
        except Exception as e:
            error_msg = f"Failed to toggle keyboard: {str(e)}"
            self.logger.error(error_msg)
            self.update_status(error_msg)
            QMessageBox.critical(self.widget, "Error", error_msg)
            return False

    def setup_keyboard_gadget(self):
        """Configure USB keyboard gadget"""
        self.logger.info("Setting up keyboard gadget...")
        self.update_status("Setting up keyboard gadget...")
        
        try:
            if not self.validate_system_requirements():
                raise Exception("System requirements validation failed")

            # Load required modules
            for module in ['dwc2', 'libcomposite']:
                try:
                    self.logger.info(f"Loading module {module}")
                    subprocess.run(['modprobe', module], check=True, capture_output=True, text=True)
                except subprocess.CalledProcessError as e:
                    raise Exception(f"Failed to load module {module}: {e.stderr}")

            # Create gadget
            gadget_path = Path('/sys/kernel/config/usb_gadget/pi_keyboard')
            try:
                self.logger.info("Creating keyboard gadget directory")
                gadget_path.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                raise Exception(f"Failed to create keyboard gadget directory: {e}")
            
            # Set USB device properties
            try:
                self.logger.info("Setting USB device properties")
                (gadget_path / 'idVendor').write_text('0x0525')
                (gadget_path / 'idProduct').write_text('0xa4a6')
                (gadget_path / 'bcdDevice').write_text('0x0100')
                (gadget_path / 'bcdUSB').write_text('0x0200')
            except Exception as e:
                raise Exception(f"Failed to set USB device properties: {e}")

            # Set strings
            try:
                self.logger.info("Setting USB strings")
                strings_path = gadget_path / 'strings/0x409'
                strings_path.mkdir(parents=True, exist_ok=True)
                (strings_path / 'manufacturer').write_text('NSATT')
                (strings_path / 'product').write_text('Keyboard Gadget')
                (strings_path / 'serialnumber').write_text('123456789')
            except Exception as e:
                raise Exception(f"Failed to set USB strings: {e}")

            # Create configuration
            try:
                self.logger.info("Creating USB configuration")
                config_path = gadget_path / 'configs/c.1'
                config_path.mkdir(parents=True, exist_ok=True)
                config_strings = config_path / 'strings/0x409'
                config_strings.mkdir(parents=True, exist_ok=True)
                (config_strings / 'configuration').write_text('Keyboard')
            except Exception as e:
                raise Exception(f"Failed to create USB configuration: {e}")

            # Create HID function
            try:
                self.logger.info("Creating HID function")
                func_path = gadget_path / 'functions/hid.0'
                func_path.mkdir(parents=True, exist_ok=True)
                (func_path / 'protocol').write_text('1')  # Keyboard
                (func_path / 'subclass').write_text('1')  # Boot interface
                (func_path / 'report_length').write_text('8')
            except Exception as e:
                raise Exception(f"Failed to create HID function: {e}")
            
            # Write HID report descriptor
            try:
                self.logger.info("Writing HID report descriptor")
                report_desc = [
                    0x05, 0x01,  # Usage Page (Generic Desktop)
                    0x09, 0x06,  # Usage (Keyboard)
                    0xa1, 0x01,  # Collection (Application)
                    0x05, 0x07,  # Usage Page (Key Codes)
                    0x19, 0xe0,  # Usage Minimum (224)
                    0x29, 0xe7,  # Usage Maximum (231)
                    0x15, 0x00,  # Logical Minimum (0)
                    0x25, 0x01,  # Logical Maximum (1)
                    0x75, 0x01,  # Report Size (1)
                    0x95, 0x08,  # Report Count (8)
                    0x81, 0x02,  # Input (Data, Variable, Absolute)
                    0x95, 0x01,  # Report Count (1)
                    0x75, 0x08,  # Report Size (8)
                    0x81, 0x03,  # Input (Constant)
                    0x95, 0x06,  # Report Count (6)
                    0x75, 0x08,  # Report Size (8)
                    0x15, 0x00,  # Logical Minimum (0)
                    0x25, 0x65,  # Logical Maximum (101)
                    0x05, 0x07,  # Usage Page (Key Codes)
                    0x19, 0x00,  # Usage Minimum (0)
                    0x29, 0x65,  # Usage Maximum (101)
                    0x81, 0x00,  # Input (Data, Array)
                    0xc0        # End Collection
                ]
                
                with open(func_path / 'report_desc', 'wb') as f:
                    f.write(bytes(report_desc))
            except Exception as e:
                raise Exception(f"Failed to write HID report descriptor: {e}")
            
            # Enable gadget
            try:
                self.logger.info("Enabling keyboard gadget")
                os.symlink(func_path, config_path / 'hid.0')
                (gadget_path / 'UDC').write_text('fe980000.usb')
            except Exception as e:
                raise Exception(f"Failed to enable keyboard gadget: {e}")

            self.logger.info("Keyboard gadget setup completed successfully")
            self.update_status("Keyboard gadget setup completed successfully")
            return True

        except Exception as e:
            error_msg = f"Keyboard gadget setup failed: {str(e)}"
            self.logger.error(error_msg)
            self.update_status(error_msg)
            return False
        
    def setup_storage_gadget(self):
        """Configure USB mass storage gadget"""
        self.logger.info("Setting up storage gadget...")
        self.update_status("Setting up storage gadget...")
        
        try:
            # Validate requirements first
            if not self.validate_system_requirements():
                raise Exception("System requirements validation failed")

            # Load required modules
            for module in ['dwc2', 'libcomposite']:
                try:
                    self.logger.info(f"Loading module {module}")
                    subprocess.run(['modprobe', module], check=True, 
                                capture_output=True, text=True)
                except subprocess.CalledProcessError as e:
                    raise Exception(f"Failed to load {module}: {e.stderr}")

            # Create gadget
            gadget_path = Path('/sys/kernel/config/usb_gadget/pi_storage')
            try:
                self.logger.info(f"Creating gadget directory at {gadget_path}")
                gadget_path.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                raise Exception(f"Failed to create gadget directory: {e}")
            
            # Set vendor and product IDs
            try:
                self.logger.info("Setting vendor/product IDs")
                (gadget_path / 'idVendor').write_text('0x0525')
                (gadget_path / 'idProduct').write_text('0xa4a5')
            except Exception as e:
                raise Exception(f"Failed to set vendor/product IDs: {e}")
            
            # Set strings
            try:
                self.logger.info("Setting USB strings")
                strings_path = gadget_path / 'strings/0x409'
                strings_path.mkdir(parents=True, exist_ok=True)
                (strings_path / 'manufacturer').write_text('NSATT')
                (strings_path / 'product').write_text('Mass Storage Gadget')
                (strings_path / 'serialnumber').write_text('123456789')
            except Exception as e:
                raise Exception(f"Failed to set USB strings: {e}")

            # Create configuration
            try:
                self.logger.info("Creating USB configuration")
                config_path = gadget_path / 'configs/c.1'
                config_path.mkdir(parents=True, exist_ok=True)
                config_strings = config_path / 'strings/0x409'
                config_strings.mkdir(parents=True, exist_ok=True)
                (config_strings / 'configuration').write_text('Mass Storage')
            except Exception as e:
                raise Exception(f"Failed to create USB configuration: {e}")

            # Create function
            try:
                self.logger.info("Creating mass storage function")
                func_path = gadget_path / 'functions/mass_storage.0'
                func_path.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                raise Exception(f"Failed to create mass storage function: {e}")
            
            # Handle storage source
            if self.selected_storage_path:
                if self.selected_storage_path.is_dir():
                    # Create image from directory
                    self.logger.info(f"Creating image from directory {self.selected_storage_path}")
                    backing_file = self.storage_dir / "storage.img"
                    size_mb = sum(f.stat().st_size for f in self.selected_storage_path.rglob('*') 
                                if f.is_file()) // (1024*1024) + 50  # Add 50MB buffer
                    
                    # Create image file
                    subprocess.run(['dd', 'if=/dev/zero', f'of={backing_file}',
                                'bs=1M', f'count={size_mb}'], check=True)
                    
                    # Format image
                    subprocess.run(['mkfs.fat', '-F', '32', str(backing_file)], check=True)
                    
                    # Mount and copy files
                    mount_point = self.storage_dir / "mount"
                    mount_point.mkdir(exist_ok=True)
                    subprocess.run(['mount', str(backing_file), str(mount_point)], check=True)
                    subprocess.run(['cp', '-r', f"{self.selected_storage_path}/*", 
                                str(mount_point)], check=True)
                    subprocess.run(['umount', str(mount_point)], check=True)
                    
                else:
                    # Use existing image file
                    backing_file = self.selected_storage_path
                    
                self.logger.info(f"Using backing file: {backing_file}")
                (func_path / 'lun.0/file').write_text(str(backing_file))
            else:
                raise Exception("No storage source selected")
            
            # Enable gadget
            try:
                self.logger.info("Enabling gadget")
                os.symlink(func_path, config_path / 'mass_storage.0')
                (gadget_path / 'UDC').write_text('fe980000.usb')
            except Exception as e:
                raise Exception(f"Failed to enable gadget: {e}")

            self.logger.info("Storage gadget setup completed successfully")
            self.update_status("Storage gadget setup completed successfully")
            return True

        except Exception as e:
            error_msg = f"Storage gadget setup failed: {str(e)}"
            self.logger.error(error_msg)
            self.update_status(error_msg)
            return False        

    def toggle_storage(self):
        """Toggle USB storage emulation"""
        try:
            if not self.storage_active:
                self.logger.info("Starting storage emulation...")
                self.update_status("Starting storage emulation...")
                
                # Check available storage paths
                has_dir = bool(self.dir_path.text())
                has_img = bool(self.img_path.text())
                
                if has_dir and has_img:
                    # Both paths set - ask user which to use
                    choice = QMessageBox.question(self.widget,
                                               "Storage Source Selection", 
                                               "Use directory as storage source?\n\n" +
                                               f"Directory: {self.dir_path.text()}\n" +
                                               f"Image: {self.img_path.text()}",
                                               QMessageBox.Yes | QMessageBox.No)
                    if choice == QMessageBox.Yes:
                        self.selected_storage_path = Path(self.dir_path.text())
                    else:
                        self.selected_storage_path = Path(self.img_path.text())
                elif has_dir:
                    # Only directory path set
                    self.selected_storage_path = Path(self.dir_path.text())
                elif has_img:
                    # Only image path set
                    self.selected_storage_path = Path(self.img_path.text())
                else:
                    # No paths set - ask user which type to browse for
                    choice = QMessageBox.question(self.widget,
                                               "Storage Source Type",
                                               "Use directory as storage source?",
                                               QMessageBox.Yes | QMessageBox.No)
                    if choice == QMessageBox.Yes:
                        self.select_storage_source()
                    else:
                        dialog = QFileDialog(self.widget)
                        dialog.setFileMode(QFileDialog.ExistingFile)
                        dialog.setNameFilter("Image files (*.img)")
                        if dialog.exec_():
                            self.selected_storage_path = Path(dialog.selectedFiles()[0])
                    
                    if not self.selected_storage_path:
                        raise Exception("No storage source selected")
                
                if not self.setup_storage_gadget():
                    raise Exception("Failed to setup storage gadget")
                    
                self.storage_active = True
                self.storage_btn.setStyleSheet("background-color: #90EE90")
                self.storage_btn.setText("Storage")
                if not self.emulation_thread.running:
                    self.emulation_thread.running = True
                    self.emulation_thread.start()
                self.logger.info("Storage emulation started successfully")
                self.update_status("Storage emulation started successfully")
            else:
                self.logger.info("Stopping storage emulation...")
                self.update_status("Stopping storage emulation...")
                
                # Cleanup storage gadget
                try:
                    subprocess.run(['rm', '-rf', '/sys/kernel/config/usb_gadget/pi_storage'], 
                                check=True, capture_output=True, text=True)
                except subprocess.CalledProcessError as e:
                    raise Exception(f"Failed to cleanup storage gadget: {e.stderr}")
                
                self.storage_active = False
                self.storage_btn.setStyleSheet("background-color: #87CEEB")
                self.storage_btn.setText("Start")
                if not (self.keyboard_active or self.network_active):
                    self.emulation_thread.stop()
                self.logger.info("Storage emulation stopped successfully")
                self.update_status("Storage emulation stopped successfully")
            return True
        except Exception as e:
            error_msg = f"Failed to toggle storage: {str(e)}"
            self.logger.error(error_msg)
            self.update_status(error_msg)
            QMessageBox.critical(self.widget, "Error", error_msg)
            return False
        
    def select_storage_source(self):
        """Prompt user to select storage source"""
        dialog = QFileDialog(self.widget)
        dialog.setFileMode(QFileDialog.Directory)
        dialog.setOption(QFileDialog.ShowDirsOnly, True)
        dialog.setWindowTitle("Select Storage Source")
        
        if dialog.exec_():
            selected = dialog.selectedFiles()[0]
            self.selected_storage_path = Path(selected)
            self.logger.info(f"Selected storage source: {self.selected_storage_path}")
            self.update_status(f"Selected storage source: {self.selected_storage_path}")

    def toggle_network(self):
        """Toggle USB network adapter emulation"""
        try:
            if not self.network_active:
                self.logger.info("Starting network adapter emulation...")
                self.update_status("Starting network adapter emulation...")
                
                # Get available network interfaces if none selected
                if not self.selected_network_interfaces:
                    interfaces = self.get_network_interfaces()
                    if not interfaces:
                        raise Exception("No network interfaces available")
                    
                    self.select_network_interfaces(interfaces)
                    if not self.selected_network_interfaces:
                        raise Exception("No network interfaces selected")
                
                # Enable network sharing for selected interfaces
                for interface in self.selected_network_interfaces:
                    self.enable_network_sharing(interface)
                
                self.network_active = True
                self.network_btn.setStyleSheet("background-color: #90EE90")
                self.network_btn.setText("Network")
                if not self.emulation_thread.running:
                    self.emulation_thread.running = True
                    self.emulation_thread.start()
                self.logger.info("Network adapter emulation started successfully")
                self.update_status("Network adapter emulation started successfully")
            else:
                self.logger.info("Stopping network adapter emulation...")
                self.update_status("Stopping network adapter emulation...")
                
                # Disable network sharing
                for interface in self.selected_network_interfaces:
                    self.disable_network_sharing(interface)
                
                self.network_active = False
                self.network_btn.setStyleSheet("background-color: #87CEEB")
                self.network_btn.setText("Network")
                if not (self.storage_active or self.keyboard_active):
                    self.emulation_thread.stop()
                self.logger.info("Network adapter emulation stopped successfully")
                self.update_status("Network adapter emulation stopped successfully")
            return True
        except Exception as e:
            error_msg = f"Failed to toggle network: {str(e)}"
            self.logger.error(error_msg)
            self.update_status(error_msg)
            QMessageBox.critical(self.widget, "Error", error_msg)
            return False

    def get_network_interfaces(self):
        """Get list of available network interfaces"""
        try:
            output = subprocess.check_output(['ip', 'link', 'show'], 
                                          universal_newlines=True)
            interfaces = []
            for line in output.splitlines():
                if ':' in line:
                    interface = line.split(':')[1].strip()
                    if interface not in ['lo', 'usb0']:
                        interfaces.append(interface)
            return interfaces
        except Exception as e:
            self.logger.error(f"Failed to get network interfaces: {e}")
            return []

    def select_network_interfaces(self, interfaces):
        """Let user select network interfaces to share"""
        dialog = QDialog(self.widget)
        dialog.setWindowTitle("Select Network Interfaces")
        layout = QVBoxLayout()

        # Add checkboxes for each interface
        checkboxes = []
        for interface in interfaces:
            checkbox = QCheckBox(interface)
            checkboxes.append(checkbox)
            layout.addWidget(checkbox)

        # Add OK/Cancel buttons
        button_box = QHBoxLayout()
        ok_button = QPushButton("OK")
        cancel_button = QPushButton("Cancel")
        
        ok_button.clicked.connect(dialog.accept)
        cancel_button.clicked.connect(dialog.reject)
        
        button_box.addWidget(ok_button)
        button_box.addWidget(cancel_button)
        layout.addLayout(button_box)

        dialog.setLayout(layout)

        if dialog.exec_():
            # Get selected interfaces
            self.selected_network_interfaces = [
                cb.text() for cb in checkboxes if cb.isChecked()
            ]
            if not self.selected_network_interfaces:
                self.logger.warning("No network interfaces selected")
                QMessageBox.warning(self.widget, "Warning", 
                                  "No network interfaces selected. Please select at least one.")
                return self.select_network_interfaces(interfaces)
            
            self.logger.info(f"Selected network interfaces: {self.selected_network_interfaces}")
        else:
            self.logger.info("Network interface selection cancelled")
            self.selected_network_interfaces = []

    def enable_network_sharing(self, interface):
        """Enable network sharing for given interface"""
        try:
            # Check if sharing is already enabled
            check = subprocess.run(['iptables', '-t', 'nat', '-C', 'POSTROUTING',
                                  '-o', interface, '-j', 'MASQUERADE'],
                                 capture_output=True)
            
            if check.returncode == 0:
                self.logger.info(f"Network sharing already enabled for {interface}")
                return
                
            # Enable IP forwarding
            subprocess.run(['sysctl', 'net.ipv4.ip_forward=1'], check=True)
            
            # Configure iptables for NAT
            subprocess.run(['iptables', '-t', 'nat', '-A', 'POSTROUTING', 
                          '-o', interface, '-j', 'MASQUERADE'], check=True)
            
            self.logger.info(f"Enabled network sharing for {interface}")
        except Exception as e:
            raise Exception(f"Failed to enable network sharing: {e}")

    def disable_network_sharing(self, interface):
        """Disable network sharing for given interface"""
        try:
            # Check if sharing is enabled before trying to remove
            check = subprocess.run(['iptables', '-t', 'nat', '-C', 'POSTROUTING',
                                  '-o', interface, '-j', 'MASQUERADE'],
                                 capture_output=True)
            
            if check.returncode != 0:
                self.logger.info(f"Network sharing already disabled for {interface}")
                return
                
            # Remove iptables rules
            subprocess.run(['iptables', '-t', 'nat', '-D', 'POSTROUTING', 
                          '-o', interface, '-j', 'MASQUERADE'], check=True)
            
            # Disable IP forwarding if no interfaces are being shared
            if not self.network_active:
                subprocess.run(['sysctl', 'net.ipv4.ip_forward=0'], check=True)
            
            self.logger.info(f"Disabled network sharing for {interface}")
        except Exception as e:
            self.logger.error(f"Failed to disable network sharing: {e}")
            raise Exception(f"Failed to disable network sharing: {e}")

    def update_status(self, status):
        """Update status in console"""
        if self.console:
            self.console.append(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {status}")
            # Scroll to bottom
            self.console.verticalScrollBar().setValue(
                self.console.verticalScrollBar().maximum()
            )
            
    def handle_error(self, error):
        """Handle errors from emulation thread"""
        self.logger.error(error)
        self.update_status(f"ERROR: {error}")
        QMessageBox.critical(self.widget, "Error", error)
            
    def update_device_info(self, devices):
        """Update device information display"""
        if self.device_info_text:
            info = "Connected USB Devices:\n\n"
            for dev_id, details in devices.items():
                info += f"Device {dev_id}:\n"
                info += f"  Description: {details['description']}\n"
                info += f"  Type: {details['type']}\n"
                info += f"  Status: {details['status']}\n\n"
            self.device_info_text.setText(info)

    def toggle_console(self):
        """Toggle console visibility"""
        self.show_console = not self.show_console
        if self.show_console:
            self.console.show()
            self.console_btn.setText("Console")
            self.console_btn.setStyleSheet("background-color: #90EE90")  # Light green
        else:
            self.console.hide()
            self.console_btn.setText("Console") 
            self.console_btn.setStyleSheet("background-color: #FFB6B6")  # Light red

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            layout = QVBoxLayout()
            
            # Basic controls
            basic_group = QGroupBox("USB Gadget Controls")
            basic_layout = QVBoxLayout()
            
            # Top row of buttons
            top_row = QHBoxLayout()
            
            self.storage_btn = QPushButton("Storage")
            self.storage_btn.setStyleSheet("background-color: #87CEEB")
            self.storage_btn.clicked.connect(self.toggle_storage)
            top_row.addWidget(self.storage_btn)
            
            self.keyboard_btn = QPushButton("Keyboard")
            self.keyboard_btn.setStyleSheet("background-color: #87CEEB")
            self.keyboard_btn.clicked.connect(self.toggle_keyboard)
            top_row.addWidget(self.keyboard_btn)

            self.network_btn = QPushButton("Network")
            self.network_btn.setStyleSheet("background-color: #87CEEB")
            self.network_btn.clicked.connect(self.toggle_network)
            top_row.addWidget(self.network_btn)
            
            self.console_btn = QPushButton("Console")
            self.console_btn.clicked.connect(self.toggle_console)
            top_row.addWidget(self.console_btn)
            
            self.advanced_btn = QPushButton("Advanced")
            self.advanced_btn.clicked.connect(self.toggle_advanced)
            top_row.addWidget(self.advanced_btn)
            
            basic_layout.addLayout(top_row)
            
            # Device info display
            self.device_info_text = QTextEdit()
            self.device_info_text.setReadOnly(True)
            self.device_info_text.setMaximumHeight(150)
            basic_layout.addWidget(self.device_info_text)
            
            # Console output
            self.console = QTextEdit()
            self.console.setReadOnly(True)
            self.console.setMinimumHeight(200)
            basic_layout.addWidget(self.console)
            
            basic_group.setLayout(basic_layout)
            layout.addWidget(basic_group)

            # Advanced controls
            self.advanced_group = QGroupBox("Advanced Settings")
            advanced_layout = QVBoxLayout()

            # Storage settings
            storage_settings = QGroupBox("Storage Settings")
            storage_layout = QVBoxLayout()

            # Directory selection
            dir_layout = QHBoxLayout()
            dir_label = QLabel("Storage Directory:")
            self.dir_path = QLineEdit("/nsatt/storage/www")
            dir_browse = QPushButton("Browse")
            dir_browse.clicked.connect(lambda: self.browse_path(self.dir_path, True))
            dir_layout.addWidget(dir_label)
            dir_layout.addWidget(self.dir_path)
            dir_layout.addWidget(dir_browse)
            storage_layout.addLayout(dir_layout)

            # Image file selection  
            img_layout = QHBoxLayout()
            img_label = QLabel("Image File:")
            self.img_path = QLineEdit("/nsatt/storage/emulation/emulation.img")
            img_browse = QPushButton("Browse")
            img_browse.clicked.connect(lambda: self.browse_path(self.img_path, False))
            img_layout.addWidget(img_label)
            img_layout.addWidget(self.img_path)
            img_layout.addWidget(img_browse)
            storage_layout.addLayout(img_layout)

            storage_settings.setLayout(storage_layout)
            advanced_layout.addWidget(storage_settings)

            # Keyboard settings
            keyboard_settings = QGroupBox("Keyboard Settings")
            keyboard_layout = QVBoxLayout()

            script_layout = QHBoxLayout()
            script_label = QLabel("Keyboard Script:")
            self.script_combo = QComboBox()
            self.script_combo.addItems(self.get_keyboard_scripts())
            send_script = QPushButton("Send Script")
            send_script.clicked.connect(self.send_keyboard_script)
            script_layout.addWidget(script_label)
            script_layout.addWidget(self.script_combo)
            script_layout.addWidget(send_script)
            keyboard_layout.addLayout(script_layout)

            keyboard_settings.setLayout(keyboard_layout)
            advanced_layout.addWidget(keyboard_settings)

            # Network settings
            network_settings = QGroupBox("Network Settings")
            network_layout = QVBoxLayout()

            self.interface_list = QListWidget()
            self.interface_list.setSelectionMode(QAbstractItemView.MultiSelection)
            self.update_network_interfaces()
            network_layout.addWidget(QLabel("Available Network Interfaces:"))
            network_layout.addWidget(self.interface_list)

            network_settings.setLayout(network_layout)
            advanced_layout.addWidget(network_settings)

            self.advanced_group.setLayout(advanced_layout)
            self.advanced_group.hide()
            layout.addWidget(self.advanced_group)
            
            self.widget.setLayout(layout)
            
            # Start monitoring thread
            self.emulation_thread.running = True
            self.emulation_thread.start()
            
            # Initial status update
            self.update_status("USB Gadget Emulation plugin initialized")
            
        return self.widget

    def toggle_advanced(self):
        """Toggle visibility of advanced settings"""
        if self.advanced_group.isVisible():
            self.advanced_group.hide()
            self.advanced_btn.setText("Advanced")
            self.advanced_btn.setStyleSheet("color: #000000")
            self.advanced_btn.setStyleSheet("background-color: #FFB6B6")  # Light red
        else:
            self.advanced_group.show()
            self.advanced_btn.setText("Advanced") 
            self.advanced_btn.setStyleSheet("color: #000000")
            self.advanced_btn.setStyleSheet("background-color: #90EE90")  # Light green

    def browse_path(self, line_edit, is_dir=False):
        """Open file browser dialog and update line edit with selected path"""
        dialog = QFileDialog(self.widget)
        if is_dir:
            dialog.setFileMode(QFileDialog.Directory)
            dialog.setOption(QFileDialog.ShowDirsOnly, True)
        else:
            dialog.setFileMode(QFileDialog.ExistingFile)
        
        if dialog.exec_():
            selected = dialog.selectedFiles()[0]
            line_edit.setText(selected)
            self.logger.info(f"Selected path: {selected}")

    def get_keyboard_scripts(self):
        """Get list of available keyboard scripts"""
        try:
            scripts = []
            script_dir = Path("/nsatt/storage/emulation/keyboard_scripts")
            if script_dir.exists():
                for script in script_dir.glob("*.txt"):
                    scripts.append(script.name)
            return scripts
        except Exception as e:
            self.logger.error(f"Failed to get keyboard scripts: {e}")
            return []

    def send_keyboard_script(self):
        """Send selected keyboard script"""
        try:
            script_name = self.script_combo.currentText()
            if not script_name:
                raise Exception("No script selected")
                
            script_path = Path("/nsatt/storage/emulation/keyboard_scripts") / script_name
            if not script_path.exists():
                raise Exception(f"Script file not found: {script_path}")
                
            # TODO: Implement keyboard script sending logic
            self.logger.info(f"Sending keyboard script: {script_name}")
            self.update_status(f"Sending keyboard script: {script_name}")
            
        except Exception as e:
            error_msg = f"Failed to send keyboard script: {e}"
            self.logger.error(error_msg)
            self.update_status(error_msg)
            QMessageBox.critical(self.widget, "Error", error_msg)

    def update_network_interfaces(self):
        """Update list of available network interfaces"""
        try:
            self.interface_list.clear()
            interfaces = self.get_network_interfaces()
            for interface in interfaces:
                item = QListWidgetItem(interface)
                if interface in self.selected_network_interfaces:
                    item.setSelected(True)
                self.interface_list.addItem(item)
        except Exception as e:
            self.logger.error(f"Failed to update network interfaces: {e}")
