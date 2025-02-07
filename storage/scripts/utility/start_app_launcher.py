from flask import Flask, render_template_string, redirect, url_for, request, jsonify
import os
import datetime
import psutil
import socket
import subprocess
import logging
import signal
import shutil
import threading
import time
import netifaces
import requests

app = Flask(__name__)

start_time = None
debug_log = []

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NSATT Launcher</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body.dark-mode { background-color: #121212; color: #e0e0e0; }
        body.light-mode { background-color: #ffffff; color: #000000; }
        .container { max-width: 960px; }
        .card { transition: all 0.3s ease; box-shadow: 0 6px 12px rgba(0, 0, 0, 0.3); }
        .card.dark-mode { background-color: #1e1e1e; border-color: #444; }
        .card.light-mode { background-color: #ffffff; border-color: #ddd; }
        .card-header { transition: all 0.3s ease; }
        .card-header.dark-mode { background-color: #282828; border-bottom-color: #444; }
        .card-header.light-mode { background-color: #f8f9fa; border-bottom-color: #ddd; }
        .table.dark-mode { color: #e0e0e0; }
        .table.light-mode { color: #000000; }
        .table-dark.dark-mode { background-color: #282828; }
        .table-dark.light-mode { background-color: #f8f9fa; }
        .btn-primary { background-color: #00aaff; border-color: #00aaff; }
        .btn-primary:hover { background-color: #008fcc; border-color: #008fcc; }
        .btn-warning { background-color: #ffc107; border-color: #ffc107; color: #000; }
        .btn-warning:hover { background-color: #e0a800; border-color: #e0a800; }
        .btn-danger { background-color: #dc3545; border-color: #dc3545; }
        .btn-danger:hover { background-color: #bd2130; border-color: #bd2130; }
        .modal-content { transition: all 0.3s ease; }
        .modal-content.dark-mode { background-color: #1e1e1e; color: #e0e0e0; }
        .modal-content.light-mode { background-color: #ffffff; color: #000000; }
        .modal-header.dark-mode { border-bottom-color: #444; }
        .modal-header.light-mode { border-bottom-color: #ddd; }
        .modal-footer.dark-mode { border-top-color: #444; }
        .modal-footer.light-mode { border-top-color: #ddd; }
        .card-title { font-weight: bold; }
        #toggleModeBtn { transition: background-color 0.3s ease; }
        #toggleModeBtn.light-mode { background-color: #f0f0f0; color: #000; }
        #toggleModeBtn.dark-mode { background-color: #444; color: #e0e0e0; }
        .toggle-btn { box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); }
        .header-container { background: linear-gradient(145deg, #333, #444); padding: 20px; color: #fff; border-radius: 10px; }
        .header-container h1 { font-family: 'Montserrat', sans-serif; font-weight: 700; }

        /* Custom styles for the message container */
        #messageContainer.dark-mode {
            background-color: #282828; /* Match the dark theme */
            color: #e0e0e0;
            border-color: #444;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
        }
        #messageContainer.light-mode {
            background-color: #f8f9fa; /* Match the light theme */
            color: #000000;
            border-color: #ddd;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
        }
        #messageContainer {
            display: none; /* Hide initially */
        }
    </style>
</head>
<body class="light-mode">
    <div class="container mt-4">
        <header class="header-container text-center mb-4">
            <h1 class="text-primary">NSATT App Launcher</h1>
        </header>
        
        <div class="info-container">
            <div class="card mb-4">
                <div class="card-header text-center">
                    <h2>NSATT Control Dashboard</h2>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-12 mb-3">
                            <button id="toggleModeBtn" class="btn btn-secondary btn-lg w-100 toggle-btn {% if not app_running %}w-100{% endif %}" onclick="toggleMode()">Light Theme</button>
                        </div>
                    </div>
                    
                    {% if app_running %}
                        <button id="stopbtn" onclick="showStopAppWarning()" class="btn btn-danger btn-lg w-100">Stop Application</button>
                        <div class="alert alert-success mt-3 text-center">
                            Application is running! Access it at: <a href="http://{{ ip_address }}:8080" target="_blank" class="alert-link">http://{{ ip_address }}:8080</a>
                        </div>
                        {% if start_time %}
                            <p class="mt-2">Application started at: {{ start_time }}</p>
                        {% endif %}
                    {% else %}
                        <button id="startbtn" onclick="showStartAppWarning()" class="btn btn-success btn-lg w-100">Start Application</button>
                    {% endif %}
                    <div id="messageContainer" class="alert alert-info mt-4 text-center" style="display: none;"></div>
                </div>
                <div id="spinner" class="text-center my-4" style="display: none;">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                </div>
            </div>
            
            <div class="card mb-4">
                <div class="card-header">
                    <h3 class="card-title">System Information</h3>
                </div>
                <div class="card-body">
                    <table class="table table-dark table-striped">
                        <tr><td>Launcher started at:</td><td>{{ launcher_start_time }}</td></tr>
                        <tr><td>System uptime:</td><td>{{ uptime }}</td></tr>
                    </table>
                </div>
            </div>

            <div class="card mb-4">
                <div class="card-header">
                    <h3 class="card-title">Service Control</h3>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <button onclick="showServiceWarning()" id="serviceToggleBtn" class="btn btn-warning btn-lg w-100">
                                {% if service_running %}Stop{% else %}Start{% endif %} Service
                            </button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="showShutdownWarning()" class="btn btn-danger btn-lg w-100">Shutdown Device</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="showRestartLauncherWarning()" class="btn btn-primary btn-lg w-100">Restart Launcher</button>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <button onclick="toggleAutostart()" class="btn btn-secondary btn-lg w-100">Toggle Autostart</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="toggleStartApp()" class="btn btn-secondary btn-lg w-100">Next Boot Start</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="restartApp()" class="btn btn-primary btn-lg w-100">Restart App</button>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <button onclick="toggleApache2()" class="btn btn-secondary btn-lg w-100">Toggle Apache2</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="toggleLLDPD()" class="btn btn-secondary btn-lg w-100">Toggle LLDPD</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="togglePostgreSQL()" class="btn btn-secondary btn-lg w-100">Toggle PostgreSQL</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="toggleSSH()" class="btn btn-secondary btn-lg w-100">Toggle SSH</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="toggleFTP()" class="btn btn-secondary btn-lg w-100">Toggle FTP</button>
                        </div>
                        <div class="col-md-4 mb-3">
                            <button onclick="reloadFiles()" class="btn btn-secondary btn-lg w-100">Reload Files</button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Restart Launcher Warning Modal -->
            <div class="modal fade" id="restartLauncherWarningModal" tabindex="-1" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">Warning: Restart Launcher</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                        </div>
                        <div class="modal-body">
                            <p><strong>You are about to restart the NSATT Launcher.</strong></p>
                            <p>This action will:</p>
                            <ul>
                                <li>Stop the current launcher process</li>
                                <li>Restart the launcher application</li>
                            </ul>
                            <p>This operation may take several seconds to complete.</p>
                            <p>Are you sure you want to proceed?</p>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="button" class="btn btn-primary" onclick="restartLauncher()">Confirm</button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card mb-4">
                <div class="card-header">
                    <h3 class="card-title">Debug Log</h3>
                </div>
                <div class="card-body">
                    <pre id="debugLog">{{ debug_log }}</pre>
                </div>
            </div>
        </div>
    </div>
    <footer class="text-center mt-4">
        <p>Visit <a href="https://www.tstp.xyz" target="_blank">TSTP.xyz</a> for more information</p>
    </footer>
    <!-- Toggle Autostart Warning Modal -->
    <div class="modal fade" id="toggleAutostartWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Warning: Toggle Autostart</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>You are about to toggle the autostart setting.</strong></p>
                    <p>This action will:</p>
                    <ul>
                        <li>Enable or disable the autostart feature</li>
                        <li>When enabled, the application will start automatically on device boot</li>
                        <li>When disabled, the application will not start automatically on device boot</li>
                    </ul>
                    <p>Are you sure you want to proceed?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-primary" onclick="confirmToggleAutostart()">Confirm</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Toggle Start App Warning Modal -->
    <div class="modal fade" id="toggleStartAppWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Warning: Toggle Start App</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>You are about to toggle the start app setting.</strong></p>
                    <p>This action will:</p>
                    <ul>
                        <li>Enable or disable the start app feature</li>
                        <li>When enabled, the application will start once and the setting will be deleted</li>
                        <li>When disabled, the application will not start automatically</li>
                    </ul>
                    <p>Are you sure you want to proceed?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-primary" onclick="confirmToggleStartApp()">Confirm</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Restart App Warning Modal -->
    <div class="modal fade" id="restartAppWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Warning: Restart App</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>You are about to restart the application.</strong></p>
                    <p>This action will:</p>
                    <ul>
                        <li>Stop the current application process</li>
                        <li>Restart the application</li>
                        <li>Users will lose access to the UI until the application returns</li>
                    </ul>
                    <p>This operation may take several seconds to complete.</p>
                    <p>Are you sure you want to proceed?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-primary" onclick="confirmRestartApp()">Confirm</button>
                </div>
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function showStartAppWarning() {
            new bootstrap.Modal(document.getElementById('startAppWarningModal')).show();
        }

        function showStopAppWarning() {
            new bootstrap.Modal(document.getElementById('stopAppWarningModal')).show();
        }

        function showRestartLauncherWarning() {
            new bootstrap.Modal(document.getElementById('restartLauncherWarningModal')).show();
        }

        function restartLauncher() {
            // Hide the modal
            bootstrap.Modal.getInstance(document.getElementById('restartLauncherWarningModal')).hide();
            fetch('/restart_launcher', { method: 'POST' })
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`Network response was not ok: ${response.statusText}`);
                    }
                    return response.json();
                })
                .then(data => {
                    if (data.message) {
                        showMessage(data.message);
                    } else {
                        showMessage('An unexpected error occurred.');
                    }
                    // Reload after a 15-second delay to allow the user to see the message
                    setTimeout(() => location.reload(), 15000);
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage(`An error occurred while restarting the launcher: ${error.message}`);
                });
        }

        function startApplication() {
            // Show spinner
            document.getElementById('spinner').style.display = 'block';
            // Hide modal
            bootstrap.Modal.getInstance(document.getElementById('startAppWarningModal')).hide();
            // Disable start button
            document.getElementById('startbtn').disabled = true;

            fetch('/start', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(data.message);
                    // Polling to check if the app is running
                    checkAppRunning();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while starting the application.');
                    // Hide spinner
                    document.getElementById('spinner').style.display = 'none';
                });
        }

        function reloadFiles() {
            fetch('/reload_files', { method: 'POST' })
                .then(response => response.json())
                .then(data => showMessage(data.message));
        }

        // Function to check if the app is running
        function checkAppRunning() {
            fetch('/status')
                .then(response => response.json())
                .then(data => {
                    if (data.app_running) {
                        // App has started, show success message and reload after 5 seconds
                        showMessage('Application has started successfully.');
                        setTimeout(() => location.reload(), 5000);
                    } else {
                        // Continue polling
                        setTimeout(checkAppRunning, 2000);
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('Error checking application status.');
                });
        }

        function stopApplication() {
            // Show spinner
            document.getElementById('spinner').style.display = 'block';
            // Hide modal
            bootstrap.Modal.getInstance(document.getElementById('stopAppWarningModal')).hide();
            // Hide Button
            document.getElementById('stopbtn').style.display = 'none';

            fetch('/stop', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(data.message);
                    // Reload after a 5-second delay to allow the user to see the message
                    setTimeout(() => location.reload(), 5000);
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while stopping the application.');
                })
                .finally(() => {
                    // Hide spinner
                    document.getElementById('spinner').style.display = 'none';
                });
        }

        // Function to show a message on the page
        function showMessage(message, type = 'info') {
            const messageContainer = document.getElementById('messageContainer');
            messageContainer.textContent = message;
            messageContainer.className = `alert alert-${type} mt-4 text-center`;
            messageContainer.style.display = 'block'; // Show the container

            // Hide the message after 5 seconds
            setTimeout(() => {
                messageContainer.style.display = 'none'; // Hide the container
            }, 5000);
        }

        function showServiceWarning() {
            const serviceAction = document.getElementById('serviceToggleBtn').textContent.trim().toLowerCase();
            document.getElementById('serviceAction').textContent = serviceAction;
            new bootstrap.Modal(document.getElementById('serviceWarningModal')).show();
        }

        function toggleService() {
            fetch('/toggle_service', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(data.message, 'success');
                    setTimeout(location.reload.bind(location), 2000); // Refresh after 2 seconds to show the updated status
                    // Hide Modal
                    bootstrap.Modal.getInstance(document.getElementById('serviceWarningModal')).hide();
                })
                .catch(error => {
                    showMessage('Service Shutdown Complete - Error connecting back to service', 'danger');
                    console.error('Error:', error);
                    // Hide Modal
                    bootstrap.Modal.getInstance(document.getElementById('serviceWarningModal')).hide();
                });
        }

        function showShutdownWarning() {
            new bootstrap.Modal(document.getElementById('shutdownWarningModal')).show();
        }

        document.addEventListener('DOMContentLoaded', function() {
            const shutdownWarningModal = document.getElementById('shutdownWarningModal');
            if (shutdownWarningModal) {
                shutdownWarningModal.addEventListener('shown.bs.modal', function() {
                    const confirmCheck = document.getElementById('shutdownConfirmCheck');
                    const confirmButton = document.getElementById('confirmShutdownBtn');
                    confirmCheck.addEventListener('change', function() {
                        confirmButton.disabled = !confirmCheck.checked;
                    });
                });
            } else {
                console.error('shutdownWarningModal is null');
            }
        });

        function initiateShutdown() {
            fetch('/shutdown', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(data.message, 'danger');
                    setTimeout(() => {
                        document.body.innerHTML = '<div class="container mt-5"><h1 class="text-danger">Device is shutting down</h1><p>This page will no longer be accessible. The device is powering off.</p></div>';
                    }, 2000);
                })
                .catch(error => {
                    showMessage('Error shutting down device.', 'danger');
                    console.error('Error:', error);
                });
        }

        function updateStatus() {
            fetch('/status')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('debugLog').textContent = data.debug_log;
                })
                .catch(error => console.error('Error:', error));
        }

        setInterval(updateStatus, 5000);

        function toggleMode() {
            const body = document.body;
            const toggleBtn = document.getElementById('toggleModeBtn');
            const currentMode = body.classList.contains('dark-mode') ? 'dark-mode' : 'light-mode';
            const newMode = currentMode === 'dark-mode' ? 'light-mode' : 'dark-mode';
            body.classList.remove(currentMode);
            body.classList.add(newMode);

            // Update button text
            toggleBtn.textContent = newMode === 'dark-mode' ? 'Light Theme' : 'Dark Theme';

            // Update classes for dark/light mode
            document.querySelectorAll('.card, .card-header, .table, .modal-content').forEach(element => {
                element.classList.remove(currentMode);
                element.classList.add(newMode);
            });

            toggleBtn.classList.remove(currentMode);
            toggleBtn.classList.add(newMode);
        }
    </script>

    <!-- Start Application Warning Modal -->
    <div class="modal fade" id="startAppWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Start NSATT Application</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>You are about to start the NSATT application.</strong></p>
                    <p>This action will:</p>
                    <ul>
                        <li>Initialize all NSATT components</li>
                        <li>Make the application accessible at http://{{ ip_address }}:8080</li>
                        <li>Begin logging all application activities</li>
                    </ul>
                    <p>Are you sure you want to proceed?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-success" onclick="startApplication()">Start Application</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Stop Application Warning Modal -->
    <div class="modal fade" id="stopAppWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Stop NSATT Application</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>Warning: You are about to stop the NSATT application.</strong></p>
                    <p>This action will:</p>
                    <ul>
                        <li>Terminate all running NSATT processes</li>
                        <li>Make the application inaccessible at http://{{ ip_address }}:8080</li>
                        <li>Stop all ongoing operations and logging</li>
                    </ul>
                    <p>Are you sure you want to proceed?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-danger" onclick="stopApplication()">Stop Application</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Service Warning Modal -->
    <div class="modal fade" id="serviceWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Warning: Service Control</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>You are about to <span id="serviceAction"></span> the NSATT Service.</strong></p>
                    <p>This action will affect the entire NSATT system:</p>
                    <ul>
                        <li><strong>Stopping the service:</strong> Will shut down all NSATT components, including the launcher and any running applications.</li>
                        <li><strong>Starting the service:</strong> Will reinitialize all NSATT components, but won't automatically start the application.</li>
                    </ul>
                    <p>This operation may take several seconds to complete.</p>
                    <p>Are you absolutely sure you want to proceed?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-warning" onclick="toggleService()">Confirm</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Shutdown Warning Modal -->
    <div class="modal fade" id="shutdownWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Warning: Device Shutdown</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>CAUTION: You are about to shut down the entire device.</strong></p>
                    <p>This action will:</p>
                    <ul>
                        <li>Stop all running services and applications</li>
                        <li>Power off the device completely</li>
                        <li>Make the device inaccessible remotely</li>
                        <li>Require physical access to restart the device</li>
                    </ul>
                    <p>This action cannot be undone remotely.</p>
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" id="shutdownConfirmCheck" onclick="toggleConfirmShutdownBtn()">
                        <label class="form-check-label" for="shutdownConfirmCheck">
                            I understand the consequences and wish to proceed
                        </label>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-danger" id="confirmShutdownBtn" onclick="showFinalShutdownWarning()" disabled>Confirm Shutdown</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', (event) => {
            const confirmCheck = document.getElementById('shutdownConfirmCheck');
            const confirmBtn = document.getElementById('confirmShutdownBtn');
            if (confirmCheck && confirmBtn) {
                confirmCheck.addEventListener('click', toggleConfirmShutdownBtn);
            }
        });
    </script>

    <!-- Final Shutdown Warning Modal -->
    <div class="modal fade" id="finalShutdownWarningModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Final Confirmation: Device Shutdown</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p><strong>WARNING: This is your last chance to cancel the shutdown.</strong></p>
                    <p>Are you absolutely sure you want to shut down the device?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-danger" onclick="initiateShutdown()">Yes, Shut Down</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        function toggleConfirmShutdownBtn() {
            const confirmCheck = document.getElementById('shutdownConfirmCheck');
            const confirmBtn = document.getElementById('confirmShutdownBtn');
            confirmBtn.disabled = !confirmCheck.checked;
        }

        function showFinalShutdownWarning() {
            new bootstrap.Modal(document.getElementById('finalShutdownWarningModal')).show();
        }

        function toggleAutostart() {
            new bootstrap.Modal(document.getElementById('toggleAutostartWarningModal')).show();
        }

        function confirmToggleAutostart() {
            fetch('/toggle_autostart', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(`Autostart is now ${data.exists ? 'enabled' : 'disabled'}.`);
                    const button = document.querySelector('button[onclick="toggleAutostart()"]');
                    button.className = `btn btn-${data.exists ? 'success' : 'danger'} btn-lg w-100`;
                    bootstrap.Modal.getInstance(document.getElementById('toggleAutostartWarningModal')).hide();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while toggling autostart.');
                });
        }

        function toggleSSH() {
            fetch('/toggle_ssh_autostart', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(`SSH Autostart is now ${data.exists ? 'enabled' : 'disabled'}.`);
                    const button = document.querySelector('button[onclick="toggleSSH()"]');
                    button.className = `btn btn-${data.exists ? 'success' : 'danger'} btn-lg w-100`;
                    bootstrap.Modal.getInstance(document.getElementById('toggleSSHWarningModal')).hide();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while toggling SSH autostart.');
                });
        }

        function toggleFTP() {
            fetch('/toggle_ftp_autostart', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(`FTP Autostart is now ${data.exists ? 'enabled' : 'disabled'}.`);
                    const button = document.querySelector('button[onclick="toggleFTP()"]');
                    button.className = `btn btn-${data.exists ? 'success' : 'danger'} btn-lg w-100`;
                    bootstrap.Modal.getInstance(document.getElementById('toggleFTPWarningModal')).hide();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while toggling FTP autostart.');
                });
        }

        function toggleLLDPD() {
            fetch('/toggle_lldpd_autostart', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(`LLDPD Autostart is now ${data.exists ? 'enabled' : 'disabled'}.`);
                    const button = document.querySelector('button[onclick="toggleLLDPD()"]');
                    button.className = `btn btn-${data.exists ? 'success' : 'danger'} btn-lg w-100`;
                    bootstrap.Modal.getInstance(document.getElementById('toggleLLDPDWarningModal')).hide();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while toggling LLDPD autostart.');
                });
        }

        function togglePostgreSQL() {
            fetch('/toggle_postgresql_autostart', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(`PostgreSQL Autostart is now ${data.exists ? 'enabled' : 'disabled'}.`);
                    const button = document.querySelector('button[onclick="togglePostgreSQL()"]');
                    button.className = `btn btn-${data.exists ? 'success' : 'danger'} btn-lg w-100`;
                    bootstrap.Modal.getInstance(document.getElementById('togglePostgreSQLWarningModal')).hide();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while toggling PostgreSQL autostart.');
                });
        }

        function toggleApache2() {
            fetch('/toggle_apache2_autostart', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(`Apache2 Autostart is now ${data.exists ? 'enabled' : 'disabled'}.`);
                    const button = document.querySelector('button[onclick="toggleApache2()"]');
                    button.className = `btn btn-${data.exists ? 'success' : 'danger'} btn-lg w-100`;
                    bootstrap.Modal.getInstance(document.getElementById('toggleApache2WarningModal')).hide();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while toggling Apache2 autostart.');
                });
        }

        function toggleStartApp() {
            new bootstrap.Modal(document.getElementById('toggleStartAppWarningModal')).show();
        }

        function confirmToggleStartApp() {
            fetch('/toggle_start_app', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showMessage(`Start App is now ${data.exists ? 'enabled' : 'disabled'}.`);
                    const button = document.querySelector('button[onclick="toggleStartApp()"]');
                    button.className = `btn btn-${data.exists ? 'success' : 'danger'} btn-lg w-100`;
                    bootstrap.Modal.getInstance(document.getElementById('toggleStartAppWarningModal')).hide();
                })
                .catch(error => {
                    console.error('Error:', error);
                    showMessage('An error occurred while toggling start app.');
                });
        }

        function restartApp() {
            new bootstrap.Modal(document.getElementById('restartAppWarningModal')).show();
        }

        function confirmRestartApp() {
            fetch('/restart', { method: 'POST' })
                .then(response => {
                    if (!response.ok) {
                        return response.text().then(text => {
                            throw new Error(text || 'Unknown error occurred');
                        });
                    }
                    return response.json();
                })
                .then(data => {
                    showMessage(data.message);
                    setTimeout(() => location.reload(), 15000);
                    bootstrap.Modal.getInstance(document.getElementById('restartAppWarningModal')).hide();
                })
                .catch(error => {
                    showMessage('Error restarting app: ' + error.message);
                });
        }
        const internal_debug_mode = true;
        const START_APP_PATH = "/nsatt/storage/settings/start_app.nsatt";
        const AUTO_START_PATH = "/nsatt/storage/settings/autostart_app.nsatt";
        const SSH_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_ssh.nsatt";
        const FTP_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_ftp.nsatt";
        const LLDPD_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_lldpd.nsatt";
        const POSTGRESQL_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_postgresql.nsatt";
        const APACHE2_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_apache2.nsatt";

        async function changeButtonColors() {
            try {
                // Function to change button colors if files are found:
                const startAppButton = document.querySelector('button[onclick="toggleStartApp()"]');
                const autostartButton = document.querySelector('button[onclick="toggleAutostart()"]');
                const sshButton = document.querySelector('button[onclick="toggleSSH()"]');
                const ftpButton = document.querySelector('button[onclick="toggleFTP()"]');
                const lldpdButton = document.querySelector('button[onclick="toggleLLDPD()"]');
                const postgresqlButton = document.querySelector('button[onclick="togglePostgreSQL()"]');
                const apache2Button = document.querySelector('button[onclick="toggleApache2()"]');
                
                const paths = [
                    { button: startAppButton, path: START_APP_PATH },
                    { button: autostartButton, path: AUTO_START_PATH },
                    { button: sshButton, path: SSH_AUTOSTART_PATH },
                    { button: ftpButton, path: FTP_AUTOSTART_PATH },
                    { button: lldpdButton, path: LLDPD_AUTOSTART_PATH },
                    { button: postgresqlButton, path: POSTGRESQL_AUTOSTART_PATH },
                    { button: apache2Button, path: APACHE2_AUTOSTART_PATH }
                ];

                for (const { button, path } of paths) {
                    const exists = await checkFileExists(path);
                    button.className = `btn btn-${exists ? 'success' : 'danger'} btn-lg w-100`;
                }
            } catch (error) {
                if (internal_debug_mode) {
                    console.error('Error in changeButtonColors:', error);
                    alert('An error occurred while changing button colors. Please check the console for more details.');
                }
            }
        }
        
        function checkFileExists(filePath) {
            return fetch(`/web_check_file_exists?path=${encodeURIComponent(filePath)}`)
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.json();
                })
                .then(data => data.exists)
                .catch(error => {
                    if (internal_debug_mode) {
                        console.error('Error checking file existence:', error);
                        alert('An error occurred while checking file existence. Please check the console for more details.');
                    }
                    return false;
                });
        }

        changeButtonColors();
    </script>
