# vnc_routes.py

import os
import subprocess
import logging
from flask import Blueprint, jsonify, current_app, request, render_template, send_from_directory
from datetime import datetime
import signal

vnc = Blueprint('vnc', __name__)

# Dictionary to keep track of sessions
# Format: {display_number: {'vnc_process': ..., 'websockify_process': ..., 'websockify_port': ...}}
sessions = {}

logger = logging.getLogger('vnc')
logger.setLevel(logging.DEBUG)

if not logger.handlers:
    logs_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../logs')
    os.makedirs(logs_dir, exist_ok=True)
    log_file = os.path.join(logs_dir, 'vnc.log')

    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s')
    fh.setFormatter(formatter)
    logger.addHandler(fh)

def register_vnc_routes(app):
    app.register_blueprint(vnc, url_prefix='/vnc')

SAVE_DIR_VNC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../saves/vnc')
SCREENSHOTS_DIR_VNC = os.path.join(SAVE_DIR_VNC, 'screenshots')
VIDEOS_DIR_VNC = os.path.join(SAVE_DIR_VNC, 'videos')

os.makedirs(SCREENSHOTS_DIR_VNC, exist_ok=True)
os.makedirs(VIDEOS_DIR_VNC, exist_ok=True)

def get_next_display_number():
    display = 1
    while f":{display}" in sessions:
        display += 1
    return display

def get_websockify_port(display):
    base_port = 6080
    return base_port + (display - 1)

@vnc.route('/')
def vnc_home():
    return render_template('vnc.html')

