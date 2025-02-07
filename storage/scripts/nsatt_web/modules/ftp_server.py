import os
import subprocess

def start_ftp_server():
    try:
        subprocess.getoutput("service vsftpd start")
        return "FTP server started successfully."
    except Exception as e:
        return f"Error starting FTP server: {e}"

def stop_ftp_server():
    try:
        subprocess.getoutput("service vsftpd stop")
        return "FTP server stopped successfully."
    except Exception as e:
        return f"Error stopping FTP server: {e}"

def restart_ftp_server():
    try:
        subprocess.getoutput("service vsftpd restart")
        return "FTP server restarted successfully."
    except Exception as e:
        return f"Error restarting FTP server: {e}"