document.addEventListener('DOMContentLoaded', function() {
    // Fetch and update the status of services without showing messages
    const services = ['apache2', 'ssh', 'vsftpd', 'lldpd', 'postgresql'];
    services.forEach(service => updateServiceStatus(service, false));

    // Fetch and populate network adapters without showing messages
    fetchNetworkAdapters();

    // Fetch and update wireless modes without showing messages
    fetchWirelessModes();

    // Fetch and update hotspot status without showing messages
    updateHotspotStatus();
});

function toggleService(service) {
    fetch(`/control/${service}/status`)
        .then(response => {
            if (!response.ok) {
                return response.text().then(text => {
                    throw new Error(text || 'Unknown error occurred');
                });
            }
            return response.json();
        })
        .then(data => {
            const action = data.status === 'active' ? 'stop' : 'start';
            return fetch(`/control/${service}/${action}`);
        })
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
            updateServiceStatus(service, true);
        })
        .catch(error => {
            showMessage('Error toggling service: ' + error.message);
        });
}

function restartScript() {
    // Display the "Script Restarting" page with detailed styling and explanation
    document.body.innerHTML = `
        <div class="container">
            <header>
                <div class="info-container">
                    <h1>TSTP Network Scan-Attack-Test Tool (NSATT)</h1>
                    <div class="section-container centered" style="text-align: center;">
                        <h2>Script Restarting</h2>
                    </div>
                </div>
            </header>
            <div class="info-container">
                <p>The script is currently restarting. During this time, you will not be able to control the services, use MSFConsole, perform wireless scans, get network information, or run nmap scans. Please wait for the script to come back online.</p>
                <p>The following services will still be running, but you will not be able to control them:</p>
                <div class="section-container">
                    <h2>Services Status</h2>
                    <table class="table-container">
                        <thead>
                            <tr>
                                <th>Service</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody id="services-status">
                            <tr>
                                <td>Apache2 (HTTP)</td>
                                <td id="apache2-status">Checking...</td>
                            </tr>
                            <tr>
                                <td>SSH</td>
                                <td id="ssh-status">Checking...</td>
                            </tr>
                            <tr>
                                <td>VSFTPD (FTP)</td>
                                <td id="vsftpd-status">Checking...</td>
                            </tr>
                            <tr>
                                <td>LLDPD</td>
                                <td id="lldpd-status">Checking...</td>
                            </tr>
                            <tr>
                                <td>PostgreSQL</td>
                                <td id="postgresql-status">Checking...</td>
                            </tr>
                        </tbody>
                    </table>
                    <div style="text-align: center;">
                        <button class="button blue" style="width: 300px;" onclick="window.location.href='http://${window.location.hostname}:8081'">Go to Main Page</button>
                    </div>
                </div>
                <p>Page will refresh in <span id="countdown">10</span> seconds...</p>
                <p>If the page does not refresh automatically, <a href="http://${window.location.hostname}:8080/settings">click here</a> to go to the settings page.</p>
            </div>
        </div>
    `;

    // Countdown timer for page refresh
    let countdown = 10;
    const countdownElement = document.getElementById('countdown');
    const interval = setInterval(() => {
        countdown -= 1;
        countdownElement.textContent = countdown;
        if (countdown === 0) {
            clearInterval(interval);
            location.reload();
        }
    }, 1000);

    // Fetch and update the status of services
    const services = ['apache2', 'ssh', 'vsftpd', 'lldpd', 'postgresql'];
    services.forEach(service => {
        fetch(`/control/${service}/status`)
            .then(response => response.json())
            .then(data => {
                const statusElement = document.getElementById(`${service}-status`);
                if (data.status === 'active') {
                    statusElement.textContent = 'Running';
                } else {
                    statusElement.textContent = 'Stopped';
                }
            })
            .catch(error => {
                const statusElement = document.getElementById(`${service}-status`);
                statusElement.textContent = 'Error';
            });
    });

    fetch('/restart')
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
        })
        .catch(error => {
            showMessage('Error restarting script: ' + error.message);
        });
}

function stopScript() {
    fetch('/stop')
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
        })
        .catch(error => {
            showMessage('Error stopping script: ' + error.message);
        });
}

function restartDevice() {
    if (confirm('Are you sure you want to restart the device?')) {
        fetch('/control/restart_device')
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
            })
            .catch(error => {
                showMessage('Error restarting device: ' + error.message);
            });
    }
}

