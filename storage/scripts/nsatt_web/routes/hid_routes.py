import os
import subprocess
import logging
import sqlite3
from flask import Blueprint, jsonify, request, render_template

# Configure logging to a file
logging.basicConfig(
    filename='/var/log/hid.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

hid_bp = Blueprint('hid', __name__)

# Paths
STORAGE_PATH = "/mnt/usb_storage"
KEYBOARD_SCRIPT_PATH = "/nsatt/storage/scripts/exploits/keyboard_script.sh"
SCRIPTS_DIR = "/nsatt/storage/scripts/"
DB_PATH = '/var/hid_controller.db'

# Ensure the necessary directories exist
os.makedirs(SCRIPTS_DIR, exist_ok=True)

# Initialize the database
def init_db():
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS scripts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL,
                    content TEXT NOT NULL
                )
            ''')
            conn.commit()
        logging.info("Database initialized successfully.")
    except Exception as e:
        logging.error(f"Error initializing database: {e}")
        raise

init_db()

def register_hid_routes(app):
    logging.debug("Registering HID routes.")
    app.register_blueprint(hid_bp, url_prefix='/hid')

def ensure_kernel_module():
    """Ensure the necessary kernel module is loaded and config files are set up."""
    try:
        # Add dtoverlay=dwc2 to /boot/config.txt if not present
        config_line = "dtoverlay=dwc2"
        with open("/boot/config.txt", "r") as f:
            config = f.read()
        if config_line not in config:
            with open("/boot/config.txt", "a") as f:
                f.write(f"\n{config_line}\n")
            logging.info("Added dtoverlay=dwc2 to /boot/config.txt.")

        # Ensure dwc2 module is loaded
        subprocess.run(["modprobe", "dwc2"], check=True)
        logging.info("Loaded dwc2 module.")
    except Exception as e:
        logging.error(f"Error ensuring kernel module: {e}")
        raise

def set_file_permissions(path):
    """Set execute permissions on the specified file."""
    try:
        subprocess.run(['chmod', '+x', path], check=True)
        logging.info(f"Set execute permissions on {path}.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to set permissions for {path}: {e}")
        raise

@hid_bp.route('/status', methods=['GET'])
def hid_status():
    try:
        logging.debug("Fetching HID status.")
        result = subprocess.run(['/nsatt/storage/scripts/exploits/hid_script.sh', 'status'], capture_output=True, text=True, check=False)
        if result.returncode == 0:
            status = result.stdout.strip()
            logging.info(f"HID status: {status}")
            return jsonify({"status": status}), 200
        else:
            logging.error("Failed to fetch HID status.")
            return jsonify({"error": "Failed to fetch HID status"}), 500
    except Exception as e:
        logging.error(f"Error fetching HID status: {e}")
        return jsonify({"error": "Failed to fetch HID status"}), 500
    
@hid_bp.route('/', methods=['GET'])
def hid_index():
    try:
        logging.debug("Accessed HID index page.")
        return render_template('hid.html')
    except Exception as e:
        logging.error(f"Failed to load HID index page: {e}")
        return jsonify({"error": "Failed to load HID index page"}), 500

@hid_bp.route('/switch_mode', methods=['POST'])
def switch_hid_mode():
    mode = request.json.get('mode')
    storage_path = request.json.get('storage_path', '/home/nsatt-admin/nsatt/storage')
    logging.debug(f"Received mode switch request: {mode} with storage path: {storage_path}")
    
    try:
        ensure_kernel_module()
        if mode == 'keyboard':
            result = subprocess.run(['/nsatt/storage/scripts/exploits/hid_script.sh', 'keyboard'], check=False)
            if result.returncode == 0:
                logging.info("Switched to keyboard mode.")
                return jsonify({"message": "Switched to keyboard mode."}), 200
            elif result.returncode == 1:
                logging.info("Keyboard mode is already active.")
                return jsonify({"message": "Keyboard mode is already active."}), 200
            else:
                logging.error("Failed to switch to keyboard mode.")
                return jsonify({"error": "Failed to switch to keyboard mode."}), 500
        elif mode == 'storage':
            result = subprocess.run(['/nsatt/storage/scripts/exploits/hid_script.sh', 'storage', storage_path], check=False)
            if result.returncode == 0:
                logging.info(f"Switched to storage mode with path: {storage_path}.")
                return jsonify({"message": f"Switched to storage mode with path: {storage_path}."}), 200
            elif result.returncode == 1:
                logging.info("Storage mode is already active.")
                return jsonify({"message": "Storage mode is already active."}), 200
            else:
                logging.error("Failed to switch to storage mode.")
                return jsonify({"error": "Failed to switch to storage mode."}), 500
        elif mode == 'off':
            result = subprocess.run(['/nsatt/storage/scripts/exploits/hid_script.sh', 'off'], check=False)
            if result.returncode == 0:
                logging.info("Disabled HID mode.")
                return jsonify({"message": "Disabled HID mode."}), 200
            else:
                logging.error("Failed to disable HID mode.")
                return jsonify({"error": "Failed to disable HID mode."}), 500
        elif mode == 'normal':
            result = subprocess.run(['/nsatt/storage/scripts/exploits/hid_script.sh', 'normal'], check=False)
            if result.returncode == 0:
                logging.info("Switched to normal mode.")
                return jsonify({"message": "Switched to normal mode."}), 200
            else:
                logging.error("Failed to switch to normal mode.")
                return jsonify({"error": "Failed to switch to normal mode."}), 500
        else:
            logging.warning("Invalid mode received.")
            return jsonify({"error": "Invalid mode"}), 400
    except subprocess.CalledProcessError as e:
        logging.error(f"Error switching mode: {e}")
        return jsonify({"error": "Failed to switch mode"}), 500

@hid_bp.route('/select_folder', methods=['POST'])
def select_folder():
    folder_path = request.json.get('folder_path')
    logging.debug(f"Received folder selection request: {folder_path}")
    
    if not folder_path or not os.path.exists(folder_path):
        logging.warning(f"Folder does not exist: {folder_path}")
        return jsonify({"error": "Folder does not exist"}), 400

    try:
        subprocess.run(['mount', '--bind', folder_path, STORAGE_PATH], check=True)
        logging.info(f"Folder {folder_path} selected for USB storage.")
        return jsonify({"message": f"Folder {folder_path} selected for USB storage."}), 200
    except subprocess.CalledProcessError as e:
        logging.error(f"Error selecting folder: {e}")
        return jsonify({"error": "Failed to select folder"}), 500

@hid_bp.route('/select_image', methods=['POST'])
def select_image():
    image_path = request.json.get('image_path')
    logging.debug(f"Received image selection request: {image_path}")
    
    if not image_path or not os.path.exists(image_path):
        logging.warning(f"Image does not exist: {image_path}")
        return jsonify({"error": "Image does not exist"}), 400

    try:
        subprocess.run(['mount', '--bind', image_path, STORAGE_PATH], check=True)
        logging.info(f"Image {image_path} selected for USB storage.")
        return jsonify({"message": f"Image {image_path} selected for USB storage."}), 200
    except subprocess.CalledProcessError as e:
        logging.error(f"Error selecting image: {e}")
        return jsonify({"error": "Failed to select image"}), 500

@hid_bp.route('/set_keyboard_script', methods=['POST'])
def set_keyboard_script():
    script_name = request.json.get('script_name')
    usb_device = request.json.get('usb_device')
    logging.debug(f"Received request to set keyboard script {script_name} for {usb_device}.")

    if not script_name or not usb_device:
        logging.warning("No script name or USB device provided.")
        return jsonify({"error": "No script name or USB device provided"}), 400

    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT content FROM scripts WHERE name=?', (script_name,))
            row = cursor.fetchone()
            if row:
                script_content = row[0]
            else:
                return jsonify({"error": "Script not found"}), 404

        # Write the selected script content into the keyboard script file
        with open(KEYBOARD_SCRIPT_PATH, 'w') as script_file:
            script_file.write(f'#!/bin/bash\n')
            script_file.write(script_content)
        set_file_permissions(KEYBOARD_SCRIPT_PATH)
        logging.info("Keyboard script updated.")
        return jsonify({"message": "Keyboard script updated."}), 200
    except Exception as e:
        logging.error(f"Error updating keyboard script: {e}")
        return jsonify({"error": "Failed to update keyboard script"}), 500

@hid_bp.route('/run_keyboard_script', methods=['POST'])
def run_keyboard_script():
    script_name = request.json.get('script_name')
    usb_device = request.json.get('usb_device')
    logging.debug(f"Running selected script {script_name} on device {usb_device}.")

    if not script_name or not usb_device:
        logging.warning("No script name or USB device provided.")
        return jsonify({"error": "No script name or USB device provided"}), 400

    try:
        # Fetch the script content from the database
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT content FROM scripts WHERE name=?', (script_name,))
            row = cursor.fetchone()
            if row:
                script_content = row[0]
            else:
                return jsonify({"error": "Script not found"}), 404

        # Define the temporary script path
        temp_script_path = f"/tmp/{script_name}.sh"

        # Write the script content to the temporary file
        with open(temp_script_path, 'w') as temp_script_file:
            temp_script_file.write(script_content)
        
        # Ensure the script has execute permissions
        set_file_permissions(temp_script_path)

        # Ensure the device is in keyboard mode
        subprocess.run(['/nsatt/storage/scripts/exploits/hid_script.sh', 'keyboard'], check=True)

        # Execute the temporary script
        subprocess.run(['bash', temp_script_path, usb_device], check=True)
        logging.info(f"Selected script {script_name} executed.")
        return jsonify({"message": f"Selected script {script_name} executed."}), 200
    except subprocess.CalledProcessError as e:
        logging.error(f"Error executing selected script: {e}")
        return jsonify({"error": f"Failed to execute selected script {script_name}"}), 500
    finally:
        # Clean up the temporary script file
        if os.path.exists(temp_script_path):
            os.remove(temp_script_path)

@hid_bp.route('/convert_script', methods=['POST'])
def convert_script():
    script_content = request.json.get('script_content', '')
    logging.debug("Received request to convert script.")
    
    if not script_content:
        logging.warning("No script content provided.")
        return jsonify({"error": "No script content provided"}), 400
    
    try:
        # Initialize the script template
        converted_script = [
            "#!/bin/bash",
            "",
            "LOG_FILE=\"/var/log/keyboard_script.log\"",
            "exec 2>>$LOG_FILE",
            "",
            "DEVICE_PATH=\"/dev/hidg0\"",
            "",
            "send_key() {",
            "    local key=\"$1\"",
            "    echo -ne \"$key\x00\x00\x00\x00\x00\x00\x00\" > $DEVICE_PATH 2>>$LOG_FILE",
            "    sleep 0.1",
            "    echo -ne '\x00\x00\x00\x00\x00\x00\x00\x00' > $DEVICE_PATH 2>>$LOG_FILE",
            "    sleep 0.1",
            "}",
            "",
            "send_combination() {",
            "    local modifier=\"$1\"",
            "    local key=\"$2\"",
            "    echo -ne \"$modifier$key\x00\x00\x00\x00\x00\" > $DEVICE_PATH 2>>$LOG_FILE",
            "    sleep 0.1",
            "    echo -ne '\x00\x00\x00\x00\x00\x00\x00\x00' > $DEVICE_PATH 2>>$LOG_FILE",
            "    sleep 0.1",
            "}"
        ]

        # Define a dictionary for special key codes
        special_keys = {
            'Windows': '\xE3', 'Enter': '\x28', 'Backspace': '\x2A', 'Tab': '\x2B', 'Esc': '\x29',
            'Insert': '\x49', 'Delete': '\x4C', 'Home': '\x4A', 'End': '\x4D', 'PageUp': '\x4B',
            'PageDown': '\x4E', 'RightArrow': '\x4F', 'LeftArrow': '\x50', 'DownArrow': '\x51', 'UpArrow': '\x52',
            'F1': '\x3A', 'F2': '\x3B', 'F3': '\x3C', 'F4': '\x3D', 'F5': '\x3E', 'F6': '\x3F',
            'F7': '\x40', 'F8': '\x41', 'F9': '\x42', 'F10': '\x43', 'F11': '\x44', 'F12': '\x45'
        }

        # Define a dictionary for regular key codes
        keycode_map = {
            'a': '\x04', 'b': '\x05', 'c': '\x06', 'd': '\x07', 'e': '\x08', 'f': '\x09',
            'g': '\x0a', 'h': '\x0b', 'i': '\x0c', 'j': '\x0d', 'k': '\x0e', 'l': '\x0f',
            'm': '\x10', 'n': '\x11', 'o': '\x12', 'p': '\x13', 'q': '\x14', 'r': '\x15',
            's': '\x16', 't': '\x17', 'u': '\x18', 'v': '\x19', 'w': '\x1a', 'x': '\x1b',
            'y': '\x1c', 'z': '\x1d',
            'A': '\x04', 'B': '\x05', 'C': '\x06', 'D': '\x07', 'E': '\x08', 'F': '\x09',
            'G': '\x0a', 'H': '\x0b', 'I': '\x0c', 'J': '\x0d', 'K': '\x0e', 'L': '\x0f',
            'M': '\x10', 'N': '\x11', 'O': '\x12', 'P': '\x13', 'Q': '\x14', 'R': '\x15',
            'S': '\x16', 'T': '\x17', 'U': '\x18', 'V': '\x19', 'W': '\x1a', 'X': '\x1b',
            'Y': '\x1c', 'Z': '\x1d',
            '1': '\x1e', '2': '\x1f', '3': '\x20', '4': '\x21', '5': '\x22', '6': '\x23',
            '7': '\x24', '8': '\x25', '9': '\x26', '0': '\x27',
            ' ': '\x2c', '!': '\x1e', '@': '\x1f', '#': '\x20', '$': '\x21', '%': '\x22',
            '^': '\x23', '&': '\x24', '*': '\x25', '(': '\x26', ')': '\x27', '_': '\x2d',
            '+': '\x2e', '-': '\x2d', '=': '\x2e', '{': '\x2f', '}': '\x30', '[': '\x2f',
            ']': '\x30', '|': '\x31', '\\': '\x31', ':': '\x33', '"': '\x34', ';': '\x33',
            '\'': '\x34', '<': '\x36', '>': '\x37', ',': '\x36', '.': '\x37', '?': '\x38',
            '/': '\x38'
        }

        # Process the script content
        lines = script_content.splitlines()
        for line in lines:
            words = line.split()
            for word in words:
                # If the word is enclosed in brackets, treat it as a special key press
                if word.startswith("[") and word.endswith("]"):
                    key_name = word[1:-1]  # Remove the brackets
                    if key_name in special_keys:
                        if key_name == "Windows":
                            # Send Windows key down and release
                            converted_script.append(f"send_key '\\xE3' '\\x00'  # Windows Key")
                        else:
                            converted_script.append(f"send_key '\\x00\\x00{special_keys[key_name]}\\x00\\x00\\x00\\x00\\x00'  # {key_name}")
                else:
                    # Convert each character in the word
                    for char in word:
                        keycode = keycode_map.get(char, '\\x00')
                        converted_script.append(f"send_key '\\x00\\x00{keycode}\\x00\\x00\\x00\\x00\\x00'  # {char}")

        converted_script_str = '\n'.join(converted_script)
        logging.debug(f"Converted script: {converted_script_str}")
        return jsonify({"converted_script": converted_script_str}), 200
    
    except Exception as e:
        logging.error(f"Error converting script: {e}")
        return jsonify({"error": "Failed to convert script"}), 500

@hid_bp.route('/save_script', methods=['POST'])
def save_script():
    script_content = request.json.get('script_content')
    script_name = request.json.get('script_name', 'custom_script.sh')
    logging.debug(f"Received request to save script as {script_name}.")
    
    if not script_content or script_content.strip() == "":
        logging.warning("No script content provided.")
        return jsonify({"error": "No script content provided"}), 400

    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO scripts (name, content) 
                VALUES (?, ?)
                ON CONFLICT(name) DO UPDATE SET content=excluded.content
            ''', (script_name, script_content))
            conn.commit()
        logging.info(f"Script saved as {script_name}.")
        return jsonify({"message": f"Script saved as {script_name}."}), 200
    except Exception as e:
        logging.error(f"Error saving script: {e}")
        return jsonify({"error": "Failed to save script"}), 500

