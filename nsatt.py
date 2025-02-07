#!/usr/bin/env python3
import sys
import os
import json
import shutil
import time
import subprocess
import importlib.util
from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout,
                             QHBoxLayout, QPushButton, QLabel, QGridLayout,
                             QScrollArea, QFrame, QStackedWidget, QComboBox,
                             QSpinBox, QCheckBox, QSpacerItem, QSizePolicy, 
                             QGroupBox, QDialog, QProgressBar, QMessageBox)
from PyQt5.QtCore import Qt, QTimer
from PyQt5.QtGui import QPixmap 
from datetime import datetime

debug_mode = False
debug_mode_1 = False
debug_mode_2 = True
debug_mode_3 = True
debug_mode_4 = True
debug_mode_5 = True
debug_mode_6 = True
debug_mode_7 = True
debug_mode_8 = True
debug_mode_9 = True
debug_mode_10 = True
production_mode = False

class ThemeManager:
    def __init__(self, theme_path="/nsatt/storage/themes"):
        self.theme_path = theme_path
        os.makedirs(self.theme_path, exist_ok=True)
        self.default_theme = {
            "background": "#1E1E1E",
            "secondary": "#2C2C2C", 
            "accent": "#3A3A3A",
            "text": "#FFFFFF",
            "text_background": "#2C2C2C",  # Dark background for QLabel
            "button_background": "#3A3A3A",
            "button_hover": "#505050",
            "close_button_background": "#E81123",
            "close_button_hover": "#F1707A",
            "border_color": "#5A5A5A",
            "border_width": "1px",
            "border_radius": "4px",
            "padding": "8px",
            "spacing": "10px",
            "checkbox_text_color": "#FFFFFF",        # New Property
            "checkbox_background": "#2C2C2C",        # New Property
            "label_color": "#FFFFFF",                 # Added label color
            "card_hover": "#3A3A3A"
        }
        self.ensure_example_themes()
        self.themes = self.load_themes()
        self.themes["default"] = self.default_theme  # Ensure default theme is always available

    def ensure_example_themes(self):
        themes = {
            "dark": {
                "background": "#121212",
                "secondary": "#1F1F1F", 
                "accent": "#2C2C2C",
                "text": "#E0E0E0",  # Light text for readability
                "text_background": "#2C2C2C",  # Dark background for QLabel
                "button_background": "#2C2C2C",
                "button_hover": "#3D3D3D",
                "close_button_background": "#CF6679",
                "close_button_hover": "#B00020",
                "border_color": "#3C3C3C",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "label_color": "#FFFFFF",
                "card_hover": "#3A3A3A",
                "checkbox_text_color": "#E0E0E0",        # Checkbox text color
                "checkbox_background": "#1F1F1F"        # Checkbox background color
            },
            "blue": {
                "background": "#0A192F",
                "secondary": "#112240", 
                "accent": "#1C2541",
                "text": "#A8DADC",  # Light text
                "text_background": "#1C2541",  # Dark background for QLabel
                "button_background": "#1C2541",
                "button_hover": "#3A506B",
                "close_button_background": "#E63946",
                "close_button_hover": "#D62828",
                "border_color": "#3A506B",
                "border_width": "1px",
                "border_radius": "6px",
                "padding": "12px",
                "spacing": "14px",
                "label_color": "#A8DADC",
                "label_background": "#1C2541",
                "card_hover": "#1C2541",
                "checkbox_text_color": "#A8DADC",        # Checkbox text color
                "checkbox_background": "#112240"        # Checkbox background color
            },
            "light": {
                "background": "#F0F0F0",
                "secondary": "#D9D9D9",
                "accent": "#B3B3B3",
                "text": "#333333",  # Dark text for readability
                "text_background": "#FFFFFF",  # Light background for QLabel
                "button_background": "#B3B3B3",
                "button_hover": "#A0A0A0",
                "close_button_background": "#FF6B6B",
                "close_button_hover": "#FF4C4C",
                "border_color": "#A0A0A0",
                "border_width": "1px",
                "border_radius": "6px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#333333",        # Checkbox text color
                "checkbox_background": "#D9D9D9",        # Checkbox background color
                "card_hover": "#D9D9D9"
            },
            "red": {
                "background": "#1C0000",
                "secondary": "#330000",
                "accent": "#4C0000",
                "text": "#FFFFFF",  # Light text
                "text_background": "#4C0000",  # Dark background for QLabel
                "button_background": "#4C0000",
                "button_hover": "#660000",
                "close_button_background": "#FF4C4C",
                "close_button_hover": "#CC0000",
                "border_color": "#660000",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#FFFFFF",        # Checkbox text color
                "checkbox_background": "#330000",        # Checkbox background color
                "card_hover": "#330000"
            },
            "nord": {
                "background": "#2E3440",
                "secondary": "#3B4252",
                "accent": "#434C5E",
                "text": "#D8DEE9",  # Light text
                "text_background": "#434C5E",  # Dark background for QLabel
                "button_background": "#434C5E",
                "button_hover": "#5E81AC",
                "close_button_background": "#BF616A",
                "close_button_hover": "#D08770",
                "border_color": "#5E81AC",
                "border_width": "1px",
                "border_radius": "6px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#D8DEE9",        # Checkbox text color
                "checkbox_background": "#3B4252",        # Checkbox background color
                "card_hover": "#3B4252"
            },
            "solarized_dark": {
                "background": "#002B36",
                "secondary": "#073642", 
                "accent": "#586E75",
                "text": "#93A1A1",  # Light text
                "text_background": "#073642",  # Dark background for QLabel
                "button_background": "#586E75",
                "button_hover": "#657B83",
                "close_button_background": "#DC322F", 
                "close_button_hover": "#CB4B16",
                "border_color": "#586E75",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#93A1A1",        # Checkbox text color
                "checkbox_background": "#073642",        # Checkbox background color
                "card_hover": "#073642"
            },
                        "solarized_light": {
                "background": "#FDF6E3",
                "secondary": "#EEE8D5",
                "accent": "#93A1A1",
                "text": "#657B83",  # Dark text
                "text_background": "#EEE8D5",  # Light background for QLabel
                "button_background": "#93A1A1",
                "button_hover": "#839496",
                "close_button_background": "#DC322F",
                "close_button_hover": "#CB4B16",
                "border_color": "#93A1A1",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "label_color": "#657B83",
                "checkbox_text_color": "#657B83",        # Checkbox text color
                "checkbox_background": "#EEE8D5",        # Checkbox background color
                "card_hover": "#EEE8D5"
            },
            "material": {
                "background": "#FFFFFF",
                "secondary": "#EEEEEE",
                "accent": "#6200EE",
                "text": "#000000",  # Dark text
                "text_background": "#EEEEEE",  # Light background for QLabel
                "button_background": "#6200EE",
                "button_hover": "#3700B3",
                "close_button_background": "#B00020",
                "close_button_hover": "#C51162",
                "border_color": "#6200EE",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "label_color": "#000000",
                "checkbox_text_color": "#000000",        # Checkbox text color
                "checkbox_background": "#EEEEEE",        # Checkbox background color
                "card_hover": "#EEEEEE"
            },
            "oceanic": {
                "background": "#1B2B34",
                "secondary": "#343D46",
                "accent": "#6699CC",
                "text": "#D8DEE9",  # Light text
                "text_background": "#343D46",  # Dark background for QLabel
                "button_background": "#343D46",
                "button_hover": "#4F5B66",
                "close_button_background": "#E06C75",
                "close_button_hover": "#BE5046",
                "border_color": "#6699CC",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "label_color": "#D8DEE9",
                "checkbox_text_color": "#D8DEE9",        # Checkbox text color
                "checkbox_background": "#343D46",        # Checkbox background color
                "card_hover": "#343D46"
            },
            "pastel": {
                "background": "#FFFBF0",
                "secondary": "#FFF3E0",
                "accent": "#FFB3BA",
                "text": "#333333",  # Dark text
                "text_background": "#FFF3E0",  # Light background for QLabel
                "button_background": "#FFB3BA",
                "button_hover": "#FF8C94",
                "close_button_background": "#FF6F61",
                "close_button_hover": "#FF3B30",
                "border_color": "#FFB3BA",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "label_color": "#333333",
                "checkbox_text_color": "#333333",        # Checkbox text color
                "checkbox_background": "#FFF3E0",        # Checkbox background color
                "card_hover": "#FFF3E0"
            },
            "high_contrast": {
                "background": "#000000",
                "secondary": "#FFFFFF",
                "accent": "#FFFF00",
                "text": "#FFFFFF",  # Light text
                "text_background": "#FFFFFF",  # Light background for QLabel
                "button_background": "#FFFFFF",
                "button_hover": "#FFFF00",
                "close_button_background": "#FF0000",
                "close_button_hover": "#FF5555",
                "border_color": "#FFFF00",
                "border_width": "2px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "label_color": "#000000",
                "checkbox_text_color": "#000000",        # Checkbox text color
                "checkbox_background": "#FFFFFF",        # Checkbox background color
                "card_hover": "#FFFFFF"
            },
            "dracula": {
                "background": "#282A36",
                "secondary": "#44475A",
                "accent": "#6272A4",
                "text": "#F8F8F2",  # Light text
                "text_background": "#6272A4",  # Dark background for QLabel
                "button_background": "#6272A4",
                "button_hover": "#BD93F9",
                "close_button_background": "#FF5555",
                "close_button_hover": "#FF79C6",
                "border_color": "#6272A4",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#F8F8F2",        # Checkbox text color
                "checkbox_background": "#44475A",        # Checkbox background color
                "card_hover": "#44475A"
            },
            "monokai": {
                "background": "#272822",
                "secondary": "#3E3D32",
                "accent": "#49483E",
                "text": "#F8F8F2",  # Light text
                "text_background": "#49483E",  # Dark background for QLabel
                "button_background": "#49483E",
                "button_hover": "#75715E",
                "close_button_background": "#F92672",
                "close_button_hover": "#FD971F",
                "border_color": "#75715E",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#F8F8F2",        # Checkbox text color
                "checkbox_background": "#3E3D32",        # Checkbox background color
                "card_hover": "#3E3D32"
            },
            "gruvbox": {
                "background": "#282828",
                "secondary": "#3C3836",
                "accent": "#504945",
                "text": "#EBDBB2",  # Light text
                "text_background": "#504945",  # Dark background for QLabel
                "button_background": "#504945",
                "button_hover": "#665C54",
                "close_button_background": "#CC241D",
                "close_button_hover": "#FB4934",
                "border_color": "#665C54",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#EBDBB2",        # Checkbox text color
                "checkbox_background": "#3C3836",        # Checkbox background color
                "card_hover": "#3C3836"
            },
            "tokyo_night": {
                "background": "#1A1B26",
                "secondary": "#24283B", 
                "accent": "#414868",
                "text": "#C0CAF5",  # Light text
                "text_background": "#414868",  # Dark background for QLabel
                "button_background": "#414868",
                "button_hover": "#565F89",
                "close_button_background": "#F7768E",
                "close_button_hover": "#FF9E64", 
                "border_color": "#565F89",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#C0CAF5",        # Checkbox text color
                "checkbox_background": "#24283B",        # Checkbox background color
                "card_hover": "#24283B"
            },
            "forest": {
                "background": "#1B2D1C",
                "secondary": "#2A4A2B",
                "accent": "#3B6B3C",
                "text": "#A8D5BA",  # Light text
                "text_background": "#3B6B3C",  # Dark background for QLabel
                "button_background": "#3B6B3C",
                "button_hover": "#4D8C4E",
                "close_button_background": "#A83232",
                "close_button_hover": "#D14343",
                "border_color": "#4D8C4E",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#A8D5BA",        # Checkbox text color
                "checkbox_background": "#2A4A2B",        # Checkbox background color
                "card_hover": "#2A4A2B"
            },
            "desert": {
                "background": "#2B1810",
                "secondary": "#3D2317", 
                "accent": "#664032",
                "text": "#F5E0C3",  # Light text
                "text_background": "#664032",  # Dark background for QLabel
                "button_background": "#664032",
                "button_hover": "#8B5543",
                "close_button_background": "#CF4520",
                "close_button_hover": "#FF5722",
                "border_color": "#8B5543",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#F5E0C3",        # Checkbox text color
                "checkbox_background": "#3D2317",        # Checkbox background color
                "card_hover": "#3D2317"
            },
            "neon_explosion": {
                "background": "#000000",
                "secondary": "#1A0033",
                "accent": "#330066", 
                "text": "#FFFFFF",  # Light text
                "text_background": "#330066",  # Dark background for QLabel
                "button_background": "#FF00FF",
                "button_hover": "#00FFFF",
                "close_button_background": "#FF0000",
                "close_button_hover": "#FF3333",
                "border_color": "#00FF00",
                "border_width": "2px",
                "border_radius": "8px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#FFFFFF",        # Checkbox text color
                "checkbox_background": "#1A0033",        # Checkbox background color
                "card_hover": "#1A0033"
            },
            "ocean": {
                "background": "#0A2E44",
                "secondary": "#0E3D5C",
                "accent": "#145C8C",
                "text": "#E0F2FE",  # Light text
                "text_background": "#145C8C",  # Dark background for QLabel
                "button_background": "#145C8C",
                "button_hover": "#1A7AB8",
                "close_button_background": "#E63946",
                "close_button_hover": "#FF4D6A",
                "border_color": "#1A7AB8",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#E0F2FE",        # Checkbox text color
                "checkbox_background": "#0E3D5C",        # Checkbox background color
                "card_hover": "#0E3D5C"
            },
            "sunset": {
                "background": "#2C1B47",
                "secondary": "#432B6F",
                "accent": "#5A3B97",
                "text": "#FFE0CC",  # Light text
                "text_background": "#5A3B97",  # Dark background for QLabel
                "button_background": "#FF6B6B",
                "button_hover": "#FF8787",
                "close_button_background": "#FF4757",
                "close_button_hover": "#FF6B81",
                "border_color": "#FF8787",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#FFE0CC",        # Checkbox text color
                "checkbox_background": "#432B6F",        # Checkbox background color
                "card_hover": "#432B6F"
            },
            "mint": {
                "background": "#1A332E",
                "secondary": "#264D45", 
                "accent": "#337066",
                "text": "#B3E6D5",  # Light text
                "text_background": "#337066",  # Dark background for QLabel
                "button_background": "#337066",
                "button_hover": "#408C7F",
                "close_button_background": "#D64545",
                "close_button_hover": "#E65C5C", 
                "border_color": "#408C7F",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#B3E6D5",        # Checkbox text color
                "checkbox_background": "#264D45",        # Checkbox background color
                "card_hover": "#264D45"
            },
            "cyberpunk": {
                "background": "#0D0221",
                "secondary": "#190634",
                "accent": "#260A4C", 
                "text": "#00FF9F",  # Neon green text
                "text_background": "#260A4C",  # Dark background for QLabel
                "button_background": "#FF00FF",
                "button_hover": "#FF33FF",
                "close_button_background": "#FF003C",
                "close_button_hover": "#FF335C",
                "border_color": "#00FFFF",
                "border_width": "2px",
                "border_radius": "6px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#00FF9F",        # Checkbox text color
                "checkbox_background": "#190634",        # Checkbox background color
                "card_hover": "#190634"
            },
            "volcanic": {
                "background": "#2D0A0A",
                "secondary": "#461111",
                "accent": "#661919",
                "text": "#FFB399",  # Warm orange text
                "text_background": "#661919",
                "button_background": "#8C2121",
                "button_hover": "#B32929",
                "close_button_background": "#FF4D4D",
                "close_button_hover": "#FF6666",
                "border_color": "#B32929",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#FFB399",
                "checkbox_background": "#461111",
                "card_hover": "#461111"
            },
            "emerald": {
                "background": "#004D40",
                "secondary": "#00695C",
                "accent": "#00796B",
                "text": "#B2DFDB",  # Soft teal text
                "text_background": "#00796B",
                "button_background": "#009688",
                "button_hover": "#00BFA5",
                "close_button_background": "#FF5252",
                "close_button_hover": "#FF8A80",
                "border_color": "#00BFA5",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",  
                "spacing": "14px",
                "checkbox_text_color": "#B2DFDB",
                "checkbox_background": "#00695C",
                "card_hover": "#00695C"
            },
            "amethyst": {
                "background": "#2E1245",
                "secondary": "#421B63",
                "accent": "#562481",
                "text": "#E6CCF2",  # Light purple text
                "text_background": "#562481",
                "button_background": "#6B2D9E",
                "button_hover": "#8036BC",
                "close_button_background": "#FF4081",
                "close_button_hover": "#FF80AB",
                "border_color": "#8036BC",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#E6CCF2",
                "checkbox_background": "#421B63",
                "card_hover": "#421B63"
            },
            "golden": {
                "background": "#332B00",
                "secondary": "#4D4000",
                "accent": "#665500",
                "text": "#FFE680",  # Soft gold text
                "text_background": "#665500",
                "button_background": "#806A00",
                "button_hover": "#997D00",
                "close_button_background": "#FF4D4D",
                "close_button_hover": "#FF6666",
                "border_color": "#997D00",
                "border_width": "1px",
                "border_radius": "4px",
                "padding": "12px",
                "spacing": "14px",
                "checkbox_text_color": "#FFE680",
                "checkbox_background": "#4D4000",
                "card_hover": "#4D4000"
            }
        }

        for name, theme in themes.items():
            theme_path = os.path.join(self.theme_path, f"{name}.json")
            if not os.path.exists(theme_path):
                try:
                    with open(theme_path, "w") as f:
                        json.dump(theme, f, indent=4)
                    print(f"Created example theme: {name}")
                except IOError as e:
                    print(f"Failed to create theme '{name}': {e}")

    def load_themes(self):
        themes = {}
        for file in os.listdir(self.theme_path):
            if file.endswith(".json"):
                name = file[:-5]
                path = os.path.join(self.theme_path, file)
                try:
                    with open(path, "r") as f:
                        data = json.load(f)
                        themes[name] = data
                except json.JSONDecodeError as e:
                    print(f"Error decoding JSON for theme '{name}': {e}")
                except IOError as e:
                    print(f"Error reading theme file '{name}': {e}")
        return themes

    def get_theme(self, name):
        return self.themes.get(name, self.default_theme)

    def get_theme_names(self):
        names = list(self.themes.keys())
        if "default" not in names:
            names.append("default")
        return names