function updateServiceStatus(service, fromToggleService = false) {
    fetch(`/control/${service}/status`)
        .then(response => {
            if (!response.ok) {
                return response.text().then(text => {
                    throw new Error(text || 'Unknown error occurred');
                });
            }
            return response.json();
        })
        .then(data => {
            const button = document.querySelector(`button[data-service="${service}"]`);
            if (button) {
                button.classList.remove('green', 'red');
                if (data.status === 'active') {
                    button.classList.add('green');
                    button.innerText = `${service.toUpperCase()} (Running)`;
                } else {
                    button.classList.add('red');
                    button.innerText = `${service.toUpperCase()} (Stopped)`;
                }
                if (fromToggleService) {
                    showMessage(`Service ${service} status updated successfully.`);
                    setTimeout(() => updateServiceStatus(service), 5000);
                }
            } else {
                console.error(`Button for service ${service} not found.`);
            }
        })
        .catch(error => {
            showMessage('Error updating service status: ' + error.message);
        });
}

function startServiceStatusUpdate(service) {
    updateServiceStatus(service);
    setInterval(() => updateServiceStatus(service), 5000);
}

function fetchNetworkAdapters() {
    fetch('/network/adapters')
        .then(response => response.json())
        .then(data => {
            const adapterContainer = document.getElementById('network-adapters').querySelector('.button-group');
            const adapterSelect = document.getElementById('network-adapter-select');
            adapterContainer.innerHTML = ''; // Clear any previous content
            adapterSelect.innerHTML = '<option value="">-- Select Adapter --</option>'; // Reset the dropdown

            data.adapters.forEach(adapter => {
                // Populate the network adapters section with buttons
                const button = document.createElement('button');
                button.type = 'button';
                button.className = adapter.status === 'up' ? 'button green' : 'button red';
                button.innerText = adapter.name;
                button.onclick = () => toggleNetworkAdapter(adapter.name);
                adapterContainer.appendChild(button);

                // Populate the dropdown for selecting the adapter for wireless modes
                const option = document.createElement('option');
                option.value = adapter.name;
                option.innerText = adapter.name;
                adapterSelect.appendChild(option);
            });
        })
        .catch(error => console.error('Error fetching network adapters:', error));
}

function toggleNetworkAdapter(adapterName) {
    fetch(`/network/adapter/${adapterName}/toggle`)
        .then(response => response.text())
        .then(data => {
            alert(data);  // Show the result of the toggle action
            fetchNetworkAdapters(); // Refresh the list to update the button color and status
        })
        .catch(error => showMessage('Error toggling network adapter: ' + error.message));
}

function fetchWirelessModes() {
    fetch('/network/wireless_modes')
        .then(response => {
            if (!response.ok) {
                return response.text().then(text => {
                    try {
                        const data = JSON.parse(text);
                        throw new Error(data.error || 'Unknown error occurred');
                    } catch (e) {
                        throw new Error('Error parsing response: ' + text);
                    }
                });
            }
            return response.json();
        })
        .then(data => {
            const modeContainer = document.getElementById('wireless-modes').querySelector('.button-group');
            modeContainer.innerHTML = ''; // Clear any previous content

            if (data.error) {
                modeContainer.innerHTML = `<p>${data.error}</p>`;
            } else if (Array.isArray(data.modes)) {
                data.modes.forEach(mode => {
                    const button = document.createElement('button');
                    button.type = 'button';
                    button.className = mode.status.toLowerCase() === 'monitor' ? 'button green' : 'button blue';
                    button.innerText = `${mode.interface} (${mode.status})`;
                    button.onclick = () => toggleWirelessMode(mode.interface, mode.status.toLowerCase());

                    modeContainer.appendChild(button);
                });
            } else {
                modeContainer.innerHTML = `<p>Unexpected data format</p>`;
            }
        })
        .catch(error => alert('Error fetching wireless modes: ' + error.message));
}

function toggleWirelessMode(interface, currentMode) {
    const newMode = currentMode === 'monitor' ? 'managed' : 'monitor';
    fetch(`/network/toggle_wireless_mode/${interface}/${currentMode}`, { method: 'POST' })
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                showMessage('Error toggling wireless mode: ' + data.error);
            } else {
                showMessage(data.message);
                fetchWirelessModes();
                fetchNetworkAdapters();
            }
        })
        .catch(error => showMessage('Error toggling wireless mode: ' + error.message));
}

function toggleVisibility(sectionId, toggle = true) {
    const section = document.getElementById(sectionId);
    if (toggle) {
        section.classList.toggle('hidden');
    } else {
        section.classList.add('hidden');
    }
}

