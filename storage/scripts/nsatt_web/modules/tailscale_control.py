import subprocess
import logging
import json
import os

def get_tailscale_status():
    """Get current Tailscale status"""
    try:
        status_output = subprocess.getoutput("tailscale status --json")
        return json.loads(status_output)
    except Exception as e:
        logging.error(f"Error getting Tailscale status: {e}")
        return {"error": str(e)}

def check_tailscale_installed():
    """Check if Tailscale is installed"""
    try:
        subprocess.run(["tailscale", "--version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def install_tailscale():
    """Install Tailscale"""
    try:
        # Download and install Tailscale for Windows
        download_cmd = "curl -Lo tailscale-setup.exe https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"
        install_cmd = "tailscale-setup.exe /S"
        
        subprocess.run(download_cmd, shell=True, check=True)
        subprocess.run(install_cmd, shell=True, check=True)
        
        # Clean up installer
        if os.path.exists("tailscale-setup.exe"):
            os.remove("tailscale-setup.exe")
            
        return {"success": True, "message": "Tailscale installed successfully"}
    except Exception as e:
        logging.error(f"Error installing Tailscale: {e}")
        return {"success": False, "error": str(e)}

def toggle_tailscale(action):
    """Enable or disable Tailscale"""
    try:
        if action == "up":
            result = subprocess.getoutput("tailscale up")
        else:
            result = subprocess.getoutput("tailscale down")
        return {"success": True, "message": result}
    except Exception as e:
        logging.error(f"Error toggling Tailscale: {e}")
        return {"success": False, "error": str(e)}

def get_tailscale_config():
    """Get Tailscale configuration"""
    try:
        prefs_output = subprocess.getoutput("tailscale get preferences")
        return json.loads(prefs_output)
    except Exception as e:
        logging.error(f"Error getting Tailscale config: {e}")
        return {"error": str(e)}

def update_tailscale_config(config_params):
    """Update Tailscale configuration"""
    try:
        cmd = ["tailscale", "set"]
        for key, value in config_params.items():
            cmd.extend([f"--{key}", str(value)])
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            return {"success": True, "message": "Configuration updated successfully"}
        else:
            return {"success": False, "error": result.stderr}
    except Exception as e:
        logging.error(f"Error updating Tailscale config: {e}")
        return {"success": False, "error": str(e)} 