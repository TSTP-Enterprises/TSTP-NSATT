from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QLineEdit, QPushButton, QHBoxLayout, QMessageBox, QCheckBox
from PyQt5.QtCore import Qt
import json
import os

class LoginWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.layout = QVBoxLayout()
        self.setLayout(self.layout)
        self.logged_in = False
        self.max_attempts = 3
        self.attempts = 0
        self.credentials_file = "/nsatt/storage/credentials.json"
        self.remember_file = "/nsatt/storage/remember_login.json"
        self.setFixedSize(400, 300)  # Set fixed size for widget

    def initialize(self):
        try:
            # Ensure credentials file exists
            self.ensure_credentials_file()
            
            # Check for remembered login
            self.check_remembered_login()
            
            # Create main layout with center alignment and spacing
            self.layout.setAlignment(Qt.AlignCenter)
            self.layout.setSpacing(20)
            self.layout.setContentsMargins(20, 20, 20, 20)
            
            # Create title
            title = QLabel("NSATT Login")
            title.setAlignment(Qt.AlignCenter)
            title.setStyleSheet("font-size: 24px; font-weight: bold; margin-bottom: 20px;")
            self.layout.addWidget(title)

            # Username field
            username_layout = QHBoxLayout()
            username_label = QLabel("Username:")
            username_label.setMinimumWidth(80)
            self.username_input = QLineEdit()
            self.username_input.setPlaceholderText("Enter username")
            self.username_input.setMinimumWidth(200)
            username_layout.addWidget(username_label)
            username_layout.addWidget(self.username_input)
            self.layout.addLayout(username_layout)

            # Password field  
            password_layout = QHBoxLayout()
            password_label = QLabel("Password:")
            password_label.setMinimumWidth(80)
            self.password_input = QLineEdit()
            self.password_input.setPlaceholderText("Enter password")
            self.password_input.setEchoMode(QLineEdit.Password)
            self.password_input.setMinimumWidth(200)
            self.password_input.returnPressed.connect(self.handle_login)
            password_layout.addWidget(password_label)
            password_layout.addWidget(self.password_input)
            self.layout.addLayout(password_layout)

            # Remember me checkbox
            self.remember_checkbox = QCheckBox("Remember me")
            self.remember_checkbox.setStyleSheet("margin-left: 80px;")
            self.layout.addWidget(self.remember_checkbox)

            # Login button
            button_layout = QHBoxLayout()
            login_button = QPushButton("Login")
            login_button.setFixedSize(120, 40)
            login_button.clicked.connect(self.handle_login)
            button_layout.addStretch()
            button_layout.addWidget(login_button)
            button_layout.addStretch()
            self.layout.addLayout(button_layout)

            # Status label
            self.status_label = QLabel("")
            self.status_label.setAlignment(Qt.AlignCenter)
            self.status_label.setStyleSheet("color: red; font-weight: bold;")
            self.layout.addWidget(self.status_label)

            # Add stretch at bottom to keep everything aligned
            self.layout.addStretch()

            return True
            
        except Exception as e:
            print(f"Failed to initialize LoginWidget: {e}")
            return False

    def ensure_credentials_file(self):
        try:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(self.credentials_file), exist_ok=True)
            
            # Create credentials file if it doesn't exist
            if not os.path.exists(self.credentials_file):
                default_creds = {
                    "admin": "admin123"  # Default credentials
                }
                with open(self.credentials_file, 'w') as f:
                    json.dump(default_creds, f)
                # Set file permissions
                os.chmod(self.credentials_file, 0o644)
        except Exception as e:
            print(f"Failed to ensure credentials file: {e}")
            # Create in-memory credentials if file operations fail
            self.credentials = {"admin": "admin123"}

    def check_remembered_login(self):
        try:
            if os.path.exists(self.remember_file):
                with open(self.remember_file, 'r') as f:
                    remembered = json.load(f)
                    username = remembered.get('username')
                    password = remembered.get('password')
                    
                    # Verify credentials still valid
                    with open(self.credentials_file, 'r') as cf:
                        valid_credentials = json.load(cf)
                        if username in valid_credentials and valid_credentials[username] == password:
                            self.logged_in = True
        except Exception as e:
            print(f"Error checking remembered login: {e}")

    def handle_login(self):
        try:
            username = self.username_input.text()
            password = self.password_input.text()

            if not username or not password:
                self.status_label.setText("Please enter both username and password")
                return

            try:
                with open(self.credentials_file, 'r') as f:
                    valid_credentials = json.load(f)
            except:
                # Fall back to in-memory credentials if file can't be read
                valid_credentials = {"nsatt": "nsatt"}

            if username in valid_credentials and valid_credentials[username] == password:
                self.logged_in = True
                self.status_label.setText("Login successful!")
                self.status_label.setStyleSheet("color: green; font-weight: bold;")
                
                # Save credentials if remember me is checked
                if self.remember_checkbox.isChecked():
                    try:
                        with open(self.remember_file, 'w') as f:
                            json.dump({
                                'username': username,
                                'password': password
                            }, f)
                    except Exception as e:
                        print(f"Error saving remembered login: {e}")
            else:
                self.attempts += 1
                remaining = self.max_attempts - self.attempts
                self.status_label.setText(f"Invalid credentials. {remaining} attempts remaining.")
                self.password_input.clear()
                
                if self.attempts >= self.max_attempts:
                    QMessageBox.critical(self, "Login Failed", "Maximum login attempts exceeded.\nPlease contact system administrator.")
                    self.username_input.setEnabled(False)
                    self.password_input.setEnabled(False)

        except Exception as e:
            self.status_label.setText("Login error occurred")
            print(f"Login error: {e}")

    def is_logged_in(self):
        return self.logged_in

    def logout(self):
        self.logged_in = False
        self.attempts = 0
        self.username_input.setEnabled(True)
        self.password_input.setEnabled(True)
        self.username_input.clear()
        self.password_input.clear()
        self.status_label.clear()
        
        # Clear remembered login
        try:
            if os.path.exists(self.remember_file):
                os.remove(self.remember_file)
        except Exception as e:
            print(f"Error clearing remembered login: {e}")