function modifyWiredSettings() {
    fetch('/network/wired_settings')
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                alert(`Error fetching wired settings: ${data.error} - Data: ${data.raw_data || 'undefined'}`);
            } else {
                alert(`Current IP: ${data.ip}\nSubnet Mask: ${data.subnet_mask}\nGateway: ${data.gateway}`);
                // Additional UI logic can be added here to modify the settings
            }
        })
        .catch(error => {
            console.error('Error fetching wired settings:', error);
            showMessage(`Error fetching wired settings: ${error.message} - Data: ${error.raw_data || 'undefined'}`);
        });
}

function scanForWirelessNetworks() {
    const adapter = document.getElementById('network-adapter-select').value;
    if (!adapter) {
        showMessage('Please select a network adapter before scanning.');
        return;
    }

    // Scan for available wireless networks using the selected adapter
    fetch(`/network/scan_wireless?adapter=${adapter}`)
        .then(response => response.json())
        .then(data => {
            const wirelessList = document.getElementById('wireless-networks-list');
            wirelessList.innerHTML = ''; // Clear previous list

            const table = document.createElement('table');
            const header = document.createElement('tr');
            header.innerHTML = `
                <th>Network Name</th>
                <th>Signal Strength</th>
                <th>Encryption Type</th>
                <th>Action</th>
            `;
            table.appendChild(header);

            data.networks.forEach(network => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${network.ssid}</td>
                    <td>${network.signal_strength}%</td>
                    <td>${network.security}</td>
                    <td><button class="button info" onclick="connectToWireless('${network.ssid}')">Connect</button></td>
                `;
                table.appendChild(row);
            });

            wirelessList.appendChild(table);
        })
        .catch(error => showMessage('Error scanning for wireless networks: ' + error.message));
}

function connectToWireless(ssid) {
    const adapter = document.getElementById('network-adapter-select').value;
    const password = prompt('Enter password for ' + ssid + ':');
    
    if (!adapter) {
        showMessage('Please select a network adapter.');
        return;
    }

    fetch(`/network/connect_wireless/${encodeURIComponent(ssid)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: password, adapter: adapter })
    })
    .then(response => response.json())
    .then(data => {
        if (response.ok) {
            showMessage(data.message);
        } else {
            showMessage(`Failed to connect: ${data.message}`);
        }
    })
    .catch(error => showMessage('Error connecting to wireless network: ' + error.message));
}


function enableScanButton() {
    const adapterSelect = document.getElementById('network-adapter-select');
    const scanButton = document.getElementById('scan-button');
    scanButton.disabled = adapterSelect.value === '';
}

function toggleHotspot() {
    fetch('/network/toggle_hotspot')
        .then(response => {
            if (!response.ok) {
                return response.json().then(data => {
                    throw new Error(data.error || 'Unknown error occurred');
                });
            }
            return response.json();
        })
        .then(data => {
            showMessage(data.message);
            updateHotspotStatus();
        })
        .catch(error => showMessage('Error toggling hotspot: ' + error.message));
}

function updateHotspotStatus() {
    fetch('/network/hotspot_status')
        .then(response => {
            if (!response.ok) {
                return response.json().then(data => {
                    throw new Error(data.error || 'Unknown error occurred');
                });
            }
            return response.json();
        })
        .then(data => {
            const hotspotStatus = document.getElementById('hotspot-status');
            const hotspotButton = document.querySelector('button[onclick="toggleHotspot()"]');
            if (data.is_running) {
                hotspotStatus.innerText = 'Hotspot is running';
                hotspotButton.classList.remove('blue');
                hotspotButton.classList.add('green');
            } else {
                hotspotStatus.innerText = 'Hotspot is not running';
                hotspotButton.classList.remove('green');
                hotspotButton.classList.add('blue');
            }
        })
        .catch(error => showMessage('Error fetching hotspot status: ' + error.message));
}

