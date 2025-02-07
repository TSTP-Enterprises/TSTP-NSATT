import os
import sqlite3
import logging
import subprocess

# Initialize logging
logging.basicConfig(level=logging.ERROR, format='%(asctime)s - %(levelname)s - %(message)s')

def initialize_databases():
    logging.info("Starting Database Initialization")
    
    # Database schemas
    schemas = {
        '/nsatt/storage/databases/network_info.db': [
            '''CREATE TABLE IF NOT EXISTS network_info (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                time TEXT,
                ip TEXT,
                mac TEXT,
                gateway TEXT,
                hostname TEXT,
                switch_info TEXT,
                wan_ip TEXT,
                wan_gateway TEXT,
                isp TEXT,
                region TEXT,
                city TEXT,
                country TEXT,
                browser TEXT,
                requesting_ip TEXT,
                dns_servers TEXT DEFAULT 'N/A',
                subnet_mask TEXT DEFAULT 'N/A',
                broadcast_ip TEXT DEFAULT 'N/A',
                org TEXT DEFAULT 'N/A',
                referer TEXT DEFAULT 'N/A',
                user_agent_platform TEXT DEFAULT 'N/A',
                user_agent_version TEXT DEFAULT 'N/A',
                user_agent_language TEXT DEFAULT 'N/A')'''
        ],
        '/nsatt/storage/databases/nmap_results.db': [
            '''CREATE TABLE IF NOT EXISTS nmap_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                time TEXT,
                scan_type TEXT,
                options TEXT,
                target TEXT,
                result TEXT)'''
        ],
        '/nsatt/storage/databases/wireless_results.db': [
            '''CREATE TABLE IF NOT EXISTS wireless_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                time TEXT,
                scan_type TEXT,
                options TEXT,
                target TEXT,
                result TEXT)'''
        ]
    }

    # Initialize each database
    for db_path, schema_statements in schemas.items():
        try:
            # Ensure the directory exists
            db_dir = os.path.dirname(db_path)
            if not os.path.exists(db_dir):
                os.makedirs(db_dir)

            # Create database file if it doesn't exist
            if not os.path.exists(db_path):
                open(db_path, 'a').close()
            
            # Set permissions
            subprocess.getoutput(f"chmod 755 {db_path}")

            # Connect and initialize
            conn = sqlite3.connect(db_path)
            c = conn.cursor()

            # Create schema version table
            c.execute('''CREATE TABLE IF NOT EXISTS schema_version (
                            version INTEGER PRIMARY KEY,
                            applied_on TEXT NOT NULL)''')

            # Check current version
            c.execute('SELECT MAX(version) FROM schema_version')
            current_version = c.fetchone()[0] or 0

            if current_version < 1:
                # Execute schema statements
                for statement in schema_statements:
                    c.execute(statement)

                # Update schema version
                c.execute('INSERT INTO schema_version (version, applied_on) VALUES (?, datetime("now"))', (1,))

            conn.commit()

        except sqlite3.Error as db_error:
            logging.error(f"SQLite error occurred while initializing {db_path}: {db_error}")
        except Exception as e:
            logging.error(f"Failed to initialize database at {db_path}: {e}")
        finally:
            if 'conn' in locals():
                conn.close()

    logging.info("Database Initialization Complete")

# Initialize all databases
initialize_databases()