@hid_bp.route('/files', methods=['GET'])
def list_files():
    directory = request.args.get('directory', '/')
    logging.debug(f"Listing files in directory: {directory}")
    
    try:
        files = os.listdir(directory)
        files = [os.path.join(directory, f) for f in files]
        return jsonify({"files": files}), 200
    except Exception as e:
        logging.error(f"Error listing files: {e}")
        return jsonify({"error": str(e)}), 500

@hid_bp.route('/usb_devices', methods=['GET'])
def list_usb_devices():
    logging.debug("Listing connected USB devices.")
    
    try:
        output = subprocess.getoutput("lsusb")
        devices = []
        
        # Parse the lsusb output and gather detailed info using udevadm or similar tools
        for line in output.splitlines():
            device_info = line.split()
            bus = device_info[1]
            device = device_info[3].rstrip(':')
            id_vendor = device_info[5].split(':')[0]
            id_product = device_info[5].split(':')[1]
            device_name = " ".join(device_info[6:])
            
            # Attempt to get the device path from udev
            try:
                udevadm_output = subprocess.getoutput(f"udevadm info --query=path --name=/dev/bus/usb/{bus}/{device}")
                device_path = udevadm_output.split('/')[-1] if udevadm_output else "Unknown Path"
            except Exception as udev_err:
                logging.error(f"Failed to get device path using udevadm: {udev_err}")
                device_path = "Unknown Path"

            devices.append({
                "bus": bus,
                "device": device,
                "vendor_id": id_vendor,
                "product_id": id_product,
                "device_name": device_name,
                "device_path": device_path
            })

        logging.debug(f"Devices found: {devices}")
        return jsonify({"devices": devices}), 200
    except Exception as e:
        logging.error(f"Error listing USB devices: {e}")
        return jsonify({"error": str(e)}), 500

@hid_bp.route('/load_script', methods=['GET'])
def load_script():
    script_name = request.args.get('script_name')
    logging.debug(f"Received request to load script: {script_name}")
    
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT content FROM scripts WHERE name=?', (script_name,))
            row = cursor.fetchone()
            if row:
                return jsonify({"script_content": row[0]}), 200
            else:
                return jsonify({"error": "Script not found"}), 404
    except Exception as e:
        logging.error(f"Error loading script: {e}")
        return jsonify({"error": "Failed to load script"}), 500

@hid_bp.route('/list_scripts', methods=['GET'])
def list_scripts():
    logging.debug("Listing available scripts.")
    
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT name FROM scripts')
            scripts = [row[0] for row in cursor.fetchall()]
        return jsonify({"scripts": scripts}), 200
    except Exception as e:
        logging.error(f"Error listing scripts: {e}")
        return jsonify({"error": "Failed to list scripts"}), 500
