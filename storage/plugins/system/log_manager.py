#!/usr/bin/env python3
import logging
import shutil
from pathlib import Path
from datetime import datetime
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                            QLabel, QGroupBox, QTextEdit, QTreeWidget, QTreeWidgetItem,
                            QComboBox, QMessageBox, QGridLayout)
from PyQt5.QtCore import Qt

plugin_image_value = "/nsatt/storage/images/icons/log_manager_icon.png"

class Plugin:
    NAME = "Log Manager"
    CATEGORY = "System" 
    DESCRIPTION = "View system logs"

    def __init__(self):
        self.widget = None
        self.logger = logging.getLogger(__name__)
        self.show_tree = True
        self.show_viewer = True
        self.current_sort = "Name (A-Z)"
        
        # Setup logging
        log_dir = Path("/nsatt/logs/log_manager")
        log_dir.mkdir(parents=True, exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = log_dir / f"log_manager_{timestamp}.log"
        
        # Base logs directory
        self.logs_dir = Path("/nsatt/logs")
        
        # Output directory for copied logs
        self.output_dir = Path("/var/www/html/log_output")
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def get_widget(self):
        if not self.widget:
            self.widget = QWidget()
            self.main_layout = QVBoxLayout()
            self.main_layout.setContentsMargins(5, 5, 5, 5)
            self.main_layout.setSpacing(5)

            # Control buttons in grid layout
            controls = QGridLayout()
            controls.setSpacing(5)
            
            # First column
            self.toggle_tree_btn = QPushButton("Hide Tree")
            self.toggle_tree_btn.clicked.connect(self.toggle_tree)
            controls.addWidget(self.toggle_tree_btn, 0, 0)
            
            refresh_btn = QPushButton("Refresh")
            refresh_btn.clicked.connect(self.refresh_logs)
            controls.addWidget(refresh_btn, 1, 0)
            
            delete_btn = QPushButton("Delete Selected")
            delete_btn.clicked.connect(self.delete_selected)
            controls.addWidget(delete_btn, 2, 0)
            
            # Second column  
            self.toggle_viewer_btn = QPushButton("Hide Viewer")
            self.toggle_viewer_btn.clicked.connect(self.toggle_viewer)
            controls.addWidget(self.toggle_viewer_btn, 0, 1)
            
            copy_btn = QPushButton("Copy to Web")
            copy_btn.clicked.connect(self.copy_to_web)
            controls.addWidget(copy_btn, 1, 1)
            
            delete_all_btn = QPushButton("Delete All Logs")
            delete_all_btn.clicked.connect(self.delete_all_logs)
            controls.addWidget(delete_all_btn, 2, 1)
            
            # Sort dropdown spans both columns
            self.sort_combo = QComboBox()
            self.sort_combo.addItems([
                "Name (A-Z)", 
                "Name (Z-A)",
                "Date (Newest)",
                "Date (Oldest)", 
                "Size (Largest)",
                "Size (Smallest)"
            ])
            self.sort_combo.currentTextChanged.connect(self.sort_logs)
            controls.addWidget(self.sort_combo, 3, 0, 1, 2)
            
            controls_widget = QWidget()
            controls_widget.setLayout(controls)
            self.main_layout.addWidget(controls_widget)

            # Tree view
            self.tree_widget = QTreeWidget()
            self.tree_widget.setHeaderLabel("Log Files")
            self.tree_widget.setMinimumHeight(200)
            self.tree_widget.setSelectionMode(QTreeWidget.ExtendedSelection)
            self.tree_widget.itemSelectionChanged.connect(self.on_selection_changed)
            self.main_layout.addWidget(self.tree_widget)

            # Log viewer
            self.log_viewer = QTextEdit()
            self.log_viewer.setReadOnly(True)
            self.log_viewer.setMinimumHeight(400)
            self.main_layout.addWidget(self.log_viewer)
            
            self.widget.setLayout(self.main_layout)
            
            # Initial population
            self.refresh_logs()

        return self.widget

    def toggle_tree(self):
        self.show_tree = not self.show_tree
        self.tree_widget.setVisible(self.show_tree)
        self.toggle_tree_btn.setText("Show Tree" if not self.show_tree else "Hide Tree")

    def toggle_viewer(self):
        self.show_viewer = not self.show_viewer
        self.log_viewer.setVisible(self.show_viewer)
        self.toggle_viewer_btn.setText("Show Viewer" if not self.show_viewer else "Hide Viewer")

    def refresh_logs(self):
        """Refresh log file tree"""
        self.tree_widget.clear()
        self.populate_log_tree()
        self.sort_logs(self.current_sort)

    def populate_log_tree(self):
        """Populate tree with log files"""
        try:
            self._add_directory_to_tree(self.logs_dir, self.tree_widget)
        except Exception as e:
            self.logger.error(f"Error populating log tree: {str(e)}")
            error_item = QTreeWidgetItem(self.tree_widget)
            error_item.setText(0, f"Error loading logs: {str(e)}")

    def _add_directory_to_tree(self, directory, parent):
        """Recursively add directory contents to tree"""
        try:
            path = Path(directory)
            
            # Create directory item if this is a subdirectory
            if path != self.logs_dir:
                dir_item = QTreeWidgetItem(parent)
                dir_item.setText(0, path.name)
                parent = dir_item
            
            # Add all subdirectories and log files
            for item in path.iterdir():
                if item.is_dir():
                    self._add_directory_to_tree(item, parent)
                elif item.suffix.lower() in ['.log', '.txt']:
                    file_item = QTreeWidgetItem(parent)
                    file_item.setText(0, item.name)
                    file_item.setData(0, Qt.UserRole, str(item))

        except Exception as e:
            self.logger.error(f"Error adding directory {directory} to tree: {str(e)}")
            error_item = QTreeWidgetItem(parent)
            error_item.setText(0, f"Error loading {directory}: {str(e)}")

    def sort_logs(self, sort_type):
        """Sort logs according to selected criteria"""
        self.current_sort = sort_type
        
        def get_sort_key(item):
            path = Path(item.data(0, Qt.UserRole) or "")
            if not path.exists():
                return ""
                
            if sort_type == "Name (A-Z)":
                return str(path).lower()
            elif sort_type == "Name (Z-A)":
                return str(path).lower(), True
            elif sort_type == "Date (Newest)":
                return -path.stat().st_mtime
            elif sort_type == "Date (Oldest)":
                return path.stat().st_mtime
            elif sort_type == "Size (Largest)":
                return -path.stat().st_size
            elif sort_type == "Size (Smallest)":
                return path.stat().st_size
            return str(path).lower()

        def sort_tree(parent):
            # Sort children that are files
            file_items = []
            for i in range(parent.childCount()):
                item = parent.child(i)
                if item.data(0, Qt.UserRole):  # Has file path data
                    file_items.append(item)
            
            # Remove and re-add in sorted order
            for item in file_items:
                parent.removeChild(item)
            
            file_items.sort(key=get_sort_key, reverse=sort_type in ["Name (Z-A)"])
            for item in file_items:
                parent.addChild(item)
            
            # Recursively sort subdirectories
            for i in range(parent.childCount()):
                sort_tree(parent.child(i))

        # Sort from root
        root = self.tree_widget.invisibleRootItem()
        sort_tree(root)

    def on_selection_changed(self):
        """Handle log file selection changes"""
        selected_items = self.tree_widget.selectedItems()
        if not selected_items:
            return
            
        # Show first selected log content
        file_path = selected_items[0].data(0, Qt.UserRole)
        if file_path:
            try:
                with open(file_path, 'r') as f:
                    self.log_viewer.setText(f.read())
            except Exception as e:
                self.logger.error(f"Error reading log file {file_path}: {str(e)}")
                self.log_viewer.setText(f"Error reading log file: {str(e)}")

    def delete_selected(self):
        """Delete selected log files"""
        selected_items = self.tree_widget.selectedItems()
        if not selected_items:
            return
            
        file_count = len([item for item in selected_items if item.data(0, Qt.UserRole)])
        if file_count == 0:
            return
            
        reply = QMessageBox.question(self.widget, 'Delete Logs',
                                   f'Are you sure you want to delete {file_count} log file(s)?',
                                   QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
                                   
        if reply == QMessageBox.Yes:
            for item in selected_items:
                file_path = item.data(0, Qt.UserRole)
                if file_path:
                    try:
                        Path(file_path).unlink()
                    except Exception as e:
                        self.logger.error(f"Error deleting log file {file_path}: {str(e)}")
                        QMessageBox.critical(self.widget, 'Error',
                                          f'Failed to delete {Path(file_path).name}: {str(e)}')
            
            self.refresh_logs()

    def delete_all_logs(self):
        """Delete all log and txt files"""
        reply = QMessageBox.question(self.widget, 'Delete All Logs',
                                   'Are you sure you want to delete ALL log and text files?',
                                   QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
                                   
        if reply == QMessageBox.Yes:
            def delete_logs_in_dir(directory):
                for item in Path(directory).iterdir():
                    if item.is_dir():
                        delete_logs_in_dir(item)
                    elif item.suffix.lower() in ['.log', '.txt']:
                        try:
                            item.unlink()
                        except Exception as e:
                            self.logger.error(f"Error deleting log file {item}: {str(e)}")
                            
            delete_logs_in_dir(self.logs_dir)
            self.refresh_logs()

    def copy_to_web(self):
        """Copy selected log to web output directory"""
        selected_items = self.tree_widget.selectedItems()
        if not selected_items:
            return
            
        for item in selected_items:
            file_path = item.data(0, Qt.UserRole)
            if file_path:
                try:
                    source = Path(file_path)
                    dest = self.output_dir / source.name
                    shutil.copy2(source, dest)
                except Exception as e:
                    self.logger.error(f"Error copying log file {file_path}: {str(e)}")
                    QMessageBox.critical(self.widget, 'Error',
                                      f'Failed to copy {source.name}: {str(e)}')
        
        QMessageBox.information(self.widget, 'Success',
                              'Selected log files copied successfully')

