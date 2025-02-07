import os
import sys
from werkzeug.wrappers import request
import subprocess

def restart_script():
    try:
        print("Attempting to restart the script...")

        # Launch the delay script as a new process
        subprocess.Popen([sys.executable, 'delay.py'] + sys.argv)

        # Shutdown the current server
        shutdown_server()

    except Exception as e:
        print(f"Error restarting script: {e}")

def shutdown_server():
    func = request.environ.get('werkzeug.server.shutdown')
    if func is None:
        raise RuntimeError('Not running with the Werkzeug Server')
    func()
    print("Server is shutting down...")