</body>
</html>
"""
LAUNCH_SCRIPT = "/nsatt/storage/scripts/utility/restart_app.sh"
AUTO_START_PATH = "/nsatt/storage/settings/autostart_app.nsatt"
START_APP_PATH = "/nsatt/storage/settings/start_app.nsatt"
FTP_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_ftp.nsatt"
SSH_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_ssh.nsatt"
LLDPD_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_lldpd.nsatt"
POSTGRESQL_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_postgresql.nsatt"
APACHE2_AUTOSTART_PATH = "/nsatt/storage/settings/autostart_apache2.nsatt"

debug_mode2 = False

@app.route('/reload_files', methods=['POST'])
def reload_files():
    try:
        subprocess.run(["sudo", "/nsatt/storage/scripts/utility/reload_files_and_permissions.sh"], check=True)
        message = "Files and permissions reloaded successfully."
        debug_log.append(f"{datetime.datetime.now()}: {message}")
        return jsonify({"message": message})
    except subprocess.CalledProcessError as e:
        error_message = f"Error reloading files and permissions: {str(e)}"
        debug_log.append(f"{datetime.datetime.now()}: {error_message}")
        return jsonify({"error": error_message}), 500

@app.route('/web_check_file_exists', methods=['GET'])
def web_check_file_exists():
    file_path = request.args.get('path')
    return jsonify({"exists": os.path.exists(file_path)})

def check_file_exists(file_path):
    return os.path.exists(file_path)

def toggle_file(file_path):
    if check_file_exists(file_path):
        os.remove(file_path)
    else:
        with open(file_path, 'w') as f:
            pass  # Create an empty file

def verify_file_creation(file_path):
    return check_file_exists(file_path)

@app.route('/toggle_autostart', methods=['POST'])
def toggle_autostart():
    toggle_file(AUTO_START_PATH)
    return jsonify({"exists": verify_file_creation(AUTO_START_PATH)})

@app.route('/toggle_start_app', methods=['POST'])
def toggle_start_app():
    toggle_file(START_APP_PATH)
    return jsonify({"exists": verify_file_creation(START_APP_PATH)})

@app.route('/toggle_ftp_autostart', methods=['POST'])
def toggle_ftp_autostart():
    toggle_file(FTP_AUTOSTART_PATH)
    return jsonify({"exists": verify_file_creation(FTP_AUTOSTART_PATH)})

@app.route('/toggle_ssh_autostart', methods=['POST'])
def toggle_ssh_autostart():
    toggle_file(SSH_AUTOSTART_PATH)
    return jsonify({"exists": verify_file_creation(SSH_AUTOSTART_PATH)})

@app.route('/toggle_lldpd_autostart', methods=['POST'])
def toggle_lldpd_autostart():
    toggle_file(LLDPD_AUTOSTART_PATH)
    return jsonify({"exists": verify_file_creation(LLDPD_AUTOSTART_PATH)})

@app.route('/toggle_postgresql_autostart', methods=['POST'])
def toggle_postgresql_autostart():
    toggle_file(POSTGRESQL_AUTOSTART_PATH)
    return jsonify({"exists": verify_file_creation(POSTGRESQL_AUTOSTART_PATH)})

@app.route('/toggle_apache2_autostart', methods=['POST'])
def toggle_apache2_autostart():
    toggle_file(APACHE2_AUTOSTART_PATH)
    return jsonify({"exists": verify_file_creation(APACHE2_AUTOSTART_PATH)})

def start_ftp_service():
    subprocess.Popen(["sudo", "systemctl", "start", "vsftpd.service"])

def start_ssh_service():
    subprocess.Popen(["sudo", "systemctl", "start", "ssh.service"])

def start_lldpd_service():
    subprocess.Popen(["sudo", "systemctl", "start", "lldpd.service"])

def start_postgresql_service():
    subprocess.Popen(["sudo", "systemctl", "start", "postgresql.service"])

def start_apache2_service():
    subprocess.Popen(["sudo", "systemctl", "start", "apache2.service"])

def stop_ssh_service():
    subprocess.Popen(["sudo", "systemctl", "stop", "ssh.service"])

def stop_ftp_service():
    subprocess.Popen(["sudo", "systemctl", "stop", "vsftpd.service"])

def stop_lldpd_service():
    subprocess.Popen(["sudo", "systemctl", "stop", "lldpd.service"])

def stop_postgresql_service():
    subprocess.Popen(["sudo", "systemctl", "stop", "postgresql.service"])

def stop_apache2_service():
    subprocess.Popen(["sudo", "systemctl", "stop", "apache2.service"])

@app.route('/check_file_status', methods=['GET'])
def check_file_status():
    autostart_exists = check_file_exists(AUTO_START_PATH)
    start_app_exists = check_file_exists(START_APP_PATH)
    ftp_autostart_exists = check_file_exists(FTP_AUTOSTART_PATH)
    ssh_autostart_exists = check_file_exists(SSH_AUTOSTART_PATH)
    lldpd_autostart_exists = check_file_exists(LLDPD_AUTOSTART_PATH)
    postgresql_autostart_exists = check_file_exists(POSTGRESQL_AUTOSTART_PATH)
    apache2_autostart_exists = check_file_exists(APACHE2_AUTOSTART_PATH)
    return jsonify({
        "autostart_exists": autostart_exists,
        "start_app_exists": start_app_exists,
        "ftp_autostart_exists": ftp_autostart_exists,
        "ssh_autostart_exists": ssh_autostart_exists,
        "lldpd_autostart_exists": lldpd_autostart_exists,
        "postgresql_autostart_exists": postgresql_autostart_exists,
        "apache2_autostart_exists": apache2_autostart_exists
    })

def get_ip_address():
    # Try to get the IP address from the eth0 interface
    interface = 'eth0'
    while True:
        try:
            # Get the IP address of the specified interface
            if interface in netifaces.interfaces():
                addrs = netifaces.ifaddresses(interface)
                if netifaces.AF_INET in addrs:
                    return addrs[netifaces.AF_INET][0]['addr']
            # Wait for the network to be up
            print("Waiting for network to be up...")
            time.sleep(2)  # Wait 2 seconds before retrying
        except Exception as e:
            print(f"Error getting IP address: {e}")
            time.sleep(2)  # Wait 2 seconds before retrying

def get_uptime():
    boot_time = datetime.datetime.fromtimestamp(psutil.boot_time())
    uptime_duration = datetime.datetime.now() - boot_time
    return uptime_duration


def is_app_running():
    try:
        pids = subprocess.check_output(["pgrep", "-f", "python3.*app.py"]).decode().strip().split()
        return bool(pids)
    except subprocess.CalledProcessError:
        return False

def check_service_status():
    try:
        output = subprocess.check_output(["systemctl", "is-active", "start_app_launcher.service"]).decode().strip()
        return output == "active"
    except subprocess.CalledProcessError:
        return False

@app.route('/')
def index():
    global start_time, debug_log
    ip_address = get_ip_address()
    uptime = get_uptime()
    app_running = is_app_running()
    service_running = check_service_status()
    if app_running and start_time is None:
        start_time = datetime.datetime.now()
    elif not app_running:
        start_time = None
    
    debug_log.append(f"{datetime.datetime.now()}: Checked app status. Running: {app_running}")
    debug_log.append(f"{datetime.datetime.now()}: Checked service status. Running: {service_running}")
    debug_log = debug_log[-10:]  # Keep only the last 10 log entries
    
    start_app_path = '/nsatt/storage/settings/start_app.nsatt'
    autostart_app_path = '/nsatt/storage/settings/autostart_app.nsatt'
    log_file = f"/nsatt/storage/logs/start_app_launcher_{datetime.datetime.now().strftime('%Y-%m-%d')}.log"
    
    rendered_template = render_template_string(html_template, 
                                               launcher_start_time=app.start_time, 
                                               start_time=start_time, 
                                               uptime=uptime, 
                                               ip_address=ip_address, 
                                               app_running=app_running, 
                                               service_running=service_running,
                                               debug_log="\n".join(debug_log))

    if not is_port_in_use(8080):
        for path in [start_app_path, autostart_app_path]:
            if os.path.exists(path):
                with open(log_file, 'a') as log:
                    log.write(f"{datetime.datetime.now()}: {os.path.basename(path)} file exists. Starting the application...\n")
                if path == start_app_path:
                    os.remove(path)
                start()
                with open(log_file, 'a') as log:
                    log.write(f"{datetime.datetime.now()}: Application start triggered and {os.path.basename(path)} file processed.\n")
    else:
        with open(log_file, 'a') as log:
            log.write(f"{datetime.datetime.now()}: Port 8080 is already active. Application start not triggered.\n")
    
    return rendered_template

@app.route('/status')
def status():
    app_running = is_app_running()
    return jsonify({"app_running": app_running, "debug_log": "\n".join(debug_log)})

@app.route('/start', methods=['POST'])
def start():
    global start_time, debug_log
    log_file_path = "/nsatt/storage/logs/debug.log"

    def log_message(message):
        """Log messages to the file and debug log."""
        debug_log.append(message)
        with open(log_file_path, "a") as log_file:
            log_file.write(f"{datetime.datetime.now()}: {message}\n")

    try:
        log_message("Attempting to start application...")

        # Ensure the log directory exists
        os.makedirs(os.path.dirname(log_file_path), exist_ok=True)

        # Run the launch script
        process = subprocess.run(
            f"/nsatt/storage/scripts/utility/launch_nsatt.sh",
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=15
        )

        if os.path.exists(SSH_AUTOSTART_PATH):
            start_ssh_service()
        if os.path.exists(FTP_AUTOSTART_PATH):
            start_ftp_service()
        if os.path.exists(LLDPD_AUTOSTART_PATH):
            start_lldpd_service()
        if os.path.exists(POSTGRESQL_AUTOSTART_PATH):
            start_postgresql_service()
        if os.path.exists(APACHE2_AUTOSTART_PATH):
            start_apache2_service()

        if process.returncode != 0:
            log_message(f"Launch script failed with return code {process.returncode}")
            log_message(f"STDOUT: {process.stdout}")
            log_message(f"STDERR: {process.stderr}")
            message = f"Failed to start NSATT Application. Error: {process.stderr}"
            return jsonify({"message": message}), 500

        log_message(f"Launch script executed successfully. STDOUT: {process.stdout}")

        # Check if the application has started
        start_time = datetime.datetime.now()
        for attempt in range(15):  # Check for up to 30 seconds
            if is_port_in_use(8080):
                log_message("Port 8080 is in use. Verifying HTTP response...")
                if is_http_responding():
                    log_message("Application is responding on port 8080.")
                    message = "NSATT Application has been started successfully."
                    return jsonify({"message": message}), 200
            log_message(f"Attempt {attempt + 1}: Port 8080 not ready. Retrying in 2 seconds...")
            time.sleep(2)

        message = "Application did not start within the expected time. Please check the logs."
        log_message(message)

    except subprocess.TimeoutExpired as timeout_err:
        log_message(f"Launch script timed out after 15 seconds: {str(timeout_err)}")
        message = "Launch script timed out. Please check the logs and try again."
        return jsonify({"message": message}), 500
    except Exception as e:
        log_message(f"Error starting application: {str(e)}")
        message = f"An unexpected error occurred: {str(e)}"
        return jsonify({"message": message}), 500

    return jsonify({"message": message}), 500

@app.route('/stop', methods=['POST'])
def stop():
    global start_time, debug_log
    try:
        pids = subprocess.check_output(["pgrep", "-f", "python3.*app.py"]).decode().strip().split()
        for pid in pids:
            os.kill(int(pid), signal.SIGTERM)

        #If the path doesn't exist, turn off the service.
        if not os.path.exists(SSH_AUTOSTART_PATH):
            stop_ssh_service()
        if not os.path.exists(FTP_AUTOSTART_PATH):
            stop_ftp_service()
        if not os.path.exists(LLDPD_AUTOSTART_PATH):
            stop_lldpd_service()
        if not os.path.exists(POSTGRESQL_AUTOSTART_PATH):
            stop_postgresql_service()
        if not os.path.exists(APACHE2_AUTOSTART_PATH):
            stop_apache2_service()

        start_time = None
        debug_log.append(f"{datetime.datetime.now()}: Application stopped successfully")
        message = "NSATT Application has been stopped successfully."
    except subprocess.CalledProcessError:
        debug_log.append(f"{datetime.datetime.now()}: No running application found to stop")
        message = "No running NSATT Application found to stop."
    except Exception as e:
        debug_log.append(f"{datetime.datetime.now()}: Error stopping application: {str(e)}")
        message = f"An error occurred while stopping the application: {str(e)}"
    return jsonify({"message": message})

@app.route('/restart', methods=['POST'])
def restart():
    subprocess.Popen(["sudo", "/nsatt/storage/scripts/utility/restart_app.sh"])
    debug_log.append(f"{datetime.datetime.now()}: NSATT is restarting...")
    return jsonify({"message": "NSATT is restarting..."})

# Restart Launcher
@app.route('/restart_launcher', methods=['POST'])
def restart_launcher():
    global debug_log
    log_file_path = "/nsatt/storage/logs/restart_launcher.log"
    try:
        debug_log.append(f"{datetime.datetime.now()}: Attempting to restart launcher...")
        with open(log_file_path, 'a') as log_file:
            log_file.write(f"{datetime.datetime.now()}: Attempting to restart launcher...\n")
        
        # Build the path to the 'restart_app.sh' script relative to this script's directory
        script_path = "/nsatt/storage/scripts/utility/restart_launcher.sh"
        
        # Make sure the script exists and is executable
        if not os.path.exists(script_path):
            error_message = f"Script {script_path} not found."
            debug_log.append(f"{datetime.datetime.now()}: {error_message}")
            with open(log_file_path, 'a') as log_file:
                log_file.write(f"{datetime.datetime.now()}: {error_message}\n")
            return jsonify({"error": error_message}), 500
        if not os.access(script_path, os.X_OK):
            error_message = f"Script {script_path} is not executable."
            debug_log.append(f"{datetime.datetime.now()}: {error_message}")
            with open(log_file_path, 'a') as log_file:
                log_file.write(f"{datetime.datetime.now()}: {error_message}\n")
            return jsonify({"error": error_message}), 500
        
        # Execute the script
        print(f"Script path: {script_path}")
        subprocess.Popen([script_path], shell=True)

        message = "Script is restarting..."
        debug_log.append(f"{datetime.datetime.now()}: {message}")
        with open(log_file_path, 'a') as log_file:
            log_file.write(f"{datetime.datetime.now()}: {message}\n")
        return jsonify({"message": message}), 200
    except Exception as e:
        error_message = f"Error restarting launcher: {str(e)}"
        debug_log.append(f"{datetime.datetime.now()}: {error_message}")
        with open(log_file_path, 'a') as log_file:
            log_file.write(f"{datetime.datetime.now()}: {error_message}\n")
        return jsonify({"error": error_message}), 500

def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0
    
def is_http_responding():
    try:
        response = requests.get('http://localhost:8080', timeout=3)
        return response.status_code == 200
    except requests.RequestException:
        return False
@app.route('/toggle_service', methods=['POST'])
def toggle_service():
    try:
        # Define service file path and name
        service_name = "start_app_launcher.service"
        service_path = f"/etc/systemd/system/{service_name}"
        
        # Log the attempt
        debug_log.append(f"{datetime.datetime.now()}: Attempting to toggle {service_name}")

        # Check if service exists and get status
        try:
            status = subprocess.run(
                ["service", "start_app_launcher", "status"],
                capture_output=True,
                text=True,
                check=True
            )
            service_exists = True
        except subprocess.CalledProcessError:
            service_exists = False

        if not service_exists:
            debug_log.append(f"{datetime.datetime.now()}: Service file not found, creating new service file")
            
            # Verify python3 exists
            try:
                python_path = subprocess.run(
                    ["which", "python3"],
                    capture_output=True,
                    text=True,
                    check=True
                ).stdout.strip()
            except subprocess.CalledProcessError:
                raise Exception("Python3 not found in system")
                
            # Verify script path exists
            script_path = "/nsatt/storage/scripts/utility/start_app_launcher.py"
            if not os.path.exists(script_path):
                raise Exception(f"Script not found at {script_path}")

            # Create service file content
            service_content = f"""[Unit]
