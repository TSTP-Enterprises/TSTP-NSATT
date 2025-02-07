document.addEventListener('DOMContentLoaded', (event) => {
    // Add any JavaScript code here for interactions
});


function stopScript() {
    fetch('/stop')
        .then(response => response.text())
        .then(data => alert(data))
        .catch(error => alert('Error: ' + error));
}


function updateServiceStatus(service) {
    fetch(`/control/${service}/status`)
        .then(response => response.json())
        .then(data => {
            const button = document.querySelector(`button[onclick="toggleService('${service}')"]`);
            button.classList.remove('green', 'red');
            if (data.status === 'active') {
                button.classList.add('green');
            } else {
                button.classList.add('red');
            }
        })
        .catch(error => console.error('Error:', error));
}

document.addEventListener('DOMContentLoaded', function() {
    const switchInfoPre = document.querySelector('.switch-info-pre');
    const toggleButton = document.querySelector('.toggle-switch-info');

    if (toggleButton) {
        toggleButton.addEventListener('click', function() {
            switchInfoPre.classList.toggle('collapsed');
        });
    }
});

function changeSwitchPortLight(action) {
    fetch(`/change_switch_port_light/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ port: 'GigabitEthernet1/0/1' })
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        alert(data.message);
    })
    .catch(error => {
        console.error('Error:', error);
        alert('An error occurred while changing the switch port light.');
    });
}

function fetchWirelessModes() {
    fetch('/network/wireless_modes')
        .then(response => response.json())
        .then(data => {
            const modeContainer = document.getElementById('wireless-modes').querySelector('.button-group');
            modeContainer.innerHTML = ''; // Clear any previous content

            if (data.error) {
                modeContainer.innerHTML = `<p>${data.error}</p>`;
            } else {
                data.modes.forEach(mode => {
                    const button = document.createElement('button');
                    button.type = 'button';
                    button.className = mode.status.toLowerCase() === 'monitor' ? 'button blue' : 'button green';
                    button.innerText = `${mode.interface} (${mode.status})`;
                    button.onclick = () => toggleWirelessMode(mode.interface, mode.status);

                    modeContainer.appendChild(button);
                });
            }
        })
        .catch(error => console.error('Error fetching wireless modes:', error));
}

function toggleWirelessMode(interface, currentMode) {
    const newMode = currentMode === 'monitor' ? 'managed' : 'monitor';
    fetch(`/network/wireless_mode/${interface}/${newMode}`)
        .then(response => response.text())
        .then(data => {
            alert(data);
            fetchWirelessModes(); // Refresh the list
        })
        .catch(error => alert('Error: ' + error));
}