import os
import sys
import time
import subprocess

def wait_for_port_to_free(port, timeout=5):
    """Wait until the specified port is free."""
    for _ in range(timeout):
        result = subprocess.run(['lsof', '-i', f':{port}'], capture_output=True, text=True)
        if not result.stdout:  # Port is free
            return True
        time.sleep(1)
    return False

def restart_main_script():
    time.sleep(5)  # Wait 10 seconds before restarting
    os.execv(sys.executable, ['python3'] + sys.argv)

if __name__ == "__main__":
    port = 8080  # Change to your port if different
    if wait_for_port_to_free(port):
        print(f"Port {port} is free, restarting the script...")
        restart_main_script()
    else:
        print(f"Port {port} is still in use after waiting, restart aborted.")