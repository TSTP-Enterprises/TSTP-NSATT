import os
import sys
from flask import request

def restart_script():
    try:
        print("Attempting to restart the script...")
        os.execv(sys.executable, ['python3'] + sys.argv)
    except Exception as e:
        print(f"Error restarting script: {e}")