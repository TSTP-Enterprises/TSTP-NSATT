#!/usr/bin/env python3
import os
import sqlite3
import json
import requests
import logging
import sys

# Paths
DB_PATH = "/home/nsatt-admin/nsatt/settings/nsatt_booter.db"
API_KEY_FILE = "/home/nsatt-admin/nsatt/settings/secure/openai_api_key.txt"
LOG_FILE = "/home/nsatt-admin/nsatt/logs/nsatt_booster.log"
OPENAI_API_ENDPOINT = "https://api.openai.com/v1/chat/completions"

# Setup logging
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.DEBUG,
    format='%(asctime)s %(levelname)s: %(message)s'
)

def ensure_directories():
    try:
        os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
        os.makedirs(os.path.dirname(API_KEY_FILE), exist_ok=True)
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    except Exception as e:
        logging.error(f"Error ensuring directories: {e}")
        print("An error occurred while ensuring directories. Check the log for details.")
        sys.exit(1)

def get_api_key():
    try:
        if not os.path.isfile(API_KEY_FILE):
            raise FileNotFoundError(f"API key file not found at {API_KEY_FILE}")
        with open(API_KEY_FILE, 'r') as f:
            for line in f:
                if line.startswith("KEY="):
                    return line.split("=", 1)[1].strip().strip('"')
        raise ValueError("API key not found in the API key file.")
    except Exception as e:
        logging.error(f"Error reading API key: {e}")
        print("An error occurred while reading the API key. Check the log for details.")
        return None

def send_to_openai(prompt, model="gpt-3.5-turbo", messages=None):
    try:
        api_key = get_api_key()
        if not api_key:
            return None
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        if messages is None:
            messages = [
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": prompt}
            ]
        else:
            messages.append({"role": "user", "content": prompt})
        payload = {
            "model": model,
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 1500,
        }
        logging.debug(f"Sending payload to OpenAI: {json.dumps(payload)}")
        response = requests.post(OPENAI_API_ENDPOINT, headers=headers, json=payload)
        logging.debug(f"Received response from OpenAI: {response.text}")
        if response.status_code != 200:
            error_message = response.json().get('error', {}).get('message', 'Unknown error')
            logging.error(f"OpenAI API Error: {error_message}")
            print(f"OpenAI API Error: {error_message}")
            return None
        return response.json()
    except Exception as e:
        logging.error(f"Error during OpenAI API call: {e}")
        print("An error occurred during the OpenAI API call. Check the log for details.")
        return None

