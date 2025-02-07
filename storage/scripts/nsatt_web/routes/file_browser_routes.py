# file_browser.py

import os
import shutil
import logging
from flask import Blueprint, render_template, request, jsonify, send_from_directory, abort
from flask_cors import CORS
from werkzeug.utils import secure_filename
from datetime import datetime

file_browser = Blueprint('file_browser', __name__)
CORS(file_browser)  # Enable CORS for this blueprint

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Define base directory to limit file access
BASE_DIR = '/home/nsatt-admin'  # Updated to match your intended directory

def is_safe_path(basedir, path, follow_symlinks=True):
    """
    Ensure the given path is within the BASE_DIR to prevent directory traversal attacks.
    """
    if follow_symlinks:
        return os.path.realpath(path).startswith(basedir)
    return os.path.abspath(path).startswith(basedir)

def register_file_browser_routes(app):
    """
    Register the file_browser blueprint with the Flask app.
    """
    app.register_blueprint(file_browser, url_prefix='/file_browser')  # Ensure url_prefix matches frontend

@file_browser.route('/')
def file_browser_home():
    return render_template('file_browser.html')

@file_browser.route('/list', methods=['GET'])
def list_files():
    directory = request.args.get('directory', BASE_DIR)
    sort_by = request.args.get('sort_by', 'name')  # Default sort by name
    order = request.args.get('order', 'asc')       # Default order ascending
    filter_name = request.args.get('filter_name', '').lower()
    filter_type = request.args.get('filter_type', '').lower()
    filter_date = request.args.get('filter_date', '')
    search_query = request.args.get('search_query', '').lower()

    logger.info(f"Listing files in directory: {directory} sorted by {sort_by} {order}")
    
    # Ensure the directory is within BASE_DIR
    if not is_safe_path(BASE_DIR, directory):
        return jsonify({'error': 'Access denied'}), 403

    try:
        files = []
        with os.scandir(directory) as it:
            for entry in it:
                stats = entry.stat()
                file_type = 'Directory' if entry.is_dir() else 'File'
                file_name = entry.name.lower()
                file_created = datetime.fromtimestamp(stats.st_ctime).strftime('%Y-%m-%d %H:%M:%S')
                file_modified = datetime.fromtimestamp(stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S')

                # Apply Filters
                if filter_name and filter_name not in entry.name.lower():
                    continue
                if filter_type and filter_type != file_type.lower():
                    continue
                if filter_date:
                    # Assuming filter_date is in YYYY-MM-DD format and filters by creation date
                    if not file_created.startswith(filter_date):
                        continue
                if search_query and search_query not in entry.name.lower():
                    continue

                files.append({
                    'name': entry.name,
                    'type': file_type,
                    'size': stats.st_size if entry.is_file() else None,
                    'permissions': oct(stats.st_mode)[-3:],
                    'path': os.path.abspath(entry.path),
                    'created': file_created,
                    'modified': file_modified,
                })
        
        # Sorting
        if sort_by in ['name', 'type', 'size', 'permissions', 'created', 'modified']:
            reverse = True if order == 'desc' else False
            if sort_by == 'size':
                files.sort(key=lambda x: x['size'] if x['size'] is not None else 0, reverse=reverse)
            else:
                files.sort(key=lambda x: x[sort_by].lower() if isinstance(x[sort_by], str) else x[sort_by], reverse=reverse)

        return jsonify({'files': files, 'directory': os.path.abspath(directory)}), 200
    except Exception as e:
        logger.error(f"Error listing files in {directory}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part in the request'}), 400
    
    file = request.files['file']
    directory = request.form.get('directory', BASE_DIR)

    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    if not is_safe_path(BASE_DIR, directory):
        return jsonify({'error': 'Access denied'}), 403

    try:
        filename = secure_filename(file.filename)
        destination = os.path.join(directory, filename)
        file.save(destination)
        logger.info(f"Uploaded file {destination}")
        return jsonify({'message': 'File uploaded successfully'}), 200
    except Exception as e:
        logger.error(f"Error uploading file to {directory}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/download', methods=['GET'])
def download_file_route():
    directory = request.args.get('directory', BASE_DIR)
    filename = request.args.get('filename')
    
    if not filename:
        return jsonify({'error': 'No filename specified'}), 400
    
    if not is_safe_path(BASE_DIR, directory):
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        return send_from_directory(directory, filename, as_attachment=True)
    except Exception as e:
        logger.error(f"Error downloading file {filename} from {directory}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/copy', methods=['POST'])
def copy_file_route():
    data = request.get_json()
    source_path = data.get('source_path')
    destination_dir = data.get('destination_dir')

    if not source_path or not destination_dir:
        return jsonify({'error': 'Invalid parameters'}), 400

    if not is_safe_path(BASE_DIR, source_path) or not is_safe_path(BASE_DIR, destination_dir):
        return jsonify({'error': 'Access denied'}), 403

    try:
        if os.path.isfile(source_path):
            shutil.copy2(source_path, destination_dir)
            logger.info(f"Copied file {source_path} to {destination_dir}")
        else:
            shutil.copytree(source_path, os.path.join(destination_dir, os.path.basename(source_path)))
            logger.info(f"Copied directory {source_path} to {destination_dir}")
        return jsonify({'message': 'File copied successfully'}), 200
    except Exception as e:
        logger.error(f"Error copying {source_path} to {destination_dir}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/move', methods=['POST'])
def move_file_route():
    data = request.get_json()
    source_path = data.get('source_path')
    destination_dir = data.get('destination_dir')

    if not source_path or not destination_dir:
        return jsonify({'error': 'Invalid parameters'}), 400

    if not is_safe_path(BASE_DIR, source_path) or not is_safe_path(BASE_DIR, destination_dir):
        return jsonify({'error': 'Access denied'}), 403

    try:
        shutil.move(source_path, destination_dir)
        logger.info(f"Moved {source_path} to {destination_dir}")
        return jsonify({'message': 'File moved successfully'}), 200
    except Exception as e:
        logger.error(f"Error moving {source_path} to {destination_dir}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/delete', methods=['POST'])
def delete_file():
    filepath = request.json.get('filepath')
    if not filepath:
        return jsonify({'error': 'No filepath specified'}), 400

    # Ensure the filepath is safe
    if not is_safe_path(BASE_DIR, filepath):
        return jsonify({'error': 'Access denied'}), 403

    try:
        if os.path.isfile(filepath):
            os.remove(filepath)
            logger.info(f"Deleted file {filepath}")
        else:
            shutil.rmtree(filepath)
            logger.info(f"Deleted directory {filepath}")
        return jsonify({'message': 'File deleted successfully'}), 200
    except Exception as e:
        logger.error(f"Error deleting {filepath}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/bulk_delete', methods=['POST'])
def bulk_delete():
    filepaths = request.json.get('filepaths', [])
    if not filepaths:
        return jsonify({'error': 'No filepaths specified'}), 400

    # Ensure all filepaths are safe
    for filepath in filepaths:
        if not is_safe_path(BASE_DIR, filepath):
            return jsonify({'error': f'Access denied for {filepath}'}), 403

    errors = []
    for filepath in filepaths:
        try:
            if os.path.isfile(filepath):
                os.remove(filepath)
                logger.info(f"Deleted file {filepath}")
            else:
                shutil.rmtree(filepath)
                logger.info(f"Deleted directory {filepath}")
        except Exception as e:
            logger.error(f"Error deleting {filepath}: {e}")
            errors.append(f"{filepath}: {str(e)}")
    
    if errors:
        return jsonify({'error': errors}), 500
    else:
        return jsonify({'message': 'Files deleted successfully'}), 200

@file_browser.route('/bulk_move', methods=['POST'])
def bulk_move():
    filepaths = request.json.get('filepaths', [])
    destination_dir = request.json.get('destination_dir')

    if not filepaths or not destination_dir:
        return jsonify({'error': 'Invalid parameters'}), 400

    # Ensure all filepaths and destination_dir are safe
    if not is_safe_path(BASE_DIR, destination_dir):
        return jsonify({'error': 'Access denied for destination directory'}), 403

    for filepath in filepaths:
        if not is_safe_path(BASE_DIR, filepath):
            return jsonify({'error': f'Access denied for {filepath}'}), 403

    errors = []
    for filepath in filepaths:
        try:
            shutil.move(filepath, destination_dir)
            logger.info(f"Moved {filepath} to {destination_dir}")
        except Exception as e:
            logger.error(f"Error moving {filepath} to {destination_dir}: {e}")
            errors.append(f"{filepath}: {str(e)}")
    
    if errors:
        return jsonify({'error': errors}), 500
    else:
        return jsonify({'message': 'Files moved successfully'}), 200

@file_browser.route('/create_folder', methods=['POST'])
def create_folder():
    data = request.get_json()
    folder_path = data.get('folder_path')

    if not folder_path:
        return jsonify({'error': 'No folder path specified'}), 400

    # Ensure folder_path is safe
    if not is_safe_path(BASE_DIR, folder_path):
        return jsonify({'error': 'Access denied'}), 403

    try:
        os.makedirs(folder_path, exist_ok=True)
        logger.info(f"Created folder {folder_path}")
        return jsonify({'message': 'Folder created successfully'}), 200
    except Exception as e:
        logger.error(f"Error creating folder {folder_path}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/rename', methods=['POST'])
def rename_file_route():
    data = request.get_json()
    old_path = data.get('old_path')
    new_path = data.get('new_path')

    if not old_path or not new_path:
        return jsonify({'error': 'Invalid file paths specified'}), 400

    # Ensure paths are safe
    if not is_safe_path(BASE_DIR, old_path) or not is_safe_path(BASE_DIR, new_path):
        return jsonify({'error': 'Access denied'}), 403

    try:
        os.rename(old_path, new_path)
        logger.info(f"Renamed {old_path} to {new_path}")
        return jsonify({'message': 'File renamed successfully'}), 200
    except Exception as e:
        logger.error(f"Error renaming {old_path} to {new_path}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/edit_file', methods=['POST'])
def edit_file():
    data = request.get_json()
    filepath = data.get('filepath')
    content = data.get('content')

    if not filepath or content is None:
        return jsonify({'error': 'Invalid parameters'}), 400

    # Ensure filepath is safe
    if not is_safe_path(BASE_DIR, filepath):
        return jsonify({'error': 'Access denied'}), 403

    # Ensure the file is a text file
    if not os.path.isfile(filepath):
        return jsonify({'error': 'File does not exist'}), 400
    if not is_text_file(filepath):
        return jsonify({'error': 'Cannot edit non-text files'}), 400

    try:
        with open(filepath, 'w') as f:
            f.write(content)
        logger.info(f"Edited file {filepath}")
        return jsonify({'message': 'File saved successfully'}), 200
    except Exception as e:
        logger.error(f"Error editing file {filepath}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/read_file', methods=['GET'])
def read_file():
    filepath = request.args.get('filepath')
    if not filepath:
        return jsonify({'error': 'No file path specified'}), 400

    # Ensure filepath is safe
    if not is_safe_path(BASE_DIR, filepath):
        return jsonify({'error': 'Access denied'}), 403

    # Ensure the file is a text file
    if not os.path.isfile(filepath):
        return jsonify({'error': 'File does not exist'}), 404
    if not is_text_file(filepath):
        return jsonify({'error': 'Cannot read non-text files'}), 400

    try:
        with open(filepath, 'r') as f:
            content = f.read()
        logger.info(f"Read file {filepath}")
        return jsonify({'content': content}), 200
    except Exception as e:
        logger.error(f"Error reading file {filepath}: {e}")
        return jsonify({'error': str(e)}), 500

@file_browser.route('/change_permissions', methods=['POST'])
def change_permissions_route():
    data = request.get_json()
    filepath = data.get('filepath')
    permissions = data.get('permissions')

    if not filepath or not permissions:
        return jsonify({'error': 'Invalid parameters'}), 400

    # Ensure filepath is safe
    if not is_safe_path(BASE_DIR, filepath):
        return jsonify({'error': 'Access denied'}), 403

    # Validate permissions format
    if not isinstance(permissions, str) or not permissions.isdigit() or len(permissions) != 3:
        return jsonify({'error': 'Invalid permissions format. Use three octal digits (e.g., 755).'}), 400

    try:
        os.chmod(filepath, int(permissions, 8))
        logger.info(f"Changed permissions of {filepath} to {permissions}")
        return jsonify({'message': 'Permissions changed successfully'}), 200
    except Exception as e:
        logger.error(f"Error changing permissions of {filepath}: {e}")
        return jsonify({'error': str(e)}), 500

def is_text_file(filepath):
    """
    Simple check to determine if a file is text-based.
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            f.read(1024)
        return True
    except:
        return False
