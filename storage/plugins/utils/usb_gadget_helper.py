#!/usr/bin/env python3
import os
import subprocess
import logging
from pathlib import Path

class USBGadgetHelper:
    @staticmethod
    def check_system_config():
        """Check system configuration for USB gadget support"""
        issues = []
        
        # Check dtoverlay in config.txt
        try:
            with open('/boot/config.txt', 'r') as f:
                config = f.read()
                if 'dtoverlay=dwc2' not in config:
                    issues.append("dtoverlay=dwc2 missing from /boot/config.txt")
        except Exception as e:
            issues.append(f"Failed to check config.txt: {e}")

        # Check modules in /etc/modules
        try:
            with open('/etc/modules', 'r') as f:
                modules = f.read()
                if 'dwc2' not in modules:
                    issues.append("dwc2 module not loaded in /etc/modules")
                if 'libcomposite' not in modules:
                    issues.append("libcomposite module not loaded in /etc/modules")
        except Exception as e:
            issues.append(f"Failed to check /etc/modules: {e}")

        # Check cmdline.txt for modules-load
        try:
            with open('/boot/cmdline.txt', 'r') as f:
                cmdline = f.read()
                if 'modules-load=dwc2,libcomposite' not in cmdline:
                    issues.append("modules-load=dwc2,libcomposite missing from cmdline.txt")
        except Exception as e:
            issues.append(f"Failed to check cmdline.txt: {e}")

        # Check if required modules are available
        required_modules = ['dwc2', 'libcomposite', 'g_mass_storage', 'g_ether']
        for module in required_modules:
            try:
                result = subprocess.run(['modprobe', '-n', module], 
                                     capture_output=True, text=True)
                if result.returncode != 0:
                    issues.append(f"Module {module} not available")
            except Exception as e:
                issues.append(f"Failed to check module {module}: {e}")

        return issues

    @staticmethod
    def fix_system_config():
        """Attempt to fix system configuration issues"""
        try:
            # Backup original files
            for file in ['/boot/config.txt', '/etc/modules', '/boot/cmdline.txt']:
                if os.path.exists(file):
                    subprocess.run(['sudo', 'cp', file, f"{file}.backup"], check=True)

            # Update config.txt
            with open('/boot/config.txt', 'a') as f:
                f.write('\ndtoverlay=dwc2\n')

            # Update modules
            with open('/etc/modules', 'a') as f:
                f.write('dwc2\nlibcomposite\n')

            # Update cmdline.txt
            with open('/boot/cmdline.txt', 'r') as f:
                cmdline = f.read().strip()
            with open('/boot/cmdline.txt', 'w') as f:
                f.write(f"{cmdline} modules-load=dwc2,libcomposite")

            return True, "System configuration updated. Please reboot to apply changes."
        except Exception as e:
            return False, f"Failed to fix system configuration: {e}"

    @staticmethod
    def check_usb_gadget_state():
        """Check current USB gadget state"""
        state = {
            'gadget_active': False,
            'current_mode': None,
            'connected_device': None,
            'errors': []
        }

        try:
            # Check for active gadget configurations
            gadget_path = Path('/sys/kernel/config/usb_gadget')
            if gadget_path.exists():
                gadgets = list(gadget_path.glob('*'))
                if gadgets:
                    state['gadget_active'] = True
                    state['current_mode'] = gadgets[0].name

            # Check USB connection state
            if Path('/sys/class/udc').glob('*'):
                try:
                    # Try to get connected device info
                    usb_info = subprocess.check_output(['lsusb'], text=True)
                    for line in usb_info.split('\n'):
                        if 'Windows' in line or 'Microsoft' in line:
                            state['connected_device'] = line.strip()
                            break
                except Exception as e:
                    state['errors'].append(f"Failed to get USB device info: {e}")

        except Exception as e:
            state['errors'].append(f"Failed to check gadget state: {e}")

        return state

    @staticmethod
    def cleanup_gadget():
        """Clean up any existing USB gadget configuration"""
        try:
            # Remove all gadget configurations
            gadget_path = Path('/sys/kernel/config/usb_gadget')
            if gadget_path.exists():
                for gadget in gadget_path.glob('*'):
                    subprocess.run(['sudo', 'rm', '-rf', str(gadget)], check=True)

            # Unload gadget modules
            modules = ['g_mass_storage', 'g_ether', 'g_hid', 'dwc2']
            for module in modules:
                subprocess.run(['sudo', 'modprobe', '-r', module], 
                             check=False, capture_output=True)

            return True, "USB gadget cleanup successful"
        except Exception as e:
            return False, f"Failed to cleanup USB gadget: {e}"

    @staticmethod
    def setup_gadget_mode(mode='mass_storage', storage_file=None):
        """Configure USB gadget with specified mode"""
        try:
            # Cleanup existing gadget configuration
            USBGadgetHelper.cleanup_gadget()
            
            # Create configfs structure
            gadget_path = Path('/sys/kernel/config/usb_gadget/pi_gadget')
            gadget_path.mkdir(parents=True, exist_ok=True)
            
            # Set USB device identifiers
            (gadget_path / 'idVendor').write_text('0x0525')   # Raspberry Pi vendor ID
            (gadget_path / 'idProduct').write_text('0xa4a5')  # Arbitrary product ID
            (gadget_path / 'bcdDevice').write_text('0x0100')  # Device version
            (gadget_path / 'bcdUSB').write_text('0x0200')     # USB 2.0
            
            # Set English (US) strings
            strings_path = gadget_path / 'strings/0x409'
            strings_path.mkdir(parents=True, exist_ok=True)
            (strings_path / 'serialnumber').write_text('000000000a')
            (strings_path / 'manufacturer').write_text('NSATT')
            (strings_path / 'product').write_text('Pi Zero USB Gadget')
            
            # Create configuration
            config_path = gadget_path / 'configs/c.1'
            config_path.mkdir(parents=True, exist_ok=True)
            config_strings = config_path / 'strings/0x409'
            config_strings.mkdir(parents=True, exist_ok=True)
            (config_strings / 'configuration').write_text('Config 1')
            
            # Setup based on mode
            if mode == 'mass_storage':
                if not storage_file:
                    storage_file = '/piusb.bin'
                    # Create storage file if it doesn't exist
                    if not Path(storage_file).exists():
                        subprocess.run(['dd', 'if=/dev/zero', 'of=' + storage_file, 
                                     'bs=1M', 'count=64'], check=True)
                        subprocess.run(['mkfs.fat', '-F', '32', storage_file], check=True)
                
                # Create mass storage function
                func_path = gadget_path / 'functions/mass_storage.usb0'
                func_path.mkdir(parents=True, exist_ok=True)
                (func_path / 'stall').write_text('0')
                (func_path / 'lun.0/cdrom').write_text('0')
                (func_path / 'lun.0/ro').write_text('0')
                (func_path / 'lun.0/file').write_text(storage_file)
                
                # Create symlink
                os.symlink(func_path, config_path / 'mass_storage.usb0')
                
            elif mode == 'ethernet':
                # Create ECM function (USB ethernet)
                func_path = gadget_path / 'functions/ecm.usb0'
                func_path.mkdir(parents=True, exist_ok=True)
                
                # Create symlink
                os.symlink(func_path, config_path / 'ecm.usb0')
            
            # Find UDC driver (usually there's only one)
            udc = next(Path('/sys/class/udc').iterdir()).name
            (gadget_path / 'UDC').write_text(udc)
            
            return True, "Gadget mode configured successfully"
            
        except Exception as e:
            return False, f"Failed to setup gadget mode: {e}"

    @staticmethod
    def get_available_usb_ports():
        """Get list of available USB ports on Pi"""
        ports = []
        try:
            # Check USB host ports
            for device in Path('/sys/bus/usb/devices').glob('usb*'):
                try:
                    # Read device information
                    manufacturer = (device / 'manufacturer').read_text().strip() if (device / 'manufacturer').exists() else "Unknown"
                    product = (device / 'product').read_text().strip() if (device / 'product').exists() else "USB Port"
                    
                    ports.append({
                        'path': str(device),
                        'name': f"{manufacturer} {product}",
                        'type': 'host',
                        'in_use': any(device.glob('*-port*/driver'))
                    })
                except Exception as e:
                    logging.debug(f"Error reading USB device {device}: {e}")
            
            # Check OTG port
            otg_path = Path('/sys/class/udc')
            if otg_path.exists() and any(otg_path.iterdir()):
                ports.append({
                    'path': str(otg_path),
                    'name': 'USB OTG Port',
                    'type': 'otg',
                    'in_use': True
                })
            
            return ports
        except Exception as e:
            logging.error(f"Failed to get USB ports: {e}")
            return []

    @staticmethod
    def is_pi_zero():
        """Check if running on a Pi Zero"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read()
                return any(model in cpuinfo for model in ['Zero', 'zero'])
        except:
            return False

    @staticmethod
    def get_connected_devices():
        """Get information about connected USB devices"""
        devices = []
        try:
            # Get USB device info using lsusb
            output = subprocess.check_output(['lsusb', '-v'], text=True, stderr=subprocess.DEVNULL)
            current_device = {}
            
            for line in output.split('\n'):
                if line.startswith('Bus'):
                    if current_device:
                        devices.append(current_device)
                    current_device = {
                        'bus_info': line.strip(),
                        'manufacturer': 'Unknown',
                        'product': 'Unknown',
                        'serial': 'Unknown'
                    }
                elif 'iManufacturer' in line:
                    current_device['manufacturer'] = line.split('iManufacturer')[-1].strip()
                elif 'iProduct' in line:
                    current_device['product'] = line.split('iProduct')[-1].strip()
                elif 'iSerial' in line:
                    current_device['serial'] = line.split('iSerial')[-1].strip()
            
            if current_device:
                devices.append(current_device)
                
            return devices
        except Exception as e:
            logging.error(f"Failed to get connected devices: {e}")
            return [] 