Description=NSATT Application Launcher Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
ExecStart={python_path} {script_path}
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target"""

            try:
                # Write service file with error handling
                with open(service_path, 'w') as f:
                    f.write(service_content)
                
                # Verify file was written correctly
                if not os.path.exists(service_path):
                    raise Exception("Failed to create service file")
                    
                # Set proper permissions
                os.chmod(service_path, 0o644)
                
                # Reload systemd daemon and enable service
                subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
                subprocess.run(["sudo", "systemctl", "enable", service_name], check=True)
                debug_log.append(f"{datetime.datetime.now()}: Created and enabled {service_name}")
                
            except Exception as e:
                debug_log.append(f"{datetime.datetime.now()}: Error creating service file: {str(e)}")
                raise

        # Get current service status
        try:
            status = subprocess.run(
                ["service", "start_app_launcher", "status"],
                capture_output=True,
                text=True
            )
            current_status = "is running" in status.stdout
        except subprocess.CalledProcessError:
            current_status = False

        debug_log.append(f"{datetime.datetime.now()}: Current service status: {'running' if current_status else 'stopped'}")

        # Toggle service state with timeout
        if current_status:
            subprocess.run(["sudo", "service", "start_app_launcher", "stop"], check=True, timeout=30)
            message = "NSATT Service has been stopped. All NSATT components are now offline."
            debug_log.append(f"{datetime.datetime.now()}: {message}")
        else:
            subprocess.run(["sudo", "service", "start_app_launcher", "start"], check=True, timeout=30)
            
            # Verify service started successfully
            time.sleep(2)  # Give service time to start
            status = subprocess.run(
                ["service", "start_app_launcher", "status"],
                capture_output=True,
                text=True
            )
            if "is running" not in status.stdout:
                raise Exception("Service failed to start")
                
            message = "NSATT Service has been started. All NSATT components are initializing."
            debug_log.append(f"{datetime.datetime.now()}: {message}")

        return jsonify({"message": message, "success": True})
        
    except subprocess.TimeoutExpired:
        error_msg = "Operation timed out while managing service"
        debug_log.append(f"{datetime.datetime.now()}: {error_msg}")
        return jsonify({"message": error_msg, "success": False}), 504
        
    except subprocess.CalledProcessError as e:
        error_msg = f"Error toggling service: {str(e)}"
        debug_log.append(f"{datetime.datetime.now()}: {error_msg}")
        return jsonify({"message": error_msg, "success": False}), 500
        
    except Exception as e:
        error_msg = f"Error managing service: {str(e)}"
        debug_log.append(f"{datetime.datetime.now()}: {error_msg}")
        return jsonify({"message": error_msg, "success": False}), 500

@app.route('/shutdown', methods=['POST'])
def shutdown():
    global debug_log
    debug_log.append(f"{datetime.datetime.now()}: Initiating device shutdown")
    subprocess.Popen(["sudo", "shutdown", "-h", "now"])
    return jsonify({"message": "The device is shutting down. This page and all services will no longer be accessible."})

def autostart_services_check():
    #Check autostart files and trigger services if found and note in logs.
    if (os.path.exists(FTP_AUTOSTART_PATH)):
        subprocess.Popen(["sudo", "systemctl", "start", "vsftpd.service"])
        debug_log.append(f"{datetime.datetime.now()}: FTP Autostart file found. Starting vsftpd.service...")
    if (os.path.exists(SSH_AUTOSTART_PATH)):
        subprocess.Popen(["sudo", "systemctl", "start", "ssh.service"])
        debug_log.append(f"{datetime.datetime.now()}: SSH Autostart file found. Starting ssh.service...")
    if (os.path.exists(LLDPD_AUTOSTART_PATH)):
        subprocess.Popen(["sudo", "systemctl", "start", "lldpd.service"])
        debug_log.append(f"{datetime.datetime.now()}: LLDPD Autostart file found. Starting lldpd.service...")
    if (os.path.exists(POSTGRESQL_AUTOSTART_PATH)):
        subprocess.Popen(["sudo", "systemctl", "start", "postgresql.service"])
        debug_log.append(f"{datetime.datetime.now()}: PostgreSQL Autostart file found. Starting postgresql.service...")
    if (os.path.exists(APACHE2_AUTOSTART_PATH)):
        subprocess.Popen(["sudo", "systemctl", "start", "apache2.service"])
        

@app.route('/tutorial')
def tutorial():
    return render_template_string("""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>NSATT App Launcher Tutorial</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
        <style>
            body { background-color: #121212; color: #e0e0e0; }
            .container { max-width: 960px; }
            .card { background-color: #1e1e1e; border-color: #444; margin-bottom: 20px; }
            .card-header { background-color: #282828; border-bottom-color: #444; }
        </style>
    </head>
    <body>
        <div class="container mt-4">
            <header class="text-center mb-4">
                <h1 class="text-primary">NSATT App Launcher Tutorial</h1>
            </header>
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title mb-0">How to use the NSATT App Launcher</h3>
                </div>
                <div class="card-body">
                    <ol>
                        <li>
                            <strong>Starting the Application:</strong>
                            <ul>
                                <li>Click the "Start Application" button.</li>
                                <button class="btn btn-success btn-lg mb-2">Start Application</button>
                                <li>Confirm the action in the warning modal.</li>
                                <li>Once started, you'll see a link to access the application.</li>
                            </ul>
                        </li>
                        <br>
                        <li>
                            <strong>Stopping the Application:</strong>
                            <ul>
                                <li>Click the "Stop Application" button when the app is running.</li>
                                <button class="btn btn-danger btn-lg mb-2">Stop Application</button>
                                <li>Confirm the action in the warning modal.</li>
                            </ul>
                        </li>
                        <br>
                        <li>
                            <strong>Toggling the Service:</strong>
                            <ul>
                                <li>Use the "Stop Service" button to stop the NSATT service.</li>
                                <button class="btn btn-warning btn-lg mb-2">Stop Service</button>
                                <li>This affects all NSATT components, including the launcher.</li>
                                <li>Use with caution, as it will disrupt ongoing operations.</li>
                            </ul>
                        </li>
                        <br>
                        <li>
                            <strong>Shutting Down the Device:</strong>
                            <ul>
                                <li>Click the "Shutdown Device" button only when necessary.</li>
                                <button class="btn btn-danger btn-lg mb-2">Shutdown Device</button>
                                <li>This will power off the entire device and require physical access to restart.</li>
                                <li>Confirm carefully through multiple prompts.</li>
                            </ul>
                        </li>
                        <br>
                        <li>
                            <strong>Monitoring:</strong>
                            <ul>
                                <li>The System Information section shows launcher start time and system uptime.</li>
                                <li>The Debug Log displays recent actions and their timestamps.</li>
                            </ul>
                        </li>
                    </ol>
                </div>
            </div>
            <div class="card">
                <div class="card-header" style="text-align: center;">
                    <h3 class="card-title mb-0">Button Examples (Disabled for Demonstration)</h3>
                </div>
                <div class="card-body">
                    <button class="btn btn-success btn-lg mb-2" style="margin: auto;" disabled>Start Application</button>
                    <button class="btn btn-danger btn-lg mb-2" style="margin: auto;" disabled>Stop Application</button>
                    <button class="btn btn-warning btn-lg mb-2" style="margin: auto;" disabled>Stop Service</button>
                    <button class="btn btn-danger btn-lg mb-2" style="margin: auto;" disabled>Shutdown Device</button>
                </div>
            </div>
            <div class="text-center mt-4">
                <a href="{{ url_for('index') }}" class="btn btn-primary btn-lg">Back to Launcher</a>
            </div>
        </div>
        <footer class="text-center mt-4">
            <p>Visit <a href="https://www.tstp.xyz" target="_blank">TSTP.xyz</a> for more information</p>
        </footer>
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    </body>
    </html>
    """)

if __name__ == '__main__':
    app.start_time = datetime.datetime.now()
    autostart_services_check()
    app.run(host='0.0.0.0', port=8081, debug=True, use_reloader=False)