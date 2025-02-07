import subprocess
import logging

def control_service(service_name, action):
    try:
        subprocess.getoutput(f"sudo systemctl {action} {service_name}")
        logging.info(f"The {action} action for service {service_name} has been completed successfully.")
        return f"The {action} action for service {service_name} has been completed successfully."
    except Exception as e:
        logging.error(f"Error {action}ing {service_name}: {e}")
        return f"Error {action}ing {service_name}: {e}"

def get_service_status(service_name):
    try:
        status_output = subprocess.getoutput(f"systemctl is-active {service_name}")
        status = "active" if status_output == "active" else "inactive"
        return {"service": service_name, "status": status}
    except Exception as e:
        logging.error(f"Error getting status of {service_name}: {e}")
        return {"error": str(e)}

def restart_device():
    try:
        subprocess.getoutput("sudo reboot")
        return "Device is restarting."
    except Exception as e:
        logging.error(f"Error restarting device: {e}")
        return f"Error restarting device: {e}"

def stop_script():
    try:
        subprocess.getoutput("service lldpd stop")
        subprocess.getoutput("service vsftpd stop")
        subprocess.getoutput("pkill -f 'python3 app.py'")
        return "Script stopped successfully."
    except Exception as e:
        logging.error(f"Error stopping script: {e}")
        return f"Error stopping script: {e}"