class WidgetManager:
    def __init__(self):
        self.widgets = {}
        self.priorities = {}
        self.widget_dir = "storage/widgets"  # Relative path instead of absolute
        os.makedirs(self.widget_dir, exist_ok=True)
        self._load_widgets()

    def _load_widgets(self):
        """Load all widget modules from the widgets directory"""
        for file in os.listdir(self.widget_dir):
            if file.endswith('.py') and not file.startswith('__'):
                try:
                    module_name = file[:-3]
                    module_path = os.path.join(self.widget_dir, file)
                    spec = importlib.util.spec_from_file_location(module_name, module_path)
                    module = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(module)
                    
                    # Look for widget class in module
                    for item in dir(module):
                        obj = getattr(module, item)
                        if isinstance(obj, type) and issubclass(obj, QWidget) and obj != QWidget:
                            widget = obj()
                            # Set login widget to highest priority
                            priority = 0 if module_name == 'login' else 100
                            self.register(module_name, widget, priority)
                            break
                            
                except Exception as e:
                    print(f"Failed to load widget {file}: {e}")

    def register(self, name, widget, priority=100):
        self.widgets[name] = widget
        self.priorities[name] = priority

    def initialize_all(self):
        # Sort widgets by priority (lowest number = highest priority)
        sorted_widgets = sorted(self.priorities.items(), key=lambda x: x[1])
        
        # Initialize widgets in priority order
        for name, _ in sorted_widgets:
            widget = self.widgets.get(name)
            if widget and hasattr(widget, 'initialize'):
                try:
                    success = widget.initialize()
                    if not success:
                        print(f"Failed to initialize widget: {name}")
                        return False
                    
                    # For login widget, wait until logged in before continuing
                    if name == 'login':
                        widget.show()  # Show login widget
                        while not widget.is_logged_in():
                            QApplication.processEvents()
                            time.sleep(0.1)  # Add small delay to prevent CPU hogging
                        widget.close()  # Close login after successful authentication
                            
                except Exception as e:
                    print(f"Error initializing widget {name}: {e}")
                    return False
        return True

    def ordered_startup(self):
        return self.initialize_all()

    def get_widget(self, name):
        return self.widgets.get(name)

    def get_priorities(self):
        return dict(self.priorities)

    def get_all_widgets(self):
        """Return all registered widgets"""
        return dict(self.widgets)