def init_db():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE
        )
        """)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS scripts (
            id INTEGER PRIMARY KEY,
            category_id INTEGER,
            name TEXT,
            command TEXT,
            FOREIGN KEY(category_id) REFERENCES categories(id)
        )
        """)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS menu_order (
            position INTEGER PRIMARY KEY,
            item_type TEXT,
            item_id INTEGER, -- For categories or functions
            name TEXT
        )
        """)
        conn.commit()
        conn.close()
    except Exception as e:
        logging.error(f"Error initializing database: {e}")
        print("An error occurred while initializing the database. Check the log for details.")
        sys.exit(1)

def list_categories():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT id, name FROM categories")
        categories = cursor.fetchall()
        conn.close()
        return categories
    except Exception as e:
        logging.error(f"Error listing categories: {e}")
        print("An error occurred while listing categories. Check the log for details.")
        return []

def list_scripts(category_id=None):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        if category_id:
            cursor.execute("SELECT id, name, command FROM scripts WHERE category_id=?", (category_id,))
        else:
            cursor.execute("SELECT id, name, command FROM scripts")
        scripts = cursor.fetchall()
        conn.close()
        return scripts
    except Exception as e:
        logging.error(f"Error listing scripts: {e}")
        print("An error occurred while listing scripts. Check the log for details.")
        return []

def add_category(name):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("INSERT OR IGNORE INTO categories (name) VALUES (?)", (name,))
        conn.commit()
        conn.close()
        # Update menu order
        add_menu_item('category', name)
    except Exception as e:
        logging.error(f"Error adding category: {e}")
        print("An error occurred while adding a category. Check the log for details.")

def delete_category(category_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        # Check if category exists
        cursor.execute("SELECT name FROM categories WHERE id=?", (category_id,))
        category = cursor.fetchone()
        if not category:
            print("Category not found.")
            return
        category_name = category[0]
        # Handle scripts under this category
        cursor.execute("SELECT id FROM scripts WHERE category_id=?", (category_id,))
        scripts = cursor.fetchall()
        if scripts:
            print("This category has scripts.")
            action = input("Do you want to (D)elete scripts or (M)ove them to another category? ").strip().lower()
            if action == 'd':
                cursor.execute("DELETE FROM scripts WHERE category_id=?", (category_id,))
                print("Scripts deleted.")
            elif action == 'm':
                categories = list_categories()
                print("Available categories:")
                for cat in categories:
                    if cat[0] != category_id:
                        print(f"{cat[0]}: {cat[1]}")
                new_category_id = int(input("Enter new category ID to move scripts to: "))
                cursor.execute("UPDATE scripts SET category_id=? WHERE category_id=?", (new_category_id, category_id))
                print("Scripts moved.")
            else:
                print("Invalid choice. Aborting delete operation.")
                return
        # Delete the category
        cursor.execute("DELETE FROM categories WHERE id=?", (category_id,))
        conn.commit()
        conn.close()
        # Remove from menu order
        remove_menu_item('category', category_name)
        print(f"Category '{category_name}' deleted.")
    except Exception as e:
        logging.error(f"Error deleting category: {e}")
        print("An error occurred while deleting the category. Check the log for details.")

def add_script(category_id, name, command):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO scripts (category_id, name, command) VALUES (?, ?, ?)", (category_id, name, command))
        conn.commit()
        conn.close()
    except Exception as e:
        logging.error(f"Error adding script: {e}")
        print("An error occurred while adding a script. Check the log for details.")

def delete_script(script_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM scripts WHERE id=?", (script_id,))
        conn.commit()
        conn.close()
    except Exception as e:
        logging.error(f"Error deleting script: {e}")
        print("An error occurred while deleting a script. Check the log for details.")

def add_menu_item(item_type, name):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        # Get the next position
        cursor.execute("SELECT MAX(position) FROM menu_order")
        max_position = cursor.fetchone()[0]
        position = (max_position or 0) + 1
        cursor.execute("INSERT INTO menu_order (position, item_type, name) VALUES (?, ?, ?)", (position, item_type, name))
        conn.commit()
        conn.close()
    except Exception as e:
        logging.error(f"Error adding menu item: {e}")

def remove_menu_item(item_type, name):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM menu_order WHERE item_type=? AND name=?", (item_type, name))
        conn.commit()
        conn.close()
    except Exception as e:
        logging.error(f"Error removing menu item: {e}")

def get_menu_items():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT position, item_type, name FROM menu_order ORDER BY position")
        items = cursor.fetchall()
        conn.close()
        return items
    except Exception as e:
        logging.error(f"Error retrieving menu items: {e}")
        return []

def reorder_menu():
    try:
        items = get_menu_items()
        if not items:
            print("No menu items to reorder.")
            return
        print("\nCurrent Menu Order:")
        for item in items:
            print(f"{item[0]}. {item[2]} ({item[1]})")
        old_position = int(input("Enter the number of the menu item to move: "))
        new_position = int(input("Enter the new position for this menu item: "))
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        # Update positions
        cursor.execute("UPDATE menu_order SET position=? WHERE position=?", (-1, old_position))
        if new_position < old_position:
            cursor.execute("UPDATE menu_order SET position=position+1 WHERE position>=? AND position<?", (new_position, old_position))
        elif new_position > old_position:
            cursor.execute("UPDATE menu_order SET position=position-1 WHERE position<=? AND position>? AND position!=-1", (new_position, old_position))
        cursor.execute("UPDATE menu_order SET position=? WHERE position=-1", (new_position,))
        conn.commit()
        conn.close()
        print("Menu reordered.")
    except Exception as e:
        logging.error(f"Error reordering menu: {e}")
        print("An error occurred while reordering the menu. Check the log for details.")

def chat_with_openai():
    try:
        messages = [{"role": "system", "content": "You are a helpful assistant."}]
        print("You can start chatting with the OpenAI assistant. Type 'exit' to end the chat.")
        while True:
            user_input = input("You: ")
            if user_input.lower() in ('exit', 'quit'):
                break
            messages.append({"role": "user", "content": user_input})
            response = send_to_openai(user_input, messages=messages)
            if response:
                assistant_reply = response['choices'][0]['message']['content']
                print(f"Assistant: {assistant_reply}")
                messages.append({"role": "assistant", "content": assistant_reply})
            else:
                print("Failed to get a response from the assistant.")
    except Exception as e:
        logging.error(f"Error in chat_with_openai: {e}")
        print("An error occurred during the chat. Check the log for details.")

def exit_program():
    print("Exiting NSATT Manager.")
    sys.exit(0)

def main():
    ensure_directories()
    init_db()
    # Initialize default menu items if not present
    default_functions = [
        ('Create Category', 'function'),
        ('List Categories', 'function'),
        ('Add Script to Category', 'function'),
        ('List Scripts', 'function'),
        ('Generate Script via OpenAI', 'function'),
        ('Run Script', 'function'),
        ('Delete Script', 'function'),
        ('Delete Category', 'function'),
        ('Chat with OpenAI Assistant', 'function'),
        ('Reorder Menu', 'function'),
        ('Exit', 'function'),
    ]
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM menu_order")
    if cursor.fetchone()[0] == 0:
        position = 1
        for name, item_type in default_functions:
            cursor.execute("INSERT INTO menu_order (position, item_type, name) VALUES (?, ?, ?)", (position, item_type, name))
            position += 1
    conn.commit()
    conn.close()

    while True:
        try:
            menu_items = get_menu_items()
            print("\n=== NSATT Manager ===")
            for item in menu_items:
                print(f"{item[0]}. {item[2]}")
            choice_input = input("Choose an option: ")
            if not choice_input.isdigit():
                print("Invalid input. Please enter a number.")
                continue
            choice = int(choice_input)
            selected_item = next((item for item in menu_items if item[0] == choice), None)
            if not selected_item:
                print("Invalid choice. Please try again.")
                continue
            name = selected_item[2]
            if name == 'Create Category':
                name = input("Enter category name: ")
                add_category(name)
                print(f"Category '{name}' created.")

            elif name == 'List Categories':
                categories = list_categories()
                if categories:
                    print("\nCategories:")
                    for cat in categories:
                        print(f"{cat[0]}: {cat[1]}")
                else:
                    print("No categories found.")

            elif name == 'Add Script to Category':
                categories = list_categories()
                if categories:
                    print("\nCategories:")
                    for cat in categories:
                        print(f"{cat[0]}: {cat[1]}")
                    category_id = int(input("Choose category ID: "))
                    name = input("Enter script name: ")
                    command = input("Enter command: ")
                    add_script(category_id, name, command)
                    print(f"Script '{name}' added.")
                else:
                    print("No categories found. Please create a category first.")

            elif name == 'List Scripts':
                categories = list_categories()
                if categories:
                    print("\nCategories:")
                    for cat in categories:
                        print(f"{cat[0]}: {cat[1]}")
                    category_id_input = input("Choose category ID (0 for all scripts): ")
                    if category_id_input.isdigit():
                        category_id = int(category_id_input)
                    else:
                        print("Invalid input. Showing all scripts.")
                        category_id = 0
                    scripts = list_scripts(category_id if category_id > 0 else None)
                    if scripts:
                        print("\nScripts:")
                        for script in scripts:
                            print(f"{script[0]}: {script[1]} - {script[2]}")
                    else:
                        print("No scripts found.")
                else:
                    print("No categories found.")

            elif name == 'Generate Script via OpenAI':
                prompt = input("Enter your script idea: ")
                response = send_to_openai(prompt)
                if response:
                    script_content = response['choices'][0]['message']['content']
                    print("\nGenerated Script:")
                    print(script_content)
                    while True:
                        action = input("Do you want to (E)xecute, (S)ave, (A)dd more, or (D)iscard? ").strip().lower()
                        if action == "e":
                            try:
                                exec(script_content, globals())
                            except Exception as e:
                                logging.error(f"Error executing generated script: {e}")
                                print("An error occurred while executing the script. Check the log for details.")
                            break
                        elif action == "s":
                            name = input("Enter script name: ")
                            # Ensure 'Generated Scripts' category exists
                            add_category("Generated Scripts")
                            # Get the category_id for 'Generated Scripts'
                            conn = sqlite3.connect(DB_PATH)
                            cursor = conn.cursor()
                            cursor.execute("SELECT id FROM categories WHERE name=?", ("Generated Scripts",))
                            category = cursor.fetchone()
                            conn.close()
                            if category:
                                category_id = category[0]
                                add_script(category_id, name, script_content)
                                print(f"Script '{name}' saved under 'Generated Scripts' category.")
                            else:
                                print("Error: 'Generated Scripts' category not found.")
                            break
                        elif action == "a":
                            enhancement_prompt = input("Enter additional instructions or enhancements for the script: ")
                            prompt = f"{script_content}\n\nEnhance the above script with the following instructions:\n{enhancement_prompt}"
                            response = send_to_openai(prompt)
                            if response:
                                script_content = response['choices'][0]['message']['content']
                                print("\nEnhanced Script:")
                                print(script_content)
                            else:
                                print("Failed to enhance the script.")
                        elif action == "d":
                            print("Script discarded.")
                            break
                        else:
                            print("Invalid choice. Please try again.")
                else:
                    print("Failed to generate script.")

            elif name == 'Run Script':
                scripts = list_scripts()
                if scripts:
                    print("\nScripts:")
                    for script in scripts:
                        print(f"{script[0]}: {script[1]}")
                    script_id_input = input("Enter script ID to run: ")
                    if script_id_input.isdigit():
                        script_id = int(script_id_input)
                        script = next((s for s in scripts if s[0] == script_id), None)
                        if script:
                            try:
                                os.system(script[2])
                            except Exception as e:
                                logging.error(f"Error running script '{script[1]}': {e}")
                                print("An error occurred while running the script. Check the log for details.")
                        else:
                            print("Script not found.")
                    else:
                        print("Invalid script ID.")
                else:
                    print("No scripts found.")

            elif name == 'Delete Script':
                scripts = list_scripts()
                if scripts:
                    print("\nScripts:")
                    for script in scripts:
                        print(f"{script[0]}: {script[1]}")
                    script_id_input = input("Enter script ID to delete: ")
                    if script_id_input.isdigit():
                        script_id = int(script_id_input)
                        delete_script(script_id)
                        print("Script deleted.")
                    else:
                        print("Invalid script ID.")
                else:
                    print("No scripts found.")

            elif name == 'Delete Category':
                categories = list_categories()
                if categories:
                    print("\nCategories:")
                    for cat in categories:
                        print(f"{cat[0]}: {cat[1]}")
                    category_id_input = input("Enter category ID to delete: ")
                    if category_id_input.isdigit():
                        category_id = int(category_id_input)
                        delete_category(category_id)
                    else:
                        print("Invalid category ID.")
                else:
                    print("No categories found.")

            elif name == 'Chat with OpenAI Assistant':
                chat_with_openai()

            elif name == 'Reorder Menu':
                reorder_menu()

            elif name == 'Exit':
                exit_program()

            else:
                # Handle categories in the menu
                categories = list_categories()
                category = next((c for c in categories if c[1] == name), None)
                if category:
                    category_id = category[0]
                    scripts = list_scripts(category_id)
                    if scripts:
                        print(f"\nScripts in '{name}' category:")
                        for script in scripts:
                            print(f"{script[0]}: {script[1]} - {script[2]}")
                        script_id_input = input("Enter script ID to run or 'b' to go back: ")
                        if script_id_input.lower() == 'b':
                            continue
                        elif script_id_input.isdigit():
                            script_id = int(script_id_input)
                            script = next((s for s in scripts if s[0] == script_id), None)
                            if script:
                                try:
                                    os.system(script[2])
                                except Exception as e:
                                    logging.error(f"Error running script '{script[1]}': {e}")
                                    print("An error occurred while running the script. Check the log for details.")
                            else:
                                print("Script not found.")
                        else:
                            print("Invalid input.")
                    else:
                        print("No scripts found in this category.")
                else:
                    print("Invalid selection.")

        except Exception as e:
            logging.error(f"An unexpected error occurred in the main loop: {e}")
            print("An unexpected error occurred. The program will reload.")

if __name__ == "__main__":
    main()
