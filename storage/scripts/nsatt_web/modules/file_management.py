import os
import shutil

def upload_file(file, upload_dir):
    try:
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)
        file.save(os.path.join(upload_dir, file.filename))
        return f"File {file.filename} uploaded successfully."
    except Exception as e:
        return f"Error uploading file: {e}"

def create_directory(directory_path):
    try:
        if not os.path.exists(directory_path):
            os.makedirs(directory_path)
            return f"Directory {directory_path} created successfully."
        else:
            return f"Directory {directory_path} already exists."
    except Exception as e:
        return f"Error creating directory: {e}"

def delete_file_or_directory(path):
    try:
        if os.path.isfile(path):
            os.remove(path)
            return f"File {path} deleted successfully."
        elif os.path.isdir(path):
            shutil.rmtree(path)
            return f"Directory {path} deleted successfully."
        else:
            return f"Path {path} does not exist."
    except Exception as e:
        return f"Error deleting file or directory: {e}"

def move_file_or_directory(source, destination):
    try:
        if os.path.exists(source):
            shutil.move(source, destination)
            return f"Moved {source} to {destination} successfully."
        else:
            return f"Source {source} does not exist."
    except Exception as e:
        return f"Error moving file or directory: {e}"