# live_feed_routes.py

import os
import subprocess
from flask import Blueprint, render_template, request, jsonify, current_app, send_from_directory
from flask_cors import CORS
import logging
import base64
from datetime import datetime
from werkzeug.utils import secure_filename

live_feed = Blueprint('live_feed', __name__)
CORS(live_feed)

# Global processes
stream_process = None
record_process = None

# Initialize logger
logger = logging.getLogger('live_feed')
logger.setLevel(logging.DEBUG)

if not logger.handlers:
    logs_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../logs')
    os.makedirs(logs_dir, exist_ok=True)
    log_file = os.path.join(logs_dir, 'live_feed.log')

    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.DEBUG)

    formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s')
    fh.setFormatter(formatter)

    logger.addHandler(fh)

def register_live_feed_routes(app):
    app.register_blueprint(live_feed, url_prefix='/live_feed')

# Save directories
SAVE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../saves/live_feed')
SCREENSHOTS_DIR = os.path.join(SAVE_DIR, 'screenshots')
VIDEOS_DIR = os.path.join(SAVE_DIR, 'videos')

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
os.makedirs(VIDEOS_DIR, exist_ok=True)

@live_feed.route('/')
def live_feed_home():
    return render_template('live_feed.html')

@live_feed.route('/list_devices', methods=['GET'])
def list_devices():
    try:
        video_devices = [f'/dev/video{i}' for i in range(0, 32) if os.path.exists(f'/dev/video{i}')]
        logger.debug(f"Available video devices: {video_devices}")
        return jsonify({'devices': video_devices}), 200
    except Exception as e:
        logger.error(f"Error listing devices: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to list devices.'}), 500

@live_feed.route('/start_stream', methods=['POST'])
def start_stream():
    global stream_process
    if stream_process and stream_process.poll() is None:
        logger.warning("Attempted to start stream, but it's already running.")
        return jsonify({'status': 'stream_already_running'}), 400

    try:
        data = request.get_json()
        input_device = data.get('input_device', '/dev/video0')
        hls_dir = os.path.join(current_app.static_folder, 'hls')
        os.makedirs(hls_dir, exist_ok=True)

        # Define HLS parameters for low latency
        hls_time = 1  # seconds per segment
        hls_list_size = 3  # number of segments in playlist

        ffmpeg_command = [
            'ffmpeg',
            '-f', 'v4l2',
            '-framerate', '30',  # Increase frame rate for smoother video
            '-video_size', '1280x720',
            '-i', input_device,
            '-c:v', 'libx264',
            '-preset', 'ultrafast',  # Prioritize low latency over compression
            '-pix_fmt', 'yuv420p',
            '-tune', 'zerolatency',  # Optimized for real-time streaming
            '-f', 'hls',
            '-hls_time', str(hls_time),
            '-hls_list_size', str(hls_list_size),
            '-hls_flags', 'delete_segments',
            '-hls_allow_cache', '0',
            os.path.join(hls_dir, 'output.m3u8')
        ]

        logger.info(f"Starting FFmpeg with command: {' '.join(ffmpeg_command)}")
        stream_process = subprocess.Popen(
            ffmpeg_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        logger.info("HLS stream started successfully.")
        return jsonify({'status': 'stream_started', 'stream_path': '/static/hls/output.m3u8'}), 200

    except Exception as e:
        logger.error(f"Failed to start stream: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to start stream.'}), 500

@live_feed.route('/stop_stream', methods=['POST'])
def stop_stream():
    global stream_process
    if stream_process:
        try:
            logger.info("Stopping FFmpeg stream process.")
            stream_process.terminate()
            stream_process.wait(timeout=5)
            logger.info("HLS stream stopped successfully.")
            stream_process = None
            return jsonify({'status': 'stream_stopped'}), 200
        except subprocess.TimeoutExpired:
            logger.error("FFmpeg process did not terminate in time.")
            return jsonify({'status': 'error', 'message': 'Failed to stop stream in time.'}), 500
        except Exception as e:
            logger.error(f"Error stopping stream: {str(e)}")
            return jsonify({'status': 'error', 'message': 'Failed to stop stream.'}), 500
    else:
        logger.warning("Attempted to stop stream, but no stream was running.")
        return jsonify({'status': 'no_stream_running'}), 400

# Recording Controls
@live_feed.route('/start_recording', methods=['POST'])
def start_recording():
    global record_process
    if record_process and record_process.poll() is None:
        logger.warning("Attempted to start recording, but it's already running.")
        return jsonify({'status': 'recording_already_running'}), 400

    try:
        hls_dir = os.path.join(current_app.static_folder, 'hls')
        hls_path = os.path.join(hls_dir, 'output.m3u8')
        video_filename = f'recording_{datetime.now().strftime("%Y%m%d_%H%M%S")}.mp4'
        video_filepath = os.path.join(VIDEOS_DIR, video_filename)

        # FFmpeg command to record from HLS stream
        ffmpeg_record_command = [
            'ffmpeg',
            '-i', hls_path,
            '-c', 'copy',
            '-f', 'mp4',
            video_filepath
        ]

        logger.info(f"Starting recording with command: {' '.join(ffmpeg_record_command)}")
        record_process = subprocess.Popen(
            ffmpeg_record_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        logger.info(f"Recording started: {video_filename}")
        return jsonify({'status': 'recording_started', 'video_file': video_filename}), 200

    except Exception as e:
        logger.error(f"Failed to start recording: {str(e)}")
        return jsonify({'status': 'error', 'message': 'Failed to start recording.'}), 500

@live_feed.route('/stop_recording', methods=['POST'])
def stop_recording():
    global record_process
    if record_process:
        try:
            logger.info("Stopping FFmpeg recording process.")
            record_process.terminate()
            record_process.wait(timeout=5)
            logger.info("Recording stopped successfully.")
            record_process = None
            return jsonify({'status': 'recording_stopped'}), 200
        except subprocess.TimeoutExpired:
            logger.error("FFmpeg recording process did not terminate in time.")
            return jsonify({'status': 'error', 'message': 'Failed to stop recording in time.'}), 500
        except Exception as e:
            logger.error(f"Error stopping recording: {str(e)}")
            return jsonify({'status': 'error', 'message': 'Failed to stop recording.'}), 500
    else:
        logger.warning("Attempted to stop recording, but no recording was running.")
        return jsonify({'status': 'no_recording_running'}), 400

# File Management Endpoints
@live_feed.route('/delete_file', methods=['POST'])
def delete_file():
    try:
        data = request.get_json()
        filename = data.get('filename')
        file_type = data.get('file_type')  # 'screenshot' or 'video'
        if not filename or not file_type:
            return jsonify({'status': 'error', 'message': 'Filename and file_type are required.'}), 400

        # Secure the filename to prevent directory traversal
        filename = secure_filename(filename)

        if file_type == 'screenshot':
            file_path = os.path.join(SCREENSHOTS_DIR, filename)
        elif file_type == 'video':
            file_path = os.path.join(VIDEOS_DIR, filename)
        else:
            return jsonify({'status': 'error', 'message': 'Invalid file_type.'}), 400

        if os.path.exists(file_path):
            os.remove(file_path)
            logger.info(f"Deleted {file_type}: {filename}")
            return jsonify({'status': 'success', 'message': f'{file_type.capitalize()} deleted.'}), 200
        else:
            return jsonify({'status': 'error', 'message': 'File does not exist.'}), 404

    except Exception as e:
        logger.error(f"Error deleting file: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to delete file.'}), 500

@live_feed.route('/rename_file', methods=['POST'])
def rename_file():
    try:
        data = request.get_json()
        old_filename = data.get('old_filename')
        new_filename = data.get('new_filename')
        file_type = data.get('file_type')  # 'screenshot' or 'video'

        if not old_filename or not new_filename or not file_type:
            return jsonify({'status': 'error', 'message': 'Old filename, new filename, and file_type are required.'}), 400

        # Secure the filenames
        old_filename = secure_filename(old_filename)
        new_filename = secure_filename(new_filename)

        if file_type == 'screenshot':
            old_file_path = os.path.join(SCREENSHOTS_DIR, old_filename)
            new_file_path = os.path.join(SCREENSHOTS_DIR, new_filename)
        elif file_type == 'video':
            old_file_path = os.path.join(VIDEOS_DIR, old_filename)
            new_file_path = os.path.join(VIDEOS_DIR, new_filename)
        else:
            return jsonify({'status': 'error', 'message': 'Invalid file_type.'}), 400

        if not os.path.exists(old_file_path):
            return jsonify({'status': 'error', 'message': 'Old file does not exist.'}), 404

        if os.path.exists(new_file_path):
            return jsonify({'status': 'error', 'message': 'New filename already exists.'}), 400

        os.rename(old_file_path, new_file_path)
        logger.info(f"Renamed {file_type}: {old_filename} to {new_filename}")
        return jsonify({'status': 'success', 'message': f'{file_type.capitalize()} renamed.'}), 200

    except Exception as e:
        logger.error(f"Error renaming file: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to rename file.'}), 500

@live_feed.route('/download_file/<file_type>/<filename>', methods=['GET'])
def download_file(file_type, filename):
    try:
        filename = secure_filename(filename)
        if file_type == 'screenshot':
            directory = SCREENSHOTS_DIR
        elif file_type == 'video':
            directory = VIDEOS_DIR
        else:
            return jsonify({'status': 'error', 'message': 'Invalid file_type.'}), 400

        if not os.path.exists(os.path.join(directory, filename)):
            return jsonify({'status': 'error', 'message': 'File does not exist.'}), 404

        return send_from_directory(directory, filename, as_attachment=True)

    except Exception as e:
        logger.error(f"Error downloading file: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to download file.'}), 500

@live_feed.route('/save_screenshot', methods=['POST'])
def save_screenshot():
    try:
        data = request.get_json()
        image_data = data.get('image')
        if not image_data:
            return jsonify({'status': 'error', 'message': 'No image data provided.'}), 400

        header, encoded = image_data.split(',', 1)
        image_bytes = base64.b64decode(encoded)

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'screenshot_{timestamp}.png'
        filepath = os.path.join(SCREENSHOTS_DIR, filename)

        with open(filepath, 'wb') as f:
            f.write(image_bytes)

        logger.info(f"Screenshot saved: {filename}")
        return jsonify({'status': 'success', 'filename': filename}), 200

    except Exception as e:
        logger.error(f"Error saving screenshot: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to save screenshot.'}), 500

@live_feed.route('/get_saves', methods=['GET'])
def get_saves():
    try:
        screenshots = sorted(os.listdir(SCREENSHOTS_DIR))
        screenshot_urls = [f'/live_feed/saves/screenshots/{filename}' for filename in screenshots]

        videos = sorted(os.listdir(VIDEOS_DIR))
        video_urls = [f'/live_feed/saves/videos/{filename}' for filename in videos]

        return jsonify({'screenshots': screenshot_urls, 'videos': video_urls}), 200

    except Exception as e:
        logger.error(f"Error fetching saves: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to fetch saves.'}), 500

@live_feed.route('/saves/screenshots/<filename>')
def get_screenshot(filename):
    return send_from_directory(SCREENSHOTS_DIR, filename)

@live_feed.route('/saves/videos/<filename>')
def get_video(filename):
    return send_from_directory(VIDEOS_DIR, filename)
