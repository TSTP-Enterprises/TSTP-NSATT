import requests
import json
import re
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QLineEdit, QTextEdit, QLabel, QFileDialog, QProgressBar, QSizePolicy,
                            QScrollArea)
from PyQt5.QtCore import Qt, QTimer

plugin_image_value = "/nsatt/storage/images/icons/chatgpt_icon.png"

class Plugin:
    NAME = "AI Chat Plugin"
    CATEGORY = "AI Tools"
    DESCRIPTION = "Chat with OpenAI API, detect code, and save it locally."

    def __init__(self):
        self.widget = None
        self.api_key = None

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            # Set size policy for the main widget to expand horizontally
            self.widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Minimum)
            main_layout = QVBoxLayout()
            main_layout.setContentsMargins(0, 0, 0, 0)  # Remove margins
            self.widget.setLayout(main_layout)

            # API Key Input (stays at top)
            key_layout = QHBoxLayout()
            key_layout.setContentsMargins(0, 0, 0, 0)
            key_label = QLabel("API Key:")
            self.api_key_input = QLineEdit()
            self.api_key_input.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            self.api_key_input.setEchoMode(QLineEdit.Password)
            save_key_button = QPushButton("Save Key")
            save_key_button.clicked.connect(self.save_api_key)
            key_layout.addWidget(key_label)
            key_layout.addWidget(self.api_key_input)
            key_layout.addWidget(save_key_button)
            main_layout.addLayout(key_layout)

            # Display Area
            self.display_area = QTextEdit()
            self.display_area.setReadOnly(True)
            
            # Prevent internal scrolling and ensure the widget expands
            self.display_area.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            self.display_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            self.display_area.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Minimum)
            self.display_area.setMinimumWidth(400)  # Set a reasonable minimum width
            self.display_area.document().documentLayout().documentSizeChanged.connect(self.adjust_text_edit_height)
            main_layout.addWidget(self.display_area)

            # Bottom controls container
            bottom_container = QWidget()
            bottom_container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            bottom_layout = QVBoxLayout(bottom_container)
            bottom_layout.setContentsMargins(0, 0, 0, 0)

            # Message Input
            self.message_input = QLineEdit()
            self.message_input.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            self.message_input.setPlaceholderText("Enter your message here...")
            bottom_layout.addWidget(self.message_input)

            # Send Button
            send_button = QPushButton("Send")
            send_button.clicked.connect(self.send_message)
            bottom_layout.addWidget(send_button)

            # Save Code Button
            self.save_button = QPushButton("Save Code")
            self.save_button.setEnabled(False)
            self.save_button.clicked.connect(self.save_code)
            bottom_layout.addWidget(self.save_button)

            main_layout.addWidget(bottom_container)

        return self.widget

    def save_api_key(self):
        self.api_key = self.api_key_input.text()
        self.display_area.append("API key saved.")

    def send_message(self):
        try:
            if not self.api_key:
                self.display_area.append("Error: API key not set.")
                return

            user_message = self.message_input.text()
            if not user_message.strip():
                self.display_area.append("Error: Message cannot be empty.")
                return

            self.display_area.append(f"User: {user_message}")
            self.message_input.clear()  # Clear input after sending
            
            # Disable send button while processing
            send_button = self.widget.findChild(QPushButton, "send_button")
            if send_button:
                send_button.setEnabled(False)
            
            try:
                response = self.get_openai_response(user_message)
                if response:
                    self.display_area.append(f"AI: {response}")
                    if self.detect_code(response):
                        self.save_button.setEnabled(True)
            finally:
                # Re-enable send button
                if send_button:
                    send_button.setEnabled(True)
                    
        except Exception as e:
            self.display_area.append(f"Error in send_message: {str(e)}")
            import traceback
            self.display_area.append(f"Details: {traceback.format_exc()}")

    def get_openai_response(self, message):
        try:
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}"
            }
            
            payload = {
                "model": "gpt-3.5-turbo",
                "messages": [{"role": "user", "content": message}]
            }
            
            try:
                response = requests.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers=headers,
                    json=payload,
                    timeout=30  # Add timeout
                )
            except requests.exceptions.Timeout:
                self.display_area.append("Error: API request timed out")
                return None
            except requests.exceptions.ConnectionError:
                self.display_area.append("Error: Connection failed. Please check your internet connection")
                return None
            
            try:
                response_data = response.json()
            except json.JSONDecodeError:
                self.display_area.append("Error: Invalid response from API")
                return None
            
            if response.status_code != 200:
                error_message = response_data.get('error', {}).get('message', 'Unknown error occurred')
                self.display_area.append(f"API Error: {error_message}")
                return None
                
            return response_data['choices'][0]['message']['content']
            
        except requests.exceptions.RequestException as e:
            self.display_area.append(f"Network Error: {str(e)}")
            return None
        except Exception as e:
            self.display_area.append(f"Error in get_openai_response: {str(e)}")
            import traceback
            self.display_area.append(f"Details: {traceback.format_exc()}")
            return None

    def detect_code(self, text):
        try:
            if not text:
                return False
                
            code_blocks = re.findall(r"```(.*?)```", text, re.DOTALL)
            if code_blocks:
                self.code_to_save = "\n\n".join(code_blocks)
                self.display_area.append("Code detected in response.")
                return True
            return False
        except Exception as e:
            self.display_area.append(f"Error in detect_code: {str(e)}")
            return False

    def save_code(self):
        if hasattr(self, 'code_to_save') and self.code_to_save:
            options = QFileDialog.Options()
            file_path, _ = QFileDialog.getSaveFileName(
                self.widget, "Save Code File", "", "Python Files (*.py);;All Files (*)", options=options
            )
            if file_path:
                with open(file_path, 'w') as file:
                    file.write(self.code_to_save)
                self.display_area.append(f"Code saved to {file_path}.")

    def adjust_text_edit_height(self):
        """Adjust the height of QTextEdit to fit its content"""
        try:
            # Calculate the document height
            doc_height = self.display_area.document().size().height()
            # Add some padding
            height = int(doc_height + 20)
            # Set both minimum and maximum height to force the widget to be exactly this tall
            self.display_area.setMinimumHeight(height)
            self.display_area.setMaximumHeight(height)
            # Update the widget's geometry
            self.widget.adjustSize()
        except Exception as e:
            print(f"Error adjusting height: {str(e)}")