@vnc.route('/start', methods=['POST'])
def start_vnc():
    global sessions
    display = get_next_display_number()
    display_str = f":{display}"
    vnc_port = 5900 + display
    websockify_port = get_websockify_port(display)

    try:
        # Start tightvncserver
        vnc_command = ['tightvncserver', display_str, '-geometry', '1280x720', '-depth', '24']
        logger.info(f"Starting VNC server with command: {' '.join(vnc_command)}")
        vnc_process = subprocess.Popen(
            vnc_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid  # Start the process in a new session
        )

        # Start websockify
        websockify_command = [
            'websockify',
            '--web', os.path.join(current_app.static_folder, 'noVNC'),
            str(websockify_port),
            f'localhost:{vnc_port}'
        ]
        logger.info(f"Starting websockify with command: {' '.join(websockify_command)}")
        websockify_process = subprocess.Popen(
            websockify_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid  # Start the process in a new session
        )

        # Add session to sessions dictionary
        sessions[display_str] = {
            'vnc_process': vnc_process,
            'websockify_process': websockify_process,
            'websockify_port': websockify_port
        }

        logger.info(f"VNC session {display_str} started successfully on port {vnc_port} with websockify port {websockify_port}.")
        return jsonify({'status': 'vnc_started', 'display': display_str, 'websockify_port': websockify_port}), 200

    except Exception as e:
        logger.error(f"Failed to start VNC session {display_str}: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to start VNC session.'}), 500

@vnc.route('/stop/<display>', methods=['POST'])
def stop_vnc(display):
    global sessions
    if display not in sessions:
        logger.warning(f"Attempted to stop non-existent VNC session {display}.")
        return jsonify({'status': 'error', 'message': 'VNC session does not exist.'}), 404

    try:
        # Terminate VNC process
        vnc_proc = sessions[display]['vnc_process']
        logger.info(f"Stopping VNC server {display}.")
        os.killpg(os.getpgid(vnc_proc.pid), signal.SIGTERM)
        vnc_proc.wait(timeout=10)

        # Terminate websockify process
        websockify_proc = sessions[display]['websockify_process']
        logger.info(f"Stopping websockify for session {display}.")
        os.killpg(os.getpgid(websockify_proc.pid), signal.SIGTERM)
        websockify_proc.wait(timeout=10)

        # Remove session from dictionary
        del sessions[display]

        logger.info(f"VNC session {display} stopped successfully.")
        return jsonify({'status': 'vnc_stopped', 'display': display}), 200

    except subprocess.TimeoutExpired:
        logger.error(f"Failed to terminate VNC or websockify processes for session {display} in time.")
        return jsonify({'status': 'error', 'message': 'Failed to terminate processes in time.'}), 500
    except Exception as e:
        logger.error(f"Error stopping VNC session {display}: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to stop VNC session.'}), 500

@vnc.route('/restart/<display>', methods=['POST'])
def restart_vnc(display):
    global sessions
    if display not in sessions:
        logger.warning(f"Attempted to restart non-existent VNC session {display}.")
        return jsonify({'status': 'error', 'message': 'VNC session does not exist.'}), 404

    try:
        # Retrieve current websockify port before restarting
        current_websockify_port = sessions[display]['websockify_port']

        # Stop the existing session
        stop_response = stop_vnc(display)
        if stop_response[1] != 200:
            return stop_response

        # Start a new session with the same display number and websockify port
        vnc_command = ['tightvncserver', display, '-geometry', '1280x720', '-depth', '24']
        logger.info(f"Restarting VNC server with command: {' '.join(vnc_command)}")
        vnc_process = subprocess.Popen(
            vnc_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid
        )

        # Start websockify with the same port
        websockify_command = [
            'websockify',
            '--web', os.path.join(current_app.static_folder, 'noVNC'),
            str(current_websockify_port),
            f'localhost:{5900 + int(display.strip(":"))}'
        ]
        logger.info(f"Restarting websockify with command: {' '.join(websockify_command)}")
        websockify_process = subprocess.Popen(
            websockify_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid
        )

        # Update session info
        sessions[display] = {
            'vnc_process': vnc_process,
            'websockify_process': websockify_process,
            'websockify_port': current_websockify_port
        }

        logger.info(f"VNC session {display} restarted successfully.")
        return jsonify({'status': 'vnc_restarted', 'display': display, 'websockify_port': current_websockify_port}), 200

    except Exception as e:
        logger.error(f"Error restarting VNC session {display}: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to restart VNC session.'}), 500

@vnc.route('/list', methods=['GET'])
def list_sessions():
    global sessions
    session_list = []
    for display, info in sessions.items():
        session = {
            'display': display,
            'vnc_port': 5900 + int(display[1:]),
            'websockify_port': info['websockify_port'],
            'connect_url': f'http://{request.host.split(":")[0]}:{info["websockify_port"]}/vnc.html?host=localhost&port={info["websockify_port"]}&path=/websockify'
        }
        session_list.append(session)
    return jsonify({'sessions': session_list}), 200

@vnc.route('/stop_all', methods=['POST'])
def stop_all_vnc():
    global sessions
    try:
        for display in list(sessions.keys()):
            stop_vnc(display)
        logger.info("All VNC sessions stopped successfully.")
        return jsonify({'status': 'all_vnc_stopped'}), 200
    except Exception as e:
        logger.error(f"Error stopping all VNC sessions: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to stop all VNC sessions.'}), 500

@vnc.route('/restart_all', methods=['POST'])
def restart_all_vnc():
    global sessions
    try:
        for display in list(sessions.keys()):
            restart_vnc(display)
        logger.info("All VNC sessions restarted successfully.")
        return jsonify({'status': 'all_vnc_restarted'}), 200
    except Exception as e:
        logger.error(f"Error restarting all VNC sessions: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to restart all VNC sessions.'}), 500

@vnc.route('/take_screenshot/<display>', methods=['POST'])
def take_screenshot_vnc(display):
    try:
        # Validate display format
        if not display.startswith(":") or not display[1:].isdigit():
            logger.error(f"Invalid display format: {display}")
            return jsonify({'status': 'error', 'message': 'Invalid display format.'}), 400

        # Use xwd to capture the screenshot of the VNC session
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        screenshot_filename = f'vnc_screenshot_{display.strip(":")}_{timestamp}.png'
        screenshot_path = os.path.join(SCREENSHOTS_DIR_VNC, screenshot_filename)

        # Command to take screenshot of display
        # Ensure xwd and ImageMagick's convert are installed on the server
        xwd_command = ['xwd', '-display', display, '-silent']
        convert_command = ['convert', '-', screenshot_path]

        logger.info(f"Capturing screenshot for {display} with command: {' '.join(xwd_command)} | {' '.join(convert_command)}")

        # Execute the xwd and convert commands
        xwd_proc = subprocess.Popen(xwd_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        convert_proc = subprocess.Popen(convert_command, stdin=xwd_proc.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        xwd_proc.stdout.close()  # Allow SIGPIPE on xwd_proc if convert_proc exits
        try:
            stdout, stderr = convert_proc.communicate(timeout=15)
        except subprocess.TimeoutExpired:
            xwd_proc.kill()
            convert_proc.kill()
            logger.error(f"Screenshot capture timed out for {display}.")
            return jsonify({'status': 'error', 'message': 'Screenshot capture timed out.'}), 500

        # Check for errors in xwd
        if xwd_proc.returncode != 0:
            xwd_error = xwd_proc.stderr.read().decode().strip()
            logger.error(f"xwd command failed for {display}: {xwd_error}")
            return jsonify({'status': 'error', 'message': f"xwd command failed: {xwd_error}"}), 500

        # Check for errors in convert
        if convert_proc.returncode != 0:
            convert_error = stderr.decode().strip()
            logger.error(f"convert command failed for {display}: {convert_error}")
            return jsonify({'status': 'error', 'message': f"convert command failed: {convert_error}"}), 500

        logger.info(f"VNC Screenshot saved: {screenshot_filename}")
        return jsonify({'status': 'success', 'filename': screenshot_filename}), 200

    except Exception as e:
        logger.error(f"Error saving VNC screenshot for {display}: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to save VNC screenshot.'}), 500

@vnc.route('/get_saves', methods=['GET'])
def get_saves_vnc():
    try:
        # Ensure the screenshots and videos directories exist
        if not os.path.exists(SCREENSHOTS_DIR_VNC):
            logger.warning(f"Screenshots directory does not exist: {SCREENSHOTS_DIR_VNC}")
            screenshots = []
        else:
            # Get list of PNG files in the screenshots directory
            screenshots = sorted([
                filename for filename in os.listdir(SCREENSHOTS_DIR_VNC)
                if filename.lower().endswith('.png')
            ], reverse=True)

        if not os.path.exists(VIDEOS_DIR_VNC):
            logger.warning(f"Videos directory does not exist: {VIDEOS_DIR_VNC}")
            videos = []
        else:
            # Get list of video files in the videos directory (e.g., .mp4, .avi, .mov)
            videos = sorted([
                filename for filename in os.listdir(VIDEOS_DIR_VNC)
                if filename.lower().endswith(('.mp4', '.avi', '.mov', '.mkv'))
            ], reverse=True)

        # Generate URLs for the screenshots and videos
        screenshot_urls = [f'/vnc/saves/screenshots/{filename}' for filename in screenshots]
        video_urls = [f'/vnc/saves/videos/{filename}' for filename in videos]

        logger.info(f"Fetched {len(screenshot_urls)} screenshots and {len(video_urls)} videos from {SAVE_DIR_VNC}")
        return jsonify({'screenshots': screenshot_urls, 'videos': video_urls}), 200

    except FileNotFoundError as e:
        logger.error(f"Saves directory not found: {e}")
        return jsonify({'status': 'error', 'message': 'Saves directory not found.'}), 500
    except PermissionError as e:
        logger.error(f"Permission error accessing saves directory: {e}")
        return jsonify({'status': 'error', 'message': 'Permission denied when accessing saves directory.'}), 500
    except Exception as e:
        logger.error(f"Unexpected error fetching VNC saves: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to fetch VNC saves.'}), 500

@vnc.route('/saves/screenshots/<filename>')
def get_screenshot_vnc(filename):
    try:
        return send_from_directory(SCREENSHOTS_DIR_VNC, filename)
    except FileNotFoundError:
        logger.warning(f"Screenshot file not found: {filename}")
        return jsonify({'status': 'error', 'message': 'Screenshot file not found.'}), 404

@vnc.route('/saves/videos/<filename>')
def get_video_vnc(filename):
    try:
        return send_from_directory(VIDEOS_DIR_VNC, filename)
    except FileNotFoundError:
        logger.warning(f"Video file not found: {filename}")
        return jsonify({'status': 'error', 'message': 'Video file not found.'}), 404

@vnc.route('/delete_screenshot', methods=['POST'])
def delete_screenshot_vnc():
    try:
        data = request.get_json()
        filename = data.get('filename')
        if not filename:
            return jsonify({'status': 'error', 'message': 'No filename provided.'}), 400

        filepath = os.path.join(SCREENSHOTS_DIR_VNC, filename)
        if not os.path.exists(filepath):
            return jsonify({'status': 'error', 'message': 'File does not exist.'}), 404

        os.remove(filepath)
        logger.info(f"VNC Screenshot deleted: {filename}")
        return jsonify({'status': 'success'}), 200

    except Exception as e:
        logger.error(f"Error deleting VNC screenshot: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to delete VNC screenshot.'}), 500

@vnc.route('/rename_screenshot', methods=['POST'])
def rename_screenshot_vnc():
    try:
        data = request.get_json()
        old_filename = data.get('oldFilename')
        new_filename = data.get('newFilename')
        if not old_filename or not new_filename:
            return jsonify({'status': 'error', 'message': 'Old and new filenames are required.'}), 400

        # Ensure new filename ends with .png
        if not new_filename.lower().endswith('.png'):
            new_filename += '.png'

        old_filepath = os.path.join(SCREENSHOTS_DIR_VNC, old_filename)
        new_filepath = os.path.join(SCREENSHOTS_DIR_VNC, new_filename)

        if not os.path.exists(old_filepath):
            return jsonify({'status': 'error', 'message': 'Original file does not exist.'}), 404

        if os.path.exists(new_filepath):
            return jsonify({'status': 'error', 'message': 'New filename already exists.'}), 400

        os.rename(old_filepath, new_filepath)
        logger.info(f"VNC Screenshot renamed from {old_filename} to {new_filename}")
        return jsonify({'status': 'success'}), 200

    except Exception as e:
        logger.error(f"Error renaming VNC screenshot: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to rename VNC screenshot.'}), 500

@vnc.route('/bulk_stop', methods=['POST'])
def bulk_stop_vnc():
    try:
        data = request.get_json()
        displays = data.get('displays', [])  # List of display numbers to stop

        if not displays:
            # If no specific displays provided, stop all
            for display in list(sessions.keys()):
                stop_vnc(display)
            logger.info("All VNC sessions stopped successfully via bulk_stop.")
            return jsonify({'status': 'all_vnc_stopped'}), 200

        for display in displays:
            if display in sessions:
                stop_vnc(display)

        logger.info(f"Selected VNC sessions stopped successfully: {displays}")
        return jsonify({'status': 'selected_vnc_stopped'}), 200

    except Exception as e:
        logger.error(f"Error during bulk stop of VNC sessions: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to stop selected VNC sessions.'}), 500

@vnc.route('/bulk_restart', methods=['POST'])
def bulk_restart_vnc():
    try:
        data = request.get_json()
        displays = data.get('displays', [])  # List of display numbers to restart

        if not displays:
            # If no specific displays provided, restart all
            for display in list(sessions.keys()):
                restart_vnc(display)
            logger.info("All VNC sessions restarted successfully via bulk_restart.")
            return jsonify({'status': 'all_vnc_restarted'}), 200

        for display in displays:
            if display in sessions:
                restart_vnc(display)

        logger.info(f"Selected VNC sessions restarted successfully: {displays}")
        return jsonify({'status': 'selected_vnc_restarted'}), 200

    except Exception as e:
        logger.error(f"Error during bulk restart of VNC sessions: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to restart selected VNC sessions.'}), 500
