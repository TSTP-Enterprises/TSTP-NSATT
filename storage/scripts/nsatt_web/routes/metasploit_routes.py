import logging
import os
import sqlite3
import re
import socket
from flask import Blueprint, render_template, request, redirect, url_for, flash, jsonify
import time
from pymetasploit3.msfrpc import MsfRpcClient

# Configure logging
logging.basicConfig(filename='metasploit.log', level=logging.DEBUG, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

metasploit_bp = Blueprint('metasploit', __name__)
db_path = 'db/metasploit.db'

rpc_client = None

def init_db():
    if not os.path.exists('db'):
        os.makedirs('db')
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS sessions 
                 (id INTEGER PRIMARY KEY, start_time TEXT, end_time TEXT, console_output TEXT)''')
    # Create table to store msfconsole state
    c.execute('''CREATE TABLE IF NOT EXISTS msfconsole_state
                 (id INTEGER PRIMARY KEY, state TEXT)''')
    # Initialize msfconsole state to 'stopped' if not already present
    c.execute('INSERT OR IGNORE INTO msfconsole_state (id, state) VALUES (1, "stopped")')
    conn.commit()
    conn.close()

init_db()

def is_rpc_server_running():
    try:
        with socket.create_connection(("127.0.0.1", 55553), timeout=5):
            return True
    except Exception as e:
        logging.error(f"RPC server is not running: {e}")
        return False

def init_msf_rpc_client():
    global rpc_client
    if not is_rpc_server_running():
        logging.error("MSF RPC server is not running. Please start msfrpcd first.")
        return False
        
    try:
        # Initialize the RPC client with the correct password
        rpc_client = MsfRpcClient('ChangeMe!', port=55553, ssl=False)
        logging.info("MSF RPC client initialized successfully")
        return True
    except Exception as e:
        logging.error(f"Failed to initialize MSF RPC client: {e}")
        rpc_client = None
        return False

def register_metasploit_routes(app):
    app.register_blueprint(metasploit_bp, url_prefix='/metasploit')

def start_msfconsole():
    if not rpc_client:
        if not init_msf_rpc_client():
            logging.error("MSF RPC client not initialized. Ensure msfrpcd is running.")
            return False
            
    try:
        console = rpc_client.consoles.console()
        console_id = console.cid
        logging.info(f"MSFConsole started successfully with console ID: {console_id}")
        
        conn = sqlite3.connect(db_path)
        c = conn.cursor()
        c.execute('INSERT INTO sessions (start_time, console_output) VALUES (datetime("now"), "")')
        conn.commit()
        conn.close()
        
        set_msfconsole_state('started')
        return True
    except Exception as e:
        logging.error(f"Error starting MSFConsole: {e}")
        return False

def stop_msfconsole():
    if not rpc_client:
        logging.error("MSF RPC client not initialized")
        return False
        
    try:
        for console in rpc_client.consoles.list:
            rpc_client.consoles.console(console['id']).destroy()
        logging.info("Stopped MSFConsole")
        
        conn = sqlite3.connect(db_path)
        c = conn.cursor()
        c.execute('UPDATE sessions SET end_time = datetime("now") WHERE end_time IS NULL')
        conn.commit()
        conn.close()
        
        set_msfconsole_state('stopped')
        return True
    except Exception as e:
        logging.error(f"Error stopping MSFConsole: {e}")
        return False

def is_msfconsole_running():
    if not rpc_client:
        return False
        
    try:
        consoles = rpc_client.call('console.list')['consoles']
        return any(console['busy'] for console in consoles)
    except Exception as e:
        logging.error(f"Error checking MSFConsole status: {e}")
        return False

@metasploit_bp.route('/')
def index():
    try:
        logging.debug("Metasploit index page accessed")
        msfconsole_running = is_msfconsole_running()
        rpc_server_running = is_rpc_server_running()
        return render_template('metasploit/index.html', 
                             msfconsole_running=msfconsole_running,
                             rpc_server_running=rpc_server_running)
    except Exception as e:
        logging.exception("Error rendering Metasploit index page")
        flash('An error occurred while loading the Metasploit page.', 'danger')
        return redirect(url_for('index'))

@metasploit_bp.route('/toggle_msfconsole', methods=['POST'])
def toggle_msfconsole():
    try:
        if not is_rpc_server_running():
            return jsonify({"status": "error", "message": "RPC server is not running"})
            
        if is_msfconsole_running():
            stop_msfconsole()
            return jsonify({"status": "stopped"})
        else:
            success = start_msfconsole()
            return jsonify({"status": "started" if success else "error"})
    except Exception as e:
        logging.exception("Error toggling MSFConsole")
        return jsonify({"status": "error", "message": str(e)})

@metasploit_bp.route('/search', methods=['POST'])
def search_modules():
    search_term = request.json.get('search_term')
    logging.debug(f"Search term received: {search_term}")

    if not rpc_client and not init_msf_rpc_client():
        return jsonify({"error": "RPC server is not running or not properly configured"})

    try:
        if not is_msfconsole_running():
            if not start_msfconsole():
                return jsonify({"error": "Failed to start MSFConsole session"})

        # Use the first available console
        console_id = rpc_client.consoles.list[0]['id']
        console = rpc_client.consoles.console(console_id)

        # Execute search command
        console.write(f'search {search_term}\n')

        # Collect output until we see the prompt again
        result = []
        start_time = time.time()
        while time.time() - start_time < 30:  # 30 seconds timeout
            console_data = console.read()
            result.append(console_data['data'])
            if console_data['busy'] is False:
                break

        result_str = ''.join(result)
        search_results = parse_search_results(result_str)

        # Update the database with the console output
        conn = sqlite3.connect(db_path)
        c = conn.cursor()
        c.execute('UPDATE sessions SET console_output = console_output || ? WHERE end_time IS NULL', (result_str,))
        conn.commit()
        conn.close()

        return jsonify({
            "search_results": search_results,
            "console_output": result_str
        })
    except Exception as e:
        logging.error(f"Error executing search command: {e}")
        return jsonify({"error": f"An error occurred while searching for modules: {str(e)}"})

def parse_search_results(result):
    search_results = []
    result = re.sub(r'\x1B\[[0-9;]*[A-Za-z]', '', result)  # Remove ANSI escape sequences
    in_results_section = False

    for line in result.splitlines():
        if line.strip().startswith("#") or line.strip().startswith("Interact with a module"):
            continue  # Skip headers and instructions
        
        if line.strip() == "":
            continue  # Skip empty lines
        
        if not in_results_section and "Matching Modules" in line:
            in_results_section = True
            continue
        
        if in_results_section:
            parts = re.split(r'\s{2,}', line.strip())
            if len(parts) >= 2 and not parts[0].startswith('_') and parts[-1] != '.':
                search_results.append({
                    'module': parts[0],
                    'description': ' '.join(parts[1:])
                })

    return search_results

@metasploit_bp.route('/get_module_options', methods=['POST'])
def get_module_options():
    module_name = request.json.get('module_name')
    logging.debug(f"Retrieving options for module: {module_name}")

    if not rpc_client and not init_msf_rpc_client():
        return jsonify({"error": "RPC server is not running or not properly configured"})

    try:
        if not is_msfconsole_running():
            if not start_msfconsole():
                return jsonify({"error": "Failed to start MSFConsole session"})

        console_id = rpc_client.consoles.list[0]['id']
        console = rpc_client.consoles.console(console_id)

        console.write(f'use {module_name}\n')
        time.sleep(1)  # Wait for the module to be loaded
        console.write('show options\n')

        # Collect output until we see the prompt again
        result = []
        start_time = time.time()
        while time.time() - start_time < 30:  # 30 seconds timeout
            console_data = console.read()
            result.append(console_data['data'])
            if console_data['busy'] is False:
                break

        result_str = ''.join(result)
        module_options = parse_module_options(result_str)

        # Update the database with the console output
        conn = sqlite3.connect(db_path)
        c = conn.cursor()
        c.execute('UPDATE sessions SET console_output = console_output || ? WHERE end_time IS NULL', (result_str,))
        conn.commit()
        conn.close()

        return jsonify(module_options)
    except Exception as e:
        logging.error(f"Error retrieving module options: {e}")
        return jsonify({"error": "An error occurred while retrieving module options"})

def parse_module_options(result):
    options = []
    in_options_section = False
    for line in result.splitlines():
        if "Name" in line and "Current Setting" in line and "Required" in line:
            in_options_section = True
            continue
        if in_options_section and line.strip() == "":
            break
        if in_options_section:
            parts = re.split(r'\s{2,}', line.strip())
            if len(parts) > 2:
                options.append({
                    'name': parts[0],
                    'required': parts[2] == 'yes',
                    'description': ' '.join(parts[4:])
                })
    return options

@metasploit_bp.route('/console_output', methods=['GET'])
def console_output():
    if not rpc_client:
        return jsonify({"console_output": "RPC client not initialized"})
        
    try:
        console_id = rpc_client.consoles.list[0]['id']
        console = rpc_client.consoles.console(console_id)
        output = console.read()['data']
        return jsonify({"console_output": output})
    except Exception as e:
        logging.error(f"Error reading console output: {e}")
        return jsonify({"console_output": f"Error reading console output: {e}"})
    
@metasploit_bp.route('/console_status', methods=['GET'])
def console_status():
    try:
        rpc_running = is_rpc_server_running()
        console_running = is_msfconsole_running() if rpc_running else False
        return jsonify({
            "rpc_running": rpc_running,
            "console_running": console_running
        })
    except Exception as e:
        logging.exception("Error getting console status")
        return jsonify({"status": "error", "message": str(e)})

@metasploit_bp.route('/previous_sessions', methods=['GET'])
def previous_sessions():
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute('SELECT id, start_time, end_time FROM sessions WHERE end_time IS NOT NULL ORDER BY start_time DESC')
    sessions = c.fetchall()
    conn.close()
    return jsonify([{"id": s[0], "start_time": s[1], "end_time": s[2]} for s in sessions])

@metasploit_bp.route('/get_session_output/<int:session_id>', methods=['GET'])
def get_session_output(session_id):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute('SELECT console_output FROM sessions WHERE id = ?', (session_id,))
    result = c.fetchone()
    conn.close()
    if result:
        return jsonify({"console_output": result[0]})
    return jsonify({"console_output": ""})

def set_msfconsole_state(state):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute('UPDATE msfconsole_state SET state = ? WHERE id = 1', (state,))
    conn.commit()
    conn.close()