class PluginManager:
    def __init__(self, settings):
        self.settings = settings
        self.plugins = {}
        self.plugin_dir = "/nsatt/storage/plugins"
        self.known_plugins = self.settings.get("known_plugins", {})
        os.makedirs(self.plugin_dir, exist_ok=True)

    def check_plugin_requirements(self, plugin_name, plugin):
        """Check if all required packages are installed for a plugin"""
        try:
            missing_packages = []
            outdated_packages = []
            if hasattr(plugin, 'REQUIRED_PACKAGES'):
                import pkg_resources
                for package_req in plugin.REQUIRED_PACKAGES:
                    try:
                        # Parse package name and version requirement
                        package_name = package_req.split('>=')[0].split('==')[0].strip()
                        req = pkg_resources.Requirement.parse(package_req)
                        
                        try:
                            # Check if package is installed
                            dist = pkg_resources.get_distribution(package_name)
                            # Check if version meets requirement
                            if dist.version not in req:
                                outdated_packages.append((package_name, dist.version, req.specs[0][1]))
                        except pkg_resources.DistributionNotFound:
                            missing_packages.append(package_req)
                            
                    except Exception as e:
                        print(f"Error checking package {package_req}: {e}")
                        missing_packages.append(package_req)
                        
            return missing_packages, outdated_packages
        except Exception as e:
            print(f"Error checking requirements for {plugin_name}: {e}")
            return [], []

    def install_requirements(self, packages, upgrade_packages=None, progress_callback=None):
        """Install required packages using pip"""
        try:
            import subprocess
            import sys
            
            total_operations = len(packages) + len(upgrade_packages or [])
            current_operation = 0
            
            # Install missing packages
            for package in packages:
                if progress_callback:
                    current_operation += 1
                    progress_callback(f"Installing {package}...", 
                                   (current_operation / total_operations) * 100)
                    
                try:
                    # Use pip to install the package
                    subprocess.check_call([
                        sys.executable, 
                        "-m", 
                        "pip", 
                        "install", 
                        package
                    ])
                except subprocess.CalledProcessError as e:
                    print(f"Failed to install {package}: {e}")
                    return False
                    
            # Upgrade outdated packages
            if upgrade_packages:
                for package, current_ver, required_ver in upgrade_packages:
                    if progress_callback:
                        current_operation += 1
                        progress_callback(f"Upgrading {package} {current_ver} → {required_ver}...",
                                       (current_operation / total_operations) * 100)
                        
                    try:
                        subprocess.check_call([
                            sys.executable,
                            "-m",
                            "pip",
                            "install",
                            "--upgrade",
                            f"{package}>={required_ver}"
                        ])
                    except subprocess.CalledProcessError as e:
                        print(f"Failed to upgrade {package}: {e}")
                        return False
                        
            return True
        except Exception as e:
            print(f"Error installing packages: {e}")
            return False

    def _load_plugin(self, item, item_path, current_menu):
        try:
            plugin_filename = item
            spec = importlib.util.spec_from_file_location(item[:-3], item_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            if hasattr(module, "Plugin"):
                plugin = module.Plugin()
                plugin_name = getattr(plugin, "NAME", item[:-3])

                # Store plugin in plugins dict
                self.plugins[plugin_name] = plugin

                # Check if this is a new plugin
                if plugin_name not in self.known_plugins:
                    self.known_plugins[plugin_name] = {
                        'enabled': False,
                        'first_seen': datetime.now().isoformat(),
                        'requirements_met': False
                    }
                    self.settings["known_plugins"] = self.known_plugins
                    self.save_settings()
                    
                    # Show new plugin dialog
                    self.show_new_plugin_dialog(plugin_name, plugin)

                # Only add to menu if enabled and requirements are met
                if self.is_plugin_enabled(plugin_name) and self.known_plugins[plugin_name]['requirements_met']:
                    plugin_data = {'plugin': plugin}
                    if hasattr(module, "plugin_image_value"):
                        plugin_data['image'] = module.plugin_image_value
                    current_menu[plugin_name] = plugin_data

        except Exception as e:
            print(f"Error loading plugin {item}: {e}")

    def show_new_plugin_dialog(self, plugin_name, plugin):
        """Show dialog for new plugin detection"""
        dialog = QDialog()
        dialog.setWindowTitle("New Plugin Detected")
        layout = QVBoxLayout()

        # Plugin info
        info_text = f"New plugin detected: {plugin_name}\n"
        if hasattr(plugin, 'DESCRIPTION'):
            info_text += f"\nDescription: {plugin.DESCRIPTION}"
        info_label = QLabel(info_text)
        layout.addWidget(info_label)

        # Check requirements
        missing_packages, outdated_packages = self.check_plugin_requirements(plugin_name, plugin)
        
        if missing_packages or outdated_packages:
            req_label = QLabel("\nPackage Requirements:")
            layout.addWidget(req_label)
            
            if missing_packages:
                layout.addWidget(QLabel("Packages to install:"))
            for package in missing_packages:
                layout.addWidget(QLabel(f"- {package}"))
                    
            if outdated_packages:
                layout.addWidget(QLabel("\nPackages to update:"))
                for package, current_ver, required_ver in outdated_packages:
                    layout.addWidget(QLabel(f"- {package}: {current_ver} → {required_ver}"))

        # Progress bar (hidden initially)
        progress_bar = QProgressBar()
        progress_bar.hide()
        layout.addWidget(progress_bar)

        # Buttons
        button_box = QHBoxLayout()
        enable_btn = QPushButton("Enable Plugin")
        cancel_btn = QPushButton("Not Now")
        button_box.addWidget(enable_btn)
        button_box.addWidget(cancel_btn)
        layout.addLayout(button_box)

        dialog.setLayout(layout)

        def handle_enable():
            if missing_packages or outdated_packages:
                if outdated_packages:
                    # Ask for permission to upgrade
                    msg = QMessageBox()
                    msg.setIcon(QMessageBox.Question)
                    msg.setText("Some packages need to be upgraded.")
                    msg.setInformativeText("Do you want to proceed with the upgrade?")
                    msg.setStandardButtons(QMessageBox.Yes | QMessageBox.No)
                    if msg.exec_() != QMessageBox.Yes:
                        dialog.reject()
                        return

                progress_bar.show()
                def update_progress(text, value):
                    progress_bar.setValue(int(value))
                    progress_bar.setFormat(f"{text} ({value:.0f}%)")
                
                if self.install_requirements(missing_packages, outdated_packages, update_progress):
                    self.known_plugins[plugin_name]['requirements_met'] = True
                    self.enable_plugin(plugin_name)
                    dialog.accept()
                else:
                    QMessageBox.warning(dialog, "Error", "Failed to install required packages")
                    dialog.reject()
            else:
                self.known_plugins[plugin_name]['requirements_met'] = True
                self.enable_plugin(plugin_name)
                dialog.accept()

        enable_btn.clicked.connect(handle_enable)
        cancel_btn.clicked.connect(dialog.reject)

        dialog.exec_()

    def enable_plugin(self, plugin_name):
        """Enable a plugin and handle requirements"""
        if plugin_name not in self.known_plugins:
            return False

        if not self.known_plugins[plugin_name]['requirements_met']:
            plugin = self.plugins.get(plugin_name)
            if plugin:
                missing_packages = self.check_plugin_requirements(plugin_name, plugin)[0]
                if missing_packages:
                    # Show installation dialog
                    dialog = QDialog()
                    dialog.setWindowTitle("Install Required Packages")
                    layout = QVBoxLayout()
                    
                    layout.addWidget(QLabel(f"The plugin '{plugin_name}' requires the following packages:"))
                    for package in missing_packages:
                        layout.addWidget(QLabel(f"- {package}"))
                    
                    progress_bar = QProgressBar()
                    progress_bar.hide()
                    layout.addWidget(progress_bar)
                    
                    button_box = QHBoxLayout()
                    install_btn = QPushButton("Install")
                    cancel_btn = QPushButton("Cancel")
                    button_box.addWidget(install_btn)
                    button_box.addWidget(cancel_btn)
                    layout.addLayout(button_box)
                    
                    dialog.setLayout(layout)
                    
                    def handle_install():
                        progress_bar.show()
                        def update_progress(text, value):
                            progress_bar.setValue(int(value))
                            progress_bar.setFormat(f"{text} ({value:.0f}%)")
                        
                        if self.install_requirements(missing_packages, update_progress):
                            self.known_plugins[plugin_name]['requirements_met'] = True
                            self.set_plugin_enabled(plugin_name, True)
                            dialog.accept()
                            return True
                        else:
                            QMessageBox.warning(dialog, "Error", "Failed to install required packages")
                            dialog.reject()
                            return False
                    
                    install_btn.clicked.connect(handle_install)
                    cancel_btn.clicked.connect(dialog.reject)
                    
                    return dialog.exec_() == QDialog.Accepted
                    
        self.set_plugin_enabled(plugin_name, True)
        return True

    def save_settings(self):
        """Save settings to file"""
        try:
            with open("/nsatt/storage/settings.json", "w") as f:
                json.dump(self.settings, f, indent=4)
        except Exception as e:
            print(f"Error saving settings: {e}")

    def is_plugin_enabled(self, plugin_name):
        """Check if plugin is enabled"""
        return self.known_plugins.get(plugin_name, {}).get('enabled', False)

    def set_plugin_enabled(self, plugin_name, enabled):
        """Enable or disable a plugin"""
        if plugin_name in self.known_plugins:
            self.known_plugins[plugin_name]['enabled'] = enabled
            self.settings["known_plugins"] = self.known_plugins
            self.save_settings()

    def load_all(self):
        self.plugins.clear()
        menu = {}
        self._load_dir(self.plugin_dir, menu)
        # Clean up empty directories from menu
        self._clean_empty_dirs(menu)
        return menu

    def _load_dir(self, path, current_menu):
        items = os.listdir(path)
        for item in items:
            if item == "__pycache__":
                continue

            item_path = os.path.join(path, item)
            if os.path.isdir(item_path):
                # Subdirectory - treat as a submenu
                submenu = {}
                
                # Look for corresponding icon image
                folder_name = os.path.basename(item_path)
                icon_name = f"{folder_name}_icon.png"
                icon_path = os.path.join(item_path, icon_name)
                
                # Create submenu and load its contents
                if os.path.exists(icon_path):
                    current_menu[item] = {'submenu': submenu, 'image': icon_path}
                else:
                    current_menu[item] = submenu
                    
                self._load_dir(item_path, submenu)
                
            elif item.endswith('.py') and not item.startswith('__'):
                self._load_plugin(item, item_path, current_menu)

    def _clean_empty_dirs(self, menu):
        # Recursively remove empty directories
        empty_keys = []
        for key, value in menu.items():
            if isinstance(value, dict):
                # Handle both plain submenu dicts and dicts with 'submenu' key
                submenu = value.get('submenu', value)
                self._clean_empty_dirs(submenu)
                if not submenu and not any(k != 'image' for k in value.keys()):
                    empty_keys.append(key)
        
        for key in empty_keys:
            del menu[key]

    def get_plugin_list(self):
        return list(self.plugins.keys())

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("NSATT")
        self.setWindowFlags(Qt.FramelessWindowHint)
        self.showFullScreen()

        # Initialize managers
        self.settings = self.load_settings()
        self.theme_manager = ThemeManager()
        self.widget_manager = WidgetManager()
        self.plugin_manager = PluginManager(self.settings)

        # State tracking
        self.history = []
        self.minimized_plugins = {}  # {plugin_name: (plugin_widget, taskbar_button)}
        self.menu_structure = {}

        # Order startup widgets (if any)
        self.widget_manager.ordered_startup()

        # Setup UI
        self.setup_ui()

        # Initialize widgets in priority order
        if not self.widget_manager.initialize_all():
            pass

        # Load plugins and show menu
        self.first_refresh_plugins()

        # Apply theme
        self.apply_current_theme()
        self.show_menu(self.menu_structure)

    def load_settings(self):
        settings_file = "/nsatt/storage/settings.json"
        if os.path.exists(settings_file):
            try:
                with open(settings_file, "r") as f:
                    return json.load(f)
            except:
                pass
        # Default settings if file not found or can't load
        return {
            "theme": "default",
            "list_view": False,
            "plugins_enabled": {}
        }

    def save_settings(self):
        settings_file = "/nsatt/storage/settings.json"
        try:
            with open(settings_file, "w") as f:
                json.dump(self.settings, f, indent=4)
        except Exception as e:
            print("Error saving settings:", e)

    def setup_ui(self):
        # Create a scroll area as the central widget
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.setCentralWidget(scroll)

        # Main container widget inside scroll area
        main_widget = QWidget()
        scroll.setWidget(main_widget)
        
        self.main_layout = QVBoxLayout(main_widget)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)

        self.setup_top_bar()

        # Content area
        self.content = QStackedWidget()
        self.content.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self.main_layout.addWidget(self.content)

        # Taskbar at the bottom
        self.setup_task_bar()

    def setup_top_bar(self):
        self.top_bar = QWidget()
        self.top_bar.setObjectName("topBar")
        top_layout = QHBoxLayout(self.top_bar)
        top_layout.setContentsMargins(10, 10, 10, 10)
        top_layout.setSpacing(10)

        # Back button
        self.back_button = QPushButton("< Back")
        self.back_button.setObjectName("backButton")
        self.back_button.clicked.connect(self.go_back)
        self.back_button.setMinimumSize(60, 40)
        top_layout.addWidget(self.back_button)

        # Menu button
        self.menu_button = QPushButton("Menu")
        self.menu_button.setObjectName("menuButton")
        self.menu_button.clicked.connect(lambda: self.show_menu(self.menu_structure))
        self.menu_button.setMinimumSize(60, 40)
        top_layout.addWidget(self.menu_button)

        # Settings button
        self.settings_button = QPushButton("Settings")
        self.settings_button.setObjectName("settingsButton")
        self.settings_button.clicked.connect(self.show_settings)
        self.settings_button.setMinimumSize(70, 40)
        top_layout.addWidget(self.settings_button)

        spacer = QSpacerItem(40, 20, QSizePolicy.Expanding, QSizePolicy.Minimum)
        top_layout.addSpacerItem(spacer)

        # Close button
        self.close_button = QPushButton("EXIT")
        self.close_button.setObjectName("closeButton")
        self.close_button.clicked.connect(self.confirm_close)
        self.close_button.setMinimumSize(40, 40)
        top_layout.addWidget(self.close_button)

        self.main_layout.addWidget(self.top_bar)

    def confirm_close(self):
        # Create custom confirmation dialog
        dialog = QWidget(self)
        dialog.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        dialog.setObjectName("confirmDialog")
        
        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        # Message
        message = QLabel("What would you like to do?")
        message.setAlignment(Qt.AlignCenter)
        layout.addWidget(message)
        
        log_dir = "/nsatt/logs/system/internal"
        os.makedirs(log_dir, exist_ok=True)
        
        today = time.strftime("%Y%m%d")
        log_file = os.path.join(log_dir, f"nsatt_internal_log_{today}.txt")
        
        # Clean up old logs
        current_time = time.time()
        for f in os.listdir(log_dir):
            if f.startswith("nsatt_internal_log_"):
                file_path = os.path.join(log_dir, f)
                if (current_time - os.path.getmtime(file_path)) > (30 * 24 * 60 * 60):
                    os.remove(file_path)
        
        # Buttons in 2x2 grid
        button_grid = QGridLayout()
        
        exit_button = QPushButton("Exit App")
        exit_button.setFixedWidth(150)
        exit_button.setFixedHeight(50)
        exit_button.setStyleSheet("background-color: #007bff; color: white;")
        exit_button.clicked.connect(lambda: self.log_and_confirm("exit", log_file, dialog))
        
        restart_button = QPushButton("Restart App")
        restart_button.setFixedWidth(150)
        restart_button.setFixedHeight(50)
        restart_button.setStyleSheet("background-color: yellow; color: black;")
        restart_button.clicked.connect(lambda: self.log_and_confirm("restart", log_file, dialog))
        
        reboot_button = QPushButton("Reboot Device")
        reboot_button.setFixedWidth(150)
        reboot_button.setFixedHeight(50)
        reboot_button.setStyleSheet("background-color: red; color: black;")
        reboot_button.clicked.connect(lambda: self.log_and_confirm("reboot", log_file, dialog))
        
        cancel_button = QPushButton("Cancel")
        cancel_button.setFixedWidth(150)
        cancel_button.setFixedHeight(50)
        cancel_button.setStyleSheet("background-color: #007bff; color: white;")
        cancel_button.clicked.connect(lambda: self.log_and_confirm("cancel", log_file, dialog))
        
        button_grid.addWidget(exit_button, 0, 0)
        button_grid.addWidget(restart_button, 0, 1) 
        button_grid.addWidget(reboot_button, 1, 0)
        button_grid.addWidget(cancel_button, 1, 1)
        
        layout.addLayout(button_grid)
        
        # Center and show dialog
        dialog.setFixedSize(400, 200)
        dialog.move(
            self.frameGeometry().center() - dialog.rect().center()
        )
        dialog.show()
        
    def log_and_confirm(self, action, log_file, dialog):
        # Log the action
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(log_file, 'a') as f:
            f.write(f"{timestamp}: User selected {action}\n")
        
        # Call appropriate confirmation
        if action == "exit":
            self.confirm_exit(dialog)
        elif action == "restart":
            self.confirm_restart(dialog)
        elif action == "reboot":
            self.confirm_reboot(dialog)
        elif action == "cancel":
            self.handle_close_confirm(dialog, "cancel")

    def confirm_exit(self, parent_dialog):
        # Create confirmation dialog
        dialog = QWidget(self)
        dialog.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        dialog.setObjectName("confirmDialog")
        
        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        message = QLabel("Are you sure you want to exit?")
        message.setAlignment(Qt.AlignCenter)
        layout.addWidget(message)
        
        button_layout = QHBoxLayout()
        yes_button = QPushButton("Yes")
        yes_button.clicked.connect(lambda: self.handle_close_confirm(parent_dialog, "exit"))
        no_button = QPushButton("No") 
        no_button.clicked.connect(dialog.close)
        
        button_layout.addWidget(yes_button)
        button_layout.addWidget(no_button)
        layout.addLayout(button_layout)
        
        dialog.setFixedSize(300, 150)
        dialog.move(
            self.frameGeometry().center() - dialog.rect().center()
        )
        dialog.show()

    def confirm_restart(self, parent_dialog):
        # Create confirmation dialog
        dialog = QWidget(self)
        dialog.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        dialog.setObjectName("confirmDialog")
        
        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        message = QLabel("Are you sure you want to restart the application?")
        message.setAlignment(Qt.AlignCenter)
        layout.addWidget(message)
        
        button_layout = QHBoxLayout()
        yes_button = QPushButton("Yes")
        yes_button.clicked.connect(lambda: self.handle_close_confirm(parent_dialog, "restart"))
        no_button = QPushButton("No")
        no_button.clicked.connect(dialog.close)
        
        button_layout.addWidget(yes_button)
        button_layout.addWidget(no_button)
        layout.addLayout(button_layout)
        
        dialog.setFixedSize(300, 150)
        dialog.move(
            self.frameGeometry().center() - dialog.rect().center()
        )
        dialog.show()

    def confirm_reboot(self, parent_dialog):
        # Create confirmation dialog
        dialog = QWidget(self)
        dialog.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        dialog.setObjectName("confirmDialog")
        
        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        message = QLabel("Are you sure you want to reboot the system?")
        message.setAlignment(Qt.AlignCenter)
        layout.addWidget(message)
        
        button_layout = QHBoxLayout()
        yes_button = QPushButton("Yes")
        yes_button.clicked.connect(lambda: self.handle_close_confirm(parent_dialog, "reboot"))
        no_button = QPushButton("No")
        no_button.clicked.connect(dialog.close)
        
        button_layout.addWidget(yes_button)
        button_layout.addWidget(no_button)
        layout.addLayout(button_layout)
        
        dialog.setFixedSize(300, 150)
        dialog.move(
            self.frameGeometry().center() - dialog.rect().center()
        )
        dialog.show()
        
    def handle_close_confirm(self, dialog, action):
        dialog.close()
        if action == "exit":
            self.close()
        elif action == "restart":
            # Create restart script if it doesn't exist
            restart_script = "/nsatt/services/reboot_app.sh"
            script_dir = os.path.dirname(restart_script)
            
            # Create directory if it doesn't exist
            if not os.path.exists(script_dir):
                os.makedirs(script_dir, exist_ok=True)
                
            # Create or update restart script with sleep to allow current process to exit
            with open(restart_script, 'w') as f:
                f.write('#!/bin/bash\n')
                f.write('sleep 1\n')  # Wait for current process to exit
                f.write('cd "$(dirname "$0")/../.."\n')  # Go to NSATT root dir
                f.write('exec python3 /nsatt/nsatt.py "$@"\n')  # Use exec to replace shell with python process
            os.chmod(restart_script, 0o755)
            
            # Launch restart script and exit current instance
            subprocess.Popen([restart_script], start_new_session=True)
            self.close()  # Close main window which will trigger clean application exit
        elif action == "reboot":
            subprocess.run(['sudo', 'reboot'])

    def setup_task_bar(self):
        self.task_bar = QWidget()
        self.task_bar.setObjectName("taskBar")
        task_layout = QHBoxLayout(self.task_bar)
        task_layout.setContentsMargins(10, 5, 10, 5)
        task_layout.setSpacing(10)
        self.task_layout = task_layout
        self.main_layout.addWidget(self.task_bar)

    def show_menu(self, items):
        # Check if there's a plugin open and minimize it
        current = self.content.currentWidget()
        if current and hasattr(current, 'plugin_name'):
            self.minimize_plugin(current.plugin_name, current)
            # Remove any control buttons from top bar
            if hasattr(current, 'control_buttons'):
                for button in current.control_buttons:
                    button.deleteLater()
                current.control_buttons.clear()

        # Hide back button if we're at root menu
        if items == self.menu_structure:
            self.back_button.hide()
        else:
            self.back_button.show()

        menu_widget = QWidget()
        menu_layout = QVBoxLayout(menu_widget)
        menu_layout.setContentsMargins(0, 0, 0, 0)
        menu_layout.setSpacing(0)

        # Fixed top scroll button
        up_btn = QPushButton("▲ Scroll Up ▲")
        up_btn.setFixedHeight(40)  # Larger touch target
        up_btn.setStyleSheet("""
            QPushButton {
                border-radius: 0;
                border-bottom: 1px solid #555555;
            }
        """)
        menu_layout.addWidget(up_btn)

        # Scrollable content area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        menu_layout.addWidget(scroll)

        # Content widget
        content_widget = QWidget()
        is_list_view = self.settings.get("list_view", False)
        
        if is_list_view:
            layout = QVBoxLayout(content_widget)
            layout.setAlignment(Qt.AlignTop)
            layout.setContentsMargins(10, 5, 10, 5)
            layout.setSpacing(2)
        else:
            # Grid layout (cards)
            layout = QGridLayout(content_widget)
            layout.setContentsMargins(10, 10, 10, 10)
            layout.setSpacing(10)
            layout.setAlignment(Qt.AlignTop | Qt.AlignLeft)
            col = row = 0
            max_cols = 3  # 3 columns for grid view

        for name, data in items.items():
            # Skip if it's just an image file
            if name.endswith('_icon.png'):
                continue
                
            item = self.create_menu_item(name, data, is_list_view)
            if is_list_view:
                # Make list items more compact but slightly bigger than before
                item.setFixedHeight(60)
                item.setFrameStyle(QFrame.NoFrame)
                layout.addWidget(item)
            else:
                # Make entire grid item clickable and fill available space
                item.setMinimumSize(120, 140)  # Slightly larger minimum size
                item.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
                
                # Make the whole item clickable
                def make_click_handler(d=data, n=name):
                    def click_handler(event):
                        if isinstance(d, dict) and 'plugin' in d:
                            self.show_plugin(d['plugin'], n)
                        else:
                            submenu = d.get('submenu', d)
                            self.show_submenu(submenu)
                    return click_handler
                
                item.mousePressEvent = make_click_handler()
                item.setCursor(Qt.PointingHandCursor)
                
                # Make text wrap and expand
                for child in item.children():
                    if isinstance(child, QPushButton):
                        child.setStyleSheet("""
                            QPushButton {
                                background: transparent;
                                border: none;
                                text-align: center;
                                padding: 5px;
                            }
                        """)
                        child.setMinimumHeight(50)
                        child.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
                
                layout.addWidget(item, row, col)
                col += 1
                if col >= max_cols:
                    col = 0
                    row += 1

        scroll.setWidget(content_widget)

        # Fixed bottom scroll button
        down_btn = QPushButton("▼ Scroll Down ▼")
        down_btn.setFixedHeight(40)  # Larger touch target
        down_btn.setStyleSheet("""
            QPushButton {
                border-radius: 0;
                border-top: 1px solid #555555;
            }
        """)
        menu_layout.addWidget(down_btn)

        # Connect scroll buttons to scroll by a fixed amount
        scroll_amount = 200  # Pixels to scroll per click
        up_btn.clicked.connect(lambda: scroll.verticalScrollBar().setValue(
            scroll.verticalScrollBar().value() - scroll_amount))
        down_btn.clicked.connect(lambda: scroll.verticalScrollBar().setValue(
            scroll.verticalScrollBar().value() + scroll_amount))

        self.set_content(menu_widget)

    # Edits to the menu (grid/list) need to be made here.
    def create_menu_item(self, name, data, is_list_view):
        item = QFrame()
        item.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        item_layout = QVBoxLayout(item)
        item_layout.setContentsMargins(10, 10, 10, 10)
        item_layout.setSpacing(10)

        has_valid_image = False
        if not is_list_view and isinstance(data, dict) and 'image' in data:
            image_label = QLabel()
            pixmap = QPixmap(data['image'])
            if not pixmap.isNull():
                # Scale image to fit within grid item while showing the full image
                scaled_pixmap = pixmap.scaled(120, 120, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                image_label.setPixmap(scaled_pixmap)
                image_label.setAlignment(Qt.AlignCenter)
                # Set fixed size to prevent layout issues
                image_label.setFixedSize(120, 120)
                item_layout.addWidget(image_label)
                has_valid_image = True

        # Only show button if in list view or no valid image in grid view
        if is_list_view or not has_valid_image:
            btn = QPushButton(name)
            btn.setObjectName("menuItemButton")
            
            if not is_list_view:
                # Set text wrapping properties for grid view only
                btn.setStyleSheet("""
                    QPushButton {
                        text-align: center;
                        padding: 5px;
                        white-space: pre-wrap;
                    }
                """)
            else:
                btn.setStyleSheet("""
                    QPushButton {
                        text-align: center;
                        padding: 5px;
                    }
                """)
            
            if isinstance(data, dict):
                if 'plugin' in data:
                    # It's a plugin
                    btn.clicked.connect(lambda checked, p=data['plugin'], n=name: self.show_plugin(p, n))
                else:
                    # It's a submenu - handle both plain dict and dict with submenu key
                    submenu = data.get('submenu', data)
                    btn.clicked.connect(lambda checked, d=submenu: self.show_submenu(d))
            else:
                # If data is not dict, treat as submenu
                btn.clicked.connect(lambda checked, d=data: self.show_submenu(d))

            item_layout.addWidget(btn)

        item_layout.addStretch()

        if not is_list_view:
            item.setObjectName("card")
            item.setMinimumSize(140, 140)
            item.setMaximumSize(140, 140)

        return item

    def show_submenu(self, submenu):
        self.show_menu(submenu)

    def show_plugin(self, plugin, name):
        # Check if plugin is already minimized
        if name in self.minimized_plugins:
            # Minimize any currently shown plugin
            current = self.content.currentWidget()
            if current and hasattr(current, 'plugin_name'):
                self.minimize_plugin(current.plugin_name, current)
            self.restore_plugin(name)
            return

        # Remove any existing control buttons from top bar
        for i in reversed(range(self.top_bar.layout().count())):
            widget = self.top_bar.layout().itemAt(i).widget()
            if widget and widget.objectName() == "windowControl":
                widget.deleteLater()

        # Minimize any currently shown plugin
        current = self.content.currentWidget()
        if current and hasattr(current, 'plugin_name'):
            self.minimize_plugin(current.plugin_name, current)

        # Check if plugin is already open but minimized
        for i in range(self.content.count()):
            widget = self.content.widget(i)
            if hasattr(widget, 'plugin_name') and widget.plugin_name == name:
                # Create new control buttons
                minimize_button = QPushButton("_")
                minimize_button.setObjectName("windowControl")
                minimize_button.setToolTip("Minimize to taskbar")
                minimize_button.clicked.connect(lambda: self.minimize_plugin(name, widget))
                minimize_button.setMinimumSize(40, 40)

                close_button = QPushButton("×")
                close_button.setObjectName("windowControl")
                close_button.setToolTip("Close plugin")
                close_button.clicked.connect(lambda: self.close_plugin(widget))
                close_button.setMinimumSize(40, 40)

                widget.control_buttons = [minimize_button, close_button]

                # Add buttons to top bar
                top_layout = self.top_bar.layout()
                button_insert_pos = top_layout.count() - 1
                top_layout.insertWidget(button_insert_pos, minimize_button)
                top_layout.insertWidget(button_insert_pos + 1, close_button)
                
                self.set_content(widget)
                return

        # Create a window-like widget for the plugin
        plugin_widget = QWidget()
        plugin_widget.plugin_name = name  # Store plugin name for checking if already open
        plugin_widget.setWindowFlags(Qt.SubWindow)
        plugin_widget.setObjectName("pluginWindow")
        layout = QVBoxLayout(plugin_widget)
        layout.setContentsMargins(0,0,0,0)  # Remove margins to maximize space
        layout.setSpacing(0)  # Remove spacing to maximize space

        # Add minimize and close buttons to main window's top bar
        minimize_button = QPushButton("_")
        minimize_button.setObjectName("windowControl")
        minimize_button.setToolTip("Minimize to taskbar")
        minimize_button.clicked.connect(lambda: self.minimize_plugin(name, plugin_widget))
        minimize_button.setMinimumSize(40, 40)

        close_button = QPushButton("×")
        close_button.setObjectName("windowControl") 
        close_button.setToolTip("Close plugin")
        close_button.clicked.connect(lambda: self.close_plugin(plugin_widget))
        close_button.setMinimumSize(40, 40)

        # Store buttons with the plugin widget for later removal
        plugin_widget.control_buttons = [minimize_button, close_button]

        # Insert before the main window close button
        top_layout = self.top_bar.layout()
        button_insert_pos = top_layout.count() - 1  # Position before main close button
        top_layout.insertWidget(button_insert_pos, minimize_button)
        top_layout.insertWidget(button_insert_pos + 1, close_button)

        # Create main container with absolute positioning
        container = QWidget()
        container.setLayout(QVBoxLayout())
        container.layout().setContentsMargins(0,0,0,0)
        container.layout().setSpacing(0)

        # Create scroll up button that spans width
        scroll_up = QPushButton("▲ Scroll Up ▲")
        scroll_up.setObjectName("scrollButton")
        scroll_up.setFixedHeight(40)
        container.layout().addWidget(scroll_up)

        # Create scroll area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOn)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        container.layout().addWidget(scroll)

        # Create scroll down button that spans width
        scroll_down = QPushButton("▼ Scroll Down ▼")
        scroll_down.setObjectName("scrollButton") 
        scroll_down.setFixedHeight(40)
        container.layout().addWidget(scroll_down)

        # Initialize scroll timer and hover timer if not already created
        if not hasattr(self, 'scroll_timer'):
            self.scroll_timer = QTimer()
            self.scroll_timer.timeout.connect(self.do_scroll)
            
        if not hasattr(self, 'hover_timer'):
            self.hover_timer = QTimer()
            self.hover_timer.setSingleShot(True)
            self.hover_timer.timeout.connect(self.start_scroll_from_hover)

        # Store current scroll area and direction for hover handling
        self.current_scroll_area = None
        self.current_scroll_direction = 0

        # Connect scroll buttons with hover events
        scroll_up.enterEvent = lambda e, s=scroll, d=-10: self.handle_hover_enter(s, d)
        scroll_up.leaveEvent = lambda e: self.handle_hover_leave()
        scroll_down.enterEvent = lambda e, s=scroll, d=10: self.handle_hover_enter(s, d)
        scroll_down.leaveEvent = lambda e: self.handle_hover_leave()

        plugin_inner = QWidget()
        plugin_layout = QVBoxLayout(plugin_inner)
        plugin_layout.setContentsMargins(20,20,20,20)
        plugin_layout.setSpacing(10)

        # If the plugin provides a widget, use it; else, show a placeholder
        if hasattr(plugin, 'get_widget'):
            w = plugin.get_widget()
            w.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            plugin_layout.addWidget(w)
        else:
            plugin_label = QLabel(f"This is the {name} plugin.")
            plugin_layout.addWidget(plugin_label)

        scroll.setWidget(plugin_inner)
        layout.addWidget(container)

        # Set size policy and make resizable
        plugin_widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        plugin_widget.setMinimumSize(400, 300)
        self.set_content(plugin_widget)

    def handle_hover_enter(self, scroll_area, direction):
        self.current_scroll_area = scroll_area
        self.current_scroll_direction = direction
        self.hover_timer.start(500)  # Start hover timer with 500ms delay

    def handle_hover_leave(self):
        self.hover_timer.stop()
        self.scroll_timer.stop()
        self.current_scroll_area = None
        self.current_scroll_direction = 0

    def start_scroll_from_hover(self):
        if self.current_scroll_area:
            self.scroll_timer.start(50)  # Start scrolling every 50ms

    def do_scroll(self):
        if self.current_scroll_area and self.current_scroll_direction:
            vbar = self.current_scroll_area.verticalScrollBar()
            vbar.setValue(vbar.value() + self.current_scroll_direction)

    def minimize_plugin(self, name, plugin_widget):
        # Remove control buttons from top bar
        if hasattr(plugin_widget, 'control_buttons'):
            for button in plugin_widget.control_buttons:
                button.deleteLater()
            plugin_widget.control_buttons.clear()

        if plugin_widget is self.content.currentWidget():
            # Go back if possible
            if self.history:
                prev_widget = self.history.pop()
                self.content.setCurrentWidget(prev_widget)
            else:
                # If no history, show main menu again
                if self.menu_structure:
                    self.show_menu(self.menu_structure)

        # Create taskbar button with integrated close button
        taskbar_btn = QPushButton()
        taskbar_btn.setObjectName("taskbarPluginButton")
        
        # Calculate width based on text length (approx 10px per character plus padding)
        text_width = len(name) * 7
        button_width = text_width # Add padding for close button and margins
        taskbar_btn.setFixedWidth(button_width)
        
        # Create horizontal layout for the button content
        btn_layout = QHBoxLayout(taskbar_btn)
        btn_layout.setContentsMargins(5,0,5,0)
        btn_layout.setSpacing(5)
        
        # Add name label
        name_label = QLabel(name)
        name_label.setStyleSheet("background-color: transparent;")
        btn_layout.addWidget(name_label)
        
        # Add close button
        close_label = QLabel("×")
        close_label.setObjectName("taskbarPluginCloseLabel")
        close_label.setStyleSheet("background-color: transparent; color: #ff0000;")
        btn_layout.addWidget(close_label)
        
        # Connect restore and close functionality
        taskbar_btn.clicked.connect(lambda checked, n=name: 
            self.restore_plugin(n) if not close_label.underMouse() else self.close_plugin(plugin_widget))

        self.task_layout.addWidget(taskbar_btn)
        self.minimized_plugins[name] = (plugin_widget, taskbar_btn)

    def restore_plugin(self, name):
        # Restore the plugin widget from minimized state
        if name in self.minimized_plugins:
            plugin_widget, taskbar_btn = self.minimized_plugins[name]
            
            # Minimize currently shown plugin if any
            current = self.content.currentWidget()
            if current and hasattr(current, 'plugin_name') and current.plugin_name != name:
                self.minimize_plugin(current.plugin_name, current)
            
            # Recreate control buttons
            minimize_button = QPushButton("_")
            minimize_button.setObjectName("windowControl")
            minimize_button.setToolTip("Minimize to taskbar")
            minimize_button.clicked.connect(lambda: self.minimize_plugin(name, plugin_widget))
            minimize_button.setMinimumSize(40, 40)

            close_button = QPushButton("×")
            close_button.setObjectName("windowControl")
            close_button.setToolTip("Close plugin")
            close_button.clicked.connect(lambda: self.close_plugin(plugin_widget))
            close_button.setMinimumSize(40, 40)

            plugin_widget.control_buttons = [minimize_button, close_button]

            # Add buttons back to top bar
            top_layout = self.top_bar.layout()
            button_insert_pos = top_layout.count() - 1
            top_layout.insertWidget(button_insert_pos, minimize_button)
            top_layout.insertWidget(button_insert_pos + 1, close_button)

            self.set_content(plugin_widget)
            taskbar_btn.deleteLater()
            del self.minimized_plugins[name]

    def close_plugin(self, plugin_widget):
        # Remove control buttons from top bar
        if hasattr(plugin_widget, 'control_buttons'):
            for button in plugin_widget.control_buttons:
                button.deleteLater()
            plugin_widget.control_buttons.clear()
        
        # Remove from minimized plugins if it was minimized
        if hasattr(plugin_widget, 'plugin_name') and plugin_widget.plugin_name in self.minimized_plugins:
            _, taskbar_btn = self.minimized_plugins[plugin_widget.plugin_name]
            taskbar_btn.deleteLater()
            del self.minimized_plugins[plugin_widget.plugin_name]
                    
        # Go back if possible
        if self.history:
            prev_widget = self.history.pop()
            self.content.setCurrentWidget(prev_widget)
        else:
            # If no history, show main menu again
            if self.menu_structure:
                self.show_menu(self.menu_structure)
                
    def show_settings(self):
        # Create main widget and scroll area
        settings_widget = QWidget()
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(settings_widget)
        
        # Create container for scroll area and scroll buttons
        container = QWidget()
        container_layout = QVBoxLayout(container)
        container_layout.setContentsMargins(0,0,0,0)
        container_layout.setSpacing(0)
        
        # Add scroll up button
        scroll_up = QPushButton("▲ Scroll Up ▲")
        scroll_up.setObjectName("scrollButton")
        scroll_up.setFixedHeight(40)
        scroll_up.pressed.connect(lambda: self.start_scroll(scroll, -10))
        scroll_up.released.connect(self.stop_scroll)
        container_layout.addWidget(scroll_up)
        
        # Add scroll area
        container_layout.addWidget(scroll)
        
        # Add scroll down button
        scroll_down = QPushButton("▼ Scroll Down ▼")
        scroll_down.setObjectName("scrollButton")
        scroll_down.setFixedHeight(40)
        scroll_down.pressed.connect(lambda: self.start_scroll(scroll, 10))
        scroll_down.released.connect(self.stop_scroll)
        container_layout.addWidget(scroll_down)
        
        layout = QVBoxLayout(settings_widget)
        layout.setContentsMargins(20,20,20,20)
        layout.setSpacing(20)

        # View mode (List or Grid)
        view_section = self.create_settings_section("View Mode")
        mode_label = QLabel("Menu Display Mode:")
        view_section.layout().addWidget(mode_label)
        view_button_layout = QHBoxLayout()
        list_btn = QPushButton("List")
        grid_btn = QPushButton("Grid")
        list_btn.setCheckable(True)
        grid_btn.setCheckable(True)
        list_btn.setChecked(self.settings.get("list_view", False))
        grid_btn.setChecked(not self.settings.get("list_view", False))
        
        # Ensure the selected mode is green
        if self.settings.get("list_view", False):
            list_btn.setStyleSheet("background-color: #28a745;")  # Green
            grid_btn.setStyleSheet("")
        else:
            grid_btn.setStyleSheet("background-color: #28a745;")  # Green
            list_btn.setStyleSheet("")
        
        list_btn.clicked.connect(lambda: self.change_view_mode("List"))
        list_btn.clicked.connect(lambda: list_btn.setStyleSheet("background-color: #28a745;"))
        list_btn.clicked.connect(lambda: grid_btn.setStyleSheet(""))
        
        grid_btn.clicked.connect(lambda: self.change_view_mode("Grid"))
        grid_btn.clicked.connect(lambda: grid_btn.setStyleSheet("background-color: #28a745;"))
        grid_btn.clicked.connect(lambda: list_btn.setStyleSheet(""))
        
        view_button_layout.addWidget(list_btn)
        view_button_layout.addWidget(grid_btn)
        view_section.layout().addLayout(view_button_layout)
        layout.addWidget(view_section)

        # Widget settings
        widget_section = self.create_settings_section("Widget Settings")
        widget_section.layout().addWidget(QLabel("Set widget startup priorities:"))
        priorities = self.widget_manager.get_priorities()
        for name, priority in priorities.items():
            widget_layout = QHBoxLayout()
            label = QLabel(name)
            priority_spin = QSpinBox()
            priority_spin.setValue(priority)
            priority_spin.valueChanged.connect(lambda v, n=name: self.change_widget_priority(n, v))
            widget_layout.addWidget(label)
            widget_layout.addWidget(priority_spin)
            widget_section.layout().addLayout(widget_layout)
        layout.addWidget(widget_section)

        # Plugin settings
        plugin_section = self.create_settings_section("Plugin Settings")
        plugin_section.layout().addWidget(QLabel("Enable/disable plugins:"))
        # Get all plugins from plugin manager
        all_plugins = self.plugin_manager.get_plugin_list()
        enabled_plugins = self.settings.get("plugins_enabled", {})
        
        # Add all plugins to the settings section
        for plugin_name in all_plugins:
            checkbox = QCheckBox(plugin_name)
            # Check if plugin is enabled in settings, default to True if not found
            is_enabled = enabled_plugins.get(plugin_name, True)
            checkbox.setChecked(is_enabled)
            checkbox.stateChanged.connect(lambda state, p=plugin_name: self.toggle_plugin(p, state))
            checkbox.setStyleSheet("""
                QCheckBox {
                    spacing: 5px;
                    font-size: 14px;
                    padding: 5px;
                }
                QCheckBox::indicator {
                    width: 15px;
                    height: 15px;
                    border: 2px solid palette(window-text);
                    border-radius: 3px;
                    background: palette(base);
                }
                QCheckBox::indicator:checked {
                    background: palette(highlight);
                    border-color: palette(highlight);
                }
                QCheckBox::indicator:unchecked {
                    background: palette(base);
                }
            """)
            plugin_section.layout().addWidget(checkbox)
        layout.addWidget(plugin_section)

        # Update buttons for plugins and themes
        update_section = self.create_settings_section("Updates")
        update_plugins_btn = QPushButton("Update Plugins")
        update_plugins_btn.clicked.connect(self.update_plugins)
        update_section.layout().addWidget(update_plugins_btn)

        update_themes_btn = QPushButton("Update Themes")
        update_themes_btn.clicked.connect(self.update_themes)
        update_section.layout().addWidget(update_themes_btn)
        layout.addWidget(update_section)

        # Theme settings
        theme_section = self.create_settings_section("Theme Settings")
        theme_section.layout().addWidget(QLabel("Select Theme:"))
        
        # Create grid layout for themes
        theme_grid = QGridLayout()
        theme_grid.setSpacing(10)
        all_themes = self.theme_manager.get_theme_names()
        current_theme = self.settings.get("theme", "default")
        if current_theme not in all_themes:
            current_theme = "default"
            
        # Calculate grid dimensions
        cols = 3  # Number of columns
        rows = (len(all_themes) + cols - 1) // cols  # Ceiling division
        
        # Add theme buttons to grid
        for i, theme in enumerate(all_themes):
            btn = QPushButton(theme)
            btn.setCheckable(True)
            btn.setChecked(theme == current_theme)
            btn.clicked.connect(lambda checked, t=theme: self.change_theme(t))
            btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            btn.setMinimumHeight(40)
            theme_grid.addWidget(btn, i // cols, i % cols)
            
        theme_section.layout().addLayout(theme_grid)
        layout.addWidget(theme_section)

        layout.addStretch()
        
        # Initialize scroll timer if not already created
        if not hasattr(self, 'scroll_timer'):
            self.scroll_timer = QTimer()
            self.scroll_timer.timeout.connect(self.do_scroll)
        
        self.set_content(container)
        
    def start_scroll(self, scroll_area, amount):
        self.scroll_area = scroll_area
        self.scroll_amount = amount
        self.scroll_timer.start(50)  # Timer interval in milliseconds
        
    def stop_scroll(self):
        self.scroll_timer.stop()

    def create_settings_section(self, title):
        group = QGroupBox(title)
        group_layout = QVBoxLayout(group)
        group_layout.setContentsMargins(10, 10, 10, 10)
        return group

    def change_theme(self, theme_name):
        self.settings["theme"] = theme_name
        self.apply_current_theme()
        self.save_settings()

    def change_view_mode(self, mode):
        if mode == "List":
            self.settings["list_view"] = True
        else:
            self.settings["list_view"] = False
        self.save_settings()

    def change_widget_priority(self, widget_name, priority):
        self.widget_manager.priorities[widget_name] = priority
        self.save_settings()

    def toggle_plugin(self, plugin_name, state):
        enabled = (state == Qt.Checked)
        self.plugin_manager.set_plugin_enabled(plugin_name, enabled)
        self.save_settings()
        self.refresh_plugins()

    def update_plugins(self):
        self.refresh_plugins()

    def update_themes(self):
        self.theme_manager.themes = self.theme_manager.load_themes()
        self.show_settings()

    def refresh_plugins(self):
        self.menu_structure = self.plugin_manager.load_all()
        self.show_settings()

    def first_refresh_plugins(self):
        self.menu_structure = self.plugin_manager.load_all()

    def set_content(self, widget):
        current = self.content.currentWidget()
        if current is not None:
            self.history.append(current)
        self.content.addWidget(widget)
        self.content.setCurrentWidget(widget)

    def go_back(self):
        # Check if there's a plugin open and minimize it
        current = self.content.currentWidget()
        if current and hasattr(current, 'plugin_name'):
            self.minimize_plugin(current.plugin_name, current)
            # Remove any control buttons from top bar
            if hasattr(current, 'control_buttons'):
                for button in current.control_buttons:
                    button.deleteLater()
                current.control_buttons.clear()

        if self.history:
            prev_widget = self.history.pop()
            self.content.setCurrentWidget(prev_widget)
            # Show menu structure if we're at root level
            if self.menu_structure and prev_widget == self.content.widget(0):
                self.show_menu(self.menu_structure)
                self.back_button.hide()
            else:
                self.back_button.show()
        else:
            # If no history, go back to main menu
            if self.menu_structure:
                self.show_menu(self.menu_structure)
                self.back_button.hide()  # Hide back button at root menu

    def apply_current_theme(self):
        theme = self.theme_manager.get_theme(self.settings.get("theme", "default"))
        self.setStyleSheet(self.generate_stylesheet(theme))

    def generate_stylesheet(self, theme):
        # Get theme values with fallbacks to prevent KeyError
        background = theme.get("background", "#1a1a1a")
        secondary = theme.get("secondary", "#2e2e2e")
        accent = theme.get("accent", "#404040") 
        text = theme.get("text", "#000000")
        text_bg = theme.get("text_background", "#808080")
        button_bg = theme.get("button_background", "#2e2e2e")
        button_hover = theme.get("button_hover", "#404040")
        close_button_bg = theme.get("close_button_background", "#d32f2f")
        close_button_hover = theme.get("close_button_hover", "#b71c1c")
        border_color = theme.get("border_color", "#555555")
        checkbox_text_color = theme.get("checkbox_text_color", text)
        checkbox_background = theme.get("checkbox_background", background)
        input_text_color = theme.get("input_text_color", text)
        input_background = theme.get("input_background", text_bg)
        card_hover = theme.get("card_hover", accent)

        return f"""
            QMainWindow {{
                background-color: {background};
                color: {text};
            }}
            QWidget {{
                background-color: {background};
            }}
            QWidget#topBar {{
                background-color: {secondary};
                border-bottom: 2px solid {border_color};
            }}
            QWidget#taskBar {{
                background-color: {secondary};
                border-top: 2px solid {border_color};
            }}
            QPushButton {{
                background-color: {button_bg};
                color: {text};
                padding: 8px;
                border: 1px solid {border_color};
                border-radius: 4px;
            }}
            QPushButton:hover {{
                background-color: {button_hover};
            }}
            QPushButton#closeButton {{
                background-color: {close_button_bg};
            }}
            QPushButton#closeButton:hover {{
                background-color: {close_button_hover};
            }}
            QGroupBox {{
                border: 1px solid {border_color};
                border-radius: 4px;
                margin-top: 20px;
                color: {text};
                background-color: {background};
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                subcontrol-position: top center;
                padding: 0 3px;
                background-color: {background};
            }}
            QFrame#card {{
                background-color: {accent};
                border: 1px solid {border_color};
                border-radius: 8px;
            }}
            QFrame#card:hover {{
                background-color: {card_hover};
            }}
            QScrollArea {{
                background-color: {background};
                border: none;
            }}
            QLabel {{
                color: {text};
                background-color: {text_bg};
                border-radius: 4px;
            }}
            QTextArea, QTextEdit {{
                background-color: {text_bg};
                color: {text};
            }}
            QCheckBox {{
                color: {checkbox_text_color};
                background-color: {checkbox_background};
            }}
            QComboBox {{
                color: {text};
                background-color: {text_bg};
                border: 1px solid {border_color};
                border-radius: 4px;
                padding: 4px;
            }}
            QListWidget {{
                color: {text};
                background-color: {text_bg};
                border: 1px solid {border_color};
                border-radius: 4px;
            }}
            QLineEdit {{
                color: {input_text_color};
                background-color: {input_background};
                border: 1px solid {border_color};
                border-radius: 4px;
                padding: 4px;
            }}
            QPushButton#backButton,
            QPushButton#menuButton,
            QPushButton#settingsButton,
            QPushButton#taskbarPluginButton {{
                border: 1px solid {border_color};
            }}
        """.strip()

def set_permissions():
    files_fixed = 0
    errors = 0
    
    # Set permissions for settings.json
    settings_path = "/nsatt/storage/settings.json"
    try:
        if not os.path.exists(settings_path):
            os.makedirs(os.path.dirname(settings_path), exist_ok=True)
            with open(settings_path, 'w') as f:
                json.dump({}, f)
        os.chmod(settings_path, 0o777)
        files_fixed += 1
        if debug_mode or debug_mode_1:
            print(f"Fixed permissions for {settings_path}")
    except PermissionError as e:
        errors += 1
        if debug_mode or debug_mode_1:
            print(f"Error setting permissions on settings.json: {e}")

    # Set permissions for all required directories
    base_paths = [
        "/nsatt/storage",
        "/nsatt/scripts", 
        "/nsatt/logs",
        "/nsatt/downloads",
        "/nsatt/services"
    ]
    
    for base_path in base_paths:
        for root, dirs, files in os.walk(base_path):
            # Skip __pycache__ directories
            if "__pycache__" in dirs:
                dirs.remove("__pycache__")
                
            # Set permissions for current directory
            try:
                os.chmod(root, 0o777)
                files_fixed += 1
                if debug_mode or debug_mode_1:
                    print(f"Fixed permissions for directory: {root}")
            except PermissionError as e:
                errors += 1
                if debug_mode or debug_mode_1:
                    print(f"Error setting permissions for directory {root}: {e}")
            
            # Set permissions for subdirectories
            for dir in dirs:
                dir_path = os.path.join(root, dir)
                try:
                    os.chmod(dir_path, 0o777)
                    files_fixed += 1
                    if debug_mode or debug_mode_1:
                        print(f"Fixed permissions for subdirectory: {dir_path}")
                except PermissionError as e:
                    errors += 1
                    if debug_mode or debug_mode_1:
                        print(f"Error setting permissions for subdirectory {dir_path}: {e}")
                
            # Set permissions for files
            for file in files:
                # Only process .py and .sh files
                if not file.endswith(('.py', '.sh')):
                    continue
                    
                file_path = os.path.join(root, file)
                try:
                    os.chmod(file_path, 0o755)
                    files_fixed += 1
                    if debug_mode or debug_mode_1:
                        print(f"Fixed permissions for file: {file_path}")
                except PermissionError as e:
                    errors += 1
                    if debug_mode or debug_mode_1:
                        print(f"Error setting permissions for file {file_path}: {e}")

    print(f"Files fixed: {files_fixed}, Errors: {errors}")

def sync_plugins_from_server(server_url=None, local_path=None):
    if not production_mode and debug_mode:
        if server_url is None:
            server_url = "http://localhost/nsatt/storage/plugins/"
        if local_path is None:
            local_path = "/nsatt/storage/plugins"
        
        try:
            # Make request to server to get file listing
            import requests
            print(f"Attempting to sync plugins from {server_url}")
            response = requests.get(server_url)
            if response.status_code == 200:
                print("Successfully connected to server")
                # Parse HTML to find files/directories
                from bs4 import BeautifulSoup
                soup = BeautifulSoup(response.text, 'html.parser')
                
                files_updated = 0
                # Find all links which are files/directories
                for link in soup.find_all('a'):
                    name = link.get('href')
                    if name in ['../', './'] or '__pycache__' in name:  # Skip parent/current directory and pycache
                        continue
                        
                    remote_path = server_url + name
                    local_file_path = os.path.join(local_path, name.rstrip('/'))
                    
                    if name.endswith('/'):  # Directory
                        print(f"Creating directory: {local_file_path}")
                        os.makedirs(local_file_path, exist_ok=True)
                        # Recursively sync subdirectory
                        sync_plugins_from_server(remote_path, local_file_path)
                    else:  # File
                        # Only download .py files
                        if name.endswith('.py'):
                            # Create parent directories if they don't exist
                            os.makedirs(os.path.dirname(local_file_path), exist_ok=True)
                            
                            # Download file
                            print(f"Downloading: {name}")
                            file_response = requests.get(remote_path)
                            if file_response.status_code == 200:
                                with open(local_file_path, 'wb') as f:
                                    f.write(file_response.content)
                                files_updated += 1
                                print(f"Successfully downloaded: {name}")
                
                print(f"Plugin sync complete. {files_updated} files updated.")
            else:
                print(f"Failed to connect to server. Status code: {response.status_code}")
                
        except Exception as e:
            print(f"Error syncing plugins from server: {e}")
            raise  # Re-raise the exception to see the full traceback

def main():
    sync_plugins_from_server()
    set_permissions()

    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