// Tailscale VPN Functions
async function checkTailscaleStatus() {
    try {
        const response = await fetch('/api/vpn/status');
        const data = await response.json();
        
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        const installButton = document.getElementById('install-tailscale');
        const enableButton = document.getElementById('enable-tailscale');
        const disableButton = document.getElementById('disable-tailscale');
        const configDiv = document.getElementById('tailscale-config');
        
        if (!data.installed) {
            statusDiv.textContent = data.message;
            statusDiv.className = 'status-message warning';
            installButton.style.display = 'inline-block';
            enableButton.style.display = 'none';
            disableButton.style.display = 'none';
            configDiv.style.display = 'none';
            return;
        }
        
        installButton.style.display = 'none';
        configDiv.style.display = 'block';
        
        if (data.status.error) {
            statusDiv.textContent = `Error: ${data.status.error}`;
            statusDiv.className = 'status-message error';
            return;
        }
        
        const isConnected = data.status.BackendState === 'Running';
        statusDiv.textContent = `Status: ${isConnected ? 'Connected' : 'Disconnected'}`;
        statusDiv.className = `status-message ${isConnected ? 'success' : 'warning'}`;
        
        enableButton.style.display = isConnected ? 'none' : 'inline-block';
        disableButton.style.display = isConnected ? 'inline-block' : 'none';
        
        // Update configuration fields
        if (data.status.Self) {
            document.getElementById('hostname').value = data.status.Self.HostName || '';
        }
        
        // Load current configuration
        const configResponse = await fetch('/api/vpn/config');
        const configData = await configResponse.json();
        
        if (!configData.error) {
            document.getElementById('advertise-routes').value = configData.AdvertiseRoutes || '';
            document.getElementById('accept-routes').value = configData.AcceptRoutes || '';
            document.getElementById('accept-dns').checked = configData.AcceptDNS || false;
            document.getElementById('shields-up').checked = configData.ShieldsUp || false;
        }
        
    } catch (error) {
        console.error('Error checking Tailscale status:', error);
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        statusDiv.textContent = `Error: ${error.message}`;
        statusDiv.className = 'status-message error';
    }
}

async function installTailscale() {
    try {
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        statusDiv.textContent = 'Installing Tailscale...';
        statusDiv.className = 'status-message warning';
        
        const response = await fetch('/api/vpn/install', { method: 'POST' });
        const data = await response.json();
        
        if (data.success) {
            statusDiv.textContent = data.message;
            statusDiv.className = 'status-message success';
            setTimeout(checkTailscaleStatus, 2000);
        } else {
            statusDiv.textContent = `Installation failed: ${data.error}`;
            statusDiv.className = 'status-message error';
        }
    } catch (error) {
        console.error('Error installing Tailscale:', error);
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        statusDiv.textContent = `Error: ${error.message}`;
        statusDiv.className = 'status-message error';
    }
}

async function toggleTailscale(action) {
    try {
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        statusDiv.textContent = `${action === 'up' ? 'Enabling' : 'Disabling'} Tailscale...`;
        statusDiv.className = 'status-message warning';
        
        const response = await fetch('/api/vpn/toggle', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ action })
        });
        
        const data = await response.json();
        
        if (data.success) {
            statusDiv.textContent = data.message;
            statusDiv.className = 'status-message success';
            setTimeout(checkTailscaleStatus, 2000);
        } else {
            statusDiv.textContent = `Error: ${data.error}`;
            statusDiv.className = 'status-message error';
        }
    } catch (error) {
        console.error('Error toggling Tailscale:', error);
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        statusDiv.textContent = `Error: ${error.message}`;
        statusDiv.className = 'status-message error';
    }
}

async function updateTailscaleConfig() {
    try {
        const config = {
            hostname: document.getElementById('hostname').value,
            'advertise-routes': document.getElementById('advertise-routes').value,
            'accept-routes': document.getElementById('accept-routes').value,
            'accept-dns': document.getElementById('accept-dns').checked,
            'shields-up': document.getElementById('shields-up').checked
        };
        
        const response = await fetch('/api/vpn/config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(config)
        });
        
        const data = await response.json();
        
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        if (data.success) {
            statusDiv.textContent = data.message;
            statusDiv.className = 'status-message success';
            setTimeout(checkTailscaleStatus, 2000);
        } else {
            statusDiv.textContent = `Error: ${data.error}`;
            statusDiv.className = 'status-message error';
        }
    } catch (error) {
        console.error('Error updating Tailscale config:', error);
        const statusDiv = document.querySelector('#tailscale-status .status-message');
        statusDiv.textContent = `Error: ${error.message}`;
        statusDiv.className = 'status-message error';
    }
}

// Add event listener to check Tailscale status when VPN settings section is shown
document.addEventListener('DOMContentLoaded', function() {
    const vpnButton = document.querySelector('button[onclick="toggleVisibility(\'vpn-settings\')"]');
    if (vpnButton) {
        vpnButton.addEventListener('click', function() {
            setTimeout(checkTailscaleStatus, 100);
        });
    }
});
