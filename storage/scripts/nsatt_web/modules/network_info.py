import os
import subprocess
import requests
import sqlite3
from datetime import datetime
from flask import request
import logging

# Initialize logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

from ipaddress import ip_network

def get_network_info(db_path, save_to_db=True):
    try:
        logging.info("Gathering network information...")

        # Gather LAN information
        lan_ip = subprocess.getoutput("hostname -I | awk '{print $1}'") or "N/A"
        mac = subprocess.getoutput("cat /sys/class/net/eth0/address") or "N/A"
        gateway = subprocess.getoutput("ip route | grep default | awk '{print $3}'") or "N/A"
        hostname = subprocess.getoutput("hostname") or "N/A"

        # Format the switch info for readability
        raw_switch_info = subprocess.getoutput("sudo lldpctl") or "N/A"
        switch_info = "\n".join(raw_switch_info.splitlines()) if raw_switch_info != "N/A" else "N/A"

        dns_servers = subprocess.getoutput("grep 'nameserver' /etc/resolv.conf | awk '{print $2}'") or "N/A"

        # Subnet Mask in CIDR notation
        cidr_subnet_mask = subprocess.getoutput("ip addr show eth0 | grep 'inet ' | awk '{print $2}'")
        subnet_mask = str(ip_network(cidr_subnet_mask, strict=False).netmask) if cidr_subnet_mask else "N/A"

        # Broadcast IP
        broadcast_ip = subprocess.getoutput("ip addr show eth0 | grep 'inet ' | awk '{print $4}'") or "N/A"

        # WAN Information
        wan_ip = "N/A"
        wan_gateway = "N/A"
        region = "N/A"
        city = "N/A"
        country = "N/A"
        isp = "N/A"
        org = "N/A"

        try:
            isp_info = requests.get('https://ipinfo.io').json()
            wan_ip = isp_info.get('ip', 'N/A')
            wan_gateway = subprocess.getoutput("ip route get 8.8.8.8 | grep -oP '(?<=via )(\\S+)'") or "N/A"
            region = isp_info.get('region', 'N/A')
            city = isp_info.get('city', 'N/A')
            country = isp_info.get('country', 'N/A')
            isp = isp_info.get('org', 'N/A')
            org = isp_info.get('org', 'N/A')
        except requests.RequestException as wan_error:
            logging.error(f"Error gathering WAN info: {wan_error}")

        # Gather Request Information
        requesting_ip = request.remote_addr or "N/A"
        browser = request.user_agent.string or "N/A"
        referer = request.referrer or "N/A"
        user_agent_platform = request.user_agent.platform or "N/A"
        user_agent_version = request.user_agent.version or "N/A"
        user_agent_language = request.accept_languages.best or "N/A"

        # Format interface names to show each interface on a new line
        raw_interface_names = subprocess.getoutput("ip -o link show | awk -F': ' '{print $2}'") or "N/A"
        interface_names = "<br>".join(raw_interface_names.splitlines()) if raw_interface_names != "N/A" else "N/A"

        default_gateway = subprocess.getoutput("ip route | grep default | awk '{print $3}'") or "N/A"
        routing_table = subprocess.getoutput("ip route show") or "N/A"

        # Prepare all info for display and save
        network_info = {
            'time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'lan_ip': lan_ip,
            'mac': mac,
            'gateway': gateway,
            'hostname': hostname,
            'switch_info': switch_info,
            'dns_servers': dns_servers,
            'subnet_mask': subnet_mask,
            'broadcast_ip': broadcast_ip,
            'wan_ip': wan_ip,
            'wan_gateway': wan_gateway,
            'region': region,
            'city': city,
            'country': country,
            'isp': isp,
            'org': org,
            'requesting_ip': requesting_ip,
            'browser': browser,
            'referer': referer,
            'user_agent_platform': user_agent_platform,
            'user_agent_version': user_agent_version,
            'user_agent_language': user_agent_language,
            'interface_names': interface_names,
            'default_gateway': default_gateway,
            'routing_table': routing_table
        }

        if save_to_db:
            conn = sqlite3.connect(db_path)
            try:
                c = conn.cursor()
                c.execute('''INSERT INTO network_info (time, ip, mac, gateway, hostname, switch_info, dns_servers, subnet_mask, broadcast_ip, isp, org, region, city, country, requesting_ip, browser, referer, user_agent_platform, user_agent_version, user_agent_language, wan_ip, wan_gateway)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                        (network_info['time'], network_info['lan_ip'], network_info['mac'],
                         network_info['gateway'], network_info['hostname'],
                         network_info['switch_info'], network_info['dns_servers'],
                         network_info['subnet_mask'], network_info['broadcast_ip'],
                         network_info['isp'], network_info['org'],
                         network_info['region'], network_info['city'],
                         network_info['country'], network_info['requesting_ip'],
                         network_info['browser'], network_info['referer'],
                         network_info['user_agent_platform'], network_info['user_agent_version'],
                         network_info['user_agent_language'], network_info['wan_ip'], network_info['wan_gateway']))
                conn.commit()
                logging.info("Network information saved to database successfully.")
            except sqlite3.Error as db_error:
                logging.error(f"Error saving network info to database: {db_error}")
            finally:
                conn.close()

        return network_info
    except Exception as e:
        logging.exception("Error gathering network info")
        return f"Error gathering network info: {e}"


def get_old_findings(db_path):
    try:
        conn = sqlite3.connect(db_path)
        c = conn.cursor()
        c.execute("SELECT id, time, ip FROM network_info ORDER BY id DESC")
        findings = c.fetchall()
        conn.close()
        logging.info("Old findings retrieved successfully.")
        return findings
    except Exception as e:
        logging.exception("Error retrieving old findings")
        return f"Error retrieving old findings: {e}"

def get_finding_details(db_path, finding_id):
    try:
        conn = sqlite3.connect(db_path)
        c = conn.cursor()
        c.execute("SELECT * FROM network_info WHERE id=?", (finding_id,))
        details = c.fetchone()
        conn.close()
        logging.info(f"Details for finding ID {finding_id} retrieved successfully.")
        return details
    except Exception as e:
        logging.exception(f"Error retrieving finding details for ID {finding_id}")
        return f"Error retrieving finding details: {e}"
    
def clear_all_findings(db_path):
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM network_info")
        conn.commit()
        logging.info("All findings cleared from the database.")
    except Exception as e:
        logging.exception("Error clearing all findings")
    finally:
        conn.close()
